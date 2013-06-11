package Dist::Zilla::Plugin::ModuleBuildDatabase;

use Moose;
use v5.10;
use File::chdir;
use Path::Class::Dir;
use AnyEvent;
use AnyEvent::Open3::Simple;
use File::Copy qw( copy );

extends 'Dist::Zilla::Plugin::ModuleBuild';

# ABSTRACT: build a Build.PL that uses Module::Build::Database
# VERSION

=head1 SYNOPSIS

 [ModuleBuildDatabase]
 mbd_database_type = PostgreSQL
 mbd_database_options.name = my_database_name
 mbd_database_options.schema = my_schema_name
 mbd_database_extensions.postgis.schema = public

=head1 DESCRIPTION

This plugin is a very light layer over L<Dist::Zilla::Plugin::ModuleBuild>
to support some of the eccentricities of L<Module::Build::Database>.  It
allows you to specify the C<database_type>, C<database_options> and 
C<database_extensions> in your C<dist.ini>.  It also set the mb_class
to L<Module::Build::Database>.

=head1 ATTRIBUTES

This plugin understands all the attributes supported by L<Dist::Zilla::Plugin::ModuleBuild>,
with the minor caveat that the default for C<mb_class> is L<Module::Build::Database>
instead of L<Module::Build>.  In addition it understands these options:

=head2 mbd_database_type

The type of database.  Any value supported by L<Module::Build::Database>, which is, as
of this writing either C<PostgreSQL> or C<SQLite>.  The details and ramifications of
using specific options are described in the L<Module::Build::Database::PostgreSQL>
and L<Module::Build::Database::SQLite> documentation.

=head2 mbd_database_options

Database options.  This is a hash reference.  This must be specified using the dot notation as in the example above.

=head2 mbd_database_extensions

Database extensions.  This is a hash reference.  This must be specified using the dot notation as in the example above.

=head1 SEE ALSO

L<Dist::Zilla::Plugin::ModuleBuild>,
L<Module::Build::Database>,
L<Module::Build::Database::PostgreSQL>,
L<Module::Build::Database::SQLite>

=cut

has '+mb_class' => ( default => 'Module::Build::Database' );

has 'mbd_database_type' => (
  isa     => 'Str',
  is      => 'rw',
  default => 'SQLite',
);

has 'mbd_extra_options' => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { { } },
);

has '_notified' => (
  isa     => 'Int',
  is      => 'rw',
  default => 0,
);

around module_build_args => sub {
  my $orig = shift;
  my $self = shift;
  
  my %args = %{ $self->$orig(@_) };
  
  $args{database_type}    = $self->mbd_database_type;
  
  while(my($k,$v) = each %{ $self->mbd_extra_options })
  {
    $args{$k} = $v;
  }
  
  \%args;
};

around BUILDARGS => sub {
  my $orig  = shift;
  my $class = shift;
  my $args  = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  
  my $option_root = {};
  
  foreach my $key (keys %$args)
  {
    next unless $key =~ /^mbd_(database_(options|extensions)\..+)$/;
    my @key = split /\./, $1;
    my $value = delete $args->{$key};
    my $opt = $option_root;
    $opt = $opt->{shift @key} //= {} while @key > 1;
    $opt->{$key[0]} = $value;
  }
  
  $args->{mbd_extra_options} = $option_root;
  
  $class->$orig($args);
};

sub mbd_build
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
  
  my $done = AnyEvent->condvar;
  
  my $ipc = AnyEvent::Open3::Simple->new(
    on_stdout => sub {
      my($proc, $line) = @_;
      $self->log("out: $line");
    },
    on_stderr => sub {
      my($proc, $line) = @_;
      $self->log("err: $line");
    },
    on_error => sub {
      my($error) = @_;
      $self->log("error starting process: $error");
      $done->send(1);
    },
    on_exit => sub {
      my($proc, $exit, $sig) = @_;
      $self->log("exit: $exit") if $exit;
      $self->log("signal: $sig") if $sig;
      $done->send($exit || $sig);
    },
  );
  $ipc->run(@$cmd);
  $done->recv and $self->log_fatal("command failed");
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
        $self->_notify;
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
        $self->_notify;
        $self->log("copy $new => $old");
        $old->openw->print($new_content);
      }
    }
  }
}

sub _notify
{
  my($self) = @_;
  return if $self->_notified;
  $self->_notified(1);
  $self->log("importing back:");
}

1;
