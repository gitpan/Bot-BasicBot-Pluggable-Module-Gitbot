use Test::More;
use Test::Exception;
use Test::TempDir qw( scratch );
use Test::Bot::BasicBot::Pluggable;

use File::Spec   qw();
use Git::Wrapper qw();

use Cwd        qw( getcwd );
use File::Path qw( rmtree );

my $bot = Test::Bot::BasicBot::Pluggable->new();

ok($bot->load('Gitbot'), "Loaded Gitbot module");

is(
    $bot->tell_private("!git garbage"),
    'Buh? Wha?',
    'Gives a semi-useless error response when given an unknown !git command'
);

is(
    $bot->tell_private("!git gitweb_url"),
    "gitweb_url is: 'http://localhost/'",
    'Gives the current git_gitweb_url, when not given a 2nd argument'
);

is(
    $bot->tell_private('!git gitweb_url http://example.com/'),
    "gitweb_url is now: 'http://example.com/'",
    'Notifies the user that the git_gitweb_url is now the 2nd argument'
);

is(
    $bot->tell_private('!git gitweb_url'),
    "gitweb_url is: 'http://example.com/'",
    'Gives the updated git_gitweb_url, when not given a 2nd argument'
);

like(
    $bot->tell_private("!git repo_root"),
    qr{repo_root is: '.*/repositories'},
    'Gives the current git_repo_root, when not given a 2nd argument'
);

is(
    $bot->tell_private('!git repo_root /gitbot/repos/live/here'),
    "repo_root is now: '/gitbot/repos/live/here'",
    'Notifies the user that the git_repo_root is now the 2nd argument'
);

is(
    $bot->tell_private('!git repo_root'),
    "repo_root is: '/gitbot/repos/live/here'",
    'Gives the updated git_repo_root, when not given a 2nd argument'
);

{
    my $path = File::Spec->rel2abs('foo');

    is(
        $bot->tell_private('!git repo_root foo'),
        "repo_root is now: '$path'",
        '"!git repo_root <path>" converts relative paths to abs paths'
    );
}

note 'Handles Git repos with working directories';
{
    my $repo_dir = scratch();
    my $repo_path = File::Spec->rel2abs("$repo_dir");

    is(
        $bot->tell_private("!git repo_root $repo_dir"),
        "repo_root is now: '$repo_path'",
        "Use the tempdir where we'll put our repositories"
    );

    is(
        $bot->tell_direct('help Gitbot'),
        "I don't know about any Git repositories.  I respond to the pattern /([0-9a-f]{7,})(?::(\\S+))?/i with a GitWeb URL.",
        'Check help text without any known repositories.'
    );

    $repo_dir->mkdir('first_repo');
    my $first_repo_path = File::Spec->catdir($repo_path, 'first_repo');

    my $git = Git::Wrapper->new($first_repo_path);
    $git->init();

    is(
        $bot->tell_private("!git refresh_repos"),
        "I now know about 1 Git repository.",
        'Refresh the repository listing'
    );

    $repo_dir->touch(File::Spec->catfile('first_repo', 'file'), qw|A few lines for the file.|);
    $git->add('.');

    local $ENV{GIT_AUTHOR_NAME}     = 'A. U. Thor';
    local $ENV{GIT_AUTHOR_EMAIL}    = 'a.u.thor@example.com';
    local $ENV{GIT_COMMITTER_NAME}  = 'Comm. I. Tor';
    local $ENV{GIT_COMMITTER_EMAIL} = 'comm.i.tor@example.com';

    $git->commit({message => 'First commit'});
    my ($commit) = $git->log({1 => 1});
    my $commit_sha = $commit->id();

    is(
        $bot->tell_indirect($commit_sha),
        "$commit_sha can be found at: http://example.com/?p=first_repo;a=commitdiff;hb=$commit_sha",
        'Handles full SHA1'
    );

    is(
        $bot->tell_indirect("$commit_sha:file"),
        "$commit_sha:file can be found at: http://example.com/?p=first_repo;a=blob;hb=$commit_sha;f=file",
        'Handles <sha>:<file> properly'
    );

    my $abbrev_sha = substr $commit_sha, 0, 7;
    is(
        $bot->tell_indirect($abbrev_sha),
        "$abbrev_sha can be found at: http://example.com/?p=first_repo;a=commitdiff;hb=$abbrev_sha",
        'Handles abbreviated SHA1'
    );

    is(
        $bot->tell_indirect("$abbrev_sha:file"),
        "$abbrev_sha:file can be found at: http://example.com/?p=first_repo;a=blob;hb=$abbrev_sha;f=file",
        'Handles <abbreviated_sha>:<file> properly'
    );

    is(
        $bot->tell_indirect(substr $commit_sha, 0, 6),
        '',
        'Does not respond to SHA1s shorter than 7 characters.'
    );

    is(
        $bot->tell_indirect("1111111"),
        '',
        'Does not say anything when given a bad SHA1.'
    );

    $repo_dir->cleanup();
}

