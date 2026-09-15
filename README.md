# NAME

Perl::Critic::Policy::RegularExpressions::PreventUselessMetacharacterEscapes - \\Q...\\E is for the variable you are interpolating, not for the text around it.

# VERSION

version 1.000

# Perl::Critic::Policy::RegularExpressions::PreventUselessMetacharacterEscapes

`\Q...\E` exists to make an interpolated value literal, because you do not know
what is in it.  You do know what is in the text you typed around it, so escaping
that is work the pattern does not need:

```perl
qr/\Qowner => "root:$admin"\E/;     # the whole thing quotemeta'd
qr/owner => "root:\Q$admin\E"/;     # only the part you cannot see
```

## Why it is worth a policy

The wide form does not merely add noise.  Everything inside `\Q...\E` is still
interpolated first, so a sigil in that literal text is a variable:

```perl
my $re = qr/\Qowner => "root:$admin"\E/;
```

Under `strict` that is a compile error naming a variable you never meant to
write.  Without it, `$admin` interpolates to empty and you get

```
(?^:owner\ \=\>\ \"root\:\")
```

\-- a pattern that has silently lost everything after the sigil and will not
match what you wrote it for.

The escapes it does produce are useless in their own right: `\:` and `\;` are
not metacharacters, and `\.` is a thing you can type.

## PROHIBITED

```perl
qr/\Qfoo.bar\E/;                # nothing interpolated: escape the dot yourself
qr/\Qx:$a;\E/;                  # literals either side of the variable
qr/\Q$a.$b\E/;                  # a literal between two variables
m/\Qowner => "root:$admin"\E/;
s/\Qfoo.bar\E/baz/;
```

## ALLOWED

`\Q...\E` around interpolation and nothing else, however many:

```perl
qr/\Q$a\E/;
qr/\Q$a$b\E/;                   # adjacent, with no literal between them
qr/owner => "root:\Q$admin\E"/;
qr/\Q$user\E and \Q$host\E/;
qr/\Q$hash{key}\E and \Q$obj->{name}\E/;
qr/\Q@list\E/;
```

## CONFIGURATION

- `allow_whitespace`

    Whether literal whitespace inside `\Q...\E` is allowed.  Off by default: a
    space needs no escaping either, and `\Q$first \E$second` is usually a span that
    should have stopped one character earlier.

    ```
    [RegularExpressions::PreventUselessMetacharacterEscapes]
    allow_whitespace = 1
    ```

## CAVEATS

`\Q...\E` works in a double-quoted string as well, with the same hazard.  This
policy looks only at regexes, which is what its namespace says it does.

A `\Q` with no `\E` runs to the end of the pattern, and is read that way here.

## METHODS

### supported\_parameters

`allow_whitespace`, whether literal whitespace inside a span is tolerated.

### default\_severity

SEVERITY\_MEDIUM.  The silent-truncation case is a wrong pattern rather than an
untidy one.

### default\_themes

bugs, maintenance

### applies\_to

PPI::Token::Regexp::Match, PPI::Token::Regexp::Substitute,
PPI::Token::QuoteLike::Regexp

### violates

Standard [Perl::Critic::Policy](https://metacpan.org/pod/Perl%3A%3ACritic%3A%3APolicy) interface.  One violation per token, however
many spans in it are too wide: the fix is the same edit in each.

# BUGS

Please report any bugs or feature requests on the bugtracker website
[https://github.com/Troglodyne-Internet-Widgets/perl-critic-policy-preventuselessmetacharacterescapes/issues](https://github.com/Troglodyne-Internet-Widgets/perl-critic-policy-preventuselessmetacharacterescapes/issues)

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHORS

Current Maintainers:

- George S. Baugh <george@troglodyne.net>

# COPYRIGHT AND LICENSE

Copyright (c) 2026 Troglodyne LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
