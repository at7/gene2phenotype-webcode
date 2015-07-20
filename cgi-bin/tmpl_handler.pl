use strict;
use warnings;

use HTML::Template;
use List::MoreUtils qw(first_index);
use DBI;
use JSON;
use lib "../../lib/gene2phenotype/modules";
use lib "../../lib/ensembl/modules";
use lib "../../lib/ensembl-variation/modules";

use G2P::Registry;
use Bio::EnsEMBL::Registry;
my $ensembl_registry = 'Bio::EnsEMBL::Registry';
$ensembl_registry->load_registry_from_db(
  -host => 'ensembldb.ensembl.org',
  -user => 'anonymous',
  -port => 3337,
);

use constant TMPL_FILE => "../htdocs/G2P.tmpl";
my $tmpl = new HTML::Template( filename => TMPL_FILE, global_vars => 1 );

my $configuration_file = '../../../../config/registry';

my $registry = G2P::Registry->new($configuration_file);

my $constants = {
  RESET_PWD_SUC => { msg => 'Password was successfully updated.', type => 'success'}, 
  PWD_ERROR => { msg  => 'Error. Password verification failed.', type => 'danger',},
  PWDS_DONT_MATCH => { msg => 'Error. Retyped and new password don\'t match.', type => 'danger',},
  MISSING_PWDS => { msg => 'Error. You must provide a new password and retype the new password.', type => 'danger',},
  RESET_PWD_ERROR => { msg => 'There was an error resetting you password. Please contact g2p-help@ebi.ac.uk.', type => 'danger'},
  RESET_USERNAME_SUC => { msg => 'Username was successfully updated.', type => 'success',},
  USERNAME_IN_USE => { msg => 'The new username is already taken.', type => 'danger'},
  NEW_USERNAME_MISSING => { msg => 'You need to provide a new username.', type => 'danger',},
  EMAIL_IN_USE => { msg => 'The new email is already taken.', type => 'danger',},
  RESET_EMAIL_SUC => { msg => 'Email was successfully updated.', type => 'success',},
  EMAIL_UNKNOWN => { msg => 'The email address is not known. Please contact g2p-help@ebi.ac.uk.', type => 'danger',},
  SESSION_IDS_DONT_MATCH => { msg => 'Session ids don\'t match. Please contact g2p-help@ebi.ac.uk.', type => 'danger',},
  ERROR_ADD_GENE_DISEASE_PAIR => { msg => 'You must provide a gene name and a disease name.', type => 'danger',},  
  LOGIN_FAILED => { msg => 'Login failed. You entered a wrong password. Try again or reset your password.', type => 'danger',},
  DISEASE_NAME_IN_DB => { msg => 'Disease name is already in database.', type => 'danger',},
  UPDATED_DISEASE_ATTRIBS_SUC => { msg => 'Successfully updated disease attributes.', type => 'success',},
  UPDATED_VISIBILITY_STATUS_SUC => { msg => 'Successfully updated visibility status.', type => 'success',},
  DISEASE_MIM_IN_DB => { msg => 'Disease mim is already in database.', type => 'danger',},
  WRONG_FORMAT_DISEASE_MIM => { msg => 'Invalid format for disease mim. It needs to be a number.', type => 'danger',},
  UPDATED_ORGAN_LIST => { msg => 'Successfully updated organ specificity list.', type => 'success',},
  UPDATED_DDD_CATEGORY_SUC => { msg => 'Successfully updated DDD category', type => 'success',},
  UPDATED_GFD_ACTION_SUC => { msg => 'Successfully updated genomic feature disease action.', type => 'success',},
  ADDED_GFD_ACTION_SUC => { msg => 'Successfully added a new genomic feature disease action.', type => 'success'},
  ADDED_GFDPHENOTYPE_SUC => { msg => 'Successfully added a new phenotype for the genomic feature disease pair.', type => 'success'},
  ADDED_PUBLICATION_SUC => { msg => 'Successfully added a new publication', type => 'success'},
  DELETED_GFDPHENOTYPE_SUC => { msg => 'Successfully delete a phenotype entry.', type => 'success'},
  ADDED_GFDPC_SUC => { msg => 'Successfully added a new comment.', type => 'success'},
  DELETED_GFD_ACTION_SUC => { msg => 'Successfully deleted a genomic feature disease action.', type => 'success'},
  DELETED_GFDPC_SUC => { msg => 'Successfully deleted the comment.', type => 'success'},
};