note 'Handles bare Git repos';
{
    my $repo_dir = scratch();
    my $repo_path = File::Spec->rel2abs("$repo_dir");

    is(
        $bot->tell_private("!git repo_root $repo_dir"),
        "repo_root is now: '$repo_path'",
        "Use the tempdir where we'll put our repositories"
    );

    is(
        $bot->tell_direct('help Gitbot'),
        "I don't know about any Git repositories.  I respond to the pattern /([0-9a-f]{7,})(?::(\\S+))?/i with a GitWeb URL.",
        'Check help text without any known repositories.'
    );

    $repo_dir->mkdir('first_repo');
    my $first_repo_path = File::Spec->catdir($repo_path, 'first_repo');

    my $git = Git::Wrapper->new($first_repo_path);
    $git->init();

    $repo_dir->touch(File::Spec->catfile('first_repo', 'file'), qw|A few lines for the file.|);
    $git->add('.');

    local $ENV{GIT_AUTHOR_NAME}     = 'A. U. Thor';
    local $ENV{GIT_AUTHOR_EMAIL}    = 'a.u.thor@example.com';
    local $ENV{GIT_COMMITTER_NAME}  = 'Comm. I. Tor';
    local $ENV{GIT_COMMITTER_EMAIL} = 'comm.i.tor@example.com';

    $git->commit({message => 'First commit'});
    my ($commit) = $git->log({1 => 1});
    my $commit_sha = $commit->id();

    system("git clone -q --no-hardlinks $first_repo_path $first_repo_path.git");
    rmtree($first_repo_path);

    is(
        $bot->tell_private("!git refresh_repos"),
        "I now know about 1 Git repository.",
        'Refresh the repository listing'
    );

    is(
        $bot->tell_indirect($commit_sha),
        "$commit_sha can be found at: http://example.com/?p=first_repo.git;a=commitdiff;hb=$commit_sha",
        'Handles full SHA1'
    );

    is(
        $bot->tell_indirect("$commit_sha:file"),
        "$commit_sha:file can be found at: http://example.com/?p=first_repo.git;a=blob;hb=$commit_sha;f=file",
        'Handles <sha>:<file> properly'
    );

    my $abbrev_sha = substr $commit_sha, 0, 7;
    is(
        $bot->tell_indirect($abbrev_sha),
        "$abbrev_sha can be found at: http://example.com/?p=first_repo.git;a=commitdiff;hb=$abbrev_sha",
        'Handles abbreviated SHA1'
    );

    is(
        $bot->tell_indirect("$abbrev_sha:file"),
        "$abbrev_sha:file can be found at: http://example.com/?p=first_repo.git;a=blob;hb=$abbrev_sha;f=file",
        'Handles <abbreviated_sha>:<file> properly'
    );

    is(
        $bot->tell_indirect(substr $commit_sha, 0, 6),
        '',
        'Does not respond to SHA1s shorter than 7 characters.'
    );

    $repo_dir->cleanup();
}

