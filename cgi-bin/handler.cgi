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

require "./tmpl_handler.pl"; # cgi-bin

my $password_file = "../../../../gene2phenotype_users"; 
my $db_config = "../../../../config/registry";
my $config = init_CGI();
my $cgi = $config->{cgi};
my $session = $config->{session};
my $search_term = $config->{search_term};

sub init_CGI { 
  my $config = {};
  my $cgi = new CGI;
  # |$sid = $cgi->cookie("CGISESSID") || $cgi->param('CGISESSID') || undef;
  # |$session = new CGI::Session(undef, $sid, {Directory=>'/tmp'});
  # --> $session = new CGI::Session(undef, $cgi, {Directory=>"/tmp"});
  my $session = CGI::Session->load("driver:file", $cgi, {Directory=>'../../../../tmp'});
  if ($session->is_empty) {
    $session = CGI::Session->new("driver:file", $cgi, {Directory=>'../../../../tmp'});
  }
  my $session_id = $session->id();

  my $cookie = $cgi->cookie( -name => $session->name, -value  => $session->id );
  $session->flush();
  if (!$cgi->param('edit_DDD_category') && !$cgi->param('edit_GFD_action') && !$cgi->param('add_GFD_action')) {
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

if ($cgi->param('search_term')) {
  my $search_term = $cgi->param('search_term');
  display_search_results($session, $search_term);
} elsif ($cgi->param('search_type')) {
  my $search_type = $cgi->param('search_type');
  my $dbID = $cgi->param('dbID');
  display_data($session, $search_type, $dbID);
} elsif ($cgi->param('login')) {
  show_login();
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
} 
elsif ($cgi->param('edit_DDD_category')) {
  my $DDD_category_attrib = $cgi->param('DDD_category');
  my $genomic_feature_disease_id = $cgi->param('genomic_feature_disease_id');
  $session->param('DDD_category_attrib', $DDD_category_attrib);
  $session->param('genomic_feature_disease_id', $genomic_feature_disease_id);
  $session->flush(); 
  my $gfd_id = update_DDD_category($session);
  my $cookie = $config->{cookie};
  my $server_name = $ENV{SERVER_NAME};
  my $script_name = $ENV{SCRIPT_NAME};
  my $url = "http://$server_name" . $script_name . "?search_type=gfd&dbID=$gfd_id";
  print $cgi->redirect(-URL => $url, -cookie => $cookie);
}
elsif ($cgi->param('edit_GFD_action')) {
  my $allelic_requirement_attribs = join(',', $cgi->param('allelic_requirement'));
  my $mutation_consequence_attrib = $cgi->param('mutation_consequence');
  my $GFD_action_id = $cgi->param('GFD_action_id');
  $session->param('allelic_requirement_attribs', $allelic_requirement_attribs);
  $session->param('mutation_consequence_attrib', $mutation_consequence_attrib);
  $session->param('GFD_action_id', $GFD_action_id);
  $session->flush();
  my $gfd_id = update_GFD_action($session);
  my $cookie = $config->{cookie};
  my $server_name = $ENV{SERVER_NAME};
  my $script_name = $ENV{SCRIPT_NAME};
  my $url = "http://$server_name" . $script_name . "?search_type=gfd&dbID=$gfd_id";
  print $cgi->redirect(-URL => $url, -cookie => $cookie);
}
elsif ($cgi->param('add_GFD_action')) {
  my $allelic_requirement_attribs = join(',', $cgi->param('allelic_requirement'));
  my $mutation_consequence_attrib = $cgi->param('mutation_consequence');
  my $GFD_id = $cgi->param('GFD_id');
  $session->param('allelic_requirement_attribs', $allelic_requirement_attribs);
  $session->param('mutation_consequence_attrib', $mutation_consequence_attrib);
  $session->param('GFD_id', $GFD_id);
  $session->flush();
  store_GFD_action($session);
  my $cookie = $config->{cookie};
  my $server_name = $ENV{SERVER_NAME};
  my $script_name = $ENV{SCRIPT_NAME};
  my $url = "http://$server_name" . $script_name . "?search_type=gfd&dbID=$GFD_id";
  print $cgi->redirect(-URL => $url, -cookie => $cookie);
}
elsif ($cgi->param('new_gene_disease')) {
  new_gene_disease($session);
}
elsif ($cgi->param('add_gene_disease')) {
  my $gene_name = $cgi->param('gene_name');
  my $disease_name = $cgi->param('disease_name');
  add_new_gene_disease($session, $gene_name, $disease_name);
}
else {
  show_default_page($session);
}

sub show_login {
  my $type = $cgi->param('login');
  show_login_page($session, $type);
}

sub logout {
  $session->param('is_logged_in', 0);
  $session->flush(); 
  display_search_results($session, $search_term);
}

sub login {
  my $auth = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly => 1, UseMD5 => 1,}); 
  my $email = $cgi->param('email');
  my $password = $cgi->param('password');
  if ($auth->htCheckPassword($email, $password)) {
    $session->param('is_logged_in', 1);
    $session->param('email', $email);
    $session->flush(); 
    display_search_results($session, $search_term);
  } else {
    show_default_page($session);
  }
}

