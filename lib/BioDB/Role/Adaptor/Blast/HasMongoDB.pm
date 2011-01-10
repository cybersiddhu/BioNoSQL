package BioDB::Role::Adaptor::Blast::HasMongodb;
use strict;

# Other modules:
use namespace::autoclean;
use Carp;
use Moose::Role;
use MongoDB;
use MooseX::Params::Validate;
use MooseX::Aliases;
use Bio::Search::Result::GenericResult;
use Bio::Search::Hit::GenericHit;
use Bio::Search::HSP::GenericHSP;

# Module implementation
#

requires qw/host database collection refresh/;

has 'connection' => (
    is      => 'rw',
    isa     => 'MongoDB::Connection',
    lazy    => 1,
    default => sub {
        my $self = shift;
        MongoDB::Connection->new( host => $self->host );
    },
);

has 'mongodb' => (
    is      => 'ro',
    isa     => 'MongoDB::Database',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->connection->get_database( $self->database );
    }
);

before 'load_blast' => sub {
    my ($self) = @_;
    $self->mongo_collection->drop if $self->refresh;
};

sub mongo_collection {
    my ($self) = @_;
    my $collection = $self->mongodb->get_collection( $self->collection );
    return $collection if $collection;
}

sub insert {
    my $self = shift;
    my ($result)
        = pos_validated_list( \@_,
        { isa => 'Bio::Search::Result::ResultI' } );

    my $result_data;
    $result_data->{query_name}
        = $self->has_id_parser
        ? $self->id_parser->( $result->query_name )
        : $result->query_name;

    $result_data->{$_} = $result->$_
        for (
        qw/query_accession query_length num_hits algorithm
        database_name/
        );

    $result_data->{statistics}->{$_} = $result->get_statistic($_)
        for $result->available_statistics;

    while ( my $hit = $result->next_hit ) {
        my $hit_data;
        while ( my $hsp = $hit->next_hsp ) {
            push @{ $hit_data->{hsps} }, {
                evalue           => $hsp->evalue,
                hsp_gaps         => $hsp->gaps,
                query_gaps       => $hsp->gaps('query'),
                hit_gaps         => $hsp->gaps('hit'),
                hsp_length       => $hsp->hsp_length,
                score            => $hsp->score,
                bits             => $hsp->bits,
                percent_identity => $hsp->percent_identity,
                query_start      => $hsp->start('query'),
                query_end        => $hsp->end('query'),
                query_length     => $hsp->length('query'),
                query_seq        => $hsp->query_string,
                hit_start        => $hsp->start('hit'),
                hit_end          => $hsp->end('hit'),
                hit_length     => $hsp->length('hit'),
                hit_string       => $hsp->hit_string,
                rank             => $hsp->rank,
                homology_seq     => $hsp->homology_string,
                hit_frame        => $hsp->frame('hit'),
                query_frame      => $hsp->frame('query'),
                identical        => $hsp->num_identical,
                conserved        => $hsp->num_conserved,

            };
        }
        $hit_data->{$_} = $hit->$_
            for
            qw/name strand frame length accession description significance bits locus num_hsps/;
        push @{ $result_data->{hits} }, $hit_data;
    }
    $self->mongo_collection->insert($result_data);
    return;
}

sub load_blast {
    my ($self) = @_;
    while ( my $result = $self->searchio->next_result ) {
        $self->insert($result);
    }
    return $self->mongo_collection->count;
}

alias save => 'insert';

before 'fetch_report' => sub {
    my ($self) = @_;
    croak 'mongodb collection ', $self->collection, "do not exist\n"
        if !$self->mongo_collection;
};

sub fetch_report {
    my $self = shift;
    my ($id) = pos_validated_list( \@_, { isa => 'Str' } );
    my $result = $self->mongo_collection->find_one( { 'query_name' => $id } );
    return if !$result;

    my $bio_result = Bio::Search::Result::GenericResult->new;
    $bio_result->$_( $result->{$_} )
        for (
        qw/query_name query_accession query_length num_hits algorithm
        database_name/
        );
    $bio_result->add_statistic( $_, $result->{statistics}->{$_} )
        for keys %{ $result->{statistics} };

    for my $hit ( @{ $result->{hits} } ) {
        my $bio_hit
            = Bio::Search::Hit::GenericHit->new( -name => $hit->{name} );
        for my $hsp ( @{ $hit->{hsps} } ) {
            my $bio_hsp = Bio::Search::HSP::GenericHSP->new(
                -evalue           => $hsp->{evalue},
                -pvalue           => $hsp->{pvalue},
                -bits             => $hsp->{bits},
                -score            => $hsp->{score},
                -hsp_length       => $hsp->{hsp_length},
                -percent_identity => $hsp->{percent_identity},
                -hsp_gaps         => $hsp->{gaps},
                -query_gaps       => $hsp->{query_gaps},
                -hit_gaps         => $hsp->{hit_gaps},
                -query_start      => $hsp->{query_start},
                -query_end        => $hsp->{query_end},
                -query_length     => $hsp->{query_length},
                -query_seq        => $hsp->{query_seq},
                -hit_start        => $hsp->{hit_start},
                -hit_end          => $hsp->{hit_end},
                -hit_length       => $hsp->{hit_length},
                -homology_seq     => $hsp->{homology_seq},
                -rank             => $hsp->{rank},
                -hit_frame        => $hsp->{hit_frame},
                -query_frame      => $hsp->{query_frame},
                -identical        => $hsp->{identical},
                -conserved        => $hsp->{conserved}
            );
            $bio_hit->add_hsp($bio_hsp);
        }
        $bio_hit->$_( $hit->{$_} )
            for
            qw/strand frame length accession description significance bits locus num_hsps/;

        $bio_result->add_hit($bio_hit);
    }
    return $bio_result;
}

1;    # Magic true value required at end of module