my $consequence_colors = {
  'intergenic_variant'                 => '#636363',
  'intron_variant'                     => '#02599c',
  'upstream_gene_variant'              => '#91a2b8',
  'downstream_gene_variant'            => '#91a2b8',
  '5_prime_UTR_variant'                => '#7ac5cd',
  '3_prime_UTR_variant'                => '#7ac5cd',
  'splice_region_variant'              => '#ff7f50',
  'splice_donor_variant'               => '#FF581A',
  'splice_acceptor_variant'            => '#FF581A',
  'frameshift_variant'                 => '#9400D3',
  'transcript_ablation'                => '#ff0000',
  'transcript_amplification'           => '#ff69b4',
  'inframe_insertion'                  => '#ff69b4',
  'inframe_deletion'                   => '#ff69b4',
  'synonymous_variant'                 => '#76ee00',
  'stop_retained_variant'              => '#76ee00',
  'missense_variant'                   => '#d8b600',
  'start_lost'                         => '#ffd700',
  'stop_gained'                        => '#ff0000',
  'stop_lost'                          => '#ff0000',
  'mature_mirna_variant'               => '#99FF00',
  'non_coding_transcript_exon_variant' => '#32cd32',
  'non_coding_transcript_variant'      => '#32cd32',
  'no_consequence'                     => '#68228b',
  'incomplete_terminal_codon_variant'  => '#ff00ff',
  'nmd_transcript_variant'             => '#ff4500',
  'hgmd_mutation'                      => '#8b4513',
  'coding_sequence_variant'            => '#99FF00',
  'failed'                             => '#cccccc',
  'tfbs_ablation'                      => '#a52a2a',
  'tfbs_amplification'                 => '#a52a2a',
  'tf_binding_site_variant'            => '#a52a2a',
  'regulatory_region_variant'          => '#a52a2a',
  'regulatory_region_ablation'         => '#a52a2a',
  'regulatory_region_amplification'    => '#a52a2a',
  'protein_altering_variant'           => '#FF0080',
  'NMD_transcript_variant'             => '#007fff',
};

sub get_message_hash {
  my $text = shift;
  return $constants->{$text};
}

sub show_downloads_page {
  my $session = shift;
  set_login_status($tmpl, $session);
  $tmpl->param(downloads => 1);
  print $tmpl->output();
  return;
}

sub identify_search_type {
  my $search_term = shift;
  my $genomic_feature_adaptor = $registry->get_adaptor('genomic_feature');
  if ($genomic_feature_adaptor->fetch_by_gene_symbol($search_term)) {
    return 'gene_symbol';
  }
  my $disease_adaptor = $registry->get_adaptor('disease');
  if ($disease_adaptor->fetch_by_name($search_term)) {
    return 'disease_name';
  }
  return 'no_entry_in_db';
}

sub set_login_status {
  my $tmpl = shift;
  my $session = shift;
  if ($session->param('is_logged_in')) {
    $tmpl->param(logged_in => 1);
    return 1;
  }
  return 0;
}

sub set_message {
  my $tmpl = shift;
  my $message = shift;
  my $msg_hash = get_message_hash($message);
  my $full_message = $msg_hash->{msg};
  my $msg_type =  $msg_hash->{type};
  $tmpl->param(message => $full_message);
  $tmpl->param(message_type => $msg_type);
}

sub display_search {
  my $session = shift;
  set_login_status($tmpl, $session);
  print $tmpl->output();
  return;
}

sub show_default_page {
  my $session = shift;
  my $message = shift;
  if ($message) {
    set_message($tmpl, $message);
  }
  set_login_status($tmpl, $session);
  print $tmpl->output();
  return;
}

sub show_login_page {
  my $session = shift;
  my $message = shift;
  my $tmpl = new HTML::Template(filename => '../htdocs/Login.tmpl');
  if ($message) {
    set_message($tmpl, $message);
  }
  set_login_status($tmpl, $session);
  $tmpl->param(show_login => 1); 
  print $tmpl->output();
  return;
}

sub show_account_data {
  my $session = shift;
  my $type = shift;
  my $message = shift;
  my $tmpl = new HTML::Template(filename => '../htdocs/Login.tmpl');

  if ($type eq 'recover_pwd') {
    $tmpl->param(recover_pwd => 1);
    print $tmpl->output();
    return; 
  }
  if ($type eq 'recover_pwd_enter_new_pwd') {
    my $email = $session->param('email');
    $tmpl->param(email => $email);
    $tmpl->param(recover_pwd_enter_new_pwd => 1);
    print $tmpl->output();
    return; 
  }

  set_login_status($tmpl, $session);
  if ($message) {
    set_message($tmpl, $message);
  }

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);
  my $name = $user->username();

  if ($type eq 'account') {
    $tmpl->param(account_info => 1);
    $tmpl->param(email => $email);
    $tmpl->param(username => $name);
  } elsif ($type eq 'edit_pwd') {
    $tmpl->param(edit_pwd => 1);
  } elsif ($type eq 'edit_username') {
    $tmpl->param(current_username => $name);
    $tmpl->param(edit_username => 1);
  } elsif ($type eq 'edit_email') {
    $tmpl->param(current_email => $email);
    $tmpl->param(edit_email => 1);
  }
  else {

  }
  print $tmpl->output();
  return; 
}

sub edit_data {
  print $tmpl->output();
  return;
}

