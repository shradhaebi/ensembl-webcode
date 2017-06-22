=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::fg_regulatory_features;

### Draw regulatory features track 

use strict;

use Role::Tiny::With;
with 'EnsEMBL::Draw::Role::Default';

use base qw(EnsEMBL::Draw::GlyphSet);

sub render_normal {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::MultiBlocks']);
  $self->{'my_config'}->set('height', 12);
  my $data = $self->get_data;
  $self->draw_features($data);
}

sub get_data {
  my $self    = shift;
  my $slice   = $self->{'container'}; 

  ## First, work out if we can even get any data!
  my $db_type = $self->my_config('db_type') || 'funcgen';
  my $db;
  if (!$slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    $db = $slice->adaptor->db->get_db_adaptor($db_type);
    if (!$db) {
      warn "Cannot connect to $db_type db";
      return [];
    }
  }
  my $rfa = $db->get_RegulatoryFeatureAdaptor; 
  if (!$rfa) {
    warn ("Cannot get get adaptors: $rfa");
    return [];
  }
 
  ## OK, looking good - fetch data from db 
  my $cell_line = $self->my_config('cell_line');  
  my $config      = $self->{'config'};
  my $fsets;
  if ($cell_line) {
    my $fsa = $db->get_FeatureSetAdaptor;
    $fsets  = $fsa->fetch_by_name($cell_line);
    my $ega = $db->get_EpigenomeAdaptor;
    my $epi = $ega->fetch_by_name($cell_line);
    $self->{'my_config'}->set('epigenome', $epi);
  }
  my $reg_feats = $rfa->fetch_all_by_Slice($self->{'container'}, $fsets); 

  my $drawable = []; 
  my $legend_entries = [];
  foreach my $rf (@{$reg_feats||[]}) {
    my ($type, $is_activity)  = $self->colour_key($rf);
    my $colour  = $self->my_colour($type, $is_activity) || '#e1e1e1';
    my $text    = $self->my_colour($type,'text');
    my ($flanks, $motifs) = $self->get_structure($rf, $type, $colour);
    push @$drawable,{
      colour        => $colour,
      label_colour  => $colour,
      start         => $rf->start,
      end           => $rf->end,
      label         => $text,
      structure     => $motifs,
    };
    push @$legend_entries, [$type, $colour];
  }
  $self->{'legend'}{'fg_regulatory_features_legend'} ||= { priority => 1020, legend => [], entries => $legend_entries };

  use Data::Dumper; warn Dumper($drawable);
  return [{
    features => $drawable,
    metadata => {
      force_strand => '-1',
      default_strand => 1,
      omit_feature_links => 1,
      display => 'normal'
    }
  }];
}

sub get_structure {
  my ($self, $f, $type, $colour) = @_;

  my $flank_colour = $colour;
  if ($type eq 'promoter') {
    $flank_colour = $self->my_colour('promoter_flanking');
  }

  my $hub = $self->{'config'}{'hub'};
  my $epigenome = $self->{'my_config'}->get('epigenome') || '';
  my $loci = [ map { $_->{'locus'} }
     @{$hub->get_query('GlyphSet::RFUnderlying')->go($self,{
      species => $self->{'config'}{'species'},
      type => 'funcgen',
      epigenome => $epigenome,
      feature => $f,
    })}
  ];
  return if $@ || !$loci || !scalar(@$loci);

  my $bound_end = pop @$loci;
  my $end       = pop @$loci;
  my ($bound_start, $start, @mf_loci) = @$loci;

  my $flanks    = [];
  if ($bound_start < $start || $bound_end > $end) {
    # Bound start/ends
    push @$flanks, {
      colour => $flank_colour,
      start  => $bound_start,
      end    => $start
    },{
      colour => $flank_colour,
      start  => $end,
      end    => $bound_end
    };
  }

  # Motif features
  my $motifs = [];
  while (my ($mf_start, $mf_end) = splice @mf_loci, 0, 2) {
    push @$motifs, {start => $mf_start, end => $mf_end};
  }
  
  return ($flanks, $motifs);
}

sub colour_key {
  my ($self, $f) = @_;
  my $type = $f->feature_type->name;

  if($type =~ /CTCF/i) {
    $type = 'ctcf';
  } elsif($type =~ /Enhancer/i) {
    $type = 'enhancer';
  } elsif($type =~ /Open chromatin/i) {
    $type = 'open_chromatin';
  } elsif($type =~ /TF binding site/i) {
    $type = 'tf_binding_site';
  } elsif($type =~ /Promoter Flanking Region/i) {
    $type = 'promoter_flanking';
  } elsif($type =~ /Promoter/i) {
    $type = 'promoter';
  } else  {
    $type = 'Unclassified';
  }

  my $is_activity = 0;
  my $config      = $self->{'config'};
  my $epigenome = $self->{'my_config'}->get('epigenome');
  if ($epigenome) {
    my $regact    = $f->regulatory_activity_for_epigenome($epigenome);
    if ($regact) {
      my $activity  = $regact->activity;
      if ($activity =~ /^(POISED|REPRESSED|NA)$/) {
        $type = $activity;
        $is_activity = 1;
      }
    }
  }

  return (lc $type, $is_activity);
}

sub href {
  my ($self, $f) = @_;
 
  my $hub = $self->{'config'}->hub;
  my $page_species = $hub->referer->{'ENSEMBL_SPECIES'};
  my @other_spp_params = grep {$_ =~ /^s[\d+]$/} $hub->param;
  my %other_spp;
  foreach (@other_spp_params) {
    ## If we're on an aligned species, swap parameters around
    if ($hub->param($_) eq $self->species) {
      $other_spp{$_} = $page_species;
    }
    else {
      $other_spp{$_} = $hub->param($_);
    }
  }

  return $self->_url({
    species =>  $self->species, 
    type    => 'Regulation',
    rf      => $f->stable_id,
    fdb     => 'funcgen', 
    cl      => $self->my_config('cell_line'),  
    %other_spp,
  });
}

1;
