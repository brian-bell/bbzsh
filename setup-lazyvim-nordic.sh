#!/bin/sh
# Install the LazyVim starter and configure the Nordic colorscheme.
set -eu

config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
config_dir="$config_home/nvim"
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
data_dir="$data_home/nvim"
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
state_dir="$state_home/nvim"
cache_home=${XDG_CACHE_HOME:-"$HOME/.cache"}
cache_dir="$cache_home/nvim"

usage() {
  cat <<'EOF'
Usage: setup-lazyvim-nordic.sh [--with-nordic] [--replace] [--with-iterm]
       setup-lazyvim-nordic.sh --uninstall

Install the LazyVim starter. Nordic is optional and off by default.

Options:
  --with-nordic  Also install and enable the Nordic colorscheme.
  --replace      Back up existing Neovim config, data, state, and cache,
                 then install a fresh configuration.
  --with-iterm   On macOS, install JetBrains Mono Nerd Font with Homebrew,
                 back up iTerm preferences, and update every iTerm profile.
  --uninstall    Back up existing Neovim config, data, state, and cache,
                 then remove them. Cannot be combined with other options.
  -h, --help     Show this help.
EOF
}

replace=0
with_iterm=0
with_nordic=0
uninstall=0
for arg do
  case "$arg" in
    --replace) replace=1 ;;
    --with-iterm) with_iterm=1 ;;
    --with-nordic) with_nordic=1 ;;
    --uninstall) uninstall=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown option: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

if [ "$uninstall" -eq 1 ] \
  && { [ "$replace" -eq 1 ] || [ "$with_iterm" -eq 1 ] || [ "$with_nordic" -eq 1 ]; }; then
  printf '%s\n' 'error: --uninstall cannot be combined with other options' >&2
  exit 1
fi

if [ "$with_iterm" -eq 1 ] && [ "$(uname -s)" != Darwin ]; then
  printf '%s\n' 'error: --with-iterm is supported only on macOS' >&2
  exit 1
fi

