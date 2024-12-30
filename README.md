# APT Deb822 Tool

This is a bash implementation of a parser for APT entries in ["One-Line-Style Format"][docs-olsf] (.list file) as well as entries in ["Deb822-style Format"][docs-deb822] (.sources file).
The tool allows to convert between both formats back and forth.

## Features

- Conversion from One-Line-Style format to Deb822 format and vice versa
- Read a whole directory (like `/etc/apt/sources.list.d`) and operate only on files with the right extension
- Create backup files of the originals

## Installation

1. Clone this repository to a location of your choice
2. Run `make install` or copy the file from the `src` directory somewhere and make it executable

## Usage

Use `apt-deb822-tool` in your terminal.

There are two modes: `to-deb822` and `to-list`.
It is mandatory to specify one of these modes as an argument.

You can specify an arbitrary amount of files and/or directories afterwards.
Directories will be walked through recursively while only files with a matching file extension will be used (unless `--all-extensions` is given as an option).

The conversion result is output on STDOUT unless the option `--write` is given.
In latter case, the result will be written to a file with the right extension next to the source file.
Output on STDOUT for multiple input files is delimited by a NULL byte, so further processing with tools like `xargs` is possible.

You can enable verbose output mode by adding the `--verbose` option.
Verbose output is written to STDERR.

Use the `--help` option for more information.

## Dependencies

This tool only requires basic system dependencies (`coreutils`, `findutils`) that should be installed on every Debian and Ubuntu out of the box.
The minimum bash version required is 5.0.

## Known limitations

- Embedded PGP public keys in the `Signed-By` field in Deb822 format are not supported yet

## Development

To run the tests, install [`bats-core`][git-bats-core] and [`bats-file`][git-bats-file], and run `make test`.

[docs-olsf]: https://manpages.debian.org/bookworm/apt/sources.list.5.en.html#ONE-LINE-STYLE_FORMAT
[docs-deb822]: https://manpages.debian.org/bookworm/apt/sources.list.5.en.html#DEB822-STYLE_FORMAT
[git-bats-core]: https://github.com/bats-core/bats-core
[git-bats-file]: https://github.com/bats-core/bats-file
