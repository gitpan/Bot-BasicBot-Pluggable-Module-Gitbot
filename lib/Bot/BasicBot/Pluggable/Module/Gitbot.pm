use 5.008;

use MooseX::Declare;

class Bot::BasicBot::Pluggable::Module::Gitbot
    extends Bot::BasicBot::Pluggable::Module
{
    use File::Fu   qw();
    use File::Spec qw();
    use Git        qw();

    use File::Basename  qw( basename  );
    use Text::Pluralize qw( pluralize );

    has _repos => (
        traits  => ['Array'],
        is      => 'rw',
        isa     => 'ArrayRef[Git]',
        default => sub { [] },
        lazy    => 1,
        handles => {
            _count_repos => 'count',
            _first_repo  => 'first',
        },
    );

    method init()
    {
        $self->set(git_repo_root => File::Spec->rel2abs('repositories'))
            unless $self->get('git_repo_root');

        $self->set(git_gitweb_url => 'http://localhost/')
            unless $self->get('git_gitweb_url');

        $self->_recache_repos();
    }

    method help($message)
    {
        return pluralize("I {don't |}know about {any|%d} Git repositor(y|ies).", $self->_count_repos()) . '  I respond to the pattern /([0-9a-f]{7,})(?::(\S+))?/i with a GitWeb URL.';
    }

    method told($message)
    {
        my ($match, $sha1, $filename) = $message->{body} =~ /(([0-9a-f]{7,})(?::(\S+))?)/i;
        return unless defined $sha1;

        my $repo = $self->_first_repo(sub {
            return eval {
                $_->command_oneline(
                    [ 'cat-file', '-t', $sha1, ],
                    { STDERR => 0 },
                )
            } ? 1 : 0;
        });

        unless ($repo) {
            $self->reply(
                $message,
                "Huh?  I have no clue what you're talking about...",
            );
            return;
        }

        my $type = eval {
            $repo->command_oneline(
                [ 'cat-file', '-t', $sha1, ],
                { STDERR => 0 },
            )
        };

        my $project = basename(
            $repo->wc_path()
                ? $repo->wc_path()
                : $repo->repo_path()
        );

        my $gitweb_url = $self->_get_gitweb_url({
            project  => $project,
            type     => $type,
            commit   => $sha1,
            filename => $filename,
        });

        return "$match can be found at: $gitweb_url";
    }

    method admin($message)
    {
        return unless $message->{body} =~ /^!git /i;
        $message->{body} =~ s/^!git\s+//;

        if (my ($new_repo_root) = $message->{body} =~ /^repo_root(?:\s+(.*))?/i) {
            if ($new_repo_root) {
                $self->set(git_repo_root => File::Spec->rel2abs($new_repo_root));
                $self->_recache_repos();
                return "repo_root is now: '@{[ $self->get('git_repo_root') ]}'";
            } else {
                return "repo_root is: '@{[ $self->get('git_repo_root') ]}'";
            }
        } elsif (my ($new_gitweb_url) = $message->{body} =~ /^gitweb_url(?:\s+(.*))?/i) {
            if ($new_gitweb_url) {
                $self->set(git_gitweb_url => $new_gitweb_url);
                return "gitweb_url is now: '@{[ $self->get('git_gitweb_url') ]}'";
            } else {
                return "gitweb_url is: '@{[ $self->get('git_gitweb_url') ]}'";
            }
        } elsif ($message->{body} =~ /^refresh_repos$/i) {
            $self->_recache_repos();
            return pluralize("I {no longer|now} know about {any|%d} Git repositor(y|ies).", $self->_count_repos());
        } else {
            return "Buh? Wha?";
        }
    }

    method _recache_repos()
    {
        my @repos = ();
        my $repo_root = File::Fu->dir($self->get('git_repo_root'));

        return unless $repo_root->d();

        foreach my $dir ($repo_root->list()) {
            next unless $dir->d();

            my $repo = Git->repository(Directory => $dir->stringify());
            next unless $repo;

            push @repos, $repo;
        }
        $self->_repos([@repos]);
    }

    method _get_gitweb_url($options)
    {
        return unless defined $options->{commit} && defined $options->{project};

        my $base         = $self->get('git_gitweb_url');
        my $type         = $options->{type};
        my $commit       = $options->{commit};
        my $project      = $options->{project};
        my $extra_params = '';

        if ($type eq 'commit') {
            $type = 'commitdiff';
        }

        if ($options->{filename}) {
            $extra_params .= ";f=@{[ $options->{filename} ]}";
            $type = 'blob';
        }

        return "$base?p=$project;a=$type;hb=$commit$extra_params";
    }

=head1 NAME

Bot::BasicBot::Pluggable::Module::Gitbot - A Bot::BasicBot::Pluggable Module to give out Gitweb links for commits.

=head1 VERSION

Version 0.01.05

=cut

our $VERSION = '0.01.05';

=head1 SYNOPSIS

    use Bot::BasicBot::Pluggable;

    my $bot = Bot::BasicBot::Pluggable->new();

    $bot->load('Gitbot');
    ...

or

    !load Gitbot


Once the module is loaded, you'll need to configure the module.  Using admin commands.

    !git gitweb_url http://example.com/
    !git repo_root /path/to/where/your/bare/git/repositories/are/


Any time someone says a SHA1 (full, or abbreviated with a minimum of 7
characters) where the bot can hear it, it will try to find a repository under
C<repo_root>, and provide a GitWeb url to the commitdiff of that SHA1.

    <me> gitbot: 1a2b3c4
    <gitbot> me: 1a2b3c4 can be found at: http://example.com/?p=my_repo.git;a=commitdiff;hb=1a2b3c4


You can also specify things in the form C<< <sha>:<file> >>, and the module will
reply with a link to the blob of that file, in the commit specified by the SHA.

    <me> Hey, you should check out 1a2b3c4:README
    <gitbot> 1a2b3c4:README can be found at: http://example.com/?p=my_repo.git;a=blob;hb=1a2b3c4;f=README


=head1 AUTHOR

Jacob Helwig, C<< <jhelwig at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-bot-basicbot-pluggable-module-gitbot at rt.cpan.org>, or through the web
interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Bot-BasicBot-Pluggable-Module-Gitbot>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Bot::BasicBot::Pluggable::Module::Gitbot


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Bot-BasicBot-Pluggable-Module-Gitbot>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Bot-BasicBot-Pluggable-Module-Gitbot>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Bot-BasicBot-Pluggable-Module-Gitbot>

=item * Search CPAN

L<http://search.cpan.org/dist/Bot-BasicBot-Pluggable-Module-Gitbot>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2010 Jacob Helwig, all rights reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

    __PACKAGE__->meta->make_immutable(inline_constructor => 0);
}

1;
