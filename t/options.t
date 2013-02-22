use strict;
use warnings;
use Test::More 0.88;
use Test::DZil;

plan tests => 8;

my $ini;

my $tzil = Builder->from_config(
  { dist_root => 'corpus/DZT' },
  {
    add_files => {
      'source/dist.ini' => $ini = simple_ini(
        {},
        'GatherDir',
        [ 'ModuleBuildDatabase' => { 
          'mbd_database_type'                      => 'PostgreSQL',
          'mbd_database_options.name'              => 'foo',
          'mbd_database_options.schema'            => 'bar',
          'mbd_database_extensions.postgis.schema' => 'baz',
        } ],
      )
    },
  }
);

$tzil->build;

my($build_pl) = grep { $_->name eq 'Build.PL' } @{ $tzil->files };

ok defined($build_pl), 'generated Build.PL';

my($plugin) = grep { $_->isa('Dist::Zilla::Plugin::ModuleBuildDatabase') } @{ $tzil->plugins };

isa_ok $plugin, 'Dist::Zilla::Plugin::ModuleBuild';

is $plugin->mb_class, 'Module::Build::Database';
is $plugin->mbd_database_type, 'PostgreSQL';
is $plugin->module_build_args->{database_type}, 'PostgreSQL';
is $plugin->module_build_args->{database_options}->{name}, 'foo';
is $plugin->module_build_args->{database_options}->{schema}, 'bar';
is $plugin->module_build_args->{database_extensions}->{postgis}->{schema}, 'baz';
