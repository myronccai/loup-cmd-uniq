# Design: uniq

## Overview

`main()` passes `runtime.args()` to `cli.app.run`. `run` parses the command
line into `Options` (`cli.args`), handles `--help`, `--version` and bad
counts, and calls `commands.uniq.run_uniq`. `run_uniq` checks the files,
redirects standard output to OUTPUT if one is given, reads INPUT whole and
feeds its lines, as byte ranges, to a `Uniq` state machine, writing the
output a chunk at a time.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (GNU uniq uses 1 for every error) |
| `source/cli/getopt.loup` | `OptSpec`, `OptHit`, `Scan`, `scan_options(argv, specs, ordering)`: a GNU `getopt_long` work-alike with PERMUTE, REQUIRE_ORDER and RETURN_IN_ORDER, optional values, and the hits before an error |
| `source/cli/argmatch.loup` | `argmatch`, `argmatch_error`: gnulib's matching of METHOD values and its message |
| `source/cli/numbers.loup` | `parse_size` (gnulib's `xstrtoimax` rules, clamped), `parse_plus` |
| `source/cli/args.loup` | `class Options`, `parse_args`: uniq's options in command-line order, operands, cross-checks |
| `source/cli/quote.loup` | `quote` (C locale), `quote_name` (quotef), `quote_always` (quoteaf) |
| `source/cli/usage.loup` | `usage()` help text, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, bad counts, run, exit status |
| `source/commands/fields.loup` | `char_len`, `is_blank_at`, `key_start`, `key_end`, `different` |
| `source/commands/output.loup` | `append_count`, `is_utf8`, `flush_bytes`, `redirect_stdout` |
| `source/commands/uniq.loup` | `class Uniq`, `uniq_into`, `uniq_bytes`, `run_uniq` |

### Command line

GNU uniq calls getopt with the optstring `-0123456789Dcdf:is:uw:z`, whose
leading `-` makes getopt return operands in order among the options. So
`scan_options` runs in RETURN_IN_ORDER mode and `parse_args` walks the hits
as GNU's loop does: an operand is `+N` (skip N characters) if it parses as
one, else the next file (a third is "extra operand"); digit options
accumulate into the field count until a `-f` starts over; a bad count stops
with "N: invalid number of ..." (`Options.problem`, no "Try" line); a bad
METHOD stops with argmatch's message. Errors are reported in command-line
order: the scan keeps the hits before a getopt error, and those are acted on
first. Operands after `--` are always files. The cross-checks (`--group`
with an output option, `-D` with `-c`) come last.

### Comparing lines

A line is a byte range of the input without its terminator. `key_start`
skips `-f` fields (blanks, then non-blanks) and `-s` characters;
`key_end` takes at most `-w` characters from there. Both step one character
at a time with `char_len`: a well-formed UTF-8 sequence, else one byte.
Blanks are TAB, space and the Unicode blanks of glibc's `iswblank` in a
UTF-8 locale, plus newline (which matters with `-z`). `different` compares
the two byte ranges, folding ASCII letters with `-i`, like GNU's
`memcmp`/`memcasecmp`. Nothing here allocates: in a native build every
allocation in a loop stays allocated.

### The state machine

`Uniq` is GNU's `check_file`. With neither `-c`, `-d`, `-u` nor `-D` (the
"simple" case, including `--group`), each line that starts a new group is
printed at once, with the group separators. Otherwise the previous line is
held until the next one shows whether it matched: `write_prev` (GNU's
`writeline`) prints it if the options want lines of that kind (unique,
first of a group, later in a group), with its count; `--all-repeated`
separators are written when a group's second line arrives.

### Output

Output bytes collect in one list. `uniq_into` writes it out and empties it
(with `pop`, since `clear()` has no native lowering and a new list per
chunk would never be freed) whenever it passes 64 KiB. `flush_bytes` prints
a chunk as a string when it is well-formed UTF-8, and otherwise byte by byte
through C's `putchar`. For an OUTPUT operand, `redirect_stdout` opens the
file with C's `open` (create, truncate) and `dup2`s it onto descriptor 1,
as GNU's `freopen` does, so all output paths write to it.

## Error handling

In GNU's order:

1. INPUT missing: `uniq: NAME: No such file or directory`, status 1, OUTPUT
   untouched.
2. OUTPUT cannot be opened: `uniq: NAME: REASON` and
   `uniq: write error: REASON` (GNU's close_stdout adds the second line),
   status 1. The reason is worked out from the path, since errno is not
   available: a directory, a missing parent, a parent that is not a
   directory, else permission denied.
3. INPUT is a directory: `uniq: error reading 'NAME': Is a directory`,
   status 1 (OUTPUT has been truncated, as with GNU).

The native runtime cannot catch a failed read, so these are checked before
reading; an unreadable file still stops the program with Loup's `IoError`.

## Differences from GNU uniq

- `-w N` compares N characters; GNU 9.5 in a UTF-8 locale advances N times
  the length of the first character of the compared part.
- Input is read whole, so endless streams are not supported.
- An unreadable INPUT stops the program with Loup's `IoError` message.
- Write errors on standard output are not reported.
- `POSIXLY_CORRECT` and `_POSIX2_VERSION` are ignored.
- Messages use the C locale's quotes; `--version` prints one line and
  `--help` has no links.
- OUTPUT and non-UTF-8 output need the native build (C functions).

## Testing

- Unit tests (`make test`, Stage0): getopt orderings and messages,
  argmatch, count parsing, quoting, option and operand handling with every
  error, character and field scanning, the comparison, count formatting,
  and `uniq_bytes` for every mode.
- End-to-end tests (`tests/e2e.sh`, the native binary): every option and
  METHOD, obsolete forms, UTF-8 characters and blanks, NUL-terminated lines
  and raw bytes (expected files written with `printf`), output larger than
  one chunk, INPUT and OUTPUT operands including INPUT as OUTPUT, every file
  error, usage error and bad count, help and version. The expected outputs
  were checked against GNU uniq 9.5 (in a UTF-8 locale for characters, in
  the C locale for quotes).
