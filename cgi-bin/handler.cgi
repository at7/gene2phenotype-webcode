#!/usr/bin/perl -wT
use strict;
use warnings;

use lib '/nfs/web-hx/vg/gene2phenotype/perl/lib/share/perl5';
use Apache::Htpasswd;
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session qw(-ip-match);
use CGI::Session::Auth;
use DBI;
use Mail::Sendmail;

$CGI::DISABLE_UPLOADS = 1;
require "./tmpl_handler.pl"; # cgi-bin
require "./downloads.pl";

my $password_file = "../../../../gene2phenotype_users"; 
my $db_config = "../../../../config/registry";
my $downloads_dir = "../../../../downloads";
my $tmp_dir = '../../../../tmp';

my $config = init_CGI();
my $cgi = $config->{cgi};
my $session = $config->{session};
my $search_term = $config->{search_term};
my $message = $session->param('message');
clear_message();
$ENV{PATH} = '';

sub init_CGI { 
  my $config = {};
  my $cgi = new CGI;
  # |$sid = $cgi->cookie("CGISESSID") || $cgi->param('CGISESSID') || undef;
  # |$session = new CGI::Session(undef, $sid, {Directory=>'/tmp'});
  # --> $session = new CGI::Session(undef, $cgi, {Directory=>"/tmp"});
  my $session = CGI::Session->load("driver:file", $cgi, {Directory => $tmp_dir});
  if ($session->is_empty) {
    $session = CGI::Session->new("driver:file", $cgi, {Directory => $tmp_dir});
  }
  my $session_id = $session->id();
  my $cookie = $cgi->cookie( -name => $session->name, -value  => $session->id );
  $session->flush();

  my @redirect_after_action = qw/download edit_DDD_category edit_GFD_action add_GFD_action add_GFD_publication_comment delete_GFD_publication_comment delete_GFD_action add_publication send_recover_pwd_mail_button set_visibility edit_organ_list update_disease delete_GFD_phenotype add_phenotype update_phenotype_tree/;
  if (!(grep {$cgi->param($_)} @redirect_after_action)) {
    print $cgi->header( -cookie => $cookie );
  }

  $cgi->param('CGISESSID', $session_id);

  my $search_term = $session->param('search_term');
  $search_term = $cgi->param('search_term');

  $config->{cgi} = $cgi;
  $config->{session} = $session;
  $config->{search_term} = $search_term;  
  $config->{cookie} = $cookie;
  return $config;
}

#login
#loggout
#account
#edit_pwd
#search
#login_button
#reset_password
#reset_username
#cancel_reset_pwd_button
#downloads

