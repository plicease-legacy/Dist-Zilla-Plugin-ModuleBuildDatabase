package Dist::Zilla::Plugin::ModuleBuildDatabase;

use Moose;
use v5.10;

extends 'Dist::Zilla::Plugin::ModuleBuild';

# ABSTRACT: build a Build.PL that uses Module::Build::Database
# VERSION

=head1 SYNOPSIS

 [ModuleBuildDatabase]
 mbd_database_type = PostgreSQL
 mbd_database_options.name = my_database_name
 mbd_database_options.schema = my_schema_name
 database_extensions.postgis.schema = public

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
L<Module::Build::Database>
L<Module::Build::Database::PostgreSQL>
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

1;
