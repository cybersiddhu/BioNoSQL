use strict;
use Test::More qw/no_plan/;
use MongoDB;
use Try::Tiny;
use File::Spec::Functions;
use Module::Build;
use Bio::SearchIO;

SKIP: {
    my $host = $ENV{MONGOD} || 'localhost';
    my $conn;
    try {
        $conn = MongoDB::Connection->new( host => $host );
    }
    catch {
        skip "mongodb connection cannot be done: $_";
    };

    use_ok('BioDB::Blast');
    my $biodb = BioDB::Blast->new( host => $host );
    isa_ok( $biodb, 'BioDB::Blast' );

    $biodb->database('test_biodb');
    $biodb->collection('test_blast');

    my $builder  = Module::Build->current;
    my $data_dir = catdir( $builder->base_dir, 't', 'data' );
    my $file     = catfile( $data_dir, 'multi_blast.bls' );
    $biodb->file($file);
    my $record = $biodb->load;
    is( $record, 4, 'it has loaded blast records' );

    $biodb->namespace('test_blast2');
    my $searchio = Bio::SearchIO->new(
        -file   => catfile( $data_dir, 'a_thaliana.blastn' ),
        -format => 'blast'
    );
    while ( my $result = $searchio->next_result ) {
        $biodb->save($result);
    }
    is( $biodb->mongo_collection->count,
        1, 'it has loaded another blast result' );

    $conn->get_database('test_biodb')->drop;

}
