package Bio::EnsEMBL::GlyphSet::generic_clone;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label {
  my $self = shift;
  return $self->my_config( 'label' ) || 'Clones';
}

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub _threshold_update {
  my $self = shift;
  my $thresholds = $self->my_config( 'threshold_array' )||{};
  my $container_length = $self->{'container'}->length();
  foreach my $th ( sort { $a<=>$b} keys %$thresholds ) {
    if( $container_length > $th * 1000 ) {
      foreach (keys %{$thresholds->{$th}}) {
warn $self->check()," SETTING $_ to ",$thresholds->{$th}{$_};
        $self->set_my_config( $_, $thresholds->{$th}{$_} );
      }
    }
  }
}

sub features {
  my ($self) = @_;
  warn $self->check," >>> ",$self->my_config( 'FEATURES' );
  my @sorted =  
    map { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map { [$_->seq_region_start - 
      1e9 * (
      $_->get_scalar_attribute('state') + $_->get_scalar_attribute('BACend_flag')/4
      ), $_]
    }
    @{$self->{'container'}->get_all_MiscFeatures( $self->my_config( 'FEATURES' ))};
  return \@sorted;
}

## If bac map clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality...

sub colour {
    my ($self, $f) = @_;
    (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
    return $self->{'colours'}{"col_$state"}||$self->{'feature_colour'},
           $self->{'colours'}{"lab_$state"}||$self->{'label_colour'},
           $self->{'part_to_colour'};
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
  my ($self, $f ) = @_;
  return ("@{[$f->get_scalar_attribute('name')]}",'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
  my ($self, $f ) = @_;
  return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=@{[$f->get_scalar_attribute('name')]}";
}

sub tag {
  my ($self, $f) = @_; 
  my @result = (); 
  my $bef = $f->get_scalar_attribute('BACend_flag');
  (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
  my ($s,$e) = $self->sr2slice( $f->get_scalar_attribute('inner_start'), $f->get_scalar_attribute('inner_end') );
  if( $s && $e ){
    push @result, {
      'style'  => 'rect',
      'colour' => $f->{'_colour_flag'} || $self->{'colours'}{"col_$state"},
      'start'  => $s,
      'end'    => $e
    };
  }
  push @result, {
    'style'  => 'right-end',
    'colour' => $self->{'colours'}{"bacend"}
  } if ( $bef == 2 || $bef == 3 );
  push @result, { 
    'style'=>'left-end',  
    'colour' => $self->{'colours'}{"bacend"}
  } if ( $bef == 1 || $bef == 3 );

  my $fp_size = $f->get_scalar_attribute('fp_size');
  if( $fp_size && $fp_size > 0 ) {
    my $start = int( ($f->start + $f->end - $fp_size)/2 );
    my $end   = $start + $fp_size - 1 ;
    push @result, {
      'style' => 'underline',
      'colour' => $self->{'colours'}{"seq_len"},
      'start'  => $start,
      'end'    => $end
    };
  }
  return @result;
}
## Create the zmenu...
## Include each accession id separately

sub zmenu {
  my ($self, $f ) = @_;
  return if $self->my_config('navigation') ne 'on';
  my $zmenu = { 
    qq(caption)                                            => qq(Clone: @{[$f->get_scalar_attribute('name')]}),
    qq(01:bp: @{[$f->seq_region_start]}-@{[$f->seq_region_end]}) => '',
    qq(02:length: @{[$f->length]} bps)                     => '',
    qq(03:Centre on clone:)                                => $self->href($f),
    };
    foreach(@{$f->get_all_attribute_values('embl_acc')}) {
        $zmenu->{"12:EMBL: $_" } = '';
    }
    (my $state = $f->get_scalar_attribute('state'))=~s/^\d\d://;
    my $bac_info = ('Interpolated', 'Start located', 'End located', 'Both ends located') [$f->get_scalar_attribute('BACend_flag')];

    $zmenu->{"13:Organisation: @{[$f->get_scalar_attribute('organisation')]}"} = '' if $f->get_scalar_attribute('organisation');
    $zmenu->{"14:State: $state"                                  } = '' if $state;
    $zmenu->{"15:Seq length: @{[$f->get_scalar_attribute('seq_len')]}"  } = '' if $f->get_scalar_attribute('seq_len');
    $zmenu->{"16:FP length:  @{[$f->get_scalar_attribute('fp_size')]}"  } = '' if $f->get_scalar_attribute('fp_size');
    $zmenu->{"17:super_ctg:  @{[$f->get_scalar_attribute('superctg')]}" } = '' if $f->get_scalar_attribute('superctg');
    $zmenu->{"18:BAC flags:  $bac_info"                          } = '' if $bac_info;
    $zmenu->{"18:FISH:  @{[$f->get_scalar_attribute('FISHmap')]}"       } = '' if $f->get_scalar_attribute('FISHmap');
    return $zmenu;
}

1;
