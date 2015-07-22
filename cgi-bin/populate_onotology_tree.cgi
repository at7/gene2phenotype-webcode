#!/usr/bin/perl -w
 
use strict;
use lib '/nfs/web-hx/vg/gene2phenotype/perl/lib/share/perl5';
use CGI;
use JSON;
use lib "../../lib/ensembl/modules";
use lib "../../lib/gene2phenotype/modules";
use Bio::EnsEMBL::Registry;
use G2P::Registry;

# HTTP HEADER
print "Content-type: application/json\n\n";

my $cgi = CGI->new();
my $id = $cgi->param('id');
my $GFD_id = $cgi->param('GFD_id');

my $ontology_registry = 'Bio::EnsEMBL::Registry';
my $ontology_file = "../../../../config/ontology_registry";
$ontology_registry->load_all($ontology_file);

my $configuration_file = '../../../../config/registry';
my $registry = G2P::Registry->new($configuration_file);

my $GFD_adaptor = $registry->get_adaptor('genomic_feature_disease');
my $GFD = $GFD_adaptor->fetch_by_dbID($GFD_id);
my $GFDPhenotypes = $GFD->get_all_GFDPhenotypes;
my @phenotype_ids = ();
foreach my $GFDPhenotype (@$GFDPhenotypes) {
  push @phenotype_ids, $GFDPhenotype->{phenotype_id};
}

my $ontology = $ontology_registry->get_adaptor( 'Multi', 'Ontology', 'OntologyTerm' );
my $ontology_name = 'HPO';

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
    state => {selected => (grep {$_ == $term->dbID} @phenotype_ids) ? JSON::true : JSON::false},
  };
}
 
# JSON OUTPUT
# http://www.jstree.com/docs/json/

print JSON::to_json(\@query_output);
