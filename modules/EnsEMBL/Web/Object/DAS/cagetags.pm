package EnsEMBL::Web::Object::DAS::cagetags;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

use Bio::EnsEMBL::Map::DBSQL::DitagFeatureAdaptor;

sub Features {
    my $self = shift;

    my $species = $self->real_species;
    my $dba = $self->{data}->{_databases}->{_dbs}->{$species}->{'core'};


    my @segments = $self->Locations;
    my @features;

    my @fts = grep { $_ } @{$self->FeatureTypes || []};

    my @ditag_analysis = qw(FANTOM_CAGE);

    my $dfa = $dba->get_DitagFeatureAdaptor; 
    my $da = $dba->get_DitagAdaptor;

    foreach my $s (@segments) {
	if (ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR') {
	    push @features, $s;
	    next;
	}
	my $slice = $s->slice;
	my @segment_features;

	foreach my $ft (sort {$a->start <=> $b->start} @{$dfa->fetch_all_by_Slice($slice) || [] }) {

	    next unless grep {$_ eq $ft->analysis->logic_name} @ditag_analysis;

	    if (@fts > 0) {
		next unless grep {$_ eq $ft->ditag_side} @fts;
	    }

	    my $tag_count = $da->fetch_by_dbID($ft->ditag_id)->tag_count();

	    my $id = join('.', $ft->ditag_id, $ft->ditag_pair_id);
	    my $g_location = "Location: ".join(' - ', ($ft->get_ditag_location)[0,1]);

	    my $group = {
		'ID' => $id,
		'LINK' => [ {text => 'More info', href => "http://www.ensembl.org/$species/CAGE.html"} ],
		'TYPE' =>  $ft->analysis->logic_name,
		'NOTE'        => ["tag_count: $tag_count", $g_location],
	    };
	    $id = join('.', $id, $ft->ditag_side);

	    my $f = {
		'ID'          => $id,
		'LABEL'       => $ft->ditag_id,
		'TYPE'        => $ft->ditag_side || '', 
		'METHOD'      => $ft->analysis->logic_name,
		'START'       => $ft->start,
		'END'         => $ft->end,
		'ORIENTATION' => $ft->strand+0,
		'NOTE'        => ["tag_count: $tag_count"],
		'GROUP' => [$group], 
	    };
	    push @segment_features, $f;
	}

	push @features, {
    	    'REGION' => $s->seq_region_name, 
	    'START'  => $s->seq_region_start, 
	    'STOP'   => $s->seq_region_end,
	    'FEATURES' => \@segment_features
	    };
    }
    return \@features;
}

sub Stylesheet {
    my $self = shift;
    return qq{
<STYLESHEET version="1.0">
  
  <CATEGORY id="group">
    <TYPE id="default">
      <GLYPH>
         <ANCHORED_ARROW>
	   <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue3</BGCOLOR>
           <FGCOLOR>lightblue3</FGCOLOR>
	   <BAR_STYLE>line</BAR_STYLE>
	   <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
  </CATEGORY>

  <CATEGORY id="default">
    <TYPE id="default">
      <GLYPH>
         <ANCHORED_ARROW>
	   <HEIGHT>10</HEIGHT>
           <BGCOLOR>lightblue3</BGCOLOR>
           <FGCOLOR>lightblue3</FGCOLOR>
	   <BAR_STYLE>line</BAR_STYLE>
	   <NO_ANCHOR>1</NO_ANCHOR>
           <BUMP>1</BUMP>
           <FONT>sanserif</FONT>
         </ANCHORED_ARROW>
      </GLYPH>
    </TYPE>
  </CATEGORY>

</STYLESHEET>
};
}

1;