sub display_search_results {
  my $session = shift;
  my $search_term = shift;
  my $logged_in = set_login_status($tmpl, $session);

  if (!defined $search_term) {
    print $tmpl->output();
    return;
  }

  my $search_type = identify_search_type($search_term);

  my $disease_adaptor = $registry->get_adaptor('disease');
  my $genomic_feature_adaptor = $registry->get_adaptor('genomic_feature');
  my $genomic_feature_disease_adaptor = $registry->get_adaptor('genomic_feature_disease');

  my $gfds;
  if ($search_type eq 'disease_name') {
    my $disease = $disease_adaptor->fetch_by_name($search_term); 
    my $name = $disease->name;
    my $dbID = $disease->dbID;
    $tmpl->param(disease_results => [{disease_name => $name, search_type => 'disease', dbID => $dbID}]); 

    $gfds = $genomic_feature_disease_adaptor->fetch_all_by_Disease($disease); 
  } elsif ($search_type eq 'gene_symbol') {
    my $genomic_feature = $genomic_feature_adaptor->fetch_by_gene_symbol($search_term);
    my $name = $genomic_feature->gene_symbol;
    my $dbID = $genomic_feature->dbID;
    $tmpl->param(gene_results => [{gene_symbol => $name, search_type => 'gene_symbol', dbID => $dbID}]);
    $gfds = $genomic_feature_disease_adaptor->fetch_all_by_GenomicFeature($genomic_feature);
  } 

  my @gfd_results = ();
  foreach my $gfd (@$gfds) {
    my $genomic_feature = $gfd->get_GenomicFeature;
    my $gene_symbol = $genomic_feature->gene_symbol;
    my $disease = $gfd->get_Disease;
    my $disease_name = $disease->name;
    my $dbID = $gfd->dbID;
    push @gfd_results, {gene_symbol => $gene_symbol, disease_name => $disease_name, search_type => 'gfd', dbID => $dbID};
  }

  $tmpl->param(gfd_results => \@gfd_results);
  $tmpl->param(search_term => $search_term);
  $tmpl->param(display_search_results => 1);
  print $tmpl->output();

}

sub display_data {
  my $session = shift;
  my $search_type = shift;
  my $dbID = shift;
  my $msg = shift;

  if ($msg) {
    set_message($tmpl, $msg);
  }

  my $logged_in = set_login_status($tmpl, $session);
  $tmpl->param(search_type => $search_type);
  $tmpl->param(dbID => $dbID);

  if ($search_type eq 'gfd') {
    $tmpl->param(display_gfd => 1);
    $tmpl->param(GFD_id => $dbID);
    my $genomic_feature_disease_adaptor = $registry->get_adaptor('genomic_feature_disease');
    my $genomic_feature_disease = $genomic_feature_disease_adaptor->fetch_by_dbID($dbID);

    if ($genomic_feature_disease->is_visible) {
      $tmpl->param(authorised => 1);
    } else {
      $tmpl->param(authorised => 0);
    }

    my $genomic_feature = $genomic_feature_disease->get_GenomicFeature;
    my $genomic_feature_attributes = get_genomic_feature_attributes($genomic_feature);
    my $disease = $genomic_feature_disease->get_Disease;
    my $disease_attributes = get_disease_attributes($disease);

    my $get_var = get_variations($genomic_feature->gene_symbol);
    my $variations = $get_var->{'tmpl'}; 
    my $counts = $get_var->{'counts'};

    my $DDD_category = $genomic_feature_disease->DDD_category || 'Not assigned';
    my $gene_disease_category_attribs = get_gene_disease_category_attribs($genomic_feature_disease);
    my $add_GFD_action_form = get_add_gfd_action($genomic_feature_disease);
    my $genomic_feature_disease_actions = $genomic_feature_disease->get_all_GenomicFeatureDiseaseActions();
    my @actions = ();
    foreach my $gfda (@$genomic_feature_disease_actions) {
      my $allelic_requirement = $gfda->allelic_requirement || 'Not assigned';
      my $mutation_consequence_summary = $gfda->mutation_consequence || 'Not assigned';
      my $form = get_edit_gfd_action($gfda); 
      push @actions, {
        mutation_consequence_summary => $mutation_consequence_summary,
        allelic_requirement => $allelic_requirement,
        edit_gfd_action => $form,
      };
    }   
    my $GFD_publications = get_GFD_publications($genomic_feature_disease);
    $tmpl->param(GFD_publications => $GFD_publications);
    my $phenotypes = get_phenotypes($genomic_feature_disease);
    $tmpl->param(phenotypes => $phenotypes);
    my $organs = get_organs($genomic_feature_disease);
    $tmpl->param(organs => $organs);

    my $organ_list = get_organ_list($genomic_feature_disease); 
    my $edit_organs_form = get_edit_organs_form($organ_list, $dbID);

    $tmpl->param($genomic_feature_attributes);
    $tmpl->param($disease_attributes);
    $tmpl->param({
      DDD_category => $DDD_category,
      gene_disease_category_attribs => $gene_disease_category_attribs,
      add_gfd_action_form => $add_GFD_action_form,
      gfd_actions => \@actions,
      edit_organs => $edit_organs_form, 
      variations => $variations,
      consequence_counts => $counts,
    });  
    my $gfd_logs = get_gfd_logs($genomic_feature_disease);
    my $gfda_logs = get_gfda_logs($genomic_feature_disease);
    $tmpl->param(gfd_logs => $gfd_logs);
    $tmpl->param(gfda_logs => $gfda_logs);
    $tmpl->param(display_gfd => 1);
    print $tmpl->output();
  } elsif ($search_type eq 'disease') {
    $tmpl->param(display_disease => 1);
    my $disease_adaptor = $registry->get_adaptor('disease');
    my $disease = $disease_adaptor->fetch_by_dbID($dbID);
    my $disease_attributes = get_disease_attributes($disease);
    $tmpl->param($disease_attributes);
    print $tmpl->output();
  } elsif ($search_type eq 'gene_symbol') {
    $tmpl->param(display_gene => 1);
    my $genomic_feature_adaptor = $registry->get_adaptor('genomic_feature');
    my $genomic_feature = $genomic_feature_adaptor->fetch_by_dbID($dbID);
    my $genomic_feature_attributes = get_genomic_feature_attributes($genomic_feature);
    my $get_var = get_variations($genomic_feature->gene_symbol);
    my $variations = $get_var->{'tmpl'}; 
    my $counts = $get_var->{'counts'};
    $tmpl->param($genomic_feature_attributes);
    $tmpl->param({
      variations => $variations,
      consequence_counts => $counts,
    });  
    print $tmpl->output();
  } else {

  }
}

