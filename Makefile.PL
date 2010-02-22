use inc::Module::Install;

name     'Bot-BasicBot-Pluggable-Module-Gitbot';
all_from 'lib/Bot/BasicBot/Pluggable/Module/Gitbot.pm';
author   'Jacob Helwig <jhelwig@cpan.org>';

test_requires 'Test::More';
test_requires 'Test::TempDir';

requires 'Bot::BasicBot::Pluggable';
requires 'File::Basename';
requires 'File::Fu';
requires 'File::HomeDir';
requires 'Git';
requires 'MooseX::Declare';
requires 'Text::Pluralize';

homepage   'http://github.com/jhelwig/Bot-BasicBot-Pluggable-Module-Gitbot';
bugtracker 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Bot-BasicBot-Pluggable-Module-Gitbot';
repository 'git://github.com/jhelwig/Bot-BasicBot-Pluggable-Module-Gitbot.git';

auto_provides_class;

WriteAll;
