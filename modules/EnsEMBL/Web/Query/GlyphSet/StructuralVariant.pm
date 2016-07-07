package EnsEMBL::Web::Query::GlyphSet::StructuralVariant;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::GlyphSet);

use List::Util qw(min max);

our $VERSION = 1;

sub fixup {
  my ($self) = @_;

  $self->fixup_slice('slice','species',100000);

  $self->SUPER::fixup();
}

sub precache {
  return {
  };
}

sub _plainify {
  my ($self,$f,$args) = @_;

  return {
    strand => $f->strand,
    start => $f->start,
    end => $f->end,
    colour_key => 'orange', # XXX
    tag => [],
    feature_label => 'XXX', # XXX
  };
}

sub _fetch_set {
  my ($self,$args) = @_;

  my $species = $args->{'species'};
  my $slice = $args->{'slice'};
  my $set_name = $args->{'set_name'};
  my $var_db = $args->{'db'};
  my $adaptors = $self->source('Adaptors');
  my $svfa =
    $adaptors->structural_variation_feature_adaptor($species,$var_db); 
  my $vsa = $adaptors->variation_set_adaptor($species,$var_db);
  my $features = [];
  if($vsa) {
    my $set = $vsa->fetch_by_name($args->{'set_name'});
    $features = $svfa->fetch_all_by_Slice_VariationSet($slice, $set);
  }
  use Data::Dumper;
  local $Data::Dumper::Maxdepth = 3;
  warn Dumper('set',$features);
  return $features;
}

sub _fetch_study {
  my ($self,$args) = @_;

  my $species = $args->{'species'};
  my $slice = $args->{'slice'};
  my $var_db = $args->{'db'};
  my $adaptors = $self->source('Adaptors');
  my $sya = $adaptors->study_adaptor($species,$var_db);
  my $features = [];
  my $svfa =
    $adaptors->structural_variation_feature_adaptor($species,$var_db); 
  if($sya) {
    my $study = $sya->fetch_by_name($args->{'study_name'});
    $features = $svfa->fetch_all_by_Slice_Study($slice,$study);
  }
  use Data::Dumper;
  local $Data::Dumper::Maxdepth = 3;
  warn Dumper('study',$features);
  return $features;
}

sub _compact {
  my ($self,$args,$features) = @_;

  warn "COMPACT\n";
  # Convert to simple ranges
  my @in;
  foreach my $f (@$features) {
    push @in,[$f->seq_region_start,$f->seq_region_end,$f->length,$f];
  }
  local $Data::Dumper::Maxdepth = 4;
  warn Dumper('in',\@in);
  # Merge overlapping ranges
  my @out;
  foreach my $f (sort { $a->[0] <=> $b->[0] } @in) {
    if(@out and $f->[0] <= $out[-1]->[1]) {
      $out[-1]->[1] = max($out[-1]->[1],$f->[1]); # ... merge
    } else {
      push @out,$f; # ... push
    }
  }
  warn Dumper('out',\@out);
  # Create blocks
  my $slice = $args->{'slice'};
  return [map {
    Bio::EnsEMBL::Variation::StructuralVariationFeature->new(
      -start => max($_->[0] - $slice->start + 1,0),
      -end   => min($_->[1] - $slice->start + 1,$args->{'slice'}->end),
      -slice => $slice
    )
  } @out];
}

sub _filter_size {
  my ($self,$args,$features) = @_;

  return $features unless defined $args->{'min_size'} or
                          defined $args->{'max_size'};
  my @out;
  foreach my $f (@$features) {
    my $length = $f->length;
    next if $args->{'max_size'} and $length > $args->{'max_size'};
    next if $args->{'min_size'} and $length < $args->{'min_size'};
    push @out,$f;
  }
  if($args->{'max_size'} and $args->{'compact'}) {
    @out = @{$self->_compact($args,\@out)};
  }
  return \@out;
}

sub _add_breakpoints {
  my ($self,$args,$features) = @_;

  return $features if defined $args->{'min_size'} or
                      defined $args->{'max_size'};
  return $features if $args->{'somatic'};
  my $slice = $args->{'slice'};
  my @out;
  foreach my $f (@$features) {
    if(!$f->{'breakpoint_order'}) {
      push @out,$f;
      next;
    }
    if(($f->seq_region_start >= $slice->start and
        $f->seq_region_start <= $slice->end      ) or
       ($f->seq_region_end   >= $slice->start and
        $f->seq_region_end   <= $slice->end      )) {
      push @out,$f;
    }
  }
  return \@out;
}

sub _fetch_all {
  my ($self,$args) = @_;

  my $features = [];

  my $species = $args->{'species'};
  my $slice = $args->{'slice'};
  my $var_db = $args->{'db'};
  my $adaptors = $self->source('Adaptors');
  # Fetch the data in one of four ways
  my $svfa =
    $adaptors->structural_variation_feature_adaptor($species,$var_db);
  my $srca = $adaptors->source_adaptor($species,$var_db);
  if($args->{'source_name'}) {
    my $source = $srca->fetch_by_name($args->{'source_name'});
    if($args->{'somatic'}) {
      warn "A\n";
      $features =
        $svfa->fetch_all_somatic_by_Slice_Source($slice,$source,undef);
    } else {
      warn "B\n";
      $features =
        $svfa->fetch_all_by_Slice_Source($slice,$source,undef);
    }
  } else {
    if($args->{'somatic'}) {
      warn "C\n";
      $features =
        $svfa->fetch_all_somatic_by_Slice($slice);
    } else {
      warn "D\n";
      $features =
        $svfa->fetch_all_by_Slice($slice);
    }
  }
  $features = $self->_filter_size($args,$features);  
  $features = $self->_add_breakpoints($args,$features);

  local $Data::Dumper::Maxdepth = 3;
  warn Dumper('all',$features);
  return $features;
}

sub fetch_features {
  my ($self,$args) = @_;

  my $adaptors = $self->source('Adaptors');

  my $species = $args->{'species'};
  my $slice = $args->{'slice'};
  my $var_db = $args->{'db'};
  unless ($var_db) {
    $self->errorTrack("Could not connect to variation database");
    return []; 
  }
  my $svf_adaptor =
    $adaptors->structural_variation_feature_adaptor($species,$var_db); 
  my $src_adaptor = $adaptors->source_adaptor($species,$var_db);

  warn "species=$species slice=".$slice->name." var_db=$var_db svf_adaptor=$svf_adaptor src_adaptor=$src_adaptor\n";

  if($args->{'set_name'}) {
    return $self->_fetch_set($args);
  } elsif($args->{'study_name'}) {
    return $self->_fetch_study($args);
  } else {
    return $self->_fetch_all($args);
  }

  return [];
}

sub get {
  my ($self,$args) = @_;

  my $features_list = $self->fetch_features($args);
  return [map { $self->_plainify($_,$args) } @$features_list];
}

1;
