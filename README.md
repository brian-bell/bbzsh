# bb.zsh / bb.bash

A small personal shell setup that replaces the parts of oh-my-zsh this repo
needs: completions and a git-aware prompt. It has no plugin manager, theme
engine, background updater, or generated config.

Two parallel ports ship the same behavior:

- **zsh** — `bb.zsh` (`*.zsh` modules)
- **bash** — `bb.bash` (`*.bash` modules), works on Linux and macOS
  (compatible with bash 3.2+)

## Install

### zsh

Source the entry point from `~/.zshrc`:

```zsh
source "$HOME/dev/bb.shell/bb.zsh"
```

### bash

Source the entry point from `~/.bashrc`:

```bash
source "$HOME/dev/bb.shell/bb.bash"
```

Open a new shell, or reload your current one (`source ~/.zshrc` or
`source ~/.bashrc`).

### LazyVim (optionally with Nordic)

`setup-lazyvim-nordic.sh` turns a bare Neovim installation into a LazyVim
setup. It requires Neovim 0.11.2 or newer and Git 2.19.0 or newer. Run it
directly from this checkout:

```zsh
./setup-lazyvim-nordic.sh
```

The installer clones the current LazyVim starter into the standard XDG
Neovim config directory, synchronizes plugins, and starts headless Neovim.
Rerunning it preserves the existing config while resynchronizing the setup.
After installation, open Neovim and run `:LazyHealth` to check external tools
such as compilers and Tree-sitter components for the languages you use.

The Nordic colorscheme is optional and off by default. To install and enable
it, add `--with-nordic`; this also verifies the colorscheme loads in headless
Neovim:

```zsh
./setup-lazyvim-nordic.sh --with-nordic
```

An unrelated existing Neovim config is left untouched. To replace one, use:

```zsh
./setup-lazyvim-nordic.sh --replace
```

Before replacement, the installer moves existing Neovim config, data, state,
and cache directories into a timestamped backup under
`~/.local/state/lazyvim-nordic-installer/backups/` (or the corresponding
`XDG_STATE_HOME`).

To remove the setup entirely, use `--uninstall`. It backs up existing Neovim
config, data, state, and cache into the same timestamped backup location, then
removes them. It cannot be combined with the install options:

```zsh
./setup-lazyvim-nordic.sh --uninstall
```

On macOS, iTerm font setup is an explicit opt-in:

```zsh
./setup-lazyvim-nordic.sh --with-iterm
```

This installs JetBrains Mono Nerd Font through Homebrew, backs up iTerm's
preferences, and changes every iTerm profile to the Nerd Font while preserving
each profile's existing font size. Open a new iTerm window afterward. Ghostty
1.2 and newer already include Nerd Font symbols and do not need this option.

## What It Does

- Bootstraps the completion system: `compinit` with Homebrew `fpath`
  directories on zsh, the `bash-completion` package on bash.
- Enables menu-style, case-insensitive completion (plus substring matching on
  zsh, which has no native bash equivalent).
- Enables colorized `ls` output on macOS, BSD, and Linux.
- Sets a robbyrussell-style prompt with the current path and git branch.
- Shows a dirty marker in the prompt when the current git worktree has changes.
- Sources `local.zsh` / `local.bash` for machine-specific overrides if present.

## Files

zsh:

- `bb.zsh`: entry point sourced by `.zshrc`.
- `ls.zsh`: colorized `ls` setup and common aliases.
- `completions.zsh`: completion bootstrap and completion styles.
- `prompt.zsh`: prompt setup plus small git helper functions.
- `local.zsh`: optional local-only overrides; ignored by git.
- `.gitconfig`: reference snapshot of the maintainer's personal git config
  (aliases, `gh` credential helper). Identity (`user.name` / `user.email`) is
  intentionally not committed. Not loaded by the shell setup.
- `install-gitconfig.sh`: installs `.gitconfig` as `~/.gitconfig`, prompting for
  `user.name` / `user.email`. Run with `sh install-gitconfig.sh`; backs up an
  existing `~/.gitconfig` first.
- `setup-lazyvim-nordic.sh`: installs LazyVim, with Nordic as an opt-in
  (`--with-nordic`); can back up and replace an existing Neovim setup,
  configure iTerm with a Nerd Font, or fully uninstall (`--uninstall`).

bash:

- `bb.bash`: entry point sourced by `.bashrc`.
- `ls.bash`: colorized `ls` setup and common aliases.
- `completions.bash`: `bash-completion` bootstrap and readline tweaks.
- `prompt.bash`: prompt setup plus small git helper functions.
- `local.bash`: optional local-only overrides; ignored by git.

## Customization

Add shared modules as sibling `.zsh` / `.bash` files and source them from the
matching entry point:

```zsh
source "${_bb_dir}/something.zsh"
```

```bash
source "${_bb_dir}/something.bash"
```

Put machine-specific or private settings in `local.zsh` / `local.bash`.

## Validation

Check syntax without loading the files, and run the bash prompt tests:

```zsh
zsh -n bb.zsh ls.zsh completions.zsh prompt.zsh
```

```bash
bash -n bb.bash ls.bash completions.bash prompt.bash
bash tests/test_prompt.bash
sh -n setup-lazyvim-nordic.sh
bash tests/test_setup_lazyvim_nordic.bash
```
