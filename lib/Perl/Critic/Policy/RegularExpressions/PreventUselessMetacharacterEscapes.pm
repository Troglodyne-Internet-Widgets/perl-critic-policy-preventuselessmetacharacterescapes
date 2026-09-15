package Perl::Critic::Policy::RegularExpressions::PreventUselessMetacharacterEscapes;

# ABSTRACT: \Q...\E is for the variable you are interpolating, not for the text around it.

use strict;
use warnings FATAL => 'all';

use 5.014;

use re '/aa';

use Readonly;

use Perl::Critic::Utils qw{ :severities :classification :ppi };
use parent              qw{Perl::Critic::Policy};

=head1 Perl::Critic::Policy::RegularExpressions::PreventUselessMetacharacterEscapes

C<\Q...\E> exists to make an interpolated value literal, because you do not know
what is in it.  You do know what is in the text you typed around it, so escaping
that is work the pattern does not need:

    qr/\Qowner => "root:$admin"\E/;     # the whole thing quotemeta'd
    qr/owner => "root:\Q$admin\E"/;     # only the part you cannot see

=head2 Why it is worth a policy

The wide form does not merely add noise.  Everything inside C<\Q...\E> is still
interpolated first, so a sigil in that literal text is a variable:

    my $re = qr/\Qowner => "root:$admin"\E/;

Under C<strict> that is a compile error naming a variable you never meant to
write.  Without it, C<$admin> interpolates to empty and you get

    (?^:owner\ \=\>\ \"root\:\")

-- a pattern that has silently lost everything after the sigil and will not
match what you wrote it for.

The escapes it does produce are useless in their own right: C<\:> and C<\;> are
not metacharacters, and C<\.> is a thing you can type.

=head2 PROHIBITED

    qr/\Qfoo.bar\E/;                # nothing interpolated: escape the dot yourself
    qr/\Qx:$a;\E/;                  # literals either side of the variable
    qr/\Q$a.$b\E/;                  # a literal between two variables
    m/\Qowner => "root:$admin"\E/;
    s/\Qfoo.bar\E/baz/;

=head2 ALLOWED

C<\Q...\E> around interpolation and nothing else, however many:

    qr/\Q$a\E/;
    qr/\Q$a$b\E/;                   # adjacent, with no literal between them
    qr/owner => "root:\Q$admin\E"/;
    qr/\Q$user\E and \Q$host\E/;
    qr/\Q$hash{key}\E and \Q$obj->{name}\E/;
    qr/\Q@list\E/;

=head2 CONFIGURATION

=over 4

=item C<allow_whitespace>

Whether literal whitespace inside C<\Q...\E> is allowed.  Off by default: a
space needs no escaping either, and C<\Q$first \E$second> is usually a span that
should have stopped one character earlier.

    [RegularExpressions::PreventUselessMetacharacterEscapes]
    allow_whitespace = 1

=back

=head2 CAVEATS

C<\Q...\E> works in a double-quoted string as well, with the same hazard.  This
policy looks only at regexes, which is what its namespace says it does.

A C<\Q> with no C<\E> runs to the end of the pattern, and is read that way here.

=cut

Readonly::Scalar my $DESC => q{\Q...\E wraps literal text, not just interpolation};
Readonly::Scalar my $EXPL => q{Put \Q...\E around the interpolated value alone; escape your own text yourself};

# $name, @name, ${name}, and whatever subscripts or arrows follow -- the parts
# of a span whose contents the author cannot see and therefore has to quote.
Readonly::Scalar my $INTERPOLATION_RX => qr/
    [\$\@]                          # a sigil
    (?: \{ \w+ \}  |  \w+ )         # ${name} or name
    (?:                             # then any run of subscripts or arrows
        -> (?: \[ [^\]]* \] | \{ [^\}]* \} )
      |     \[ [^\]]* \]
      |     \{ [^\}]* \}
    )*
/x;

=head2 METHODS

=head3 supported_parameters

C<allow_whitespace>, whether literal whitespace inside a span is tolerated.

=head3 default_severity

SEVERITY_MEDIUM.  The silent-truncation case is a wrong pattern rather than an
untidy one.

=head3 default_themes

bugs, maintenance

=head3 applies_to

PPI::Token::Regexp::Match, PPI::Token::Regexp::Substitute,
PPI::Token::QuoteLike::Regexp

=cut

sub supported_parameters {
    return (
        {
            name           => 'allow_whitespace',
            description    => 'Allow literal whitespace inside \Q...\E.',
            default_string => '0',
            behavior       => 'boolean',
        }
    );
}

sub default_severity { return $SEVERITY_MEDIUM }
sub default_themes   { return qw(bugs maintenance) }

sub applies_to {
    return qw{
      PPI::Token::Regexp::Match
      PPI::Token::Regexp::Substitute
      PPI::Token::QuoteLike::Regexp
    };
}

# What each \Q...\E in this string holds, with the interpolations taken out.
# A span with no \E runs to the end, which is what perl does with it.
sub _literal_remainders {
    my ( $self, $string ) = @_;

    return () if !defined $string || index( $string, '\\Q' ) < 0;

    my @remainders;
    while ( $string =~ m/\\Q(.*?)(?:\\E|\z)/gs ) {
        my $body = $1;

        $body =~ s/$INTERPOLATION_RX//g;
        $body =~ s/\s+//g if $self->{_allow_whitespace};

        push @remainders, $body if length $body;
    }

    return @remainders;
}

=head3 violates

Standard L<Perl::Critic::Policy> interface.  One violation per token, however
many spans in it are too wide: the fix is the same edit in each.

=cut

sub violates {
    my ( $self, $elem, undef ) = @_;

    foreach my $half (qw{get_match_string get_substitute_string}) {
        next if !$elem->can($half);

        my $string = eval { $elem->$half };
        return $self->violation( $DESC, $EXPL, $elem ) if $self->_literal_remainders($string);
    }

    return;
}

1;