# Move any existing Neovim config, data, state, and cache into a fresh
# timestamped backup directory. Sets $backup_dir and returns 0 when something
# was backed up; returns 1 (leaving nothing behind) when no files exist. A
# failed mkdir or mv aborts the whole script so a partial backup is never
# reported as complete (set -e is suppressed when this runs in a condition).
backup_neovim_files() {
  _has_neovim_files=0
  for path in "$config_dir" "$data_dir" "$state_dir" "$cache_dir"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      _has_neovim_files=1
      break
    fi
  done
  [ "$_has_neovim_files" -eq 1 ] || return 1

  backup_dir="$state_home/lazyvim-nordic-installer/backups/$(date +%Y%m%d-%H%M%S)-$$"
  if ! mkdir -p "$backup_dir"; then
    printf 'error: failed to create backup directory %s\n' "$backup_dir" >&2
    exit 1
  fi
  for item in \
    "config:$config_dir" \
    "data:$data_dir" \
    "state:$state_dir" \
    "cache:$cache_dir"
  do
    name=${item%%:*}
    path=${item#*:}
    if [ -e "$path" ] || [ -L "$path" ]; then
      if ! mv "$path" "$backup_dir/$name"; then
        printf 'error: failed to back up %s\n' "$path" >&2
        exit 1
      fi
    fi
  done
  return 0
}

if [ "$uninstall" -eq 1 ]; then
  if backup_neovim_files; then
    printf 'Backed up and removed Neovim files. Backup: %s\n' "$backup_dir"
  else
    printf '%s\n' 'No Neovim config, data, state, or cache found; nothing to remove.'
  fi
  exit 0
fi

configure_iterm() (
  if [ "$(uname -s)" != Darwin ]; then
    printf '%s\n' 'error: --with-iterm is supported only on macOS' >&2
    exit 1
  fi

  if command -v brew >/dev/null 2>&1; then
    brew_cmd=$(command -v brew)
  elif [ -x /opt/homebrew/bin/brew ]; then
    brew_cmd=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    brew_cmd=/usr/local/bin/brew
  else
    printf '%s\n' 'error: --with-iterm requires Homebrew' >&2
    exit 1
  fi

  for command_name in defaults plutil; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'error: --with-iterm requires %s\n' "$command_name" >&2
      exit 1
    fi
  done

  iterm_tmp_dir=$(mktemp -d)
  trap 'rm -rf "$iterm_tmp_dir"' EXIT HUP INT TERM
  iterm_domain=com.googlecode.iterm2
  iterm_work_plist="$iterm_tmp_dir/$iterm_domain.plist"
  if ! defaults export "$iterm_domain" "$iterm_work_plist" >/dev/null 2>&1; then
    printf '%s\n' 'error: no iTerm preferences found; open iTerm once, then retry' >&2
    exit 1
  fi

  iterm_backup_dir="$HOME/Library/Application Support/iTerm2/Preferences Backups"
  mkdir -p "$iterm_backup_dir"
  iterm_backup_file="$iterm_backup_dir/$iterm_domain-before-nerd-font-$(date +%Y%m%d-%H%M%S)-$$.plist"
  cp "$iterm_work_plist" "$iterm_backup_file"

  font_cask=font-jetbrains-mono-nerd-font
  if ! "$brew_cmd" list --cask "$font_cask" >/dev/null 2>&1; then
    "$brew_cmd" install --cask "$font_cask"
  fi

  profile_index=0
  while plutil -extract "New Bookmarks.$profile_index.Name" raw "$iterm_work_plist" >/dev/null 2>&1; do
    current_font=$(plutil -extract "New Bookmarks.$profile_index.Normal Font" raw "$iterm_work_plist" 2>/dev/null || true)
    font_size=${current_font##* }
    case "$font_size" in
      ''|*[!0-9.]*) font_size=12 ;;
    esac
    font_value="JetBrainsMonoNFM-Regular $font_size"

    plutil -replace "New Bookmarks.$profile_index.Normal Font" \
      -string "$font_value" "$iterm_work_plist"
    if plutil -extract "New Bookmarks.$profile_index.Non Ascii Font" raw \
      "$iterm_work_plist" >/dev/null 2>&1; then
      plutil -replace "New Bookmarks.$profile_index.Non Ascii Font" \
        -string "$font_value" "$iterm_work_plist"
    else
      plutil -insert "New Bookmarks.$profile_index.Non Ascii Font" \
        -string "$font_value" "$iterm_work_plist"
    fi
    profile_index=$((profile_index + 1))
  done

  if [ "$profile_index" -eq 0 ]; then
    printf '%s\n' 'error: no iTerm profiles were found in preferences' >&2
    exit 1
  fi

  defaults import "$iterm_domain" "$iterm_work_plist"
  printf 'Configured %s iTerm profile(s) with JetBrains Mono Nerd Font.\n' "$profile_index"
  printf 'iTerm preferences backup: %s\n' "$iterm_backup_file"
  printf '%s\n' 'Open a new iTerm window to use the new font.'
)

sync_and_verify_nvim() {
  NVIM_APPNAME=nvim nvim --headless "+Lazy! sync" +qa
  if [ "$with_nordic" -eq 1 ]; then
    NVIM_APPNAME=nvim nvim --headless \
      "+lua assert(vim.g.colors_name == 'nordic', 'Nordic colorscheme failed to load')" \
      +qa
  fi
}

if ! command -v nvim >/dev/null 2>&1; then
  printf '%s\n' 'error: Neovim is required but was not found in PATH' >&2
  exit 1
fi

nvim_version=$(nvim --version | sed -n '1s/^NVIM v\([0-9][0-9.]*\).*/\1/p')
if [ -z "$nvim_version" ]; then
  printf '%s\n' 'error: unable to determine the installed Neovim version' >&2
  exit 1
fi
IFS=. read -r nvim_major nvim_minor nvim_patch _nvim_rest <<EOF
$nvim_version
EOF
nvim_major=${nvim_major:-0}
nvim_minor=${nvim_minor:-0}
nvim_patch=${nvim_patch:-0}
if [ "$nvim_major" -eq 0 ] \
  && { [ "$nvim_minor" -lt 11 ] \
    || { [ "$nvim_minor" -eq 11 ] && [ "$nvim_patch" -lt 2 ]; }; }; then
  printf 'error: Neovim 0.11.2 or newer is required (found %s)\n' "$nvim_version" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  printf '%s\n' 'error: Git is required but was not found in PATH' >&2
  exit 1
fi

git_version=$(git --version | sed -n '1s/^git version \([0-9][0-9.]*\).*/\1/p')
if [ -z "$git_version" ]; then
  printf '%s\n' 'error: unable to determine the installed Git version' >&2
  exit 1
fi
IFS=. read -r git_major git_minor _git_patch _git_rest <<EOF
$git_version
EOF
git_major=${git_major:-0}
git_minor=${git_minor:-0}
if [ "$git_major" -lt 2 ] \
  || { [ "$git_major" -eq 2 ] && [ "$git_minor" -lt 19 ]; }; then
  printf 'error: Git 2.19.0 or newer is required (found %s)\n' "$git_version" >&2
  exit 1
fi

# Write the Nordic plugin spec into an existing config's plugins directory.
write_nordic_spec() {
  mkdir -p "$config_dir/lua/plugins"
  cat > "$config_dir/lua/plugins/nordic.lua" <<'EOF'
return {
  {
    "AlexvZyl/nordic.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "nordic",
    },
  },
}
EOF
}

