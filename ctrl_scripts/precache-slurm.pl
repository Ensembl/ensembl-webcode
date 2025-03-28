#! /usr/bin/env perl

# Script to manage and submit SLURM jobs for generating precaches
# Handles job submission, monitoring, and automatic retry on failure

use strict;
use warnings;

use FindBin qw($Bin);

BEGIN { require "$Bin/../conf/includeSiteDefs.pl" }

use Getopt::Long;
use JSON;

# Command line options
my ($list, @subparts);
my $workers = 10;
my $verbose = 0;
my $resume = 0;

GetOptions(
  'l' => \$list,
  's=s' => \@subparts,
  'workers=i' => \$workers,
  'verbose|v' => \$verbose,
  'resume' => \$resume
);
if ($list) {
  print qx($Bin/precache.pl --mode=list);
  exit 0;
}
my @params;
push @params, "-s $_" for (@subparts);
push @params, @ARGV;

qx($Bin/precache.pl --mode=start @params);

my @jobs = @ARGV;
if (!@jobs) {
  @jobs = split('\n', qx($Bin/precache.pl --mode=list));
}

foreach my $j (@jobs) {
  warn "preparing $j\n";
  qx($Bin/precache.pl --mode=prepare $j);
}

open(SPEC, '<', "$SiteDefs::ENSEMBL_PRECACHE_DIR/spec") or die $!;
my $jobs;
{ local $/ = undef; $jobs = JSON->new->decode(<SPEC>); }
close SPEC;
die "No jobs in spec" unless $jobs;

my $njobs = @$jobs;

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
my %job_resources;  # Track resources per job
my %completed_jobs; # Track successfully completed jobs
my $max_retries = 2;
my $job_file = "$SiteDefs::ENSEMBL_PRECACHE_DIR/running_jobs.json";

# Resource limits (in GB and hours)
my $default_mem = 8;
my $default_time = 2;
my $max_mem = 32;
my $max_time = 8;

# Log directory for job output
my $log_dir = "$SiteDefs::ENSEMBL_PRECACHE_DIR/logs";
mkdir $log_dir unless -d $log_dir;

