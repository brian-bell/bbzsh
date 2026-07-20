# AGENTS.md

## Project Notes

- This repo is a minimal shell configuration, not a general shell framework.
- There are two parallel ports that should stay behaviorally in sync:
  - zsh: `bb.zsh` entry point + `*.zsh` modules.
  - bash: `bb.bash` entry point + `*.bash` modules (targets Linux; also
    works on macOS). Kept compatible with bash 3.2+.
- Each entry point should stay small.
- Keep scripts shell-specific when useful; `.zsh` files are sourced by zsh and
  `.bash` files by bash, neither is POSIX sh.
- Prefer small, readable modules over abstractions or plugin-manager behavior.
- Keep machine-specific settings out of git; use `local.zsh` / `local.bash`,
  which are ignored.
- `.gitconfig` is a checked-in reference snapshot of the maintainer's personal
  git config; it is not part of the shell setup and nothing sources it.
  Identity (`user.name` / `user.email`) is intentionally not committed.
- `install-gitconfig.sh` installs `.gitconfig` as `~/.gitconfig`, prompting for
  identity. It is POSIX sh (run, not sourced), unlike the `.zsh` / `.bash`
  modules.
- `setup-lazyvim-nordic.sh` is a POSIX sh standalone installer for LazyVim.
  Nordic is optional and off by default; `--with-nordic` opts in. Its optional
  `--with-iterm` path is macOS-only and must remain explicitly opt-in. Its
  `--uninstall` path backs up existing Neovim config, data, state, and cache to
  the installer backups dir, then removes them; it cannot be combined with the
  install options.

## Checks

- zsh: `zsh -n bb.zsh ls.zsh completions.zsh prompt.zsh`
- bash: `bash -n bb.bash ls.bash completions.bash prompt.bash`
- bash prompt tests: `bash tests/test_prompt.bash`
- gitconfig installer: `sh -n install-gitconfig.sh` and
  `bash tests/test_install_gitconfig.bash`
- LazyVim installer: `sh -n setup-lazyvim-nordic.sh` and
  `bash tests/test_setup_lazyvim_nordic.bash`
