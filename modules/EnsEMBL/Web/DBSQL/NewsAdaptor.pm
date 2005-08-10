package EnsEMBL::Web::DBSQL::NewsAdaptor;

#--------------------------------------------------------------------------
# SQL calls for the "what's new" elements of the ENSEMBL_WEBSITE database
#--------------------------------------------------------------------------

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
                                                                                
sub new {
  my( $class, $DB ) = @_;
  my $dbh;
  my $self = $DB;
  bless $self, $class;
  return $self;
}
                                                                                
sub db {
  my $self = shift;
  $self->{'dbh'} ||= DBI->connect(
    "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
    $self->{'USER'}, "$self->{'PASS'}", { RaiseError => 1}
  );
  return $self->{'dbh'};
}

############## QUERIES FOR NEWS_ITEM TABLE ################

sub fetch_all_by_release {
    my ($self, $release) = @_;
    my $results = [];

    return [] unless $self->db;
 
    # get news item info
    my $sql = qq(
        SELECT
                n.news_item_id   as news_item_id,
                r.release_id     as release_id,
                r.number         as release,
                n.title          as title,
                n.content        as content,
                c.news_cat_id    as news_cat_id,
                c.name           as news_cat_name,
                n.priority       as priority
        FROM
                news_item n,
                news_cat c,
                release r
        WHERE   n.news_cat_id = c.news_cat_id
        AND     n.release_id = r.release_id
        AND     r.number = $release
        GROUP BY news_item_id
    );

    my $T = $self->db->selectall_arrayref($sql, {});

    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @A = @{$T->[$i]};

        # get species list for this item
        my $id = $A[0];
        $sql = qq(
            SELECT
                s.species_id     as species_id,
                s.name           as species_name
            FROM
                species s,
                item_species i
            WHERE   s.species_id = i.species_id
            AND     i.news_item_id = $id
            );
 
        my $X = $self->db->selectall_arrayref($sql, {});

        return [] unless $X;
        my $species = [];
        for (my $j=0; $j<scalar(@$X);$j++) {
            my @B = @{$X->[$j]};
            push (@$species,
                {
                    'species_id'    => $B[0],
                    'species_name'  => $B[1],
                });
        }

        push (@$results,
            {
                'news_item_id'  => $A[0],
                'release_id'    => $A[1],
                'release'       => $A[2],
                'title'         => $A[3],
                'content'       => $A[4],
                'news_cat_id'   => $A[5],
                'news_cat_name' => $A[6],
                'priority'      => $A[7],
                'species'       => $species
            });
    }
    return $results;
}


sub fetch_by_id {
    my ($self, $id) = @_;
    my $results = [];

    return [] unless $self->db;

    # get list of species this item relates to
    my $sql = qq(
        SELECT
                s.species_id     as species_id,
                s.name           as species_name
        FROM
                species s,
                item_species i
        WHERE   s.species_id = i.species_id
        AND     i.news_item_id = $id
    );
 
    my $T = $self->db->selectall_arrayref($sql, {});

    return [] unless $T;
    my $species = [];
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @A = @{$T->[$i]};
        push (@$species,
            {
                'species_id'    => $A[0],
                'species_name'  => $A[1],
            });
    }

    # get item information
    $sql = qq(
        SELECT
                n.news_item_id   as news_item_id,
                r.release_id     as release_id,
                r.number         as release,
                n.title          as title,
                n.content        as content,
                c.news_cat_id    as news_cat_id,
                c.name           as news_cat_name,
                n.priority       as priority
        FROM
                news_item n,
                news_cat c,
                release r
        WHERE   n.news_cat_id = c.news_cat_id
        AND     n.release_id = r.release_id
        AND     n.news_item_id = $id
    );
 
    $T = $self->db->selectall_arrayref($sql, {});

    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @A = @{$T->[$i]};
        push (@$results,
            {
                'news_item_id'  => $A[0],
                'release_id'    => $A[1],
                'release'       => $A[2],
                'title'         => $A[3],
                'content'       => $A[4],
                'news_cat_id'   => $A[5],
                'news_cat_name' => $A[6],
                'priority'      => $A[7],
                'species'       => $species
            });
    }


    return $results;
}

sub add_news_item {
    my ($self, $item_ref) = @_;
    my %item = %{$item_ref};

    my $release_id      = $item{'release_id'};
    my $title           = $item{'title'};
    my $content         = $item{'content'};
    my $news_cat_id     = $item{'news_cat_id'};
    my $species_id      = $item{'species_id'};
    my $priority        = $item{'priority'};

    my $sql = qq(
        INSERT INTO
            news_item
        SET
            release_id      = "$release_id",
            date            = NOW(),
            title           = "$title",
            content         = "$content",
            news_cat_id     = "$news_cat_id",
            species_id      = "$species_id",
            priority        = "$priority"
        );
    my $sth = $self->db->prepare($sql);
#warn 'SQL: '.$sql;
    my $result = $sth->execute();

}

sub update_news_item {
    my ($self, $item_ref) = @_;
    my %item = %{$item_ref};

    my $id              = $item{'news_item_id'};
    my $release_id      = $item{'release_id'};
    my $title           = $item{'title'};
    my $content         = $item{'content'};
    $content =~ s/"/\\"/g;
    $content =~ s/'/\\'/g;
    my $news_cat_id     = $item{'news_cat_id'};
    my $species_id      = $item{'species_id'};
    my $priority        = $item{'priority'};

    my $sql = qq(
        UPDATE
            news_item
        SET
            release_id    = "$release_id",
            date            = NOW(),
            title           = "$title",
            content         = "$content",
            news_cat_id     = "$news_cat_id",
            species_id      = "$species_id",
            priority        = "$priority"
        WHERE
            news_item_id = "$id"
        );
    my $sth = $self->db->prepare($sql);
#warn 'SQL: '.$sql;
    my $result = $sth->execute();

}

############## QUERIES FOR ADDITIONAL TABLES ################

sub fetch_release_list {
    my $self = shift;
    my $results = [];

    return [] unless $self->db;

    my $sql = qq(
        SELECT
                r.release_id    as release_id,
                r.number        as release_number,
                DATE_FORMAT(r.date, '%b %Y') as date
        FROM
                release r
        ORDER BY release_id DESC
    );

    my $T = $self->db->selectall_arrayref($sql, {});

    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        push (@$results,
            {
            'release_id'        => $array[0],
            'release_number'    => $array[1],
            'date'              => $array[2]
            }
        );
    }
    return $results;
}

sub fetch_species_list {
    my ($self, $release) = @_;
    my $results = [];

    return [] unless $self->db;

    my $sql = qq(
        SELECT
                s.species_id    as species_id,
                s.name          as species_name
        FROM
                species s,
                release r,
                release_species x
        WHERE   s.species_id = x.species_id
        AND     r.release_id = x.release_id
        AND     r.number = $release
        ORDER BY species_name ASC
    );

    my $T = $self->db->selectall_arrayref($sql);
    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        push (@$results,
            {
            'species_id'        => $array[0],
            'species_name'      => $array[1],
            }
        );
    }
    return $results;
}

sub fetch_cat_list {
    my $self = shift;
    my $results = [];

    return [] unless $self->db;

    my $sql = qq(
        SELECT
                c.news_cat_id    as news_cat_id,
                c.name           as news_cat_name
        FROM
                news_cat c
        ORDER BY c.priority DESC
    );

    my $T = $self->db->selectall_arrayref($sql);
    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        push (@$results,
            {
            'news_cat_id'        => $array[0],
            'news_cat_name'      => $array[1],
            }
        );
    }
    return $results;
}

1;