lazyvim_present=0
if [ -f "$config_dir/lua/config/lazy.lua" ] \
  && grep -q 'LazyVim/LazyVim' "$config_dir/lua/config/lazy.lua"; then
  lazyvim_present=1
fi

nordic_present=0
if [ -f "$config_dir/lua/plugins/nordic.lua" ] \
  && grep -q 'AlexvZyl/nordic.nvim' "$config_dir/lua/plugins/nordic.lua" \
  && grep -q 'colorscheme = "nordic"' "$config_dir/lua/plugins/nordic.lua"; then
  nordic_present=1
fi

if [ "$replace" -eq 0 ] && [ "$lazyvim_present" -eq 1 ]; then
  # Reuse the existing LazyVim config, adding Nordic in place if requested.
  # Never clobber a nordic.lua the installer did not write; a conflicting one
  # is a hard error before syncing, since the later Nordic verification cannot
  # be guaranteed for a spec the installer does not manage.
  if [ "$with_nordic" -eq 1 ] && [ "$nordic_present" -eq 0 ]; then
    if [ -e "$config_dir/lua/plugins/nordic.lua" ] \
      || [ -L "$config_dir/lua/plugins/nordic.lua" ]; then
      printf '%s\n' \
        "error: existing lua/plugins/nordic.lua does not match the installer's Nordic spec" >&2
      printf '%s\n' \
        'Remove or rename it to let the installer manage Nordic, or re-run without --with-nordic.' >&2
      exit 1
    fi
    write_nordic_spec
    printf 'Added the Nordic colorscheme to the existing LazyVim config.\n'
  fi
else
  if [ "$replace" -eq 0 ]; then
    for path in "$config_dir" "$data_dir" "$state_dir" "$cache_dir"; do
      if [ -e "$path" ] || [ -L "$path" ]; then
        printf 'error: Neovim files already exist at %s\n' "$path" >&2
        printf '%s\n' 'Re-run with --replace to back them up and install a fresh config.' >&2
        exit 1
      fi
    done
  fi

  if [ "$replace" -eq 1 ] && backup_neovim_files; then
    printf 'Backed up existing Neovim files to %s\n' "$backup_dir"
  fi

  mkdir -p "$config_home"
  git clone --filter=blob:none https://github.com/LazyVim/starter "$config_dir"
  rm -rf "$config_dir/.git"

  if [ "$with_nordic" -eq 1 ]; then
    write_nordic_spec
  fi

fi

sync_and_verify_nvim
if [ "$with_nordic" -eq 1 ]; then
  printf 'LazyVim with Nordic is ready at %s\n' "$config_dir"
else
  printf 'LazyVim is ready at %s\n' "$config_dir"
fi
printf '%s\n' 'Open Neovim and run :LazyHealth to check external tooling.'

if [ "$with_iterm" -eq 1 ]; then
  configure_iterm
fi