sub new_gene_disease {
  my $session = shift;
  my $message = shift;
  my $logged_in = set_login_status($tmpl, $session);
  set_message($tmpl, $message) if ($message);
  $tmpl->param(new_gene_disease => 1);
  $tmpl->param(add_new_gene_disease => $logged_in);
  print $tmpl->output();
}

sub add_new_gene_disease {
  my $session = shift;
  my $gene_name = shift;
  my $disease_name = shift;
  if (!$gene_name || !$disease_name) {
    new_gene_disease($session, 'ERROR_ADD_GENE_DISEASE_PAIR');
    return; 
  }

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $genomic_feature_adaptor = $registry->get_adaptor('genomic_feature');
  my $disease_adaptor = $registry->get_adaptor('disease');
  my $genomic_feature_disease_adaptor = $registry->get_adaptor('genomic_feature_disease');

  my $genomic_feature = $genomic_feature_adaptor->fetch_by_gene_symbol($gene_name);

  my $disease = $disease_adaptor->fetch_by_name($disease_name);
  if (!$disease) {
    $disease = G2P::Disease->new({name => $disease_name});
    $disease = $disease_adaptor->store($disease); 
  }

  my $genomic_feature_disease = $genomic_feature_disease_adaptor->fetch_by_GenomicFeature_Disease($genomic_feature, $disease);

  if (!$genomic_feature_disease) {
    $genomic_feature_disease = G2P::GenomicFeatureDisease->new({
      genomic_feature_id => $genomic_feature->dbID(),
      disease_id => $disease->dbID(),
    });
    $genomic_feature_disease = $genomic_feature_disease_adaptor->store($genomic_feature_disease, $user);
  }

  display_data($session, 'gfd', $genomic_feature_disease->dbID);
}

sub get_genomic_feature_attributes {
  my $genomic_feature = shift;
  my $gene_symbol = $genomic_feature->gene_symbol;
  my $gene_mim = $genomic_feature->mim;
  my $ensembl_stable_id = $genomic_feature->ensembl_stable_id;
  return {
    ensembl_stable_id => $ensembl_stable_id,
    gene_symbol => $gene_symbol,
    gene_mim => $gene_mim,
  };
}

sub get_disease_attributes {
  my $disease = shift;
  my $disease_name = $disease->name;
  my $disease_mim = $disease->mim;
  my $disease_id = $disease->dbID;
  return { 
    disease_name => $disease_name,
    disease_mim => $disease_mim,
    disease_id => $disease_id,
  };
}

sub get_variations {
  my $gene_symbol = shift;

  my $gene_adaptor = $ensembl_registry->get_adaptor('human', 'core', 'gene');
  my $vfa = $ensembl_registry->get_adaptor('human', 'variation', 'variationfeature');
  my @genes = @{ $gene_adaptor->fetch_all_by_external_name($gene_symbol) };

  my @variations_tmpl = ();
  my $counts = {};
  foreach my $gene (@genes) {
    my $vfs = $vfa->fetch_all_by_Slice_constraint($gene->feature_Slice, "vf.clinical_significance='pathogenic'");
    my $consequence_count = {};
    foreach my $vf (@$vfs) {
      my $variant_name = $vf->variation_name;
      my $clin_sgn = join(', ', @{$vf->get_all_clinical_significance_states});
      my $tvs = $vf->get_all_TranscriptVariations();
      foreach my $tv (@$tvs) {
        foreach my $consequence (@{$tv->consequence_type}) {
          $counts->{$consequence}++;
        }
        my $consequence_types = join(', ', @{$tv->consequence_type});
        my $hgvs_transcript = join(',', values %{$tv->hgvs_transcript()});
        push @variations_tmpl, {
          variant_name => $variant_name,
          consequence => $consequence_types, 
          hgvs_transcript => $hgvs_transcript,
          clin_sgn => $clin_sgn,
        };
      }
    }
  }
  my @array = ();
  while (my ($consequence, $count) = each %$counts) {
    push @array, {'label' => $consequence, 'value' => $count, 'color' => $consequence_colors->{$consequence} || '#d0d6fe'};
  }
  my $encoded_counts = encode_json(\@array);
  return { 'tmpl' => \@variations_tmpl, 'counts' => $encoded_counts };
}