# Increase resource limits for failed jobs
sub get_adjusted_resources {
  my ($idx, $state) = @_;
  my $current = $job_resources{$idx} || {mem => $default_mem, time => $default_time};

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

# Cancel running jobs on exit
sub cleanup {
  warn "Cleaning up...\n";
  system("scancel $_") for values %job_ids;
  unlink $job_file;
  exit 1;
}
$SIG{INT} = $SIG{TERM} = \&cleanup;

# Load previous job state when resuming
if (-f $job_file) {
  open(my $fh, '<', $job_file) or die $!;
  my $data = JSON->new->decode(do { local $/; <$fh> });
  close $fh;
  %job_ids = %{$data->{jobs} || {}};
  %retry_count = %{$data->{retries} || {}};
  %job_resources = %{$data->{resources} || {}};
  %completed_jobs = %{$data->{completed} || {}};
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
  my $failed = scalar grep { $retry_count{$_} >= $max_retries } keys %retry_count;
  printf("Status: %d/%d (%d%%) done, %d submitted, %d failed\n",
         $done, $njobs, $done * 100 / $njobs, $submitted, $failed);
}

# Check error logs for failed jobs
sub check_job_logs {
  my ($job_id) = @_;
  # Split array job ID into master_id and task_id
  my ($master_id, $task_id) = $job_id =~ /(\d+)_(\d+)/;
  return unless $master_id && $task_id;

  my $error_file = "$log_dir/slurm-${master_id}_${task_id}.err";
  my $output_file = "$log_dir/slurm-${master_id}_${task_id}.out";
  
  warn "\nJob array task $task_id (master job $master_id) error log:";
  if (-f $error_file) {
    warn "\n=== Last 10 lines of stderr ===";
    system("tail -n 10 $error_file");
  }
  if (-f $output_file) {
    warn "\n=== Last 10 lines of stdout ===";
    system("tail -n 10 $output_file");
  }
}

# Resubmit failed jobs
sub handle_job_failure {
  my ($idx, $job_id, $reason) = @_;
  warn "Job $job_id for index $idx $reason (attempt $retry_count{$idx}/$max_retries)\n";
  
  # Add log checking
  check_job_logs($job_id);

  if ($retry_count{$idx} >= $max_retries) {
    delete $job_ids{$idx};
    delete $job_resources{$idx};
    save_status();
    return 0;
  }
  delete $job_ids{$idx};
  return handle_job($idx, $idx);
}

# Return current state of a job
sub get_job_state {
  my ($job_id) = @_;
  my $cmd = "sacct -j $job_id --format=state -n --parsable2 | head -n1";
  chomp(my $state = qx($cmd));
  warn $state;

  return 'UNKNOWN' unless $state && $state =~ /\S/;
  return (split '|', $state =~ s/\s+//g)[0] || 'UNKNOWN';
}

# Process a single job or job array
sub handle_job {
  my ($start_idx, $end_idx) = @_;
  return 0 unless defined $start_idx;
  
  my $array_size = $end_idx - $start_idx + 1;
  my $resources = {mem => $default_mem, time => $default_time};
  
  # Submit as job array
  my $cmd = qq{sbatch --parsable } .
            qq{--array=$start_idx-$end_idx } .
            qq{--output=$log_dir/slurm-%A_%a.out } .
            qq{--error=$log_dir/slurm-%A_%a.err } .
            qq{--time=$resources->{time}:00:00 --mem=$resources->{mem}G } .
            qq{--wrap="perl $libs $Bin/precache.pl --mode=index --index=\$SLURM_ARRAY_TASK_ID"};
  $verbose && warn $cmd;

  chomp(my $array_job_id = qx($cmd));
  die "sbatch failed: $!" if $?;
  die "Invalid job ID" unless $array_job_id =~ /^\d+$/;

  # Track array job
  for my $idx ($start_idx..$end_idx) {
    $job_ids{$idx} = "${array_job_id}_$idx";
    $retry_count{$idx}++;
  }
  save_status();
  return 1;
}

# Pick next job to run
sub get_next_job {
  for my $idx (0..$#$jobs) {
    return $idx if !exists $job_ids{$idx} && !exists $completed_jobs{$idx};
  }
  return undef;
}

# Process all jobs
while (1) {
  my @pending;
  my $last_idx = -1;
  my $array_size = 0;

  # Group consecutive indices for array jobs
  for my $idx (0..$#$jobs) {
    next if exists $job_ids{$idx} || exists $completed_jobs{$idx};
    
    if ($last_idx == -1 || $idx != $last_idx + 1) {
      # Start new array if sequence breaks
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

  # Submit array jobs up to worker limit
  while (@pending && (scalar keys %job_ids) < $workers) {
    my ($start, $end) = @{shift @pending};
    handle_job($start, $end);
  }

  # Check completion status
  for my $idx (keys %job_ids) {
    my $job_id = $job_ids{$idx};
    my ($master_id, $task_id) = $job_id =~ /(\d+)_(\d+)/;
    
    chomp(my $state = qx(sacct -j $master_id --array-tasks=$task_id --format=state -n --parsable2 | head -n1));
    
    if ($state =~ /^(FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY)$/) {
      handle_job_failure($idx, $job_id, "failed with state $state");
    } elsif ($state eq 'COMPLETED') {
      if (system("sacct -j $master_id --array-tasks=$task_id --format=exitcode -n | grep -q '0:0'") == 0) {
        delete $job_ids{$idx};
        delete $retry_count{$idx};
        delete $job_resources{$idx};
        $completed_jobs{$idx} = 1;
        save_status();
      }
    }
  }

  print_status();
  last unless %job_ids || @pending;
  sleep 30;
}

warn "doing mode=end...\n";
qx($Bin/precache.pl --mode=end);
unlink $job_file;
1;
