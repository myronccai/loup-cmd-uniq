#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones, and for errors
# its standard error.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$1
FIX=tests/fixtures
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... as check_file does and compares standard error.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want_err"
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want_err" "$TMP/err"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    /' | head -10
    fi
}

TRY=$'\nTry \'uniq --help\' for more information.\n'
FRUIT="$FIX/fruit.txt"
LOG="$FIX/log.txt"

# Which lines are printed.
check "merge adjacent"          0 $'apple\nbanana\ncherry\napple\ndate\n'          "$FRUIT"
check "-c"                      0 $'      2 apple\n      1 banana\n      3 cherry\n      1 apple\n      1 date\n' -c "$FRUIT"
check "-d"                      0 $'apple\ncherry\n'                               -d "$FRUIT"
check "-u"                      0 $'banana\napple\ndate\n'                         -u "$FRUIT"
check "-D"                      0 $'apple\napple\ncherry\ncherry\ncherry\n'        -D "$FRUIT"
check "-dc"                     0 $'      2 apple\n      3 cherry\n'               -dc "$FRUIT"
check "-du prints nothing"      0 ''                                               -du "$FRUIT"
check "-Du"                     0 $'apple\ncherry\ncherry\n'                       -Du "$FRUIT"
check "long options"            0 $'      2 apple\n      3 cherry\n'               --count --repeated "$FRUIT"
check "--unique"                0 $'banana\napple\ndate\n'                         --unique "$FRUIT"
check "--all-repeated"          0 $'apple\napple\ncherry\ncherry\ncherry\n'        --all-repeated "$FRUIT"
check "--all-repeated=none"     0 $'apple\napple\ncherry\ncherry\ncherry\n'        --all-repeated=none "$FRUIT"
check "--all-repeated=prepend"  0 $'\napple\napple\n\ncherry\ncherry\ncherry\n'    --all-repeated=prepend "$FRUIT"
check "--all-repeated=separate" 0 $'apple\napple\n\ncherry\ncherry\ncherry\n'      --all-repeated=separate "$FRUIT"
check "method abbreviated"      0 $'apple\napple\n\ncherry\ncherry\ncherry\n'      --all-repeated=s "$FRUIT"
check "--group"                 0 $'apple\napple\n\nbanana\n\ncherry\ncherry\ncherry\n\napple\n\ndate\n' --group "$FRUIT"
IN=<(printf 'a\na\nb\n') check "--group=prepend" 0 $'\na\na\n\nb\n'              --group=prepend
IN=<(printf 'a\na\nb\n') check "--group=append"  0 $'a\na\n\nb\n\n'              --group=append
IN=<(printf 'a\na\nb\n') check "--group=both"    0 $'\na\na\n\nb\n\n'            --group=both
IN=<(printf '') check "--group, empty input"     0 ''                             --group=both

# What is compared.
check "-f 1"                    0 $'10:01 alice login\n10:02 bob login\n10:05 Bob login\n10:07 carol logout\n' -f 1 "$LOG"
check "-f 1 -i -c"              0 $'      2 10:01 alice login\n      2 10:02 bob login\n      2 10:07 carol logout\n' -f 1 -i -c "$LOG"
check "-f 2"                    0 $'      4 10:01 alice login\n      2 10:07 carol logout\n' -f2 -c "$LOG"
check "-s 6"                    0 $'      2 10:01 alice login\n      1 10:02 bob login\n      1 10:05 Bob login\n      2 10:07 carol logout\n' -s 6 -c "$LOG"
check "-s 3 -w 2"               0 $'      1 10:01 alice login\n      2 10:02 alice login\n      1 10:05 Bob login\n      1 10:07 carol logout\n      1 10:09 carol logout\n' -s 3 -w2 -c "$LOG"
check "-d -f 1 -i"              0 $'10:01 alice login\n10:02 bob login\n10:07 carol logout\n' -d -f 1 -i "$LOG"
IN=<(printf 'x a 1\ny a 1\ny b 1\nz b 2\n') check "-f then -s" 0 $'x a 1\nz b 2\n'   -f1 -s2
IN=<(printf 'a b\na\tc\n') check "blanks before a field count" 0 $'a b\na\tc\n'   -f 1
IN=<(printf '  a\n\tb\n') check "leading blanks"    0 $'  a\n'                    -f 1
IN=<(printf 'abc\nabd\n') check "-w 0 compares nothing" 0 $'abc\n'                -w 0
IN=<(printf 'a\nb\n') check "-f past the end"       0 $'a\n'                      -f 99999999999999999999
IN=<(printf 'A\na\nb\n') check "-i"                 0 $'A\nb\n'                   -i
IN=<(printf 'x a\ny a\n') check "obsolete -N"       0 $'x a\n'                    -1
IN=<(printf 'x y z a\nq r s a\n') check "-1 -2 is 12 fields" 0 $'x y z a\n'       -1 -2
IN=<(printf 'xa\nya\n') check "obsolete +N"         0 $'xa\n'                     +1
IN=<(printf 'xa\nya\n') check "+N after --" 1 ''                                  -- +1

