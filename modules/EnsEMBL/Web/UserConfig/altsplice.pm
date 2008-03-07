package EnsEMBL::Web::UserConfig::altsplice;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
    my ($self) = @_;
    $self->{'_userdatatype_ID'} = 12;
    $self->{'_transcript_names_'} = 'yes';
    $self->{'general'}->{'altsplice'} = {
	'_artefacts' => [qw(
	    ruler
            contig scalebar
	)],
	
	'_options' => [qw(pos col known unknown)],
        '_settings'     => {
            'features' => [ ],
            'show_labels' => 'yes',
	        'show_buttons'=> 'no',
	        'opt_shortlabels'     => 1,
            'opt_zclick'     => 1,
	        'width'       => 600,
          'opt_lines'   => 1,
	        'bgcolor'     => 'background1',
	        'bgcolour1'   => 'background1',
	        'bgcolour2'   => 'background1',
	     },

	'ruler' => {
	    'on'  => "on",
	    'pos' => '11',
	    'str'   => 'r',
	    'col' => 'black',
	},

  'scalebar' => {
      'on' => 'on',
      'pos' => '100000',
      'col'       => 'black',
      'label'     => 'on',
      'max_division'  => '12',
      'str'       => 'b',
      'subdivs'     => 'on',
      'abbrev'    => 'on',
      'navigation'  => 'off'
  },
                                                            
        
    'contig' => {
	    'on'  => "on",
	    'pos' => '0',
	    'col' => 'black',
	    'navigation'  => 'off',
        }
    };
    
    $self->ADD_ALL_TRANSCRIPTS( 0, 'on' => 'on' );
}

1;
