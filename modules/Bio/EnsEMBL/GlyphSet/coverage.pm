package Bio::EnsEMBL::GlyphSet::coverage;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);

sub init_label {
  my $self = shift;
#  return undef;
  $self->label(new Sanger::Graphics::Glyph::Text({
    'text'      => "Read coverage",
    'font'      => 'Small',
    'absolutey' => 1,
  }));
}


sub _init {
  my ($self) = @_;
  # Data
  #  my $slice       = $self->{'container'};
  my $type = $self->check();
  my $Config         = $self->{'config'};
  my $transcript     = $Config->{'transcript'}->{'transcript'};
  my @coverage_levels = sort { $a <=> $b } @{$Config->{'transcript'}->{'coverage_level'}};
  my $max_coverage   = $coverage_levels[-1];
  my $min_coverage   = $coverage_levels[0] || $coverage_levels[1];
  my $coverage_obj   = $Config->{'transcript'}->{'coverage_obj'};
  return unless @$coverage_obj && @coverage_levels;
  my $sample         = $Config->{'transcript'}->{'sample'};
  my $A = $Config->get( $type, 'type' ) eq 'bottom' ? 0 : 1;

  my %level = (
    $coverage_levels[0] => [0, "grey70"],
    $coverage_levels[1] => [1, "grey40"],
  );

  # my $type = $self->check();
  #   return unless defined $type;
  #   return unless $self->strand() == -1;

  # my $EXTENT        = $Config->get('_settings','context');
  #    $EXTENT        = 1e6 if $EXTENT eq 'FULL';
  # my $seq_region_name = $self->{'container'}->seq_region_name();

  # Drawing stuff
  my $fontname      = $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'};
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);

  # Bumping 
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width(); #int($Config->container_width() * $pix_per_bp);
  my $voffset = 0;
  my @bitmap;
  my $max_row = -1;

  foreach my $coverage ( sort { $a->[2]->level <=> $b->[2]->level } @$coverage_obj  ) {
    my $level  = $coverage->[2]->level;
    my $y =  $level{$level}[0];
    my $z = 2+$y;# -19+$y;
       $y =  1 - $y if $A; 
       $y *= 4;
    my $h = 8 - $y;
       $y = 0;
    # Draw ------------------------------------------------
    my $S =  $coverage->[0];
    my $E =  $coverage->[1];
    my $width = $font_w_bp * length( $level );
    my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
    my $start = $coverage->[2]->start() + $offset;
    my $end   = $coverage->[2]->end() + $offset;
    my $pos   = "$start-$end";

    my $bglyph = new Sanger::Graphics::Glyph::Rect({
      'x'         => $S,
      'y'         => 8-$h,
      'height'    => $h,                            #$y,
      'width'     => $E-$S+1,
      'colour'    => $level{$level}->[1],
      'absolutey' => 1,
      'zmenu' => {
        'caption' => 'Read coverage: '.$level,
        "12:bp $pos" => '',
        "14:sample $sample" => '',
      },
      'z'    => $z
    });
    #$self->join_tag( $bglyph, "$S:$E:$level", $A,$A, $level{$level}->[1], 'fill',  $z );
    #$self->join_tag( $bglyph, "$S:$E:$level", 1-$A,$A, $level{$level}->[1], 'fill',  $z );
    $self->push( $bglyph );
  }
}

#sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }

1;
