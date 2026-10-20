# Requirements: uniq

## Introduction

`uniq` copies its input to its output, merging each run of adjacent
matching lines into one, or reporting only the repeated or only the unique
lines. Options choose what is compared (skipping fields or characters,
limiting the length, ignoring case) and how the result is shown (counts,
every repeated line, empty lines between groups). This repository recreates
GNU coreutils `uniq` in Loup, with its option grammar, messages and exit
statuses. Shell users combine it with `sort` to count or deduplicate lines.

## Requirements

### Requirement 1: Merging and selecting lines

**User Story:** As a shell user, I want to merge, count or pick out runs of
repeated lines so that I can summarise sorted data.

#### Acceptance Criteria

1. WHEN no selection option is given, THE program SHALL print the first
   line of each run of adjacent matching lines.
2. WHEN `-c` is given, THE program SHALL prefix each printed line with the
   number of lines in its run, right-aligned in 7 columns and followed by a
   space.
3. WHEN `-d` is given, THE program SHALL print only runs of two or more
   lines; WHEN `-u` is given, only runs of one line; WHEN both are given,
   nothing.
4. WHEN `-D` or `--all-repeated[=METHOD]` is given, THE program SHALL print
   every line of each run of two or more lines, with an empty line before
   each run (`prepend`) or between runs (`separate`) if asked.
5. WHEN `--group[=METHOD]` is given, THE program SHALL print every line,
   with an empty line between runs (`separate`, the default), before each
   (`prepend`), after each (`append`) or both.

### Requirement 2: What is compared

**User Story:** As a shell user, I want to compare only part of each line
so that lines that differ in a prefix or in case still match.

#### Acceptance Criteria

1. WHEN `-f N` is given, THE program SHALL ignore the first N fields, a
   field being a run of blanks followed by a run of non-blanks.
2. WHEN `-s N` is given, THE program SHALL then ignore N more characters.
3. WHEN `-w N` is given, THE program SHALL compare at most N characters.
4. WHEN `-i` is given, THE program SHALL compare ASCII letters without
   regard to case.
5. THE program SHALL count characters as UTF-8 characters (any byte that is
   not part of one counts as one) and treat as blanks the characters glibc
   classes as blank in a UTF-8 locale.

### Requirement 3: Input and output

**User Story:** As a script author, I want uniq to read and write files
like GNU uniq so that it fits in scripts and pipelines.

#### Acceptance Criteria

1. THE program SHALL read the INPUT operand, or standard input when it is
   missing or `-`, and write the OUTPUT operand, created or replaced, or
   standard output when it is missing or `-`.
2. THE program SHALL end every output line with the line terminator,
   adding one after a last line that lacks it.
3. WHEN `-z` is given, THE program SHALL use NUL instead of newline as the
   line terminator for input, output and group separators.
4. THE program SHALL pass bytes that are not UTF-8 through unchanged.
5. WHEN INPUT does not exist or is a directory, or OUTPUT cannot be
   created, THE program SHALL print GNU uniq's message and exit with
   status 1.

### Requirement 4: Command line

**User Story:** As a script author, I want uniq's options and errors to
match GNU uniq so that it can replace it.

#### Acceptance Criteria

1. THE program SHALL accept options and operands in any order, short
   options combined, long options and METHOD values as unambiguous
   prefixes, and the obsolete `-N` (skip N fields) and `+N` (skip N
   characters).
2. WHEN a third operand, an unknown option, a bad METHOD, or a conflicting
   combination (`--group` with `-c`/`-d`/`-D`/`-u`, `-D` with `-c`) is
   given, THE program SHALL print GNU uniq's message and the "Try" line and
   exit with status 1, reporting the first problem in command-line order.
3. WHEN a count for `-f`, `-s` or `-w` is not a number of at least 0, THE
   program SHALL print `uniq: N: invalid number of ...` and exit with
   status 1.
4. THE program SHALL exit with status 0 after processing its input.