# Characters.
IN=<(printf 'éa\nèa\n') check "-s counts characters" 0 $'éa\n'                    -s 1
IN=<(printf 'aéX\naèX\n') check "-w counts characters" 0 $'aéX\naèX\n'            -w 2
IN=<(printf 'éaX\néaY\n') check "-w with a multibyte start" 0 $'éaX\n'            -w 2
IN=<(printf 'a\343\200\200x\na\343\200\200y\n') check "U+3000 is a blank" 0 $'a\343\200\200x\na\343\200\200y\n' -f 1
IN=<(printf 'a\302\240x\nb\302\240y\n') check "U+00A0 is not" 0 $'a\302\240x\n'  -f 1
IN=<(printf 'É\né\n') check "-i folds ASCII only"   0 $'É\né\n'                   -i

# Lines and bytes.
IN=<(printf 'a\na') check "final newline added"   0 $'a\n'
IN=<(printf '') check "empty input"               0 ''                            -c
IN=<(printf '\n\n\nx\n') check "empty lines"      0 $'      3 \n      1 x\n'       -c
printf 'a\0a\0b' > "$TMP/z_in"
printf 'a\0b\0' > "$TMP/z_want"
check_file "-z"                 0 "$TMP/z_want"                                    -z "$TMP/z_in"
printf 'a\nb\0a\nb\0c' > "$TMP/z2_in"
printf '      2 a\nb\0      1 c\0' > "$TMP/z2_want"
check_file "-z keeps newlines"  0 "$TMP/z2_want"                                   -zc "$TMP/z2_in"
printf 'x\377y\nx\377y\nz\342\202\n' > "$TMP/raw_in"
printf 'x\377y\nz\342\202\n' > "$TMP/raw_want"
check_file "bytes that are not UTF-8" 0 "$TMP/raw_want"                            "$TMP/raw_in"
seq 1 30000 | sed 'p' > "$TMP/big_in"
seq 1 30000 > "$TMP/big_want"
check_file "output past 64 KiB"  0 "$TMP/big_want"                                 "$TMP/big_in"

