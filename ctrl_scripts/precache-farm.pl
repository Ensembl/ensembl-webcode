#! /usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);

BEGIN { require "$Bin/../conf/includeSiteDefs.pl" }

use Getopt::Long;
use JSON;

# Command line options
my ($list, @subparts);
my $max_submissions = 2;
my $max_array_size = 75;
my $verbose = 0;
my $resume = 0;
# Note: keep concurrent jobs (max_submissions*max_array_size) < 200 to avoid db connection errors
GetOptions(
  'l|list' => \$list,
  's|subparts=s' => \@subparts,
  'submissions=i' => \$max_submissions,
  'array_size=i' => \$max_array_size,
  'verbose|v' => \$verbose,
  'resume|r' => \$resume,
  'help|h' => sub { print_usage(); exit 0; }
);

sub print_usage {
  print <<USAGE;
Usage: $0 [options] [types...]

Options:
  -l, --list              List available precache types
  -s, --subparts STR      Limit to specific subparts
  --submissions INT       Max. concurrent job array submissions (default: $max_submissions)
  --array_size INT        Max. number of jobs in each array (default: $max_array_size)
  -v, --verbose           Print more details about job submissions
  -r, --resume            Resume from previous submission session
  -h, --help              Print this help message
USAGE
}

if ($list) {
  print qx($Bin/precache.pl --mode=list);
  exit 0;
}

# Prepare for indexing
my @params;
push @params, "-s $_" for (@subparts);
push @params, @ARGV;

qx($Bin/precache.pl --mode=start @params);

my @jobs = @ARGV;
if (!@jobs) {
  @jobs = split('\n', qx($Bin/precache.pl --mode=list));
}

foreach my $j (@jobs) {
  print "Preparing $j\n";
  qx($Bin/precache.pl --mode=prepare $j);
}

open(SPEC, '<', "$SiteDefs::ENSEMBL_PRECACHE_DIR/spec") or die $!;
my $jobs;
{ local $/ = undef; $jobs = JSON->new->decode(<SPEC>); }
close SPEC;
die "No jobs in spec file" unless $jobs;

my $njobs = scalar @$jobs;

# Set up library paths for precache script
my @lib_dirs;
my @plugins = reverse @{$SiteDefs::ENSEMBL_PLUGINS};
while (my ($dir, $name) = splice @plugins, 0, 2) {
  push @lib_dirs, "$dir/modules";
}
push @lib_dirs, @$SiteDefs::ENSEMBL_API_LIBS;
my $libs = join(' ', map { "-I $_" } @lib_dirs);

# Job tracking state
my %job_ids;
my %retry_count;
my %job_resources;
my %completed_jobs;
my $max_retries = 3;
my $log_dir = "$SiteDefs::ENSEMBL_PRECACHE_DIR/logs";
mkdir $log_dir unless -d $log_dir;
my $job_file = "$log_dir/slurm_jobs_state.json";

# Resource limits (in GB and hours)
my $default_mem = 16;
my $default_time = 2;
my $max_mem = 32;
my $max_time = 8;

# Cancel running jobs on exit
sub stop_jobs {
  print "Stopping jobs...\n";
  system("scancel $_") for values %job_ids;
  print "Logs are in $log_dir\n";
  exit 1;
}
$SIG{INT} = $SIG{TERM} = \&stop_jobs;

# Load previous job state when resuming
if ($resume && -f $job_file) {
  open(my $fh, '<', $job_file) or do {
    warn "Cannot open job file $job_file: $!";
    return;
  };
  my $data = eval { JSON->new->decode(do { local $/; <$fh> }) };
  if ($@) {
    warn "Error parsing job file $job_file: $@";
    close $fh;
    return;
  }
  close $fh;
  %job_ids = %{$data->{jobs} || {}};
  %retry_count = %{$data->{retries} || {}};
  %job_resources = %{$data->{resources} || {}};
  %completed_jobs = %{$data->{completed} || {}};
  print "Resumed from previous state with ".(scalar keys %job_ids)." running jobs\n";
} elsif (-d $log_dir) {
  system("rm -rf $log_dir/*");
}

# Save current job state to disk
sub save_status {
  open(my $fh, '>', $job_file) or die $!;
  print $fh JSON->new->encode({
    jobs => \%job_ids,
    retries => \%retry_count,
    resources => \%job_resources,
    completed => \%completed_jobs
  });
  close $fh;
}

# Print current progress
sub print_status {
  my $done = scalar keys %completed_jobs;
  my $submitted = scalar keys %job_ids;
  my $failed = scalar grep { $retry_count{$_} > $max_retries } keys %retry_count;
  printf("Status: %d/%d (%d%%) done, %d submitted, %d failed\n",
         $done, $njobs, $done * 100 / $njobs, $submitted, $failed);
}

# Check error logs for failed jobs
sub check_job_logs {
  my ($job_id) = @_;
  my ($master_id, $task_id) = $job_id =~ /(\d+)_(\d+)/;
  return unless $master_id && $task_id;

  my $error_file = "$log_dir/slurm-${master_id}_${task_id}.err";
  my $output_file = "$log_dir/slurm-${master_id}_${task_id}.out";
  
  print "\nJob array task $task_id (master job $master_id) error log:";
  if (-f $error_file) {
    print "\n=== First 10 lines of stderr ===";
    system("head -n 10 $error_file");
  }
  if (-f $output_file) {
    print "\n=== First 10 lines of stdout ===";
    system("head -n 10 $output_file");
  }
}

