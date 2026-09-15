use strict;
use warnings;

use re '/aa';

use 5.014;

use Test::More;

use Perl::Critic;
use Perl::Critic::Policy::RegularExpressions::PreventUselessMetacharacterEscapes;

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for
# a .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets -- which then fail for want of POD rather than for escaping.
# Note the hyphen in -single-policy: -single_policy is accepted and silently
# ignored, leaving all 200-odd policies switched on.
my $critic = Perl::Critic->new(
    -profile         => q{},
    '-single-policy' => 'PreventUselessMetacharacterEscapes',
    -severity        => 1,
);

sub violations {
    my ($source) = @_;
    return scalar $critic->critique( \"use strict;\nuse warnings;\n$source\n" );
}

my %prohibited = (
    'nothing interpolated at all' => q{my $re = qr/\Qfoo.bar\E/;},
    'literals either side'        => q{my $re = qr/\Qx:$a;\E/;},
    'a literal between two vars'  => q{my $re = qr/\Q$a.$b\E/;},
    'the whole pattern wrapped'   => q{my $re = m/\Qowner => "root:$admin"\E/;},
    'in a substitution match'     => q{s/\Qfoo.bar\E/baz/;},
    'in a replacement'            => q{s/\Q$find\E/\Qliteral\E/;},
    'unterminated, running on'    => q{my $re = qr/\Qfoo.bar/;},
);

foreach my $case ( sort keys %prohibited ) {
    is( violations( $prohibited{$case} ), 1, "$case is a violation" );
}

my %allowed = (
    'a variable alone'         => q{my $re = qr/\Q$a\E/;},
    'two adjacent variables'   => q{my $re = qr/\Q$a$b\E/;},
    'literal outside the span' => q{my $re = qr/owner => "root:\Q$admin\E"/;},
    'two spans, each narrow'   => q{my $re = qr/\Q$user\E and \Q$host\E/;},
    'a hash element'           => q{my $re = qr/\Q$hash{key}\E/;},
    'an arrow dereference'     => q{my $re = qr/\Q$obj->{name}\E/;},
    'an array'                 => q{my $re = qr/\Q@list\E/;},
    'no quotemeta at all'      => q{my $re = qr/foo\.bar/;},
    'unterminated but narrow'  => q{my $re = qr/\Q$only/;},
);

foreach my $case ( sort keys %allowed ) {
    is( violations( $allowed{$case} ), 0, "$case is allowed" );
}

# One complaint per token, however many spans in it are too wide: the fix is
# the same edit in each, and two violations would be two reports of one mistake.
is( violations(q{my $re = qr/\Qa.b\E and \Qc.d\E/;}), 1, 'two wide spans in one regex are one violation' );

done_testing;
