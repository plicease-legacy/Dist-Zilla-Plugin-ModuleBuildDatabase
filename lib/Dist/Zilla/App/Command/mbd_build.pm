package Dist::Zilla::App::Command::mbd_build;

use strict;
use warnings;
use v5.10;
use Dist::Zilla::App -command;

# ABSTRACT: run Module::Build::Database commands
# VERSION

=head1 SYNOPSIS

 % dzil mbd_build dbtest
 % dzil mbd_build dbdist
 % dzil mbd_build dbfakeinstall
 % dzil mbd_build dbinstall

=head1 DESCRIPTION

After building the distribution, run the given C<Build> command.
The results to the db directory are then copied back into your 
working copy so they can be checked into your version control.

=cut

sub abstract { 'run Module::Build::Database commands' }

sub opt_spec {
  ([ 'in=s' => 'the directory in which to build the distribution' ])
}

sub execute
{
  my($self, $opt, $args) = @_;
  
  my($plugin) = grep { $_->isa('Dist::Zilla::Plugin::ModuleBuildDatabase') } @{ $self->zilla->plugins };
  
  unless(defined $plugin)
  {
    $self->log_fatal("MUST use [ModuleBuildDatabase] for this command");
  }
  
  $plugin->mbd_build($opt, $args);
}

1;