note 'Handles multiple repos';
{
    my $repo_dir = scratch();
    my $repo_path = File::Spec->rel2abs("$repo_dir");

    is(
        $bot->tell_private("!git repo_root $repo_dir"),
        "repo_root is now: '$repo_path'",
        "Use the tempdir where we'll put our repositories"
    );

    is(
        $bot->tell_direct('help Gitbot'),
        "I don't know about any Git repositories.  I respond to the pattern /([0-9a-f]{7,})(?::(\\S+))?/i with a GitWeb URL.",
        'Check help text without any known repositories.'
    );

    $repo_dir->mkdir('first_repo');
    $repo_dir->mkdir('second_repo');
    my $first_repo_path  = File::Spec->catdir($repo_path, 'first_repo');
    my $second_repo_path = File::Spec->catdir($repo_path, 'second_repo');

    my $git = Git::Wrapper->new($first_repo_path);
    $git->init();

    my $git2 = Git::Wrapper->new($second_repo_path);
    $git2->init();

    is(
        $bot->tell_private("!git refresh_repos"),
        "I now know about 2 Git repositories.",
        'Refresh the repository listing'
    );

    $repo_dir->touch(File::Spec->catfile('first_repo', 'file'), qw|A few lines for the file.|);
    $repo_dir->touch(File::Spec->catfile('second_repo', 'another_file'), qw|This file has different lines.|);
    $git->add('.');
    $git2->add('.');

    local $ENV{GIT_AUTHOR_NAME}     = 'A. U. Thor';
    local $ENV{GIT_AUTHOR_EMAIL}    = 'a.u.thor@example.com';
    local $ENV{GIT_COMMITTER_NAME}  = 'Comm. I. Tor';
    local $ENV{GIT_COMMITTER_EMAIL} = 'comm.i.tor@example.com';

    $git->commit({message => 'First commit'});
    my ($first_repo_commit) = $git->log({1 => 1});
    my $first_repo_commit_sha = $first_repo_commit->id();

    $git2->commit({message => 'First commit in second repo'});
    my ($second_repo_commit) = $git2->log({1 => 1});
    my $second_repo_commit_sha = $second_repo_commit->id();

    is(
        $bot->tell_indirect($first_repo_commit_sha),
        "$first_repo_commit_sha can be found at: http://example.com/?p=first_repo;a=commitdiff;hb=$first_repo_commit_sha",
        'Finds the correct repository for a first_repo SHA1'
    );

    is(
        $bot->tell_indirect("$first_repo_commit_sha:file"),
        "$first_repo_commit_sha:file can be found at: http://example.com/?p=first_repo;a=blob;hb=$first_repo_commit_sha;f=file",
        'Handles <sha>:<file> properly for first_repo'
    );

    my $abbrev_first_repo_sha = substr $first_repo_commit_sha, 0, 7;
    is(
        $bot->tell_indirect($abbrev_first_repo_sha),
        "$abbrev_first_repo_sha can be found at: http://example.com/?p=first_repo;a=commitdiff;hb=$abbrev_first_repo_sha",
        'Handles abbreviated SHA1 for first_repo'
    );

    is(
        $bot->tell_indirect("$abbrev_first_repo_sha:file"),
        "$abbrev_first_repo_sha:file can be found at: http://example.com/?p=first_repo;a=blob;hb=$abbrev_first_repo_sha;f=file",
        'Handles <abbreviated_sha>:<file> properly for first_repo'
    );

    is(
        $bot->tell_indirect($second_repo_commit_sha),
        "$second_repo_commit_sha can be found at: http://example.com/?p=second_repo;a=commitdiff;hb=$second_repo_commit_sha",
        'Finds the correct repository for a second_repo SHA1'
    );

    is(
        $bot->tell_indirect("$second_repo_commit_sha:another_file"),
        "$second_repo_commit_sha:another_file can be found at: http://example.com/?p=second_repo;a=blob;hb=$second_repo_commit_sha;f=another_file",
        'Handles <sha>:<file> properly for second_repo'
    );

    my $abbrev_second_repo_sha = substr $second_repo_commit_sha, 0, 7;
    is(
        $bot->tell_indirect($abbrev_second_repo_sha),
        "$abbrev_second_repo_sha can be found at: http://example.com/?p=second_repo;a=commitdiff;hb=$abbrev_second_repo_sha",
        'Handles abbreviated SHA1 for second_repo'
    );

    is(
        $bot->tell_indirect("$abbrev_second_repo_sha:file"),
        "$abbrev_second_repo_sha:file can be found at: http://example.com/?p=second_repo;a=blob;hb=$abbrev_second_repo_sha;f=file",
        'Handles <abbreviated_sha>:<file> properly for second_repo'
    );

    $repo_dir->cleanup();
}

done_testing();
