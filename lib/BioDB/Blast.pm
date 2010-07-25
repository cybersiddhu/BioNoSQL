package BioDB::Blast;

use strict;
use Moose;
use BioDB::Types qw/BlastFormat/;
use MongoDB;
use Moose::Util qw/apply_all_roles/;
use Bio::SearchIO;
use Carp;
use MooseX::Aliases;
use namespace::autoclean;

has 'host' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'localhost',
    lazy    => 1
);

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
    alias   => 'namespace',
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
    isa     => 'Bool',
    is      => 'rw',
    default => sub {0},
    lazy    => 1
);

has 'searchio' => (
    isa => 'Bio::SearchIO',
    is  => 'rw'
);

sub load {
    my ( $self, $arg ) = @_;
    my $file = $arg ? $arg : $self->file;
    croak "Input file not given\n" if !$file;

    $self->searchio(
        Bio::SearchIO->new( -format => $self->format, -file => $file ) );

    my $adaptor = 'BioDB::Role::Adaptor::Blast::Has' . ucfirst $self->adaptor;
    my $interface = 'BioDB::Role::Adaptor::Blast';
    if ( !$self->meta->does_role($adaptor) ) {
        apply_all_roles( $self, $adaptor );
    }
    if ( !$self->meta->does_role($interface) ) {
        apply_all_roles( $self, $interface );
    }
    $self->load_blast;
}

1;

__END__

=head1 BioDB::Blast
