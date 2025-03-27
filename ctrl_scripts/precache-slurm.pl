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
my ($list,@subparts);
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
if($list) {
  print qx($Bin/precache.pl --mode=list);
  exit 0;
}
my @params;
push @params,"-s $_" for(@subparts);
push @params,@ARGV;

qx($Bin/precache.pl --mode=start @params);

my @jobs = @ARGV;
if(!@jobs) {
  @jobs = split('\n',qx($Bin/precache.pl --mode=list));
}

foreach my $j (@jobs) {
  warn "preparing $j\n";
  qx($Bin/precache.pl --mode=prepare $j);
}

open(SPEC,'<',"$SiteDefs::ENSEMBL_PRECACHE_DIR/spec") or die $!;
my $jobs;
{ local $/ = undef; $jobs = JSON->new->decode(<SPEC>); }
close SPEC;
die "No jobs in spec" unless $jobs;
  
my $njobs=@$jobs;
my $ndone=0;

# Set up library paths for precache script
my @lib_dirs;
my @plugins = reverse @{$SiteDefs::ENSEMBL_PLUGINS};
while (my ($dir, $name) = splice @plugins, 0, 2) {
 push @lib_dirs, "$dir/modules";
}
push @lib_dirs, @$SiteDefs::ENSEMBL_API_LIBS;
my $libs =  join(' ', map {"-I $_"} @lib_dirs);

# Job tracking state
my %job_status;
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
  system("scancel $_") for values %job_status;
  unlink $job_file;
  exit 1;
}
$SIG{INT} = $SIG{TERM} = \&cleanup;

# Load previous job state when resuming
if (-f $job_file) {
  open(my $fh, '<', $job_file) or die $!;
  my $data = JSON->new->decode(do { local $/; <$fh> });
  close $fh;
  %job_status = %{$data->{jobs} || {}};
  %retry_count = %{$data->{retries} || {}};
  %job_resources = %{$data->{resources} || {}};
}

# Save current job state to disk
sub save_status {
  open(my $fh, '>', $job_file) or die $!;
  print $fh JSON->new->encode({
    jobs => \%job_status,
    retries => \%retry_count,
    resources => \%job_resources
  });
  close $fh;
}

# Print current progress
sub print_status {
  my $running = scalar keys %job_status;
  my $failed = scalar grep { $retry_count{$_} >= $max_retries } keys %retry_count;
  my $submitted = scalar keys %retry_count;
  printf("Status: %d/%d (%d%%) done, %d running, %d submitted, %d failed\n",
         $ndone, $njobs, $ndone*100/$njobs, $running, $submitted, $failed);
}

# Handle job failure and cleanup
sub handle_job_failure {
  my ($idx, $job_id, $reason) = @_;
  warn "Job $job_id for index $idx $reason (attempt $retry_count{$idx}/$max_retries)\n";
  
  if ($retry_count{$idx} >= $max_retries) {
    warn "Max retries reached for index $idx, giving up\n";
    delete $job_status{$idx};
    delete $job_resources{$idx};
    save_status();
    return 0;
  }
  delete $job_status{$idx};
  return handle_job($idx);
}

# Main job handling function
sub handle_job {
  my ($idx) = @_;
  return 0 unless defined $idx;
  
  # Submit new job if not already running
  if (!exists $job_status{$idx}) {
    return 0 if $retry_count{$idx} && $retry_count{$idx} >= $max_retries;
    
    my $resources = $job_resources{$idx} || {mem => $default_mem, time => $default_time};
    my $cmd = qq{sbatch --parsable --time=$resources->{time}:00:00 --mem=$resources->{mem}G }.
              qq{--wrap="perl $libs $Bin/precache.pl --mode=index --index=$idx"};
    $verbose && warn $cmd;
    
    chomp(my $job_id = qx($cmd));
    die "sbatch failed: $!" if $?;
    die "Invalid job ID" unless $job_id =~ /^\d+$/;
    
    $job_status{$idx} = $job_id;
    $retry_count{$idx}++;
    save_status();
    return 1;
  }
  
  # Check status of running job
  my $job_id = $job_status{$idx};
  my $status = qx(squeue -h -j $job_id -o %t 2>/dev/null);
  die "squeue failed: $!" if $? && $? != 256; # ignore if job not found
  return 1 if $status =~ /[RPC]/;
  
  # Handle various failure states
  my $state = qx(sacct -j $job_id --format=state -n 2>/dev/null);
  if ($state =~ /FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY/) {
    $job_resources{$idx} = get_adjusted_resources($idx, $state);
    return handle_job_failure($idx, $job_id, "failed with state $state");
  }
  
  # Check exit code for completed job
  if (system("sacct -j $job_id --format=exitcode -n | grep -q '0:0'") != 0) {
    return handle_job_failure($idx, $job_id, "failed with non-zero exit code");
  }
  
  # Job completed successfully
  delete $job_status{$idx};
  delete $retry_count{$idx};
  delete $job_resources{$idx};
  save_status();
  $ndone++;
  return 0;
}

# Find next job to run
sub get_next_job {
  return (grep { !exists $job_status{$_} } 0..$#$jobs)[0];
}

# Process/monitor jobs until all are done
while (1) {
  my @current_jobs = keys %job_status;
  my @running = grep { handle_job($_) } @current_jobs;
  handle_job(get_next_job()) if @running < $workers;
  last unless %job_status || get_next_job();

  print_status();
  sleep 30;
}

warn "doing mode=end...\n";
qx($Bin/precache.pl --mode=end);
unlink $job_file;
1;