sub get_GFD_publications {
  my $GFD = shift;
  my @GFD_publications_tmpl = ();
  my $GFD_publications = $GFD->get_all_GFDPublications;
  foreach my $GFD_publication (@$GFD_publications) {
    my $publication = $GFD_publication->get_Publication;
    my $comments = $GFD_publication->get_all_GFDPublicationComments; 
    my @comments_tmpl = ();
    foreach my $comment (@$comments) {
      push @comments_tmpl, {
        user => $comment->get_User()->username,
        date => $comment->created,
        comment_text => $comment->comment_text,
        GFD_publication_comment_id => $comment->dbID,
        GFD_id => $GFD->dbID,
      }; 
    }
    my $pmid = $publication->pmid;
    my $title = $publication->title;
    my $source = $publication->source;
   
    $title ||= 'PMID:' . $pmid;
    $title .= " ($source)" if ($source);

    push @GFD_publications_tmpl, {
      comments => \@comments_tmpl,
      title => $title, 
      pmid => $pmid,
      GFD_publication_id => $GFD_publication->dbID,
      GFD_id => $GFD->dbID,
    };
  }
  return \@GFD_publications_tmpl;
}

sub get_phenotypes {
  my $GFD = shift;
  my @phenotypes_tmpl = ();
  my $GFDPhenotypes = $GFD->get_all_GFDPhenotypes;
  foreach my $GFDPhenotype (@$GFDPhenotypes) {
    my $phenotype = $GFDPhenotype->get_Phenotype;
    my $stable_id = $phenotype->stable_id;
    my $name = $phenotype->name;
    push @phenotypes_tmpl, {
      stable_id => $stable_id,
      name => $name,
      GFD_phenotype_id => $GFDPhenotype->dbID,
    };
  }
  my @sorted_phenotypes_tmpl = sort {$a->{name} cmp $b->{name}} @phenotypes_tmpl;
  return \@sorted_phenotypes_tmpl;
}

sub delete_GFDPhenotype {
  my $session = shift;
  my $GFD_phenotype_id = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $GFDPA = $registry->get_adaptor('genomic_feature_disease_phenotype');
  my $GFDphenotype = $GFDPA->fetch_by_dbID($GFD_phenotype_id);  
  $GFDPA->delete($GFDphenotype, $user);
  return 'DELETED_GFDPHENOTYPE_SUC';
} 

sub add_GFDPhenotype {
  my $session = shift;
  my $GFD_id = shift;
  my $phenotype_name = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $GFDPA = $registry->get_adaptor('genomic_feature_disease_phenotype');
  my $PA = $registry->get_adaptor('phenotype');
  my $phenotype = $PA->fetch_by_name($phenotype_name);

  my $GFDP = $GFDPA->fetch_by_GFD_id_phenotype_id($GFD_id, $phenotype->dbID);
  if (!$GFDP) {
    $GFDP = G2P::GenomicFeatureDiseasePhenotype->new({
      genomic_feature_disease_id => $GFD_id,
      phenotype_id => $phenotype->dbID,
      registry => $registry,
    });
    $GFDPA->store($GFDP);
  }
  return 'ADDED_GFDPHENOTYPE_SUC';
} 

sub get_organs {
  my $GFD = shift;
  my @organs_tmpl = ();
  my $organs = $GFD->get_all_GFDOrgans;
  foreach my $organ (@$organs) {
    my $name = $organ->get_Organ()->name;
    push @organs_tmpl, {
      name => $name,
    };
  }
  return \@organs_tmpl;
}

sub get_organ_list {
  my $GFD = shift;
  my @organ_list = ();
  my $organs = $GFD->get_all_GFDOrgans;
  foreach my $organ (@$organs) {
    my $name = $organ->get_Organ()->name;
    push @organ_list, $name;
  }
  return \@organ_list;
}

sub add_GFD_publication_comment {
  my $session = shift;
  my $GFD_id = shift;
  my $GFD_publication_id = shift;
  my $comment = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $gfd_p_c_a = $registry->get_adaptor('GFD_publication_comment');
  my $GFD_publication_comment = G2P::GFDPublicationComment->new({
    comment_text => $comment,
    GFD_publication_id => $GFD_publication_id,
    registry => $registry,
  });

  $gfd_p_c_a->store($GFD_publication_comment, $user);
  return 'ADDED_GFDPC_SUC';
}

sub delete_GFD_publication_comment {
  my $session = shift;
  my $GFD_id = shift;
  my $GFD_publication_comment_id = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $gfd_p_c_a = $registry->get_adaptor('GFD_publication_comment');
  my $GFD_publication_comment = $gfd_p_c_a->fetch_by_dbID($GFD_publication_comment_id);  

  $gfd_p_c_a->delete($GFD_publication_comment, $user);
  return 'DELETED_GFDPC_SUC';
}

