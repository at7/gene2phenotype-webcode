use strict;
use warnings;

use HTML::Template;
use DBI;
use JSON;
use lib "../../lib/gene2phenotype/modules";

use G2P::Registry;
use constant TMPL_FILE => "../htdocs/G2P.tmpl";
my $tmpl = new HTML::Template( filename => TMPL_FILE );

my $configuration_file = '../../../config/registry';

my $registry = G2P::Registry->new($configuration_file);

my $constants = {
 'reset_pwd_successful' => {
    msg  => 'Password was successfully updated.',
    type => 'success'}, 
  'current_pwd_wrong' => {
    msg  => 'Error. Password verification failed.',
    type => 'danger',},
  'new_and_retyped_dont_match' => {
    msg => 'Error. Retyped and new password don\'t match.',
    type => 'danger',},
  'missing_pwds' => {
    msg => 'Error. You must provide a new password and retype the new password.',
    type => 'danger',},
  'reset_pwd_failed' => {
    msg => 'There was an error resetting you password. Please contact g2p-help@ebi.ac.uk.',
    type => 'danger'},
  'reset_username_successful' => {
    msg => 'Username was successfully updated.',
    type => 'success',},
  'new_username_already_taken' => {
    msg => 'The new username is already taken.',
    type => 'danger'},
  'new_username_missing' => {
    msg => 'You need to provide a new username.',
    type => 'danger',},
  'email_is_taken' => {
    msg => 'The new email is already taken.',
    type => 'danger',},
  'reset_email_successful' => {
    msg => 'Email was successfully updated.',
    type => 'success',},
  'email_unknown' => {
    msg => 'The email address is not known. Please contact g2p-help@ebi.ac.uk.',
    type => 'danger',},
  'session_ids_dont_match' => {
    msg => 'Session ids don\'t match. Please contact g2p-help@ebi.ac.uk.',
    type => 'danger',
  },
};

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
  my $full_message = $constants->{$message}->{msg};
  my $msg_type =  $constants->{$message}->{type};
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
  my $type = shift;
  my $tmpl = new HTML::Template(filename => '../htdocs/Login.tmpl');
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

  my $logged_in = set_login_status($tmpl, $session);

  if ($search_type eq 'gfd') {
    $tmpl->param(display_gfd => 1);
    my $genomic_feature_disease_adaptor = $registry->get_adaptor('genomic_feature_disease');
    my $genomic_feature_disease = $genomic_feature_disease_adaptor->fetch_by_dbID($dbID);
    my $genomic_feature = $genomic_feature_disease->get_GenomicFeature;
    my $genomic_feature_attributes = get_genomic_feature_attributes($genomic_feature);
    my $disease = $genomic_feature_disease->get_Disease;
    my $disease_attributes = get_disease_attributes($disease);

    my $variations = get_variations($genomic_feature_disease);
    my $counts = get_consequence_counts($genomic_feature_disease);

    my $DDD_category = $genomic_feature_disease->DDD_category || 'Not assigned';
    my $edit_DDD_category_form = get_edit_DDD_category_form($genomic_feature_disease); 
    my $add_GFD_action_form = get_add_gfd_action($genomic_feature_disease);
    my $genomic_feature_disease_actions = $genomic_feature_disease->get_all_GenomicFeatureDiseaseActions();
    my @actions = ();
    foreach my $gfda (@$genomic_feature_disease_actions) {
      my $allelic_requirement = $gfda->allelic_requirement || 'Not assigned';
      my $mutation_consequence_summary = $gfda->mutation_consequence || 'Not assigned';
      my $form = get_edit_gfd_action($gfda); 
      push @actions, {
        edit_gene_disease => $logged_in,
        mutation_consequence_summary => $mutation_consequence_summary,
        allelic_requirement => $allelic_requirement,
        edit_gfd_action => $form,
      };
    }   
    $tmpl->param($genomic_feature_attributes);
    $tmpl->param($disease_attributes);
    $tmpl->param({
      DDD_category => $DDD_category,
      edit_DDD_category => $edit_DDD_category_form,
      add_gfd_action_form => $add_GFD_action_form,
      gfd_actions => \@actions,
      variations => $variations,
      consequence_counts => $counts,
      edit_gene_disease => $logged_in,
    });  
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
    my $variations = get_variations($genomic_feature);
    my $counts = get_consequence_counts($genomic_feature);

    $tmpl->param($genomic_feature_attributes);
    $tmpl->param({
      variations => $variations,
      consequence_counts => $counts,
    });  
    print $tmpl->output();
  } else {

  }
}

sub get_genomic_feature_attributes {
  my $genomic_feature = shift;
  my $gene_symbol = $genomic_feature->gene_symbol;
  my $gene_mim = $genomic_feature->mim;
  my $ensembl_stable_id = $genomic_feature->ensembl_stable_id;
  my $organ_specificity_list = join(', ', @{$genomic_feature->get_organ_specificity_list});
  return {
    ensembl_stable_id => $ensembl_stable_id,
    gene_symbol => $gene_symbol,
    gene_mim => $gene_mim,
    organ_specificity_list => $organ_specificity_list,
  };
}

sub get_disease_attributes {
  my $disease = shift;
  my $disease_name = $disease->name;
  my $disease_mim = $disease->mim;
  return { 
    disease_name => $disease_name,
    disease_mim => $disease_mim,
  };
}

