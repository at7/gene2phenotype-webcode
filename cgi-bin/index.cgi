#!/usr/bin/perl -wT
use Apache::Htpasswd;
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session qw(-ip-match);
use CGI::Session::Auth;
use DBI;
use Mail::Sendmail;

use strict;
use warnings;

require "./tmpl_handler.pl"; # cgi-bin

my $password_file = "../../gene2phenotype_users";
my $db_config = "../../config/registry";
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
  my $session = CGI::Session->load("driver:file", $cgi, {Directory=>'../tmp'});
  if ($session->is_empty) {
    $session = CGI::Session->new("driver:file", $cgi, {Directory=>'../tmp'});
  }
  my $session_id = $session->id();

  my $cookie = $cgi->cookie( -name => $session->name, -value  => $session->id );
  $session->flush();
  print $cgi->header( -cookie => $cookie );
  # print "Content-type: text/html\n\n";

  $cgi->param('CGISESSID', $session_id);

  my $search_term = $session->param('search_term');
  $search_term = $cgi->param('search_term');

  $config->{cgi} = $cgi;
  $config->{session} = $session;
  $config->{search_term} = $search_term;
  return $config;
}
show_default_page($session);
