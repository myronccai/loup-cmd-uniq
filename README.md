# loup-cmd-uniq

GNU `uniq` recreated in [Loup](https://code-craft.ai/references/loup): report
or omit repeated adjacent lines, with counts, `-d`/`-u`/`-D`, grouping,
field and character skipping, case folding, and GNU's messages, in a single
pass over the input.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                                     # native binary: build/uniq
make ci                                        # check, unit tests, build, end-to-end tests
make run ARGS="-c tests/fixtures/fruit.txt"    # run from source with loup run
```

```text
$ cat tests/fixtures/fruit.txt
apple
apple
banana
cherry
cherry
cherry
apple
date
$ build/uniq tests/fixtures/fruit.txt
apple
banana
cherry
apple
date
$ build/uniq -c tests/fixtures/fruit.txt
      2 apple
      1 banana
      3 cherry
      1 apple
      1 date
$ build/uniq -d tests/fixtures/fruit.txt
apple
cherry
$ build/uniq -u tests/fixtures/fruit.txt
banana
apple
date
$ build/uniq --all-repeated=separate tests/fixtures/fruit.txt
apple
apple

cherry
cherry
cherry
$ build/uniq -f 1 -i -c tests/fixtures/log.txt
      2 10:01 alice login
      2 10:02 bob login
      2 10:07 carol logout
$ sort tests/fixtures/fruit.txt | build/uniq -c
      3 apple
      1 banana
      3 cherry
      1 date
$ build/uniq -D -c tests/fixtures/fruit.txt; echo "exit $?"
uniq: printing all duplicated lines and repeat counts is meaningless
Try 'uniq --help' for more information.
exit 1
$ build/uniq -f x tests/fixtures/fruit.txt; echo "exit $?"
uniq: x: invalid number of fields to skip
exit 1
$ build/uniq missing.txt; echo "exit $?"
uniq: missing.txt: No such file or directory
exit 1
$ build/uniq --version
uniq (loup-cmd-uniq) 0.1.0
```

`uniq [OPTION]... [INPUT [OUTPUT]]` reads INPUT (standard input if it is
missing or `-`) and writes OUTPUT (standard output if it is missing or
`-`), which it creates or replaces. Options:

| Option | Meaning |
|---|---|
| `-c`, `--count` | prefix each line with its number of occurrences |
| `-d`, `--repeated` | print only repeated lines, one for each group |
| `-u`, `--unique` | print only lines that are not repeated |
| `-D` | print every line of each group of repeated lines |
| `--all-repeated[=METHOD]` | like `-D`; METHOD `none` (default), `prepend` or `separate` adds an empty line before each group or between groups |
| `--group[=METHOD]` | print every line, with an empty line `separate` (default), `prepend`, `append` or `both` around groups |
| `-f N`, `--skip-fields=N` | do not compare the first N fields (a field is blanks, then non-blanks) |
| `-s N`, `--skip-chars=N` | do not compare the first N characters, after the fields |
| `-w N`, `--check-chars=N` | compare at most N characters |
| `-i`, `--ignore-case` | ignore the case of ASCII letters when comparing |
| `-z`, `--zero-terminated` | lines end with NUL, not newline |
| `--help`, `--version` | print help or the version and exit |

As in GNU uniq, options and files may come in any order, short options may
be combined (`-dc`), long ones and METHODs shortened (`--all-rep=sep`), and
the obsolete forms `-N` (`-f N`) and `+N` (`-s N`) still work. Only
adjacent lines are compared: sort the input first to count all
occurrences. The last line is printed with a newline even if it had none.

Exit status: `0` on success; `1` on a usage error, a bad count, or a file
that cannot be read or written, as in GNU uniq.

## Differences from the original

- `-w N` compares N characters. GNU uniq 9.5 in a UTF-8 locale measures N
  times the length of the line's first character instead, so it compares
  too much after a multibyte first character (`éaX` and `éaY` differ with
  `-w 2`) and splits characters after an ASCII one (`aéX` and `aèX` match
  with `-w 2`). On ASCII text, and for `-f`, `-s`, `-i` and blanks, the
  output is GNU's in a UTF-8 locale: `-s` counts characters, `-i` folds
  ASCII letters only, and fields are separated by the blanks glibc knows
  (TAB, space, U+1680, U+2000–U+2006, U+2008–U+200A, U+205F, U+3000).
- The input is read whole before any output (Loup 1.26.0 has no streaming
  reader), so `uniq` cannot work on an endless stream.
- An INPUT that exists but cannot be read (for example, permission denied)
  stops the program with Loup's own `IoError` message and status 1: the
  Loup 1.26.0 native runtime does not let the program catch that error.
  Missing files and directories are checked beforehand and reported as GNU
  does.
- Write errors on standard output (a full disk, `> /dev/full`) are not
  reported; GNU prints `uniq: write error: ...` and exits with 1.
- `POSIXLY_CORRECT` and `_POSIX2_VERSION` are ignored: `+N` always means
  `-s N` before `--`.
- Messages use the C locale's quotes (`'x'`, not `‘x’`); file names are
  quoted as GNU quotes them.
- `--version` prints a single line; `--help` omits GNU's links to its
  online documentation.
- An OUTPUT operand and output that is not UTF-8 use C functions through
  Loup's FFI, which only the native build can call: under `make run` (the
  `loup run` interpreter) they stop the program.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/getopt.loup        # GNU getopt_long work-alike, with getopt's three orderings
source/cli/argmatch.loup      # METHOD values: prefixes, gnulib's messages
source/cli/numbers.loup       # counts for -f, -s, -w, and +N
source/cli/args.loup          # uniq's options, operands and cross-checks
source/cli/quote.loup         # GNU-style quoting of values and file names
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, dispatch, exit status
source/commands/fields.loup   # the compared part of a line; the comparison
source/commands/output.loup   # counts, UTF-8 check, writing, OUTPUT redirection
source/commands/uniq.loup     # the state machine over lines; files and errors
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/uniq (make e2e)
tests/fixtures/               # input files for the examples and tests
specs/uniq/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