sub delete_GFD_action {
  my $session = shift;
  my $GFD_action_id = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $gfda_a = $registry->get_adaptor('genomic_feature_disease_action');
  my $GFDA = $gfda_a->fetch_by_dbID($GFD_action_id);  

  $gfda_a->delete($GFDA, $user);
  return 'DELETED_GFD_ACTION_SUC';
}

sub add_publication {
  my $session = shift;
  my $GFD_id = shift;
  my $pmid = shift;
  my $title = shift;
  my $source = shift;

  my $pa = $registry->get_adaptor('publication');
  my $GFD_pa = $registry->get_adaptor('genomic_feature_disease_publication'); 
  my ($publication, $GFD_publication);

  if ($pmid) {
    $publication = $pa->fetch_by_PMID($pmid); 
  } else {
    $publication = $pa->fetch_by_title($title); 
  }

  if (!$publication) {
    $publication = G2P::Publication->new({
      pmid => $pmid || undef,
      title => $title || undef,
      source => $source || undef,
    });
    $publication = $pa->store($publication);
  }
  $GFD_publication = $GFD_pa->fetch_by_GFD_id_publication_id($GFD_id, $publication->dbID);
  if (!$GFD_publication) {
    $GFD_publication = G2P::GenomicFeatureDiseasePublication->new({
      genomic_feature_disease_id => $GFD_id,
      publication_id => $publication->dbID,
      registry => $registry,
    });
    $GFD_pa->store($GFD_publication);
  }
  return 'ADDED_PUBLICATION_SUC';
}

sub get_gfd_logs {
  my $genomic_feature_disease = shift;
  my $gfda = $registry->get_adaptor('genomic_feature_disease');
  my $gfd_log_entries = $gfda->fetch_log_entries($genomic_feature_disease);
  my @log_entries = ();
  foreach my $entry (@$gfd_log_entries) {
    push @log_entries, {
      user => $entry->get_User()->username, 
      date => $entry->created,
      action => $entry->action,
      DDD_category => $entry->DDD_category,
    };    
  } 
  return \@log_entries;
}

sub get_gfda_logs {
  my $genomic_feature_disease = shift;
  my $gfdaa = $registry->get_adaptor('genomic_feature_disease_action');
  my $gfd_actions = $genomic_feature_disease->get_all_GenomicFeatureDiseaseActions;
  my @log_entries = ();
  foreach my $gfd_action (@$gfd_actions) {
    my $gfd_action_log_entries = $gfdaa->fetch_log_entries($gfd_action);
    foreach my $entry (@$gfd_action_log_entries) {
      push @log_entries, {
        user => $entry->get_User()->username, 
        date => $entry->created,
        action => $entry->action,
        allelic_requirement => $entry->allelic_requirement,
        mutation_consequence => $entry->mutation_consequence,
      };    
    } 
  }
  return \@log_entries;
}

sub get_gene_disease_category_attribs {
  my $genomic_feature_disease = shift;
  my $DDD_category = $genomic_feature_disease->DDD_category;
  my $genomic_feature_disease_id = $genomic_feature_disease->dbID; 
  my $attribute_adaptor = $registry->get_adaptor('attribute');
  my $attribs = $attribute_adaptor->get_attribs_by_type_value('DDD_Category');
  my @tmpl = ();
  foreach my $value (sort keys %$attribs) {
    my $id = $attribs->{$value};
    my $is_selected =  ($value eq $DDD_category) ? 'selected' : '';
    push @tmpl, {
      'selected' => $is_selected,
      'attrib_id' => $id,
      'attrib_value' => $value,
    };   
  }
  return \@tmpl;
}

sub get_add_gfd_action {
  my $genomic_feature_disease = shift;
  my $genomic_feature_disease_id = $genomic_feature_disease->dbID;
  my $attribute_adaptor = $registry->get_adaptor('attribute');
 
  my $attribs = $attribute_adaptor->get_attribs_by_type_value('allelic_requirement');

  my $allelic_requirement_form = "<div class=\"form-group\">\n<label>Allelic requirement:</label><br>\n";
  
  foreach my $value (sort keys %$attribs) {
    my $id = $attribs->{$value};
    $allelic_requirement_form .= "<input type=\"checkbox\" name=\"allelic_requirement\" value=\"$id\">$value<br>\n";
  }
  $allelic_requirement_form .= "</div>\n";

  $attribs = $attribute_adaptor->get_attribs_by_type_value('mutation_consequence');

  my $mutation_consequence_form = join("\n",
    '<div class="form-group">',
    '<label>Mutation consequence summary:</label>',
    '<select name="mutation_consequence">', "\n");
  foreach my $value (sort keys %$attribs) {
    my $id = $attribs->{$value};
    $mutation_consequence_form .= "<option value=\"$id\">$value</option>\n"
  }
  $mutation_consequence_form .= "</select>\n</div>\n";

  my $form = join("\n",
    '<div class="edit_gene_disease">',
    '<h4>Add allelic requirements and mutation consequence:</h4>',
    '<form role="form" method="get" action="./handler.cgi">',
    $allelic_requirement_form,
    $mutation_consequence_form,
    '<div class="edit_attributes">',
    "<input name=\"GFD_id\" value=\"$genomic_feature_disease_id\" type=\"hidden\">",
    '<input id="button" type="submit" name="add_GFD_action" value="Add" class="btn btn-primary btn-sm"/>',
    '<input type="button" value="Discard" class="btn btn-primary btn-sm discard"/>',
    '</div>',
    '</form>',
    '</div> <!--End edit gene-disease-->',
    "\n");
  return $form;
}

