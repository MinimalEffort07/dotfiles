# dotfiles

Personal dotfiles for Linux (apt, i3) and macOS (brew). `install.sh` installs
packages, links configuration out of this repository into `$HOME`, and builds the
language servers that ship no usable binaries. `nvim/` is the neovim
configuration those language servers are for.

`install.sh install` sets a machine up. `install.sh clean` takes it back off.
`--headless` skips the linux desktop only steps.

## Requirements

These are the properties the script is expected to hold. Breaking one of them is
a bug even when the change works on the machine it was written on.

### Idempotent

Running `install.sh` twice in a row must leave the machine in the same state as
running it once, do no work the second time, and print why each step was
skipped. Every step therefore checks for its own end state first, and the check
is for that end state and not for a proxy:

- Version, not existence, wherever a version is pinned. A `zls` binary sitting in
  the pinned output directory is only the pinned build if it says so — otherwise
  it is a leftover to be rebuilt.
- A downloaded artifact is checked before the download, so a re-run neither
  re-fetches it nor re-verifies a tarball that is no longer on disk.
- Nothing may prompt on a re-run. `chsh` authenticates even when the shell is
  already the one asked for, which is why `login_shell` is compared first; the
  same care applies to anything else that authenticates.

A step that cannot reach its end state warns and lets the rest continue.
`exit 1` is for cases where continuing would build on something broken.

### Non destructive

The machine has state that predates the script, and none of it is the script's
to throw away.

- A real file in the way of a symlink is backed up with `--backup=numbered`
  before it is replaced, and a file that could not be backed up is never
  deleted.
- A configuration value that is already set to something other than ours is
  reported and left (`set_git_config`).
- A git checkout under `~/repos` belongs to whoever cloned it. Do not move its
  HEAD, and do not overwrite what it has built. A pinned build gets a `git
  worktree` of its own instead (`add_worktree`), which shares the object store
  and leaves the original checkout on its own branch with its own build output
  intact.
- A checkout with modified tracked files is left where it is
  (`checkout_pinned_rev`). Untracked files do not count, since `git checkout`
  refuses on its own when it would overwrite one.
- When a build was already on the machine, it becomes another candidate rather
  than something to replace. Every candidate is linked into `~/.local/bin` under
  its own versioned name and the newest of them gets the plain name
  (`link_versioned_alternatives`). "Newest" is `version_rank`, where a release
  outranks the prereleases numbered for it, so
  `0.16.0 < 0.17.0-dev.387 < 0.17.0`.
- When PATH already resolves a plain name to the newest candidate, leave it
  completely alone. Claiming it would take ownership of a link the user may have
  made themselves, which `clean` would then remove.

### Clean mirrors install

`clean` must remove what `install` created and nothing else.

- Symlink targets are declared once in `declare_file_targets` and read by both
  paths. Adding a config file means editing that function, not two lists.
- The links into `~/.local/bin` are the exception: they are named after the
  version each binary reported, which is not known until install has looked at
  the machine. They are recorded in `LINK_MANIFEST` (`~/.dotfiles_links`) as they
  are made and read back by `remove_recorded_links`. Only a link this run
  actually created is recorded — one that already pointed at the right place was
  not ours to make and so is not ours to remove.
- A destination is only removed when it is still a symlink to the source we gave
  it (`remove_syms`). Repointed links and real files that replaced them stay.
- Directories are removed with `rmdir`, so anything the user put in one keeps it.
- Deliberately never undone: installed packages, `/opt` clones, the `~/repos`
  checkouts, worktrees and unpacked toolchains, and the login shell. These are
  expensive to rebuild and useful independently of these dotfiles.

### Portable

`install.sh` runs under bash 3.2, which is what macOS ships. That rules out
several things worth remembering because they fail in ways that look like
something else:

- No associative arrays, no `local -n` namerefs. Arrays are passed by name and
  copied with `copy_array`, which uses `eval` for exactly this reason.
- No `readlink -f`, no `sort -V`, no `mktemp -t` without a template. Use
  `resolve_path` and `version_rank`; both exist because of this.
- `sha256sum` is GNU, `shasum` is what macOS has. `file_sha256` tries both.
- `mv` is `gmv` on macOS, hence `${MV}`.

`set -u` is on. Expanding an empty array trips it on bash 3.2, so guard with
`[ ${#arr[@]} -gt 0 ]` before expanding, and give every variable a default at the
top of the file if it is only assigned on some platforms.

Anything platform specific goes in the matching `*_mac_only` / `*_linux_only` /
`*_linux_desktop` array and is dispatched by `run_platform_step` or
`run_desktop_step`, not in an `if` at the call site.

### Everything runs unattended

- `sudo` is not assumed to be passwordless, but it is assumed to have been
  primed by the package manager step earlier in the run. Do not add a `sudo` read
  to a path that a re-run reaches in its steady state — check without `sudo`
  first and only escalate when a change is actually needed.
- The pattern for anything needing privilege is: try unprivileged, retry with
  `sudo` and say so (`Required sudo`), then fail.
- Output is silenced (`&>/dev/null`) and reported through the `print_*` helpers.
  The exception is a build long enough to want a record: those redirect to a log
  under `$TMPDIR` and print its path on failure.

### Pinned and verified

- A toolchain download is pinned to a version and a `sha256` published by
  upstream, and a mismatch refuses to unpack rather than warning and carrying on.
  Both live next to the version constant, `zig_shasum` for the current one.
- A language server that tracks a compiler's breaking changes is pinned to the
  release matching it (`ZLS_TAG` against `ZIG_VERSION`). Bumping one means
  bumping the other and replacing all four shasums.
- A pin the build system enforces will fail loudly, which is the point: zls
  master refuses to compile with anything below the zig it was written against.

## Conventions

- Output goes through `print_info`, `print_warn`, `print_err`, `print_section`.
  Continuation lines within a step are prefixed `....`. Paths go through
  `style_path` (which shortens `$HOME` to `~`), names and values through
  `highlight_text`, step headings through `emphasize_text`.
- Dependency entries are `package:command` when the installed binary is not named
  after its package (`neovim:nvim`, `ninja-build:ninja`), so that a hand
  installed binary counts as satisfying the dependency. See `check_installed`.
- Symlink entries are a single space separated `"source destination"` string,
  split inside the function that consumes them. Paths with spaces in them are not
  supported anywhere in this script.
- Comments explain why, not what. A comment earns its place by recording the
  reason a non obvious choice was made — the sharp edge that forced it, the case
  that broke without it. Nothing narrates the code.

## Testing

`install.sh` ends in `main "$@"`, so it cannot be sourced as it stands. To
exercise functions without running an install:

```bash
grep -v '^main "\$@"$' install.sh > /tmp/funcs.sh
# then source it, set OS/MV/PCKMAN/DOTFILES, and call what you want
```

`create_syms` opens with `sudo test`, which blocks unattended. Stub it when
testing anything that links, and check `bash -n install.sh` on every change.

Verify idempotency by running the same step twice and reading the second run's
output: every line should be a skip.