# Files.
IN="$FRUIT" check "standard input"  0 $'apple\nbanana\ncherry\napple\ndate\n'
IN="$FRUIT" check "- is standard input" 0 $'apple\ncherry\n'                       -d -
check "options after files"     0 $'apple\ncherry\n'                               "$FRUIT" -d
check "OUTPUT operand"          0 ''                                               -d "$FRUIT" "$TMP/out.txt"
cmp -s "$TMP/out.txt" <(printf 'apple\ncherry\n') && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: OUTPUT contents"; }
printf 'old contents, longer than the new ones\n' > "$TMP/out2.txt"
check "OUTPUT replaced"         0 ''                                               -u "$FRUIT" "$TMP/out2.txt"
cmp -s "$TMP/out2.txt" <(printf 'banana\napple\ndate\n') && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: OUTPUT replaced contents"; }
IN="$FRUIT" check "- to OUTPUT" 0 ''                                               -c - "$TMP/out3.txt"
cmp -s "$TMP/out3.txt" <(printf '      2 apple\n      1 banana\n      3 cherry\n      1 apple\n      1 date\n') && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: - to OUTPUT contents"; }
cp "$FRUIT" "$TMP/same.txt"
check "INPUT as OUTPUT empties it" 0 ''                                            "$TMP/same.txt" "$TMP/same.txt"
[ ! -s "$TMP/same.txt" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: INPUT as OUTPUT"; }

# File errors.
mkdir -p "$TMP/dir" "$TMP/it's"
check_err "missing input"       1 $'uniq: nope.txt: No such file or directory\n'  nope.txt "$TMP/never.txt"
[ ! -e "$TMP/never.txt" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: OUTPUT created for a missing INPUT"; }
check_err "quoted input name"   1 $'uniq: \'a b\': No such file or directory\n'   'a b'
check_err "input is a directory" 1 "uniq: error reading '$TMP/dir': Is a directory"$'\n' "$TMP/dir"
check_err "quoted directory"    1 "uniq: error reading \"$TMP/it's\": Is a directory"$'\n' "$TMP/it's"
IN="$TMP/dir" check_err "stdin is a directory" 1 $'uniq: error reading \'-\': Is a directory\n'
check_err "OUTPUT in a missing directory" 1 $'uniq: /nonexistent/x: No such file or directory\nuniq: write error: No such file or directory\n' "$FRUIT" /nonexistent/x
check_err "OUTPUT is a directory" 1 "uniq: $TMP/dir: Is a directory"$'\nuniq: write error: Is a directory\n' "$FRUIT" "$TMP/dir"
check_err "OUTPUT under a file" 1 "uniq: $FRUIT/x: Not a directory"$'\nuniq: write error: Not a directory\n' "$FRUIT" "$FRUIT/x"

# Usage errors.
check_err "extra operand"       1 "uniq: extra operand 'c'$TRY"                    a b c
check_err "extra operand first" 1 "uniq: extra operand 'c'$TRY"                    a b c -q
check_err "invalid option"      1 "uniq: invalid option -- 'q'$TRY"                -q
check_err "unknown long"        1 "uniq: unrecognized option '--nope'$TRY"         --nope
check_err "ambiguous long"      1 "uniq: option '--skip' is ambiguous; possibilities: '--skip-fields' '--skip-chars'$TRY" --skip 1
check_err "no argument allowed" 1 "uniq: option '--count' doesn't allow an argument$TRY" --count=1
check_err "missing value"       1 "uniq: option requires an argument -- 'f'$TRY"   -f
check_err "--group with -c"     1 "uniq: --group is mutually exclusive with -c/-d/-D/-u$TRY" --group -c
check_err "-D with -c"          1 "uniq: printing all duplicated lines and repeat counts is meaningless$TRY" -Dc
check_err "bad method"          1 "uniq: invalid argument 'x' for '--all-repeated'"$'\nValid arguments are:\n  - \'none\'\n  - \'prepend\'\n  - \'separate\''"$TRY" --all-repeated=x
check_err "ambiguous method"    1 "uniq: ambiguous argument '' for '--group'"$'\nValid arguments are:\n  - \'prepend\'\n  - \'append\'\n  - \'separate\'\n  - \'both\''"$TRY" --group=

# Bad counts: a message, no "Try" line.
check_err "-f x"                1 $'uniq: x: invalid number of fields to skip\n'   -f x
check_err "-s -1"               1 $'uniq: -1: invalid number of bytes to skip\n'   -s -1
check_err "-w with a suffix"    1 $'uniq: 1 : invalid number of bytes to compare\n' -w '1 '
check_err "bad count first"     1 $'uniq: x: invalid number of fields to skip\n'   -f x -q

# Help and version.
check "version"                 0 $'uniq (loup-cmd-uniq) 0.1.0\n'                  --version
check "help wins"               0 "$("$BIN" --help)"$'\n'                           --help -q
"$BIN" --help | head -1 | grep -q '^Usage: uniq \[OPTION\]... \[INPUT \[OUTPUT\]\]' && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: help text"; }

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
