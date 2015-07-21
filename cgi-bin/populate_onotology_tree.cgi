#!/usr/bin/perl -w
 
use strict;
use lib '/nfs/web-hx/vg/gene2phenotype/perl/lib/share/perl5';
use CGI;
use JSON;
use lib "../../lib/ensembl/modules";
use Bio::EnsEMBL::Registry;

# HTTP HEADER
print "Content-type: application/json\n\n";

my $cgi = CGI->new();
my $id = $cgi->param('id');
my $registry = 'Bio::EnsEMBL::Registry';

$registry->load_registry_from_db(
  -host => 'ensembldb.ensembl.org',
  -user => 'anonymous',
  -port => 3337,
);

my $ontology = $registry->get_adaptor( 'Multi', 'Ontology', 'OntologyTerm' );
my $ontology_name = 'GO';

my @terms = (); 
my @query_output = ();

if ("$id" eq '#') {
  @terms = @{$ontology->fetch_all_roots($ontology_name)};
} else {
  my $parent_term = $ontology->fetch_by_dbID($id);
  @terms = @{$ontology->fetch_all_by_parent_term($parent_term)};
}

foreach my $term (@terms) {
  my @children = @{$term->children};
  push @query_output, {
    id => $term->dbID,
    text => $term->name,
    children => (scalar @children > 0) ? JSON::true : JSON::false,
  };

}
 
# JSON OUTPUT
#[{"id":1,"text":"Root node","children":true}]

print JSON::to_json(\@query_output);