sub send_recover_pwd_mail {
  my $email = $cgi->param('email');
  $session->param('email', $email);
  $session->flush(); 

  my $auth = get_auth();
  my $is_known = $auth->fetchPass($email); 
  if (!$is_known) {
    show_account_data($session, 'recover_pwd', 'email_unknown');
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
  if ($success) {
    show_default_page($session); # message email was send
    return;
  } else {
    show_default_page($session); # error sending email, print $Mail::Sendmail::error, $Mail::Sendmail::log
    return;
  }
}

sub show_recover_pwd_page {
  my $param_cgisessid = $cgi->param('CGISESSID');
  my $session_cgisessid = $session->id();
  if ($param_cgisessid == $session_cgisessid) {
    show_account_data($session, 'recover_pwd_enter_new_pwd');
  } else {
    show_default_page($session, 'session_ids_dont_match');
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
    show_error_reset_user_data('edit_pwd', 'current_pwd_wrong');
    return;
  }
  if (!($new_pwd && $retyped_pwd)) {
    show_error_reset_user_data('edit_pwd', 'missing_pwds');
    return;
  }
  if ($retyped_pwd && ($new_pwd ne $retyped_pwd)) {
    show_error_reset_user_data('edit_pwd', 'new_and_retyped_dont_match');
    return;
  }
  $success = $auth->htpasswd($email, $new_pwd, $current_pwd);
  if ($success) {
    show_account_data($session, 'account', 'reset_pwd_successful');
  } else {
    show_account_data($session, 'account', 'reset_pwd_failed');
  }
}

sub recover_pwd {
  my $auth = get_auth();
  my $email = $cgi->param('email');
  my $new_pwd = $cgi->param('new_password');
  my $retyped_pwd = $cgi->param('retyped_password');

  if ($new_pwd ne $retyped_pwd) {
    show_error_reset_user_data('recover_pwd_enter_new_pwd', 'new_and_retyped_dont_match');
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
    show_error_reset_user_data('edit_username', 'current_pwd_wrong');
    return;
  }
  if ( length($new_username) == 0) {
    show_error_reset_user_data('edit_username', 'new_username_missing');
    return;
  }

  my $dbh = get_dbh();
  my $stmt = qq{SELECT email FROM user WHERE username=?};
  my $sth = $dbh->prepare($stmt) or die $dbh->errstr;
  $sth->execute($new_username) or die $sth->errstr;
  my $ary_ref = $sth->fetchall_arrayref();
  if (scalar @$ary_ref == 1) {
    show_error_reset_user_data('edit_username', 'new_username_already_taken');
  } 

  $stmt = qq{UPDATE user SET username=? WHERE username=?};
  $dbh->do($stmt, undef, ($new_username, $current_username));
  show_account_data($session, 'account', 'reset_username_successful');
}

sub reset_email {
  my $auth = get_auth();
  my $email = $cgi->param('current_email');
  my $new_email = $cgi->param('new_email');
  my $password = $cgi->param('pwd');
  my $success = $auth->htCheckPassword($email, $password);
  if (!$success) {
    show_error_reset_user_data('edit_email', 'current_pwd_wrong');
    return;
  }
  my $email_is_used = $auth->fetchPass($new_email);
  if ($email_is_used) {
    show_error_reset_user_data('edit_email', 'email_is_taken');
    return;
  }
  
  my $dbh = get_dbh();
  my $stmt = qq{UPDATE user SET email=? WHERE email=?;};
  $dbh->do($stmt, undef, ($new_email, $email)); 

  $auth->htDelete($email);
  $auth->htpasswd($new_email, $password);
  $session->param('email', $new_email);
  $session->flush(); 
  show_account_data($session, 'account', 'reset_email_successful');  
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

