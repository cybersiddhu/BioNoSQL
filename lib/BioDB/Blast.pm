package BioDB::Blast;

use strict;
use Moose;
use BioDB::Types qw/BlastFormat/;
use MongoDB;
use namespace::autoclean;

has 'database' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'blastdb',
    lazy    => 1
);

has 'adaptor' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'mongodb',
    lazy    => 1
);

has 'collection' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'blast',
    lazy    => 1
);

has 'file' => (
    is  => 'rw',
    isa => 'Str'
);

has 'format' => (
    isa     => BlastFormat,
    is      => 'rw',
    default => 'blast',
    lazy    => 1
);

has 'refresh' => (
    isa     => 'Boolean',
    is      => 'rw',
    default => sub {0},
    lazy    => 1
);

1;


__END__

# ABSTRACT: Storage and retreival of biological data formats using NoSQL backend
