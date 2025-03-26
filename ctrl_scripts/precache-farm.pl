#! /usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);

BEGIN { require "$Bin/../conf/includeSiteDefs.pl" }

use Getopt::Long;
use JSON;

use List::Util qw(shuffle);

my ($list,@subparts);
my $workers = 10;
my $verbose = 0;
my $resume_from = 0;

GetOptions(
  'l' => \$list,
  's=s' => \@subparts,
  'workers=i' => \$workers,
  'verbose|v' => \$verbose,
  'resume=i' => \$resume_from
);
if($list) {
  print qx($Bin/precache.pl --mode=list);
  exit 0;
}
my @params;
push @params,"-s $_" for(@subparts);
push @params,@ARGV;

my $params = join(' ',@params);
  
qx($Bin/precache.pl --mode=start $params);

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

my @lib_dirs;
my @plugins = reverse @{$SiteDefs::ENSEMBL_PLUGINS};
while (my ($dir, $name) = splice @plugins, 0, 2) {
 push @lib_dirs, "$dir/modules";
}
push @lib_dirs, @$SiteDefs::ENSEMBL_API_LIBS;
my $libs =  join(' ', map {"-I $_"} @lib_dirs);

my %job_status;
my $job_file = "$SiteDefs::ENSEMBL_PRECACHE_DIR/running_jobs.json";
my $ndone = 0;

# Cancel running jobs on exit
sub cleanup {
  system("scancel $_") for values %job_status;
  unlink $job_file;
  exit 1;
}
$SIG{INT} = $SIG{TERM} = \&cleanup;

# Load previous jobs if resuming
if (-f $job_file) {
  open(my $fh, '<', $job_file) or die $!;
  %job_status = %{JSON->new->decode(do { local $/; <$fh> })};
  close $fh;
}

sub save_status {
  open(my $fh, '>', $job_file) or die $!;
  print $fh JSON->new->encode(\%job_status);
  close $fh;
}

sub handle_job {
  my ($idx) = @_;
  
  # Submit new job if needed
  if (!exists $job_status{$idx}) {
    my $cmd = qq{sbatch --parsable --time=02:00:00 --mem=8G --wrap="perl $libs $Bin/precache.pl --mode=index --index=$idx"};
    $verbose && warn $cmd;
    chomp(my $job_id = qx($cmd));
    $job_status{$idx} = $job_id;
    save_status();
    return 1;  # Job running
  }
  
  my $job_id = $job_status{$idx};
  return 1 if qx(squeue -h -j $job_id -o %t 2>/dev/null) =~ /[RPC]/;
  
  # Job finished - check status
  if (system("sacct -j $job_id --format=exitcode -n | grep -q '0:0'") != 0) {
    warn "Job $job_id for index $idx failed, resubmitting\n";
    delete $job_status{$idx};  # Will trigger resubmission
    return handle_job($idx);
  }
  
  # Job completed successfully
  delete $job_status{$idx};
  save_status();
  $ndone++;
  printf("%d/%d (%d%%) done\n", $ndone, $njobs, $ndone*100/$njobs);
  return 0;
}

# Main processing loop
for my $i ($resume_from..$#$jobs) {
  handle_job($i);
  
  # Process running jobs
  while (%job_status) {
    my @running = grep { handle_job($_) } keys %job_status;
    last if @running < $workers;
    sleep 30;
  }
}

# Wait for remaining jobs
while (%job_status) {
  sleep 30;
  handle_job($_) for keys %job_status;
}

warn "doing mode=end...\n";
qx($Bin/precache.pl --mode=end);
unlink $job_file;
1;
