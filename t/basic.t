use strict;
use warnings;
use Test::More 0.88;
use Test::DZil;

plan tests => 5;

my $tzil = Builder->from_config(
  { dist_root => 'corpus/DZT' },
  {
    add_files => {
      'source/dist.ini' => simple_ini(
        {},
        'GatherDir',
        [ 'ModuleBuildDatabase' => { } ],
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
is $plugin->mbd_database_type, 'SQLite';
is $plugin->module_build_args->{database_type}, 'SQLite';