if ($cgi->param('login')) {
  show_login();
} elsif ($cgi->param('search_term')) {
  my $search_term = $cgi->param('search_term');
  display_search_results($session, $search_term);
} elsif ($cgi->param('search_type')) {
  my $search_type = $cgi->param('search_type');
  my $dbID = $cgi->param('dbID');
  display_data($session, $search_type, $dbID, $message);
} elsif ($cgi->param('logout')) {
  logout();
} elsif ($cgi->param('account') || $cgi->param('cancel_edit_account_data_button')) {
  show_account_data($session, 'account');
} elsif ($cgi->param('edit_pwd')) {
  show_account_data($session, 'edit_pwd');
} elsif ($cgi->param('edit_username')) {
  show_account_data($session, 'edit_username');
} elsif ($cgi->param('edit_email')) {
  show_account_data($session, 'edit_email');
} elsif ($cgi->param('login_button')) {
  login();
} elsif ($cgi->param('reset_password') || $cgi->param('change_pwd_button')) {
  reset_password();
} elsif ($cgi->param('reset_username') || $cgi->param('change_username_button')) {
  reset_username();
} elsif ($cgi->param('reset_email') || $cgi->param('change_email_button')) {
  reset_email();
} elsif ($cgi->param('forgot_pwd')) {
  show_account_data($session, 'recover_pwd');
} elsif ($cgi->param('send_recover_pwd_mail_button')) {
  send_recover_pwd_mail();
} elsif ($cgi->param('send_recover_pwd_enter_new_pwd_button')) {
  recover_pwd($session);
} elsif ($cgi->param('recover_pwd')) {
  show_recover_pwd_page($session);
} elsif ($cgi->param('show_downloads')) {
  show_downloads_page($session);
} elsif ($cgi->param('show_disclaimer')) {
  show_disclaimer_page($session);
} elsif ($cgi->param('download')) { 
  my $file = download_data($downloads_dir);
  open(my $DLFILE, '<', "$downloads_dir/$file");
  print $cgi->header(
          -type => 'application/x-download',
          -attachment => $file,
          -Content_length  => -s "$downloads_dir/$file",
        );
  binmode $DLFILE;
  print while <$DLFILE>;
  undef ($DLFILE);
  unlink "$downloads_dir/$file";
  redirect("show_downloads=all");
}
elsif ($cgi->param('edit_DDD_category')) {
  my $DDD_category_attrib = $cgi->param('DDD_category');
  my $GFD_id = $cgi->param('genomic_feature_disease_id');
  $session->param('DDD_category_attrib', $DDD_category_attrib);
  $session->param('genomic_feature_disease_id', $GFD_id);
  $session->flush(); 
  my $msg = update_DDD_category($session);
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('edit_GFD_action')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $allelic_requirement_attribs = join(',', $cgi->param('allelic_requirement'));
  my $mutation_consequence_attrib = $cgi->param('mutation_consequence');
  my $GFD_action_id = $cgi->param('GFD_action_id');
  $session->param('allelic_requirement_attribs', $allelic_requirement_attribs);
  $session->param('mutation_consequence_attrib', $mutation_consequence_attrib);
  $session->param('GFD_action_id', $GFD_action_id);
  $session->flush();
  my $msg = update_GFD_action($session);
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('edit_organ_list')) {
  my @organ_ids = $cgi->param('organ');
  my $GFD_id = $cgi->param('genomic_feature_disease_id');
  my $msg = update_organ_list($session, \@organ_ids, $GFD_id);
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('add_GFD_action')) {
  my $allelic_requirement_attribs = join(',', $cgi->param('allelic_requirement'));
  my $mutation_consequence_attrib = $cgi->param('mutation_consequence');
  my $GFD_id = $cgi->param('GFD_id');
  $session->param('allelic_requirement_attribs', $allelic_requirement_attribs);
  $session->param('mutation_consequence_attrib', $mutation_consequence_attrib);
  $session->param('GFD_id', $GFD_id);
  $session->flush();
  my $msg = store_GFD_action($session);
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('new_gene_disease')) {
  new_gene_disease($session);
}
elsif ($cgi->param('add_gene_disease')) {
  my $gene_name = $cgi->param('gene_name');
  my $disease_name = $cgi->param('disease_name');
  add_new_gene_disease($session, $gene_name, $disease_name);
}
elsif ($cgi->param('add_GFD_publication_comment')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $GFD_publication_id = $cgi->param('GFD_publication_id');
  my $comment = $cgi->param('GFD_publication_comment');
  my $msg = add_GFD_publication_comment($session, $GFD_id, $GFD_publication_id, $comment); 
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('delete_GFD_publication_comment')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $GFD_publication_comment_id = $cgi->param('GFD_publication_comment_id');
  my $msg = delete_GFD_publication_comment($session, $GFD_id, $GFD_publication_comment_id); 
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('delete_GFD_action')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $GFD_action_id = $cgi->param('GFD_action_id');
  my $msg = delete_GFD_action($session, $GFD_action_id); 
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('add_publication')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $pmid = $cgi->param('pmid');
  my $title = $cgi->param('title');
  my $source = $cgi->param('source');
  my $msg = add_publication($session, $GFD_id, $pmid, $title, $source); 
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('set_visibility')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $visibility = $cgi->param('visibility');
  my $msg = update_visibility($session, $GFD_id, $visibility); 
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('update_disease')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $disease_id = $cgi->param('disease_id');
  my $disease_mim = $cgi->param('mim');
  my $disease_name = $cgi->param('name');
  my $msg = update_disease($session, $disease_id, $disease_mim, $disease_name);
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('delete_GFD_phenotype')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $GFD_phenotype_id = $cgi->param('GFD_phenotype_id');
  my $msg = delete_GFDPhenotype($session, $GFD_phenotype_id);
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('add_phenotype')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $phenotype_name = $cgi->param('phenotype_name');
  my $msg = add_GFDPhenotype($session, $GFD_id, $phenotype_name);
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
elsif ($cgi->param('update_phenotype_tree')) {
  my $GFD_id = $cgi->param('GFD_id');
  my $phenotype_ids = $cgi->param('phenotype_ids');
  my $msg = update_GFDPhenotypes($session, $GFD_id, $phenotype_ids);
  redirect("search_type=gfd&dbID=$GFD_id", $msg);
}
else {
  show_default_page($session);
}

sub show_login {
  my $type = $cgi->param('login');
  my $search_type = $cgi->param('search_type');
  my $dbID = $cgi->param('dbID');
  $session->param('search_type', $search_type);
  $session->param('dbID', $dbID);
  $session->flush(); 
  show_login_page($session);
}

sub logout {
  $session->param('is_logged_in', 0);
  $session->flush(); 
  my $search_type = $session->param('search_type');
  my $dbID = $session->param('dbID');
  if ($search_type && $dbID) {
    display_data($session, $search_type, $dbID);
  } else {
    display_search_results($session, $search_term);
  }
}

sub login {
  my $auth = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly => 1, UseMD5 => 1,}); 
  my $email = $cgi->param('email');
  my $password = $cgi->param('password');
  if ($auth->htCheckPassword($email, $password)) {
    $session->param('is_logged_in', 1);
    $session->param('email', $email);
    $session->flush(); 
    my $search_type = $session->param('search_type');
    my $dbID = $session->param('dbID');
    if ($search_type && $dbID) {
      display_data($session, $search_type, $dbID);
    } else {
      display_search_results($session, $search_term);
    }
  } else {
    show_login_page($session, 'LOGIN_FAILED');
  }
}

