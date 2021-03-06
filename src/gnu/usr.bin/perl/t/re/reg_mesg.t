#!./perl -w

BEGIN {
	chdir 't' if -d 't';
	@INC = '../lib';
	require './test.pl';
	eval 'require Config'; # assume defaults if this fails
}

use strict;
use open qw(:utf8 :std);

##
## If the markers used are changed (search for "MARKER1" in regcomp.c),
## update only these two regexs, and leave the {#} in the @death/@warning
## arrays below. The {#} is a meta-marker -- it marks where the marker should
## go.
##
## Returns empty string if that is what is expected.  Otherwise, handles
## either a scalar, turning it into a single element array; or a ref to an
## array, adjusting each element.  If called in array context, returns an
## array, otherwise the join of all elements

sub fixup_expect {
    my $expect_ref = shift;
    return if $expect_ref eq "";

    my @expect;
    if (ref $expect_ref) {
        @expect = @$expect_ref;
    }
    else {
        @expect = $expect_ref;
    }

    foreach my $element (@expect) {
        $element =~ s/{\#}/in regex; marked by <-- HERE in/;
        $element =~ s/{\#}/ <-- HERE /;
        $element .= " at ";
    }
    return wantarray ? @expect : join "", @expect;
}

## Because we don't "use utf8" in this file, we need to do some extra legwork
## for the utf8 tests: Append 'use utf8' to the pattern, and mark the strings
## to check against as UTF-8
##
## This also creates a second variant of the tests to check if the
## latin1 error messages are working correctly.
my $l1   = "\x{ef}";
my $utf8 = "\x{30cd}";
utf8::encode($utf8);

sub mark_as_utf8 {
    my @ret;
    while ( my ($pat, $msg) = splice(@_, 0, 2) ) {
        my $l1_pat = $pat =~ s/$utf8/$l1/gr;
        my $l1_msg;
        $pat = "use utf8; $pat";
        
        if (ref $msg) {
            $l1_msg = [ map { s/$utf8/$l1/gr } @$msg ];
            @$msg   = map { my $c = $_; utf8::decode($c); $c } @$msg;
        }
        else {
            $l1_msg = $msg =~ s/$utf8/$l1/gr;
            utf8::decode($msg);
        }
        push @ret, $pat => $msg;
        push @ret, $l1_pat => $l1_msg unless $l1_pat =~ /#no latin1/;
    }
    return @ret;
}

my $inf_m1 = ($Config::Config{reg_infty} || 32767) - 1;
my $inf_p1 = $inf_m1 + 2;

##
## Key-value pairs of code/error of code that should have fatal errors.
##
my @death =
(
 '/[[=foo=]]/' => 'POSIX syntax [= =] is reserved for future extensions {#} m/[[=foo=]{#}]/',

 '/(?<= .*)/' =>  'Variable length lookbehind not implemented in regex m/(?<= .*)/',

 '/(?<= x{1000})/' => 'Lookbehind longer than 255 not implemented in regex m/(?<= x{1000})/',

 '/(?@)/' => 'Sequence (?@...) not implemented {#} m/(?@{#})/',

 '/(?{ 1/' => 'Missing right curly or square bracket',

 '/(?(1x))/' => 'Switch condition not recognized {#} m/(?(1x{#}))/',
 '/(?(1x(?#)))/'=> 'Switch condition not recognized {#} m/(?(1x{#}(?#)))/',

 '/(?(1)x|y|z)/' => 'Switch (?(condition)... contains too many branches {#} m/(?(1)x|y|{#}z)/',

 '/(?(x)y|x)/' => 'Unknown switch condition (?(...)) {#} m/(?(x{#})y|x)/',

 '/(?/' => 'Sequence (? incomplete {#} m/(?{#}/',

 '/(?;x/' => 'Sequence (?;...) not recognized {#} m/(?;{#}x/',
 '/(?<;x/' => 'Group name must start with a non-digit word character {#} m/(?<;{#}x/',
 '/(?\ix/' => 'Sequence (?\...) not recognized {#} m/(?\{#}ix/',
 '/(?\mx/' => 'Sequence (?\...) not recognized {#} m/(?\{#}mx/',
 '/(?\:x/' => 'Sequence (?\...) not recognized {#} m/(?\{#}:x/',
 '/(?\=x/' => 'Sequence (?\...) not recognized {#} m/(?\{#}=x/',
 '/(?\!x/' => 'Sequence (?\...) not recognized {#} m/(?\{#}!x/',
 '/(?\<=x/' => 'Sequence (?\...) not recognized {#} m/(?\{#}<=x/',
 '/(?\<!x/' => 'Sequence (?\...) not recognized {#} m/(?\{#}<!x/',
 '/(?\>x/' => 'Sequence (?\...) not recognized {#} m/(?\{#}>x/',
 '/(?^-i:foo)/' => 'Sequence (?^-...) not recognized {#} m/(?^-{#}i:foo)/',
 '/(?^-i)foo/' => 'Sequence (?^-...) not recognized {#} m/(?^-{#}i)foo/',
 '/(?^d:foo)/' => 'Sequence (?^d...) not recognized {#} m/(?^d{#}:foo)/',
 '/(?^d)foo/' => 'Sequence (?^d...) not recognized {#} m/(?^d{#})foo/',
 '/(?^lu:foo)/' => 'Regexp modifiers "l" and "u" are mutually exclusive {#} m/(?^lu{#}:foo)/',
 '/(?^lu)foo/' => 'Regexp modifiers "l" and "u" are mutually exclusive {#} m/(?^lu{#})foo/',
'/(?da:foo)/' => 'Regexp modifiers "d" and "a" are mutually exclusive {#} m/(?da{#}:foo)/',
'/(?lil:foo)/' => 'Regexp modifier "l" may not appear twice {#} m/(?lil{#}:foo)/',
'/(?aaia:foo)/' => 'Regexp modifier "a" may appear a maximum of twice {#} m/(?aaia{#}:foo)/',
'/(?i-l:foo)/' => 'Regexp modifier "l" may not appear after the "-" {#} m/(?i-l{#}:foo)/',
'/a\b{cde/' => 'Use "\b\{" instead of "\b{" {#} m/a\{#}b{cde/',
'/a\B{cde/' => 'Use "\B\{" instead of "\B{" {#} m/a\{#}B{cde/',

 '/((x)/' => 'Unmatched ( {#} m/({#}(x)/',

 "/x{$inf_p1}/" => "Quantifier in {,} bigger than $inf_m1 {#} m/x{{#}$inf_p1}/",


 '/x**/' => 'Nested quantifiers {#} m/x**{#}/',

 '/x[/' => 'Unmatched [ {#} m/x[{#}/',

 '/*/', => 'Quantifier follows nothing {#} m/*{#}/',

 '/\p{x/' => 'Missing right brace on \p{} {#} m/\p{{#}x/',

 '/[\p{x]/' => 'Missing right brace on \p{} {#} m/[\p{{#}x]/',

 '/(x)\2/' => 'Reference to nonexistent group {#} m/(x)\2{#}/',

 '/\g/' => 'Unterminated \g... pattern {#} m/\g{#}/',
 '/\g{1/' => 'Unterminated \g{...} pattern {#} m/\g{1{#}/',

 'my $m = "\\\"; $m =~ $m', => 'Trailing \ in regex m/\/',

 '/\x{1/' => 'Missing right brace on \x{} {#} m/\x{1{#}/',
 '/\x{X/' => 'Missing right brace on \x{} {#} m/\x{{#}X/',

 '/[\x{X]/' => 'Missing right brace on \x{} {#} m/[\x{{#}X]/',
 '/[\x{A]/' => 'Missing right brace on \x{} {#} m/[\x{A{#}]/',

 '/\o{1/' => 'Missing right brace on \o{ {#} m/\o{1{#}/',
 '/\o{X/' => 'Missing right brace on \o{ {#} m/\o{{#}X/',

 '/[\o{X]/' => 'Missing right brace on \o{ {#} m/[\o{{#}X]/',
 '/[\o{7]/' => 'Missing right brace on \o{ {#} m/[\o{7{#}]/',

 '/[[:barf:]]/' => 'POSIX class [:barf:] unknown {#} m/[[:barf:]{#}]/',

 '/[[=barf=]]/' => 'POSIX syntax [= =] is reserved for future extensions {#} m/[[=barf=]{#}]/',

 '/[[.barf.]]/' => 'POSIX syntax [. .] is reserved for future extensions {#} m/[[.barf.]{#}]/',

 '/[z-a]/' => 'Invalid [] range "z-a" {#} m/[z-a{#}]/',

 '/\p/' => 'Empty \p{} {#} m/\p{#}/',

 '/\P{}/' => 'Empty \P{} {#} m/\P{{#}}/',
 '/(?[[[:word]]])/' => "Unmatched ':' in POSIX class {#} m/(?[[[:word{#}]]])/",
 '/(?[[:word]])/' => "Unmatched ':' in POSIX class {#} m/(?[[:word{#}]])/",
 '/(?[[[:digit: ])/' => "Unmatched '[' in POSIX class {#} m/(?[[[:digit:{#} ])/",
 '/(?[[:digit: ])/' => "Unmatched '[' in POSIX class {#} m/(?[[:digit:{#} ])/",
 '/(?[[[::]]])/' => "POSIX class [::] unknown {#} m/(?[[[::]{#}]])/",
 '/(?[[[:w:]]])/' => "POSIX class [:w:] unknown {#} m/(?[[[:w:]{#}]])/",
 '/(?[[:w:]])/' => "POSIX class [:w:] unknown {#} m/(?[[:w:]{#}])/",
 '/(?[a])/' =>  'Unexpected character {#} m/(?[a{#}])/',
 '/(?[\t])/l' => '(?[...]) not valid in locale {#} m/(?[{#}\t])/',
 '/(?[ + \t ])/' => 'Unexpected binary operator \'+\' with no preceding operand {#} m/(?[ +{#} \t ])/',
 '/(?[ \cK - ( + \t ) ])/' => 'Unexpected binary operator \'+\' with no preceding operand {#} m/(?[ \cK - ( +{#} \t ) ])/',
 '/(?[ \cK ( \t ) ])/' => 'Unexpected \'(\' with no preceding operator {#} m/(?[ \cK ({#} \t ) ])/',
 '/(?[ \cK \t ])/' => 'Operand with no preceding operator {#} m/(?[ \cK \t{#} ])/',
 '/(?[ \0004 ])/' => 'Need exactly 3 octal digits {#} m/(?[ \0004 {#}])/',
 '/(?[ \05 ])/' => 'Need exactly 3 octal digits {#} m/(?[ \05 {#}])/',
 '/(?[ \o{1038} ])/' => 'Non-octal character {#} m/(?[ \o{1038{#}} ])/',
 '/(?[ \o{} ])/' => 'Number with no digits {#} m/(?[ \o{}{#} ])/',
 '/(?[ \x{defg} ])/' => 'Non-hex character {#} m/(?[ \x{defg{#}} ])/',
 '/(?[ \xabcdef ])/' => 'Use \\x{...} for more than two hex characters {#} m/(?[ \xabc{#}def ])/',
 '/(?[ \x{} ])/' => 'Number with no digits {#} m/(?[ \x{}{#} ])/',
 '/(?[ \cK + ) ])/' => 'Unexpected \')\' {#} m/(?[ \cK + ){#} ])/',
 '/(?[ \cK + ])/' => 'Incomplete expression within \'(?[ ])\' {#} m/(?[ \cK + {#}])/',
 '/(?[ \p{foo} ])/' => 'Property \'foo\' is unknown {#} m/(?[ \p{foo}{#} ])/',
 '/(?[ \p{ foo = bar } ])/' => 'Property \'foo = bar\' is unknown {#} m/(?[ \p{ foo = bar }{#} ])/',
 '/(?[ \8 ])/' => 'Unrecognized escape \8 in character class {#} m/(?[ \8{#} ])/',
 '/(?[ \t ]/' => 'Syntax error in (?[...]) in regex m/(?[ \t ]/',
 '/(?[ [ \t ]/' => 'Syntax error in (?[...]) in regex m/(?[ [ \t ]/',
 '/(?[ \t ] ]/' => 'Syntax error in (?[...]) in regex m/(?[ \t ] ]/',
 '/(?[ [ ] ]/' => 'Syntax error in (?[...]) in regex m/(?[ [ ] ]/',
 '/(?[ \t + \e # This was supposed to be a comment ])/' => 'Syntax error in (?[...]) in regex m/(?[ \t + \e # This was supposed to be a comment ])/',
 '/(?[ ])/' => 'Incomplete expression within \'(?[ ])\' {#} m/(?[ {#}])/',
 'm/(?[[a-\d]])/' => 'False [] range "a-\d" {#} m/(?[[a-\d{#}]])/',
 'm/(?[[\w-x]])/' => 'False [] range "\w-" {#} m/(?[[\w-{#}x]])/',
 'm/(?[[a-\pM]])/' => 'False [] range "a-\pM" {#} m/(?[[a-\pM{#}]])/',
 'm/(?[[\pM-x]])/' => 'False [] range "\pM-" {#} m/(?[[\pM-{#}x]])/',
 'm/(?[[\N{LATIN CAPITAL LETTER A WITH MACRON AND GRAVE}]])/' => '\N{} in character class restricted to one character {#} m/(?[[\N{U+100.300{#}}]])/',
 'm/(?[ \p{Digit} & (?(?[ \p{Thai} | \p{Lao} ]))])/' => 'Sequence (?(...) not recognized {#} m/(?[ \p{Digit} & (?({#}?[ \p{Thai} | \p{Lao} ]))])/',
 'm/(?[ \p{Digit} & (?:(?[ \p{Thai} | \p{Lao} ]))])/' => 'Expecting \'(?flags:(?[...\' {#} m/(?[ \p{Digit} & (?{#}:(?[ \p{Thai} | \p{Lao} ]))])/',
 'm/\o{/' => 'Missing right brace on \o{ {#} m/\o{{#}/',
 'm/\o/' => 'Missing braces on \o{} {#} m/\o{#}/',
 'm/\o{}/' => 'Number with no digits {#} m/\o{}{#}/',
 'm/[\o{]/' => 'Missing right brace on \o{ {#} m/[\o{{#}]/',
 'm/[\o]/' => 'Missing braces on \o{} {#} m/[\o{#}]/',
 'm/[\o{}]/' => 'Number with no digits {#} m/[\o{}{#}]/',
 'm/(?^-i:foo)/' => 'Sequence (?^-...) not recognized {#} m/(?^-{#}i:foo)/',
 'm/\87/' => 'Reference to nonexistent group {#} m/\87{#}/',
 'm/a\87/' => 'Reference to nonexistent group {#} m/a\87{#}/',
 'm/a\97/' => 'Reference to nonexistent group {#} m/a\97{#}/',
 'm/(*DOOF)/' => 'Unknown verb pattern \'DOOF\' {#} m/(*DOOF){#}/',
 'm/(?&a/'  => 'Sequence (?&... not terminated {#} m/(?&a{#}/',
 'm/(?P=/' => 'Sequence ?P=... not terminated {#} m/(?P={#}/',
 "m/(?'/"  => "Sequence (?'... not terminated {#} m/(?'{#}/",
 "m/(?</"  => "Sequence (?<... not terminated {#} m/(?<{#}/",
 'm/(?&/'  => 'Sequence (?&... not terminated {#} m/(?&{#}/',
 'm/(?(</' => 'Sequence (?(<... not terminated {#} m/(?(<{#}/',
 "m/(?('/" => "Sequence (?('... not terminated {#} m/(?('{#}/",
 'm/\g{/'  => 'Sequence \g{... not terminated {#} m/\g{{#}/',
 'm/\k</'  => 'Sequence \k<... not terminated {#} m/\k<{#}/',
 'm/\c??/' => "Character following \"\\c\" must be printable ASCII",
);

my @death_utf8 = mark_as_utf8(
 '/???[[=???=]]???/' => 'POSIX syntax [= =] is reserved for future extensions {#} m/???[[=???=]{#}]???/',
 '/???(?<= .*)/' =>  'Variable length lookbehind not implemented in regex m/???(?<= .*)/',

 '/(?<= ???{1000})/' => 'Lookbehind longer than 255 not implemented in regex m/(?<= ???{1000})/',

 '/???(????)???/' => 'Sequence (????...) not recognized {#} m/???(????{#})???/',

 '/???(?(1???))???/' => 'Switch condition not recognized {#} m/???(?(1???{#}))???/',

 '/(?(1)???|y|???)/' => 'Switch (?(condition)... contains too many branches {#} m/(?(1)???|y|{#}???)/',

 '/(?(???)y|???)/' => 'Unknown switch condition (?(...)) {#} m/(?(???{#})y|???)/',

 '/???(?/' => 'Sequence (? incomplete {#} m/???(?{#}/',

 '/???(?;???/' => 'Sequence (?;...) not recognized {#} m/???(?;{#}???/',
 '/???(?<;???/' => 'Group name must start with a non-digit word character {#} m/???(?<;{#}???/',
 '/???(?\ix???/' => 'Sequence (?\...) not recognized {#} m/???(?\{#}ix???/',
 '/???(?^lu:???)/' => 'Regexp modifiers "l" and "u" are mutually exclusive {#} m/???(?^lu{#}:???)/',
'/???(?lil:???)/' => 'Regexp modifier "l" may not appear twice {#} m/???(?lil{#}:???)/',
'/???(?aaia:???)/' => 'Regexp modifier "a" may appear a maximum of twice {#} m/???(?aaia{#}:???)/',
'/???(?i-l:???)/' => 'Regexp modifier "l" may not appear after the "-" {#} m/???(?i-l{#}:???)/',

 '/???((???)/' => 'Unmatched ( {#} m/???({#}(???)/',

 "/???{$inf_p1}???/" => "Quantifier in {,} bigger than $inf_m1 {#} m/???{{#}$inf_p1}???/",


 '/???**???/' => 'Nested quantifiers {#} m/???**{#}???/',

 '/???[???/' => 'Unmatched [ {#} m/???[{#}???/',

 '/*???/', => 'Quantifier follows nothing {#} m/*{#}???/',

 '/???\p{???/' => 'Missing right brace on \p{} {#} m/???\p{{#}???/',

 '/(???)\2???/' => 'Reference to nonexistent group {#} m/(???)\2{#}???/',

 '/\g{???/; #no latin1' => 'Sequence \g{... not terminated {#} m/\g{???{#}/',

 'my $m = "???\\\"; $m =~ $m', => 'Trailing \ in regex m/???\/',

 '/\x{???/' => 'Missing right brace on \x{} {#} m/\x{{#}???/',
 '/???[\x{???]???/' => 'Missing right brace on \x{} {#} m/???[\x{{#}???]???/',
 '/???[\x{???]/' => 'Missing right brace on \x{} {#} m/???[\x{{#}???]/',

 '/???\o{???/' => 'Missing right brace on \o{ {#} m/???\o{{#}???/',
 '/???[[:???:]]???/' => 'POSIX class [:???:] unknown {#} m/???[[:???:]{#}]???/',

 '/???[[=???=]]???/' => 'POSIX syntax [= =] is reserved for future extensions {#} m/???[[=???=]{#}]???/',

 '/???[[.???.]]???/' => 'POSIX syntax [. .] is reserved for future extensions {#} m/???[[.???.]{#}]???/',

 '/[???-a]???/' => 'Invalid [] range "???-a" {#} m/[???-a{#}]???/',

 '/???\p{}???/' => 'Empty \p{} {#} m/???\p{{#}}???/',

 '/???(?[[[:???]]])???/' => "Unmatched ':' in POSIX class {#} m/???(?[[[:???{#}]]])???/",
 '/???(?[[[:???: ])???/' => "Unmatched '[' in POSIX class {#} m/???(?[[[:???:{#} ])???/",
 '/???(?[[[::]]])???/' => "POSIX class [::] unknown {#} m/???(?[[[::]{#}]])???/",
 '/???(?[[[:???:]]])???/' => "POSIX class [:???:] unknown {#} m/???(?[[[:???:]{#}]])???/",
 '/???(?[[:???:]])???/' => "POSIX class [:???:] unknown {#} m/???(?[[:???:]{#}])???/",
 '/???(?[???])???/' =>  'Unexpected character {#} m/???(?[???{#}])???/',
 '/???(?[???])/l' => '(?[...]) not valid in locale {#} m/???(?[{#}???])/',
 '/???(?[ + [???] ])/' => 'Unexpected binary operator \'+\' with no preceding operand {#} m/???(?[ +{#} [???] ])/',
 '/???(?[ \cK - ( + [???] ) ])/' => 'Unexpected binary operator \'+\' with no preceding operand {#} m/???(?[ \cK - ( +{#} [???] ) ])/',
 '/???(?[ \cK ( [???] ) ])/' => 'Unexpected \'(\' with no preceding operator {#} m/???(?[ \cK ({#} [???] ) ])/',
 '/???(?[ \cK [???] ])???/' => 'Operand with no preceding operator {#} m/???(?[ \cK [???{#}] ])???/',
 '/???(?[ \0004 ])???/' => 'Need exactly 3 octal digits {#} m/???(?[ \0004 {#}])???/',
 '/(?[ \o{???} ])???/' => 'Non-octal character {#} m/(?[ \o{???{#}} ])???/',
 '/???(?[ \o{} ])???/' => 'Number with no digits {#} m/???(?[ \o{}{#} ])???/',
 '/(?[ \x{???} ])???/' => 'Non-hex character {#} m/(?[ \x{???{#}} ])???/',
 '/(?[ \p{???} ])/' => 'Property \'???\' is unknown {#} m/(?[ \p{???}{#} ])/',
 '/(?[ \p{ ??? = bar } ])/' => 'Property \'??? = bar\' is unknown {#} m/(?[ \p{ ??? = bar }{#} ])/',
 '/???(?[ \t ]/' => 'Syntax error in (?[...]) in regex m/???(?[ \t ]/',
 '/(?[ \t + \e # ??? This was supposed to be a comment ])/' => 'Syntax error in (?[...]) in regex m/(?[ \t + \e # ??? This was supposed to be a comment ])/',
 'm/(*???)???/' => q<Unknown verb pattern '???' {#} m/(*???){#}???/>,
 '/\c???/' => "Character following \"\\c\" must be printable ASCII",
);
push @death, @death_utf8;

# Tests involving a user-defined charnames translator are in pat_advanced.t

# In the following arrays of warnings, the value can be an array of things to
# expect.  If the empty string, it means no warning should be raised.

##
## Key-value pairs of code/error of code that should have non-fatal regexp warnings.
##
my @warning = (
    'm/\b*/' => '\b* matches null string many times {#} m/\b*{#}/',
    'm/[:blank:]/' => 'POSIX syntax [: :] belongs inside character classes {#} m/[:blank:]{#}/',

    "m'[\\y]'"     => 'Unrecognized escape \y in character class passed through {#} m/[\y{#}]/',

    'm/[a-\d]/' => 'False [] range "a-\d" {#} m/[a-\d{#}]/',
    'm/[\w-x]/' => 'False [] range "\w-" {#} m/[\w-{#}x]/',
    'm/[a-\pM]/' => 'False [] range "a-\pM" {#} m/[a-\pM{#}]/',
    'm/[\pM-x]/' => 'False [] range "\pM-" {#} m/[\pM-{#}x]/',
    "m'\\y'"     => 'Unrecognized escape \y passed through {#} m/\y{#}/',
    '/x{3,1}/'   => 'Quantifier {n,m} with n > m can\'t match {#} m/x{3,1}{#}/',
    '/\08/' => '\'\08\' resolved to \'\o{0}8\' {#} m/\08{#}/',
    '/\018/' => '\'\018\' resolved to \'\o{1}8\' {#} m/\018{#}/',
    '/[\08]/' => '\'\08\' resolved to \'\o{0}8\' {#} m/[\08{#}]/',
    '/[\018]/' => '\'\018\' resolved to \'\o{1}8\' {#} m/[\018{#}]/',
    '/(?=a)*/' => '(?=a)* matches null string many times {#} m/(?=a)*{#}/',
    'my $x = \'\m\'; qr/a$x/' => 'Unrecognized escape \m passed through {#} m/a\m{#}/',
    '/\q/' => 'Unrecognized escape \q passed through {#} m/\q{#}/',
    '/\q{/' => 'Unrecognized escape \q{ passed through {#} m/\q{{#}/',
    '/(?=a){1,3}/' => 'Quantifier unexpected on zero-length expression {#} m/(?=a){1,3}{#}/',
    '/(a|b)(?=a){3}/' => 'Quantifier unexpected on zero-length expression {#} m/(a|b)(?=a){3}{#}/',
    '/\_/' => "",
    '/[\_\0]/' => "",
    '/[\07]/' => "",
    '/[\006]/' => "",
    '/[\0005]/' => "",
    '/[\8\9]/' => ['Unrecognized escape \8 in character class passed through {#} m/[\8{#}\9]/',
                   'Unrecognized escape \9 in character class passed through {#} m/[\8\9{#}]/',
                  ],
    '/[:alpha:]/' => 'POSIX syntax [: :] belongs inside character classes {#} m/[:alpha:]{#}/',
    '/[:zog:]/' => 'POSIX syntax [: :] belongs inside character classes {#} m/[:zog:]{#}/',
    '/[.zog.]/' => 'POSIX syntax [. .] belongs inside character classes {#} m/[.zog.]{#}/',
    '/[a-b]/' => "",
    '/[a-\d]/' => 'False [] range "a-\d" {#} m/[a-\d{#}]/',
    '/[\d-b]/' => 'False [] range "\d-" {#} m/[\d-{#}b]/',
    '/[\s-\d]/' => 'False [] range "\s-" {#} m/[\s-{#}\d]/',
    '/[\d-\s]/' => 'False [] range "\d-" {#} m/[\d-{#}\s]/',
    '/[a-[:digit:]]/' => 'False [] range "a-[:digit:]" {#} m/[a-[:digit:]{#}]/',
    '/[[:digit:]-b]/' => 'False [] range "[:digit:]-" {#} m/[[:digit:]-{#}b]/',
    '/[[:alpha:]-[:digit:]]/' => 'False [] range "[:alpha:]-" {#} m/[[:alpha:]-{#}[:digit:]]/',
    '/[[:digit:]-[:alpha:]]/' => 'False [] range "[:digit:]-" {#} m/[[:digit:]-{#}[:alpha:]]/',
    '/[a\zb]/' => 'Unrecognized escape \z in character class passed through {#} m/[a\z{#}b]/',
    '/(?c)/' => 'Useless (?c) - use /gc modifier {#} m/(?c{#})/',
    '/(?-c)/' => 'Useless (?-c) - don\'t use /gc modifier {#} m/(?-c{#})/',
    '/(?g)/' => 'Useless (?g) - use /g modifier {#} m/(?g{#})/',
    '/(?-g)/' => 'Useless (?-g) - don\'t use /g modifier {#} m/(?-g{#})/',
    '/(?o)/' => 'Useless (?o) - use /o modifier {#} m/(?o{#})/',
    '/(?-o)/' => 'Useless (?-o) - don\'t use /o modifier {#} m/(?-o{#})/',
    '/(?g-o)/' => [ 'Useless (?g) - use /g modifier {#} m/(?g{#}-o)/',
                    'Useless (?-o) - don\'t use /o modifier {#} m/(?g-o{#})/',
                  ],
    '/(?g-c)/' => [ 'Useless (?g) - use /g modifier {#} m/(?g{#}-c)/',
                    'Useless (?-c) - don\'t use /gc modifier {#} m/(?g-c{#})/',
                  ],
      # (?c) means (?g) error won't be thrown
     '/(?o-cg)/' => [ 'Useless (?o) - use /o modifier {#} m/(?o{#}-cg)/',
                      'Useless (?-c) - don\'t use /gc modifier {#} m/(?o-c{#}g)/',
                    ],
    '/(?ogc)/' => [ 'Useless (?o) - use /o modifier {#} m/(?o{#}gc)/',
                    'Useless (?g) - use /g modifier {#} m/(?og{#}c)/',
                    'Useless (?c) - use /gc modifier {#} m/(?ogc{#})/',
                  ],
    '/a{1,1}?/' => 'Useless use of greediness modifier \'?\' {#} m/a{1,1}?{#}/',
    '/b{3}  +/x' => 'Useless use of greediness modifier \'+\' {#} m/b{3}  +{#}/',
);

my @warnings_utf8 = mark_as_utf8(
    'm/???\b*???/' => '\b* matches null string many times {#} m/???\b*{#}???/',
    '/(?=???)*/' => '(?=???)* matches null string many times {#} m/(?=???)*{#}/',
    'm/???[:foo:]???/' => 'POSIX syntax [: :] belongs inside character classes {#} m/???[:foo:]{#}???/',
    "m'???[\\y]???'" => 'Unrecognized escape \y in character class passed through {#} m/???[\y{#}]???/',
    'm/???[???-\d]???/' => 'False [] range "???-\d" {#} m/???[???-\d{#}]???/',
    'm/???[\w-???]???/' => 'False [] range "\w-" {#} m/???[\w-{#}???]???/',
    'm/???[???-\pM]???/' => 'False [] range "???-\pM" {#} m/???[???-\pM{#}]???/',
    '/???[???-[:digit:]]???/' => 'False [] range "???-[:digit:]" {#} m/???[???-[:digit:]{#}]???/',
    '/???[\d-\s]???/' => 'False [] range "\d-" {#} m/???[\d-{#}\s]???/',
    '/???[a\zb]???/' => 'Unrecognized escape \z in character class passed through {#} m/???[a\z{#}b]???/',
    '/???(?c)???/' => 'Useless (?c) - use /gc modifier {#} m/???(?c{#})???/',    
    '/utf8 ??? (?ogc) ???/' => [
        'Useless (?o) - use /o modifier {#} m/utf8 ??? (?o{#}gc) ???/',
        'Useless (?g) - use /g modifier {#} m/utf8 ??? (?og{#}c) ???/',
        'Useless (?c) - use /gc modifier {#} m/utf8 ??? (?ogc{#}) ???/',
    ],

);

push @warning, @warnings_utf8;

my @experimental_regex_sets = (
    '/(?[ \t ])/' => 'The regex_sets feature is experimental {#} m/(?[{#} \t ])/',
    'use utf8; /utf8 ??? (?[ [\t???] ])/' => do { use utf8; 'The regex_sets feature is experimental {#} m/utf8 ??? (?[{#} [\t???] ])/' },
    '/noutf8 ??? (?[ [\t???] ])/' => 'The regex_sets feature is experimental {#} m/noutf8 ??? (?[{#} [\t???] ])/',
);

my @deprecated = (
    "/(?x)latin1\\\x{85}\x{85}\\\x{85}/" => 'Escape literal pattern white space under /x {#} ' . "m/(?x)latin1\\\x{85}\x{85}{#}\\\x{85}/",
    'use utf8; /(?x)utf8\????\??/' => 'Escape literal pattern white space under /x {#} ' . "m/(?x)utf8\\\N{NEXT LINE}\N{NEXT LINE}{#}\\\N{NEXT LINE}/",
    '/((?# This is a comment in the middle of a token)?:foo)/' => 'In \'(?...)\', splitting the initial \'(?\' is deprecated {#} m/((?# This is a comment in the middle of a token)?{#}:foo)/',
    '/((?# This is a comment in the middle of a token)*FAIL)/' => 'In \'(*VERB...)\', splitting the initial \'(*\' is deprecated {#} m/((?# This is a comment in the middle of a token)*{#}FAIL)/',
);

while (my ($regex, $expect) = splice @death, 0, 2) {
    my $expect = fixup_expect($expect);
    no warnings 'experimental::regex_sets';
    # skip the utf8 test on EBCDIC since they do not die
    next if $::IS_EBCDIC && $regex =~ /utf8/;

    warning_is(sub {
		   $_ = "x";
		   eval $regex;
		   like($@, qr/\Q$expect/, $regex);
	       }, undef, "... and died without any other warnings");
}

foreach my $ref (\@warning, \@experimental_regex_sets, \@deprecated) {
    my $warning_type = ($ref == \@warning)
                       ? 'regexp'
                       : ($ref == \@deprecated)
                         ? 'regexp, deprecated'
                         : 'experimental::regex_sets';
    while (my ($regex, $expect) = splice @$ref, 0, 2) {
        my @expect = fixup_expect($expect);
        {
            $_ = "x";
            no warnings;
            eval $regex;
        }
        if (is($@, "", "$regex did not die")) {
            my @got = capture_warnings(sub {
                                    $_ = "x";
                                    eval $regex });
            my $count = @expect;
            if (! is(scalar @got, scalar @expect, "... and gave expected number ($count) of warnings")) {
                if (@got < @expect) {
                    $count = @got;
                    note "Expected warnings not gotten:\n\t" . join "\n\t", @expect[$count .. $#expect];
                }
                else {
                    note "Unexpected warnings gotten:\n\t" . join("\n\t", @got[$count .. $#got]);
                }
            }
            foreach my $i (0 .. $count - 1) {
                if (! like($got[$i], qr/\Q$expect[$i]/, "... and gave expected warning")) {
                    chomp($got[$i]);
                    chomp($expect[$i]);
                    diag("GOT\n'$got[$i]'\nEXPECT\n'$expect[$i]'");
                }
                else {
                    ok (0 == capture_warnings(sub {
                                    $_ = "x";
                                    eval "no warnings '$warning_type'; $regex;" }
                                ),
                    "... and turning off '$warning_type' warnings suppressed it");
                    # Test that whether the warning is on by default is
                    # correct.  Experimental and deprecated warnings are;
                    # others are not.  This test relies on the fact that we
                    # are outside the scope of any ???use warnings???.
                    local $^W;
                    my $on = 'on' x ($warning_type ne 'regexp');
                    ok !!$on ==
                        capture_warnings(sub { $_ = "x"; eval $regex }),
                      "... and the warning is " . ($on||'off')
                       . " by default";
                }
            }
        }
    }
}

done_testing();
