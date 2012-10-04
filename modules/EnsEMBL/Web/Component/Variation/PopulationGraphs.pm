package EnsEMBL::Web::Component::Variation::PopulationGraphs;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $hub = $self->hub;
  
  my $freq_data = $object->freqs;
  
  my $pop_freq = $self->format_frequencies($freq_data);
  my $graph_width = '118px';
  
  return '' unless (defined($pop_freq));
  
  my @pop_phase1 = grep{ /phase_1/} keys(%$pop_freq);
  return '' unless (scalar @pop_phase1);

  my @graphs;
  my @inputs;
  my $graph_id = 0;
  my $height   = 50;

  my $pop_tree;                 
  my %sub_pops;                 
  my @alleles;
  # Get alleles list
  foreach my $pop_name (sort(keys(%$pop_freq))) {
    my $values = '';
    my $p_name = (split(':',$pop_name))[1];
    
    $pop_tree = $self->update_pop_tree($pop_tree,$pop_name,$pop_freq->{$pop_name}{sub_pop}) if (defined($pop_freq->{$pop_name}{sub_pop}));
    
    foreach my $ssid (keys %{$pop_freq->{$pop_name}{freq}}) {
      foreach my $allele (sort(keys %{$pop_freq->{$pop_name}{freq}{$ssid}})) {
        my $freq = $pop_freq->{$pop_name}{freq}{$ssid}{$allele};
        push (@alleles, $allele) if ((!grep {$allele eq $_} @alleles) && $freq>0);
       }
    }  
  }
  
  my $nb_alleles = scalar(@alleles);
  if ($nb_alleles>2) {
    while ($nb_alleles != 2) {
      $height += 6;
      $nb_alleles --;
    }
  }
 
  # Create graphs
  foreach my $pop_name (sort {($a !~ /ALL/) cmp ($b !~ /ALL/) || $a cmp $b} (@pop_phase1)) {
    
    my $values = '';
    my @pop_names = (split(':',$pop_name));
    shift @pop_names;
    my $p_name = join(':',@pop_names);
    my $short_name = $self->get_short_name($p_name);
    my $pop_desc = $pop_freq->{$pop_name}{desc};
    
    # Constructs the array for the pie charts: [allele,frequency]
    foreach my $al (@alleles) {
      foreach my $ssid (keys %{$pop_freq->{$pop_name}{freq}}) {

        next if (!$pop_freq->{$pop_name}{freq}{$ssid}{$al});
          
        my $freq = $pop_freq->{$pop_name}{freq}{$ssid}{$al};
          
        $values .= ',' if ($values ne '');
        $freq = 0.5 if ($freq < 0.5); # Fixed bug if freq between 0 and 0.5
        $values .= "['$al',$freq]";
        last;
      }
    }
    
    if ($short_name =~ /ALL/ || $pop_tree->{$short_name}) {
      push @inputs, qq{<input type="hidden" class="population" value="[$values]" />};
      push @graphs, sprintf qq{<div class="pie-chart%s" title="$pop_desc"><span>$short_name</span><div id="graphHolder$graph_id" style="width:%s;height:$height\px;"></div></div>}, $short_name eq 'ALL' ? ' all-population' : '', $graph_width;
      $graph_id ++;
    }
  }
  
  my $html = sprintf q{<h2>1000 Genomes allele frequencies</h2>
                       <div><input type="hidden" class="panel_type" value="PopulationGraph" />%s</div>
                       <div class="population-genetics-pie">%s</div>},
    join('', @inputs),
    join('', @graphs)
  ;

  return $html;
}

sub format_frequencies {
  my ($self, $freq_data) = @_;
  my $hub = $self->hub;
  my $pop_freq;
  
   foreach my $pop_id (keys %$freq_data) {
    foreach my $ssid (keys %{$freq_data->{$pop_id}}) {
      my $pop_name = $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'};
      next if($freq_data->{$pop_id}{$ssid}{'pop_info'}{'Name'} !~ /^1000genomes\:.*/i);
      next if($freq_data->{$pop_id}{$ssid}{failed_desc});
      # Freqs alleles ---------------------------------------------
      my @allele_freq = @{$freq_data->{$pop_id}{$ssid}{'AlleleFrequency'}};
      
      $pop_freq->{$pop_name}{desc} = $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Description'};
      
      if (scalar(keys %{$freq_data->{$pop_id}{$ssid}{'pop_info'}{'Sub-Population'}})) {
        $pop_freq->{$pop_name}{sub_pop} = $freq_data->{$pop_id}{$ssid}{'pop_info'}{'Sub-Population'};
      }
      
      foreach my $gt (@{$freq_data->{$pop_id}{$ssid}{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;
        
        my $freq = $self->format_number(shift @allele_freq);
        if ($freq ne 'unknown') {
          $pop_freq->{$pop_name}{freq}{$ssid}{$gt} = $freq;
        }
      }
    }
  }
  return $pop_freq;
}

sub format_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;
  $number = $number*100 if (defined $number);
  return defined $number ? sprintf '%.2f', $number : 'unknown';
}


sub update_pop_tree {
  my $self = shift;
  my $p_tree = shift;
  my $p_name = shift;
  my $sub_list = shift;
  
  my $p_short_name = $self->get_short_name($p_name);
  foreach my $sub_pop (keys(%{$sub_list})) {
    my $sub_name = $sub_list->{$sub_pop}{Name};
    my $sub_short_name = $self->get_short_name($sub_name);
    $p_tree->{$p_short_name}{$sub_short_name} = 1;
  }
  return $p_tree;
}


sub get_short_name {
  my $self   = shift;
  my $p_name = shift;
  $p_name =~ /phase_1_(.+)/; # Gets a shorter name for the display
  return ($1) ? $1 : $p_name;
}

1;
