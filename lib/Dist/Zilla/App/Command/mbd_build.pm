package Dist::Zilla::App::Command::mbd_build;

use strict;
use warnings;
use v5.10;
use File::chdir;
use Path::Class::Dir;
use File::Copy qw( copy );
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
  
  my $build_root = $opt->in 
  ? Path::Class::Dir->new($opt->in) 
  : $self->zilla->root->subdir('.build', 'mbd');
  
  if(-d $build_root)
  {
    $self->log("using existing build: $build_root");
    $self->log("(run dzil clean to start from scratch)");
  }
  else
  {
    $self->log("mkdir -p $build_root");
    $build_root->mkpath;
    $self->log("building in $build_root");
    $self->zilla->build_in($build_root);
    $self->_run_in($build_root, [$^X, 'Build.PL']);
  }
  $self->_run_in($build_root, ['./Build', @$args]);
  $self->_recurse($self->zilla->root->subdir('db'), $build_root->subdir('db'));
}

sub _run_in
{
  my($self, $dir, $cmd) = @_;
  
  local $CWD = $dir;
  $self->log("% @$cmd");
  system(@$cmd) and $self->log_fatal("command failed");
}

sub _recurse
{
  my($self, $dist_root, $build_root) = @_;

  state $first = 1;
  
  foreach my $child ($build_root->children(no_hidden => 1))
  {
    my $name = $child->basename;
    if($child->is_dir)
    {
      my $build_dir = $child;
      my $dist_dir = $dist_root->subdir($name);
      unless(-d $dist_dir)
      {
        $self->_notify if $first;
        $first = 0;
        $self->log("create $dist_dir/");
        $dist_dir->mkpath;
      }
      $self->_recurse($dist_dir, $build_dir);
    }
    else
    {
      my $new = $child;
      my $new_content = $new->slurp;
      my $old = $dist_root->file($name);
      if($new_content ne (eval { $old->slurp } // ''))
      {
        $self->_notify if $first;
        $first = 0;
        $self->log("copy $new => $old");
        $old->openw->print($new_content);
      }
    }
  }
}

sub _notify
{
  my($self) = @_;
  $self->log("importing back:");
}

1;