sub send_recover_pwd_mail {
  my $email = $cgi->param('email');
  $session->param('email', $email);
  $session->flush(); 

  my $auth = get_auth();
  my $is_known = $auth->fetchPass($email); 
  if (!$is_known) {
    show_account_data($session, 'recover_pwd', 'EMAIL_UNKNOWN');
    return;
  }

  my $server_name = $ENV{SERVER_NAME};
  my $request_uri = $ENV{REQUEST_URI};

  my $session_id = $session->id();
  my $to = $email;
  my $from = 'anja@ebi.ac.uk';
  my $subject = 'Reset your password for gene2phenotype website';
  my $message = "http://$server_name" . $request_uri . "?recover_pwd=recover_pwd&CGISESSID=$session_id";

  my %mail = (To      => $to,
              From    => $from,
              Subject => $subject,
              Message => $message,
           );

  $mail{smtp} = 'smtp.ebi.ac.uk';
  my $success = sendmail(%mail);
#  if ($success) {
#    show_default_page($session); # message email was send
#    return;
#  } else {
#    show_default_page($session); # error sending email, print $Mail::Sendmail::error, $Mail::Sendmail::log
#    return;
#  }
  redirect();
}

sub show_recover_pwd_page {
  my $param_cgisessid = $cgi->param('CGISESSID');
  my $session_cgisessid = $session->id();
  if ($param_cgisessid == $session_cgisessid) {
    show_account_data($session, 'recover_pwd_enter_new_pwd');
  } else {
    show_default_page($session, 'SESSION_IDS_DONT_MATCH');
  }
}

sub reset_password {
  my $auth = get_auth();
  my $email = $session->param('email');
  my $current_pwd = $cgi->param('current_pwd');
  my $new_pwd = $cgi->param('new_pwd');
  my $retyped_pwd = $cgi->param('retyped_pwd');
  my $success = $auth->htCheckPassword($email, $current_pwd);
  if (!$success) {
    show_error_reset_user_data('edit_pwd', 'PWD_ERROR');
    return;
  }
  if (!($new_pwd && $retyped_pwd)) {
    show_error_reset_user_data('edit_pwd', 'missing_pwds');
    return;
  }
  if ($retyped_pwd && ($new_pwd ne $retyped_pwd)) {
    show_error_reset_user_data('edit_pwd', 'PWDS_DONT_MATCH');
    return;
  }
  $success = $auth->htpasswd($email, $new_pwd, $current_pwd);
  if ($success) {
    show_account_data($session, 'account', 'RESET_PWD_SUC');
  } else {
    show_account_data($session, 'account', 'RESET_PWD_ERROR');
  }
}

