use strict;
use warnings;
use Test::More 0.88;
use Test::DZil;

plan tests => 1;

my $tzil = Builder->from_config(
  { dist_root => 'corpus/DZT' },
  {
    add_files => {
      'source/dist.ini' => simple_ini(
        {},
        'GatherDir',
        [ 'ModuleBuildDatabase' => { 
          'mbd_database_type' => 'SQLite',
          'mbd_database_options.name' => 'foo.sqlite',
        } ],
      )
    },
  }
);

$tzil->build;

my($plugin) = grep { $_->isa('Dist::Zilla::Plugin::ModuleBuildDatabase') } @{ $tzil->plugins };

is $plugin->mbd_extra_options->{database_options}->{name}.'', $tzil->root->file('foo.sqlite').'',
  'use dist root instead of build root';
note $plugin->mbd_extra_options->{database_options}->{name};