sub get_consequence_counts {
  my $genomic_feature_disease = shift;
  my $variations = $genomic_feature_disease->get_all_Variations; 
  my $counts = encode_json(variation_consequence_counts($variations));
  return $counts;
}

sub get_variations {
  my $genomic_feature_disease = shift;
  my @variations_tmpl = ();
  my $variations = $genomic_feature_disease->get_all_Variations; 
  foreach my $variation (@$variations) {
    my $mutation    = $variation->mutation;
    my $consequence = $variation->consequence;
    my $publication = $variation->get_Publication;
    my ($title, $pmid);
    if ($publication) {       
      $title = $publication->title;
      $pmid = $publication->pmid; 
    }
    my $variation_synonyms = $variation->get_all_synonyms_order_by_source;
    my @dbsnp_ids = ();
    foreach (@{$variation_synonyms->{dbsnp}}) {
      push @dbsnp_ids, {name => $_};
    }
    my @clinvar_ids = ();
    foreach (@{$variation_synonyms->{clinvar}}) {
      push @clinvar_ids, {name => $_};
    }
    push @variations_tmpl, {
      mutation => $mutation, 
      consequence => $consequence, 
      dbsnp_ids => \@dbsnp_ids,
      clinvar_ids => \@clinvar_ids,
      pmid => $pmid,
      title => $title,
    };
  }
  return \@variations_tmpl;
}

sub get_edit_DDD_category_form {
  my $genomic_feature_disease = shift;
  my $DDD_category = $genomic_feature_disease->DDD_category;
  my $genomic_feature_disease_id = $genomic_feature_disease->dbID; 
  my $attribute_adaptor = $registry->get_adaptor('attribute');
  my $attribs = $attribute_adaptor->get_attribs_by_type_value('DDD_Category');
  my $form = join("\n",
    '<div class="edit_gene_disease">',
    '<h4>Edit DDD category:</h4>',
    '<form role="form" method="get" action="./handler.cgi">',
    '<div class="form-group">',
    '<label>DDD category:</label>',
    '<select name="DDD_category">', "\n");
  foreach my $value (sort keys %$attribs) {
    my $id = $attribs->{$value};
    if ($value eq $DDD_category) {
      $form .= "<option value=\"$id\" selected>$value</option>\n"
    } else {
      $form .= "<option value=\"$id\">$value</option>\n"
    }
  }
  $form .= join("\n",
    "</select>\n</div>",
    '<div class="edit_attributes">',
    "<input name=\"genomic_feature_disease_id\" value=\"$genomic_feature_disease_id\" type=\"hidden\">",
    '<input id="button" type="submit" name="edit_DDD_category" value="Save" class="btn btn-primary btn-sm"/>',
    '<input type="button" value="Discard" class="btn btn-primary btn-sm discard"/>',
    '</div>',
    '</form>',
    '</div> <!--End edit gene-disease-->',
    "\n");
  return $form;
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
    '<input id="button" type="submit" name="edit_GFD_action" value="Save" class="btn btn-primary btn-sm"/>',
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

sub variation_consequence_counts {
  my $variations = shift;
  my $counts = {};
  foreach my $variation (@$variations) {
    $counts->{$variation->consequence}++;
  }
  my @array = ();
  while (my ($consequence, $count) = each %$counts) {
    push @array, {'label' => $consequence, 'value' => $count};
  }

  return \@array;
}

sub update_DDD_category {
  my $session = shift;
  my $genomic_feature_disease_adaptor = $registry->get_adaptor('genomic_feature_disease');
  my $DDD_category_attrib = $session->param('DDD_category_attrib');
  my $genomic_feature_disease_id = $session->param('genomic_feature_disease_id');
  my $genomic_feature_disease = $genomic_feature_disease_adaptor->fetch_by_dbID($genomic_feature_disease_id);
  $genomic_feature_disease->DDD_category_attrib($DDD_category_attrib);
  $genomic_feature_disease = $genomic_feature_disease_adaptor->update($genomic_feature_disease); 
  my $GFD_id = $genomic_feature_disease->dbID;
  display_data($session, 'gfd', $GFD_id); 
}

sub update_GFD_action {
  my $session = shift;
  my $GFD_action_adaptor = $registry->get_adaptor('genomic_feature_disease_action');
  my $allelic_requirement_attribs = $session->param('allelic_requirement_attribs');
  my $mutation_consquence_attrib = $session->param('mutation_consequence_attrib');
  my $GFD_action_id = $session->param('GFD_action_id'); 
  my $GFD_action = $GFD_action_adaptor->fetch_by_dbID($GFD_action_id);
  $GFD_action->allelic_requirement_attrib($allelic_requirement_attribs);  
  $GFD_action->mutation_consequence_attrib($mutation_consquence_attrib);
  $GFD_action = $GFD_action_adaptor->update($GFD_action);
 
  my $GFD_id = $GFD_action->genomic_feature_disease_id;
  display_data($session, 'gfd', $GFD_id); 
}

sub store_GFD_action {
  my $session = shift;

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
  $GFD_action = $GFD_action_adaptor->store($GFD_action);

  my $GFD_adaptor = $registry->get_adaptor('genomic_feature_disease');
  my $GFD = $GFD_adaptor->fetch_by_dbID($GFD_id);
  my $gene_symbol = $GFD->get_GenomicFeature->gene_symbol;
  display_data($session, 'gfd', $GFD_id); 
}