# Increase resource limits for failed jobs
sub get_adjusted_resources {
  my ($idx, $state) = @_;
  my $current = $job_resources{$idx} || {mem => $default_mem, time => $default_time};
  $state ||= '';

  if ($state eq 'OUT_OF_MEMORY') {
    my $mem = $current->{mem} * 2;
    $mem = $mem > $max_mem ? $max_mem : $mem;
    return {%$current, mem => $mem};
  }

  if ($state eq 'TIMEOUT') {
    my $time = $current->{time} * 2;
    $time = $time > $max_time ? $max_time : $time;
    return {%$current, time => $time};
  }
  return $current;
}

# Resubmit failed jobs
sub handle_job_failure {
  my ($idx, $job_id, $state) = @_;
  warn "Job $job_id-$idx failed with $state (attempt $retry_count{$idx}/$max_retries)\n";

  if ($state eq 'OUT_OF_MEMORY' || $state eq 'TIMEOUT') {
    $job_resources{$idx} = get_adjusted_resources($idx, $state);
    $verbose && print "Increasing resources to $job_resources{$idx}{mem}GB/$job_resources{$idx}{time}h\n";
  } else {
    check_job_logs($job_id);
  }

  if ($retry_count{$idx} >= $max_retries) {
    $verbose && print "Giving up on resubmitting job $job_id-$idx\n";
    delete $job_ids{$idx};
    delete $job_resources{$idx};
    save_status();
    return 0;
  }
  delete $job_ids{$idx};
  return submit_job($idx);
}

# Submit a job array
sub submit_job {
  my ($start_idx, $end_idx) = @_;
  return 0 unless defined $start_idx;
  $end_idx ||= $start_idx;
  
  my $array_size = $end_idx - $start_idx + 1;
  my $resources = get_adjusted_resources($start_idx);
  
    my $cmd = qq{sbatch --parsable --array=$start_idx-$end_idx }.
            qq{--output=$log_dir/slurm-%A_%a.out --error=$log_dir/slurm-%A_%a.err }.
            qq{--time=$resources->{time}:00:00 --mem=$resources->{mem}G }.
            qq{--wrap='perl $libs $Bin/precache.pl --mode=index --index=\$SLURM_ARRAY_TASK_ID'};
  
  $verbose && print "Submitting: $cmd\n";

  chomp(my $array_job_id = qx($cmd));
  if ($?) {
    warn "sbatch command failed with status $?";
    return 0;
  }

  # Register submitted jobs for tracking
  for my $idx ($start_idx..$end_idx) {
    $job_ids{$idx} = "${array_job_id}_$idx";
    $retry_count{$idx}++;
  }
  save_status();
  return 1;
}

# Return current state of a job
sub get_job_state {
  my ($job_id) = @_;
  my $cmd = "sacct -j $job_id --format=state -n --parsable2 | head -n1";
  chomp(my $state = qx($cmd));
  $state =~ s/\s+//g;
  return $state || 'UNKNOWN';
}

print "Submitting $njobs precache jobs in $max_submissions\*$max_array_size batches...\n";

# Process & monitor all jobs
while (1) {
  my @pending;
  my $last_idx = -1;
  my $array_size = 0;
  
  # Group consecutive indexes into job arrays
  for my $idx (0..$njobs-1) {
    next if exists $job_ids{$idx} || exists $completed_jobs{$idx} || exists $retry_count{$idx};
    # Start new array if sequence breaks or max size reached
    if ($last_idx == -1 || $idx != $last_idx + 1 || $array_size >= $max_array_size) {
      if ($array_size > 0) {
        push @pending, [$last_idx - $array_size + 1, $last_idx];
      }
      $array_size = 1;
    } else {
      $array_size++;
    }
    $last_idx = $idx;
  }
  # Add final array group
  push @pending, [$last_idx - $array_size + 1, $last_idx] if $array_size > 0;

  # Submit array jobs up to concurrent submissions limit
  while (@pending && (scalar keys %job_ids) < ($max_submissions*$max_array_size)) {
    my ($start, $end) = @{shift @pending};
    submit_job($start, $end);
  }

  # Check state of all submitted jobs
  for my $idx (keys %job_ids) {
    my $job_id = $job_ids{$idx};
    
    # Get the state of a single job (from job array)
    my $state = get_job_state($job_id);

    if ($state =~ /^(FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY)$/) {
      handle_job_failure($idx, $job_id, $state);
    } elsif ($state eq 'COMPLETED') {
      # Check exit code
      if (system("sacct -j $job_id --format=exitcode -n | grep -q '0:0'") == 0) {
        delete $job_ids{$idx};
        delete $retry_count{$idx};
        delete $job_resources{$idx};
        $completed_jobs{$idx} = 1;
        save_status();
      } else {
        handle_job_failure($idx, $job_id, "completed with non-zero exit code");
      }
    }
  }

  print_status();
  last unless %job_ids || @pending;
  sleep 30;
}

print "Doing mode=end...\n";
qx($Bin/precache.pl --mode=end);
1;
