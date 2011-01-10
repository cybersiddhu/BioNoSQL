package BioDB::Role::Adaptor::Blast;

use strict;

# Other modules:
use Moose::Role;
use namespace::autoclean;

# Module implementation
#

requires qw/load load_blast file/;

has 'id_parser' => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_id_parser'
);

has 'default_id_parser' => (
    is      => 'ro',
    isa     => 'CodeRef',
    default => sub {
        sub {
            my ($string) = @_;
            return $1 if $string =~ /^>\s*(\S+)/;
        }
    }
);

1;    # Magic true value required at end of module

