# AGENTS.md

This repository recreates GNU `uniq` in the Loup programming language, as
part of the loup-cmd series of example applications. The program is
`host.dual` Loup built as a native executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── getopt.loup          # scan_options(): GNU getopt_long rules, three orderings, messages
│   │   ├── argmatch.loup        # argmatch(), argmatch_error(): METHOD values
│   │   ├── numbers.loup         # parse_size(), parse_plus(): counts for -f, -s, -w, +N
│   │   ├── args.loup            # class Options, parse_args(): options, operands, cross-checks
│   │   ├── quote.loup           # quote(), quote_name(), quote_always(): GNU-style quoting
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, run_uniq, exit status
│   └── commands/
│       ├── fields.loup          # char_len(), key_start(), key_end(), different()
│       ├── output.loup          # append_count(), flush_bytes(), redirect_stdout()
│       └── uniq.loup            # class Uniq (the state machine), uniq_bytes(), run_uniq()
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── e2e.sh                   # end-to-end tests of the native binary
│   └── fixtures/                # input files for the examples and e2e.sh
├── specs/uniq/                  # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-c tests/fixtures/fruit.txt"` | `loup run source/main.loup -- ARGS`; an OUTPUT operand and output that is not UTF-8 need the native build |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, one at a time |
| Run matching tests | `make test TEST_ARGS="--filter group"` | tests whose name contains `group` |
| Run one test file | `make test TEST_ARGS="--file tests/args_test.loup"` | |
| Build | `make build` | native binary at `build/uniq` |
| Run the binary | `build/uniq --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/uniq`: output compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/uniq --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/uniq/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/uniq/tasks.md`.

Keep behaviour in pure functions that return values (`uniq_bytes` returns
the whole output for an input, `parse_args` the options or the message) so
unit tests can check it; only `run_uniq` reads and writes.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Records shared between modules are classes (`Options`, `Uniq`), and the
  few structs (in `getopt.loup`) have field names used nowhere else: the
  native build lays out struct fields by name across the whole program.
- Work on the input as bytes and byte ranges, and do not allocate per line:
  the native runtime never frees what a loop allocates. Reuse one output
  list and empty it with `pop()` (`list.clear()` and `list.is_empty()` fail
  native codegen).
- The native runtime does not let a program catch the `IoError` from
  `readBytes`, so `run_uniq` checks `exists` and `io.fs.isDir` first.
- GNU uniq is installed here as `gnuuniq` (plain `uniq` may be uutils);
  compare behaviour with it, but write expected output into
  `tests/e2e.sh`. Its character handling depends on the locale: compare in
  a UTF-8 locale, and use `LC_ALL=C` only to see its ASCII quotes.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