sub recover_pwd {
  my $auth = get_auth();
  my $email = $cgi->param('email');
  my $new_pwd = $cgi->param('new_password');
  my $retyped_pwd = $cgi->param('retyped_password');

  if ($new_pwd ne $retyped_pwd) {
    show_error_reset_user_data('recover_pwd_enter_new_pwd', 'PWDS_DONT_MATCH');
    return;
  } 
  my $success = $auth->htpasswd($email, $new_pwd, {'overwrite' => 1});
  if ($success) {
    $session->param('is_logged_in', 1);
    $session->param('email', $email);
    $session->flush(); 
    show_default_page($session, 'reset_pwd_successful');
  } else {
    show_default_page($session, 'reset_pwd_failed');
  }
}

sub reset_username {
  my $auth = get_auth();
  my $current_username = $cgi->param('current_username');
  my $new_username = $cgi->param('new_username');
  my $password = $cgi->param('pwd');
  my $email = $session->param('email');
  my $success = $auth->htCheckPassword($email, $password);
  unless ($success) {
    show_error_reset_user_data('edit_username', 'PWD_ERROR');
    return;
  }
  if ( length($new_username) == 0) {
    show_error_reset_user_data('edit_username', 'NEW_USERNAME_MISSING');
    return;
  }

  my $dbh = get_dbh();
  my $stmt = qq{SELECT email FROM user WHERE username=?};
  my $sth = $dbh->prepare($stmt) or die $dbh->errstr;
  $sth->execute($new_username) or die $sth->errstr;
  my $ary_ref = $sth->fetchall_arrayref();
  if (scalar @$ary_ref == 1) {
    show_error_reset_user_data('edit_username', 'USERNAME_IN_USE');
  } 

  $stmt = qq{UPDATE user SET username=? WHERE username=?};
  $dbh->do($stmt, undef, ($new_username, $current_username));
  show_account_data($session, 'account', 'RESET_USERNAME_SUC');
}

sub reset_email {
  my $auth = get_auth();
  my $email = $cgi->param('current_email');
  my $new_email = $cgi->param('new_email');
  my $password = $cgi->param('pwd');
  my $success = $auth->htCheckPassword($email, $password);
  if (!$success) {
    show_error_reset_user_data('edit_email', 'PWD_ERROR');
    return;
  }
  my $email_is_used = $auth->fetchPass($new_email);
  if ($email_is_used) {
    show_error_reset_user_data('edit_email', 'EMAIL_IN_USE');
    return;
  }
  
  my $dbh = get_dbh();
  my $stmt = qq{UPDATE user SET email=? WHERE email=?;};
  $dbh->do($stmt, undef, ($new_email, $email)); 

  $auth->htDelete($email);
  $auth->htpasswd($new_email, $password);
  $session->param('email', $new_email);
  $session->flush(); 
  show_account_data($session, 'account', 'RESET_EMAIL_SUC');  
}

sub show_error_reset_user_data {
  my $type = shift;
  my $message = shift;  
  show_account_data($session, $type, $message);
  return;
}

sub get_auth {
  return new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly => 0, UseMD5 => 1,}); 
}

sub get_dbh {
  my $fh = FileHandle->new($db_config, 'r'); 
  my $config = {};
  while (<$fh>) {
    chomp;
    my ($key, $value) = split/=/;
    $config->{$key} = $value;
  }
  $fh->close();
  my $database = $config->{database};
  my $host = $config->{host};
  my $user = $config->{user};
  my $port = $config->{port};
  my $password = $config->{password};
  my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host;port=$port;", $user, $password) or die $DBI::errstr;
  return $dbh;
}

sub redirect {
  my $action = shift; 
  my $message = shift;
  if ($message) {
    store_message($message);
  }
  my $cookie = $config->{cookie};
  my $server_name = $ENV{SERVER_NAME};
  my $script_name = $ENV{SCRIPT_NAME};
  my $url = "http://$server_name" . $script_name;
  if ($action) {
    $url .= "?$action";
  }
  print $cgi->redirect( -URL => $url, -cookie => $cookie,);
}

sub store_message {
  my $message = shift;
  $session->param('message', $message);
  $session->flush(); 
}

sub clear_message {
  $session->clear(['message']);
}