sub get_edit_gfd_action {
  my $gf_disease_action = shift;
  my $GFD_id = $gf_disease_action->genomic_feature_disease_id;
  my $allelic_requirement = $gf_disease_action->allelic_requirement;
  my $mutation_consequence = $gf_disease_action->mutation_consequence;
  my $GFD_action_id = $gf_disease_action->dbID;
  my $allelic_requirement_form = get_allelic_requirement_form($allelic_requirement);
  my $mutation_consequence_form = get_mutation_consequence_form($mutation_consequence);
  my $form = join("\n",
    '<div class="edit_gene_disease">',
    '<h4>Edit allelic requirements and mutation consequence:</h4>',
    '<form role="form" method="get" action="./handler.cgi">',
    $allelic_requirement_form,
    $mutation_consequence_form,
    '<div class="edit_attributes">',
    "<input name=\"GFD_action_id\" value=\"$GFD_action_id\" type=\"hidden\">",
    "<input name=\"GFD_id\" value=\"$GFD_id\" type=\"hidden\">",
    '<input id="button" type="submit" name="edit_GFD_action" value="Save" class="btn btn-primary btn-sm"/>',
    '<input id="button" type="submit" name="delete_GFD_action" value="Delete" class="btn btn-primary btn-sm"/>',
    '<input type="button" value="Discard" class="btn btn-primary btn-sm discard"/>',
    '</div>',
    '</form>',
    '</div> <!--End edit gene-disease-->',
    "\n");
  return $form;
}

sub get_allelic_requirement_form {
  my $allelic_requirement = shift;
  my @requirements = split(',', $allelic_requirement); 

  my $attribute_adaptor = $registry->get_adaptor('attribute');
  my $attribs = $attribute_adaptor->get_attribs_by_type_value('allelic_requirement');

  my $form = "<div class=\"form-group\">\n<label>Allelic requirement:</label><br>\n";
  
  foreach my $value (sort keys %$attribs) {
    my $id = $attribs->{$value};
    if (grep $_ eq $value, @requirements) {
      $form .= "<input type=\"checkbox\" name=\"allelic_requirement\" value=\"$id\" checked>$value<br>\n";
    } else {
      $form .= "<input type=\"checkbox\" name=\"allelic_requirement\" value=\"$id\">$value<br>\n";
    }
  }
  $form .= "</div>\n";

  return $form;
}

sub get_mutation_consequence_form {
  my $mutation_consequence = shift;
  my $attribute_adaptor = $registry->get_adaptor('attribute');
  my $attribs = $attribute_adaptor->get_attribs_by_type_value('mutation_consequence');

  my $form = join("\n",
    '<div class="form-group">',
    '<label>Mutation consequence summary:</label>',
    '<select name="mutation_consequence">', "\n");
  foreach my $value (sort keys %$attribs) {
    my $id = $attribs->{$value};
    if ($value eq $mutation_consequence) {
      $form .= "<option value=\"$id\" selected>$value</option>\n"
    } else {
      $form .= "<option value=\"$id\">$value</option>\n"
    }
  }
  $form .= "</select>\n</div>\n";
  return $form;
}

sub get_edit_organs_form {
  my $organ_list = shift; 
  my $GFD_id = shift; 

  my $organ_adaptor = $registry->get_adaptor('organ');
  my %all_organs = map {$_->name => $_->dbID} @{$organ_adaptor->fetch_all};
  my $form = join("\n",
    '<div class="edit_gene_disease">',
    '<h4>Edit organ specificity list:</h4>',
    '<form role="form" method="get" action="./handler.cgi">',
    '<div class="form-group">',
    '<label>Organ specificity:</label><br>', "\n");
  
  foreach my $value (sort keys %all_organs) {
    my $id = $all_organs{$value};
    if (grep $_ eq $value, @$organ_list) {
      $form .= "<input type=\"checkbox\" name=\"organ\" value=\"$id\" checked>$value<br>\n";
    } else {
      $form .= "<input type=\"checkbox\" name=\"organ\" value=\"$id\">$value<br>\n";
    }
  }
  $form .= join("\n",
    "</select>\n</div>",
    '<div class="edit_attributes">',
    "<input name=\"genomic_feature_disease_id\" value=\"$GFD_id\" type=\"hidden\">",
    '<input id="button" type="submit" name="edit_organ_list" value="Save" class="btn btn-primary btn-sm"/>',
    '<input type="button" value="Discard" class="btn btn-primary btn-sm discard"/>',
    '</div>',
    '</form>',
    '</div> <!--End edit gene-disease-->',
    "\n");
  return $form;
}

