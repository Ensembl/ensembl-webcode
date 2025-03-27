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
my $ndone = 0;

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
my $max_retries = 2;
my $job_file = "$SiteDefs::ENSEMBL_PRECACHE_DIR/running_jobs.json";

# Resource limits (in GB and hours)
my $default_mem = 8;
my $default_time = 2;
my $max_mem = 32;
my $max_time = 8;

# Adjust resource limits for failed jobs
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
}

# Save current job state to disk
sub save_status {
  open(my $fh, '>', $job_file) or die $!;
  print $fh JSON->new->encode({
    jobs => \%job_ids,
    retries => \%retry_count,
    resources => \%job_resources
  });
  close $fh;
}

# Print current progress
sub print_status {
  my $running = scalar keys %job_ids;
  my $failed = scalar grep { $retry_count{$_} >= $max_retries } keys %retry_count;
  my $submitted = scalar keys %retry_count;
  printf("Status: %d/%d (%d%%) done, %d running, %d submitted, %d failed\n",
         $ndone, $njobs, $ndone * 100 / $njobs, $running, $submitted, $failed);
}

# Handle job failure and cleanup
sub handle_job_failure {
  my ($idx, $job_id, $reason) = @_;
  warn "Job $job_id for index $idx $reason (attempt $retry_count{$idx}/$max_retries)\n";

  if ($retry_count{$idx} >= $max_retries) {
    warn "Max retries reached for index $idx, giving up\n";
    delete $job_ids{$idx};
    delete $job_resources{$idx};
    save_status();
    return 0;
  }
  delete $job_ids{$idx};
  return handle_job($idx);
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

# Process a single job
sub handle_job {
  my ($idx) = @_;
  return 0 unless defined $idx;

  # Submit new job if not already running
  if (!exists $job_ids{$idx}) {
    return 0 if $retry_count{$idx} && $retry_count{$idx} >= $max_retries;

    my $resources = $job_resources{$idx} || {mem => $default_mem, time => $default_time};
    my $cmd = qq{sbatch --parsable --time=$resources->{time}:00:00 --mem=$resources->{mem}G } .
              qq{--wrap="perl $libs $Bin/precache.pl --mode=index --index=$idx"};
    $verbose && warn $cmd;

    chomp(my $job_id = qx($cmd));
    die "sbatch failed: $!" if $?;
    die "Invalid job ID" unless $job_id =~ /^\d+$/;

    $job_ids{$idx} = $job_id;
    $retry_count{$idx}++;
    save_status();
    return 1;
  }

  # Check status of running job
  my $job_id = $job_ids{$idx};
  #my $state = get_job_state($job_id);
  chomp(my $state = qx(sacct -j $job_id --format=state -n --parsable2 | head -n1));
  warn $state;
  warn 'job is running' if $state =~ /^(PENDING|RUNNING|CONFIGURING)$/;
  return 1 if $state =~ /^(PENDING|RUNNING|CONFIGURING)$/;

  # Handle various failure states
  if ($state =~ /^(FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY)$/) {
    warn 'job failed, retrying';
    $job_resources{$idx} = get_adjusted_resources($idx, $state);
    return handle_job_failure($idx, $job_id, "failed with state $state");
  }

  # Check exit code
  if ($state eq 'COMPLETED') {
    warn 'checking exit code';
    if (system("sacct -j $job_id --format=exitcode -n | grep -q '0:0'") == 0) {
      warn 'job done';
      # Success
      delete $job_ids{$idx};
      delete $retry_count{$idx};
      delete $job_resources{$idx};
      save_status();
      $ndone++;
      return 0;
    }
    return handle_job_failure($idx, $job_id, "completed with non-zero exit");
  }

  warn "Unknown job state '$state' for job $job_id";
  return 1;  # Keep monitoring unknown states
}

# Pick next job to run
sub get_next_job {
  return (grep { !exists $job_ids{$_} } 0..$#$jobs)[0];
}

# Process all jobs
while (1) {
  # Update running jobs
  my @current = keys %job_ids;
  my @still_running = grep { handle_job($_) } @current;

  # Submit new jobs up to worker limit
  my $slots = $workers - @still_running;
  while ($slots > 0) {
    my $next = get_next_job();
    last unless defined $next;
    if (handle_job($next)) {
      $slots--;
    }
  }

  # Loop until all jobs done
  print_status();
  last unless %job_ids || defined get_next_job();

  sleep 30;
}

warn "doing mode=end...\n";
qx($Bin/precache.pl --mode=end);
unlink $job_file;
1;
