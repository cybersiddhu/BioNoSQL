use strict;
use Test::More qw/no_plan/;
use MongoDB;
use Try::Tiny;
use FindBin qw/$Bin/;
use File::Spec::Functions;
use Module::Build;

SKIP: {
	my $host = $ENV{MONGOD} || 'localhost';
	my $conn;
	try {
		$conn = MongoDB::Connection->new(host => $host);
	}
	catch {
		skip "mongodb connection cannot be done: $_";	
	};

	use_ok('BioDB::Blast');
	my $biodb = BioDB::Blast->new(host => $host);
	isa_ok($biodb,  'BioDB::Blast');

	$biodb->database('test_biodb');
	$biodb->collection('test_blast');

	my $builder = Module::Build->current;
	my $file = catfile($builder->base_dir,  't',  'data',  'multi_blast.bls');
	$biodb->file($file);
	my $record = $biodb->load;
	is($record, 4,  'it has loaded blast records');

	$conn->get_database('test_biodb')->drop;

}
