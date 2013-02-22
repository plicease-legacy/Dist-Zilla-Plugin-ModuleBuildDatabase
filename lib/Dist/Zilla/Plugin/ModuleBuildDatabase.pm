package Dist::Zilla::Plugin::ModuleBuildDatabase;

use Moose;

extends 'Dist::Zilla::Plugin::ModuleBuild';

# ABSTRACT: build a Build.PL that uses Module::Build::Database
# VERSION

has '+mb_class' => ( default => 'Module::Build::Database' );

has 'mbd_database_type' => (
  isa     => 'Str',
  is      => 'rw',
  default => 'SQLite',
);

around module_build_args => sub {
  my $orig = shift;
  my $self = shift;
  
  my %args = %{ $self->$orig(@_) };
  
  $args{database_type} = $self->mbd_database_type;
  
  \%args;
};

1;
