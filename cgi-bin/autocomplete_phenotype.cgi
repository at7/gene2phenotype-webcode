#!/usr/bin/perl -w

# PERL MODULES WE WILL BE USING
# http://www.jensbits.com/2011/05/09/jquery-ui-autocomplete-widget-with-perl-and-mysql/
use strict;
use lib '/nfs/web-hx/vg/gene2phenotype/perl/lib/share/perl5';
use CGI;
use DBI;
use DBD::mysql;
use JSON;
use FileHandle;

# HTTP HEADER
print "Content-type: application/json\n\n";

# CONFIG VARIABLES
my $platform = "mysql";

my $configuration_file = '../../../../config/registry';
my $fh = FileHandle->new($configuration_file, 'r');
my $params = {};
while (<$fh>) {
  chomp;
  my ($db_connection_parameter, $value) = split /=/;
  $params->{$db_connection_parameter} = $value;
}
$fh->close();
my $database = $params->{database};
my $host = $params->{host};
my $port = $params->{port};
my $user = $params->{user};
my $password = $params->{password};
my $tablename = "phenotype";

my $cgi = CGI->new();
my $term = $cgi->param('term');

# DATA SOURCE NAME
my $dsn = "dbi:mysql:$database:$host:$port";
# PERL DBI CONNECT
my $connect = DBI->connect($dsn, $user, $password);

# PREPARE THE QUERY
my $query_handle = $connect->prepare(qq{select name AS value FROM phenotype where name like ?;});

# EXECUTE THE QUERY
#$query_handle->execute('%'.$term.'%');
$query_handle->execute($term.'%');

# LOOP THROUGH RESULTS
my @query_output = ();
while ( my $row = $query_handle->fetchrow_hashref ){
    push @query_output, $row;
}
# CLOSE THE DATABASE CONNECTION
$connect->disconnect();

# JSON OUTPUT
print JSON::to_json(\@query_output);
