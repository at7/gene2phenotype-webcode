use strict;
use warnings;

use lib "../../lib/gene2phenotype/modules";
use Text::CSV;
use G2P::Registry;

my $configuration_file = '../../../../config/registry';

my $registry = G2P::Registry->new($configuration_file);

sub download_data_api {
  my $downloads_dir = shift;
  my $csv_file_name = "G2P.csv";
  my $csv_file = "$downloads_dir/$csv_file_name";
  
  my $GFD_adaptor = $registry->get_adaptor('genomic_feature_disease');

  my $GFDs = $GFD_adaptor->fetch_all();

  my $csv = Text::CSV->new ( { binary => 1, eol => "\r\n" } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
  open my $fh, ">:encoding(utf8)", "$csv_file" or die "$csv_file: $!";
  $csv->eol ("\r\n");
  $csv->print($fh, ['gene symbol', 'gene mim', 'disease name', 'disease mim', 'DDD category', 'allelic requirement', 'mutation consequence', 'phenotypes', 'organ specificity list', 'pmids']);
  foreach my $GFD (@$GFDs) {
  # Header: Gene_name Gene_mim Disease_name Disease_mim DDD_category Allelic_requirement Mutation_consequence Phenotypes Organs PMIDs
    my $gene_symbol = $GFD->get_GenomicFeature()->gene_symbol || 'No gene symbol'; 
    my $gene_mim = $GFD->get_GenomicFeature()->mim || 'No gene mim'; 
    my $disease_name = $GFD->get_Disease()->name || 'No disease name';
    my $disease_mim = $GFD->get_Disease()->mim || 'No disease mim';
    my $DDD_category = $GFD->DDD_category() || 'No DDD category';
    my $phenotypes = join(';', map {$_->get_Phenotype->stable_id} @{$GFD->get_all_GFDPhenotypes});
    my $organs = join(';', map {$_->get_Organ->name} @{$GFD->get_all_GFDOrgans});
    my $pmids = join(';', map {$_->get_Publication->pmid} @{$GFD->get_all_GFDPublications});
    my $GFDAs = $GFD->get_all_GenomicFeatureDiseaseActions();
    foreach my $GFDA (@$GFDAs) {
      my $allelic_requirement = $GFDA->allelic_requirement;
      my $mutation_consequence = $GFDA->mutation_consequence;
      my @row = ($gene_symbol, $gene_mim, $disease_name, $disease_mim, $DDD_category, $allelic_requirement, $mutation_consequence, $phenotypes, $organs, $pmids);
      $csv->print ($fh, \@row);
    }
  }
  close $fh or die "$csv: $!";
  system("/usr/bin/gzip $csv_file");
  return "$csv_file_name.gz"
}

sub download_data {
  my $downloads_dir = shift;
  my $panel_name = shift;
  my $csv_file_name = 'G2P.csv';
  if ($panel_name eq 'DD') {
    $csv_file_name = 'DDG2P.csv';
  } elsif ($panel_name eq 'Skin') {
    $csv_file_name = 'SkinG2P.csv';
  } else {
    $csv_file_name = 'G2P.csv';
  }
  my $csv_file = "$downloads_dir/$csv_file_name";

  my $dbh = $registry->{dbh};

  my $csv = Text::CSV->new ( { binary => 1, eol => "\r\n" } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
  open my $fh, ">:encoding(utf8)", "$csv_file" or die "$csv_file: $!";
  $csv->print($fh, ['gene symbol', 'gene mim', 'disease name', 'disease mim', 'DDD category', 'allelic requirement', 'mutation consequence', 'phenotypes', 'organ specificity list', 'pmids', 'panel']);

  $csv->eol ("\r\n");

  my $gfd_attribute_tables = {
    phenotype => {sql => 'SELECT gfdp.genomic_feature_disease_id, p.stable_id FROM genomic_feature_disease_phenotype gfdp, phenotype p WHERE gfdp.phenotype_id = p.phenotype_id;'},
    organ => {sql => 'SELECT gfdo.genomic_feature_disease_id, o.name FROM genomic_feature_disease_organ gfdo, organ o WHERE gfdo.organ_id = o.organ_id'},
    publication => {sql => 'SELECT gfdp.genomic_feature_disease_id, p.pmid FROM genomic_feature_disease_publication gfdp, publication p WHERE gfdp.publication_id = p.publication_id;'},
  };

  my $gfd_attributes = {};
  foreach my $table (keys %$gfd_attribute_tables) {
    my $sql = $gfd_attribute_tables->{$table}->{sql};
    my $sth = $dbh->prepare($sql);
    $sth->execute() or die 'Could not execute statement: ' . $sth->errstr;
    while (my $row = $sth->fetchrow_arrayref()) {
      my ($id, $value) = @$row;
      $gfd_attributes->{$id}->{$table}->{$value} = 1;
    }
  }

  my $attribs = {};
  my $sth = $dbh->prepare(q{SELECT attrib_id, value FROM attrib;});
  $sth->execute() or die 'Could not execute statement: ' . $sth->errstr;
  while (my $row = $sth->fetchrow_arrayref()) {
    my ($id, $value) = @$row;
    $attribs->{$id} = $value;
  }
  my $where = ($panel_name eq 'ALL') ? '' : "WHERE a.value = '$panel_name'";

  $sth = $dbh->prepare(qq{
    SELECT gfd.genomic_feature_disease_id, gf.gene_symbol, gf.mim, d.name, d.mim, gfd.DDD_category_attrib, gfda.allelic_requirement_attrib, gfda.mutation_consequence_attrib, a.value
    FROM genomic_feature_disease gfd
    LEFT JOIN genomic_feature_disease_action gfda ON gfd.genomic_feature_disease_id = gfda.genomic_feature_disease_id
    LEFT JOIN genomic_feature gf ON gfd.genomic_feature_id = gf.genomic_feature_id
    LEFT JOIN disease d ON gfd.disease_id = d.disease_id
    LEFT JOIN attrib a ON gfd.panel_attrib = a.attrib_id
    $where;
  });

  $sth->execute() or die 'Could not execute statement: ' . $sth->errstr;
  my ($gfd_id, $gene_symbol, $gene_mim, $disease_name, $disease_mim, $DDD_category_attrib, $ar_attrib, $mc_attrib, $panel);
  $sth->bind_columns(\($gfd_id, $gene_symbol, $gene_mim, $disease_name, $disease_mim, $DDD_category_attrib, $ar_attrib, $mc_attrib, $panel));
  while ( $sth->fetch ) {
    $gene_symbol ||= 'No gene symbol';
    $gene_mim ||= 'No gene mim';
    $disease_name ||= 'No disease name';
    $disease_mim ||= 'No disease mim';
    my $DDD_category = ($DDD_category_attrib) ? $attribs->{$DDD_category_attrib} : 'No DDD category';
    my $allelic_requirement = ($ar_attrib) ? join(',', map { $attribs->{$_} } split(',', $ar_attrib)) : undef;
    my $mutation_consequence = ($mc_attrib) ? join(',', map { $attribs->{$_} } split(',', $mc_attrib)) : undef;

    my @annotations = ();
    if ($gfd_attributes->{$gfd_id}) {
      foreach my $table (qw/phenotype organ publication/) {
        if ($gfd_attributes->{$gfd_id}->{$table}) {
          push @annotations, join(';', keys %{$gfd_attributes->{$gfd_id}->{$table}});
        } else {
          push @annotations, undef;
        }
      }
    } else {
      push @annotations, (undef, undef, undef);
    }

    my @row = ($gene_symbol, $gene_mim, $disease_name, $disease_mim, $DDD_category, $allelic_requirement, $mutation_consequence, @annotations, $panel);

    $csv->print ($fh, \@row);
  }
  close $fh or die "$csv: $!";
  system("/usr/bin/gzip $csv_file");
  return "$csv_file_name.gz"
}
