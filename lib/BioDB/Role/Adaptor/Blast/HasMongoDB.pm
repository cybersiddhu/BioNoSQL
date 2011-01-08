package BioDB::Role::Adaptor::Blast::HasMongodb;
use strict;
# Other modules:
use Carp;
use Moose::Role;
use MongoDB;
use MooseX::Params::Validate;
use MooseX::Aliases;
use namespace::autoclean;

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

has 'mongo_collection' => (
    is      => 'rw',
    isa     => 'MongoDB::Collection',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->mongodb->get_collection( $self->collection );
    }
);

after 'collection' => sub {
	my ($self,  $name) = @_;
	return if !$name;
	$self->mongo_collection($self->mongodb->$name);
};

before 'load_blast' => sub {
    my ($self) = @_;
    $self->mongo_collection->drop if $self->refresh;
};

sub insert {
    my $self = shift;
    my ($result)
        = pos_validated_list( \@_,
        { isa => 'Bio::Search::Result::ResultI' } );

    my $result_data;
    $result_data->{$_} = $result->$_
        for (
        qw/query_accession query_name query_length num_hits algorithm
        database_name/
        );
    while ( my $hit = $result->next_hit ) {
        my $hit_data;
        while ( my $hsp = $hit->next_hsp ) {
            push @{ $hit_data->{hsps} }, {
                evalue           => $hsp->evalue,
                gaps             => $hsp->gaps,
                total_length     => $hsp->hsp_length,
                score            => $hsp->score,
                bits             => $hsp->bits,
                percent_identity => $hsp->percent_identity,
                query_start      => $hsp->start('query'),
                query_end        => $hsp->end('query'),
                hit_start        => $hsp->start('hit'),
                hit_end          => $hsp->end('hit'),
                rank             => $hsp->rank,
                query_string     => $hsp->query_string,
                hit_string       => $hsp->hit_string,
                homology_string  => $hsp->homology_string,

            };
        }
        $hit_data->{$_} = $hit->$_
            for
            qw/strand frame length accession description significance bits locus num_hsps/;
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

1;    # Magic true value required at end of module