sub update_DDD_category {
  my $session = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $genomic_feature_disease_adaptor = $registry->get_adaptor('genomic_feature_disease');
  my $DDD_category_attrib = $session->param('DDD_category_attrib');
  my $genomic_feature_disease_id = $session->param('genomic_feature_disease_id');
  my $genomic_feature_disease = $genomic_feature_disease_adaptor->fetch_by_dbID($genomic_feature_disease_id);
  $genomic_feature_disease->DDD_category_attrib($DDD_category_attrib);
  $genomic_feature_disease = $genomic_feature_disease_adaptor->update($genomic_feature_disease, $user); 

  return 'UPDATED_DDD_CATEGORY_SUC';
}

sub update_GFD_action {
  my $session = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $GFD_action_adaptor = $registry->get_adaptor('genomic_feature_disease_action');
  my $allelic_requirement_attribs = $session->param('allelic_requirement_attribs');
  my $mutation_consquence_attrib = $session->param('mutation_consequence_attrib');
  my $GFD_action_id = $session->param('GFD_action_id'); 
  my $GFD_action = $GFD_action_adaptor->fetch_by_dbID($GFD_action_id);
  $GFD_action->allelic_requirement_attrib($allelic_requirement_attribs);  
  $GFD_action->mutation_consequence_attrib($mutation_consquence_attrib);
  $GFD_action = $GFD_action_adaptor->update($GFD_action, $user);
  return 'UPDATED_GFD_ACTION_SUC';
}

sub update_organ_list {
  my $session = shift;
  my $updated_organ_ids = shift;
  my $GFD_id = shift;
  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $GFDO_adaptor = $registry->get_adaptor('genomic_feature_disease_organ');
  $GFDO_adaptor->delete_all_by_GFD_id($GFD_id);

  foreach my $new_id (@$updated_organ_ids) {
    my $GFDO =  G2P::GenomicFeatureDiseaseOrgan->new({
      organ_id => $new_id,
      genomic_feature_disease_id => $GFD_id,
      registry => $registry, 
    });
    $GFDO_adaptor->store($GFDO);
  }  
  return 'UPDATED_ORGAN_LIST';
}

sub store_GFD_action {
  my $session = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $allelic_requirement_attrib = $session->param('allelic_requirement_attribs');
  my $mutation_consequence_attrib = $session->param('mutation_consequence_attrib');
  my $GFD_id = $session->param('GFD_id');
  
  my $GFD_action = G2P::GenomicFeatureDiseaseAction->new({
    genomic_feature_disease_id => $GFD_id,
    allelic_requirement_attrib => $allelic_requirement_attrib,
    mutation_consequence_attrib => $mutation_consequence_attrib,  
    user_id => undef,
  });

  my $GFD_action_adaptor = $registry->get_adaptor('genomic_feature_disease_action');
  $GFD_action = $GFD_action_adaptor->store($GFD_action, $user);

  my $GFD_adaptor = $registry->get_adaptor('genomic_feature_disease');
  my $GFD = $GFD_adaptor->fetch_by_dbID($GFD_id);
  my $gene_symbol = $GFD->get_GenomicFeature->gene_symbol;
  return 'ADDED_GFD_ACTION_SUC';
}

sub update_visibility {
  my $session = shift;
  my $GFD_id = shift;
  my $visibility = shift;

  my $email = $session->param('email');
  my $user_adaptor = $registry->get_adaptor('user');
  my $user = $user_adaptor->fetch_by_email($email);

  my $GFD_adaptor = $registry->get_adaptor('genomic_feature_disease');
  my $GFD = $GFD_adaptor->fetch_by_dbID($GFD_id);
  if ($visibility eq 'authorised') {
    $GFD->is_visible(1);
  } else {
    $GFD->is_visible(0);
  }
  $GFD_adaptor->update($GFD, $user);
  return 'UPDATED_VISIBILITY_STATUS_SUC';
} 

sub update_disease {
  my $session = shift;
  my $disease_id = shift;
  my $disease_mim = shift;
  my $disease_name = shift;

  my $disease_adaptor = $registry->get_adaptor('disease');
  my $disease = $disease_adaptor->fetch_by_dbID($disease_id);

  if ($disease_mim) {
    $disease_mim =~ s/^\s+|\s+$//g;
    if ($disease_mim =~ m/^\d+$/) {
      my $tmp_disease = $disease_adaptor->fetch_by_mim($disease_mim);
      if ($tmp_disease) {
        if ($tmp_disease->dbID != $disease_id) {
          return 'DISEASE_MIM_IN_DB'; 
        } 
      }
      $disease->mim($disease_mim);
    } else {
      return 'WRONG_FORMAT_DISEASE_MIM'; 
    }  
  } 
  if ($disease_name) {
    $disease_name =~ s/^\s+|\s+$//g;
    my $tmp_disease = $disease_adaptor->fetch_by_name($disease_name);
    if ($tmp_disease) {
      if ($tmp_disease->dbID != $disease_id) {
        return 'DISEASE_NAME_IN_DB'; 
      } 
    }
    $disease->name($disease_name);
  }
  $disease_adaptor->update($disease);
  return 'UPDATED_DISEASE_ATTRIBS_SUC';
}

