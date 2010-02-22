use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name   => 'Bot::BasicBot::Pluggable::Module::Gitbot',
    license       => 'perl',
    dist_author   => 'Jacob Helwig <jhelwig@cpan.org>',
    dist_version  => '0.01',
    test_requires => {
        'Test::More'    => 0,
        'Test::TempDir' => 0,
    },
    requires => {
        'Bot::BasicBot::Pluggable' => 0,
        'File::Basename'           => 0,
        'File::Fu'                 => 0,
        'File::HomeDir'            => 0,
        'Git'                      => 0,
        'MooseX::Declare'          => 0,
        'Text::Pluralize'          => 0,
    },
    add_to_cleanup     => [ 'Bot-BasicBot-Pluggable-Module-Gitbot-*' ],
    create_makefile_pl => 'traditional',
    meta_merge         => {
        resources => {
            homepage    => 'http://github.com/jhelwig/Bot-BasicBot-Pluggable-Module-Gitbot',
            bugtracker  => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Bot-BasicBot-Pluggable-Module-Gitbot',
            repository  => 'git://github.com/jhelwig/Bot-BasicBot-Pluggable-Module-Gitbot.git'
        }
    },

);

$builder->create_build_script();
