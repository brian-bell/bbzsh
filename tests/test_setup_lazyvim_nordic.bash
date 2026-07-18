#!/usr/bin/env bash
# Behavioral tests for setup-lazyvim-nordic.sh.
# Run with: bash tests/test_setup_lazyvim_nordic.bash
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
script="$repo/setup-lazyvim-nordic.sh"

fails=0
ok()   { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; fails=$((fails + 1)); }
backup_contains() {
  find "$1" -type f -path "*/$2" -exec grep -F -l "$3" {} \; 2>/dev/null | grep -q .
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_bin="$tmp/bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/git" <<'EOF'
#!/bin/sh
if [ "${1-}" = "--version" ]; then
  printf 'git version %s\n' "${FAKE_GIT_VERSION:-2.50.0}"
  exit 0
fi
if [ "${1-}" = "clone" ]; then
  for destination do :; done
  mkdir -p "$destination/.git" "$destination/lua/config" "$destination/lua/plugins"
  printf '%s\n' '-- LazyVim starter' > "$destination/init.lua"
  printf '%s\n' 'require("lazy").setup({ { "LazyVim/LazyVim" } })' > "$destination/lua/config/lazy.lua"
  exit 0
fi
printf 'unexpected git invocation: %s\n' "$*" >&2
exit 1
EOF

cat > "$fake_bin/nvim" <<'EOF'
#!/bin/sh
if [ "${1-}" = "--version" ]; then
  printf 'NVIM v%s\n' "${FAKE_NVIM_VERSION:-0.11.2}"
  exit 0
fi
if [ -n "${FAKE_EXPECT_NVIM_APPNAME:-}" ] \
  && [ "${NVIM_APPNAME-}" != "$FAKE_EXPECT_NVIM_APPNAME" ]; then
  printf 'expected NVIM_APPNAME=%s, found %s\n' \
    "$FAKE_EXPECT_NVIM_APPNAME" "${NVIM_APPNAME-<unset>}" >&2
  exit 1
fi
if [ -n "${FAKE_CALL_LOG:-}" ]; then
  printf 'nvim %s\n' "$*" >> "$FAKE_CALL_LOG"
fi
exit 0
EOF

cat > "$fake_bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${FAKE_UNAME:-Darwin}"
EOF

cat > "$fake_bin/brew" <<'EOF'
#!/bin/sh
if [ -n "${FAKE_CALL_LOG:-}" ]; then
  printf 'brew %s\n' "$*" >> "$FAKE_CALL_LOG"
fi
case "$*" in
  'list --cask font-jetbrains-mono-nerd-font') exit 1 ;;
  'install --cask font-jetbrains-mono-nerd-font') exit 0 ;;
esac
exit 1
EOF

cat > "$fake_bin/defaults" <<'EOF'
#!/bin/sh
if [ -n "${FAKE_CALL_LOG:-}" ]; then
  printf 'defaults %s\n' "$*" >> "$FAKE_CALL_LOG"
fi
case "${1-}" in
  export)
    : > "$3"
    ;;
  import)
    ;;
  *) exit 1 ;;
esac
EOF

cat > "$fake_bin/plutil" <<'EOF'
#!/bin/sh
if [ -n "${FAKE_CALL_LOG:-}" ]; then
  printf 'plutil %s\n' "$*" >> "$FAKE_CALL_LOG"
fi
if [ "${1-}" = '-extract' ]; then
  case "$2" in
    'New Bookmarks.0.Name') printf '%s\n' 'Default' ;;
    'New Bookmarks.1.Name') printf '%s\n' 'tmux' ;;
    'New Bookmarks.0.Normal Font'|'New Bookmarks.1.Normal Font') printf '%s\n' 'Monaco 12' ;;
    *) exit 1 ;;
  esac
  exit 0
fi
if [ "${1-}" = '-replace' ] || [ "${1-}" = '-insert' ]; then
  exit 0
fi
exit 1
EOF
chmod +x "$fake_bin/git" "$fake_bin/nvim" "$fake_bin/uname" \
  "$fake_bin/brew" "$fake_bin/defaults" "$fake_bin/plutil"

# --- a fresh install creates a LazyVim config with Nordic enabled --------
home1="$tmp/home1"
mkdir -p "$home1"
output1="$tmp/output1"
call_log1="$tmp/calls1"
if HOME="$home1" FAKE_CALL_LOG="$call_log1" PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" >"$output1" 2>&1; then
  config1="$home1/.config/nvim"
  if grep -q 'AlexvZyl/nordic.nvim' "$config1/lua/plugins/nordic.lua" \
    && grep -q 'colorscheme = "nordic"' "$config1/lua/plugins/nordic.lua"; then
    ok "fresh install configures Nordic for LazyVim"
  else
    fail "fresh install did not create the Nordic plugin spec"
  fi
  if [ ! -e "$config1/.git" ]; then
    ok "fresh install detaches the LazyVim starter repository"
  else
    fail "fresh install left the starter .git directory in place"
  fi
  if grep -q 'Lazy! sync' "$call_log1" \
    && grep -q "colors_name == 'nordic'" "$call_log1"; then
    ok "fresh install syncs plugins and verifies Nordic headlessly"
  else
    fail "fresh install did not run the headless sync and Nordic verification"
  fi
else
  fail "fresh install failed: $(cat "$output1")"
fi

# --- rerunning an installed setup succeeds without replacing config ------
printf '%s\n' '-- user customization' > "$home1/.config/nvim/lua/config/options.lua"
output2="$tmp/output2"
call_log2="$tmp/calls2"
if HOME="$home1" FAKE_CALL_LOG="$call_log2" PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" >"$output2" 2>&1; then
  if grep -q 'user customization' "$home1/.config/nvim/lua/config/options.lua"; then
    ok "rerun preserves an existing LazyVim and Nordic setup"
  else
    fail "rerun replaced user configuration"
  fi
  if grep -q 'Lazy! sync' "$call_log2" \
    && grep -q "colors_name == 'nordic'" "$call_log2"; then
    ok "rerun resyncs plugins and verifies Nordic"
  else
    fail "rerun did not resync and verify the existing setup"
  fi
else
  fail "rerun of installed setup failed: $(cat "$output2")"
fi

# --- an unrelated existing config is refused and preserved --------------
home2="$tmp/home2"
mkdir -p "$home2/.config/nvim"
printf '%s\n' 'do not overwrite' > "$home2/.config/nvim/init.lua"
output3="$tmp/output3"
if HOME="$home2" PATH="$fake_bin:/usr/bin:/bin" sh "$script" >"$output3" 2>&1; then
  fail "unrelated existing config should be refused"
elif [ "$(cat "$home2/.config/nvim/init.lua")" = 'do not overwrite' ]; then
  ok "existing unrelated config is refused and preserved"
else
  fail "existing unrelated config was modified"
fi

# --- --replace backs up Neovim files before installing ------------------
home3="$tmp/home3"
mkdir -p "$home3/.config/nvim" "$home3/.local/share/nvim" \
  "$home3/.local/state/nvim" "$home3/.cache/nvim"
printf '%s\n' 'old config' > "$home3/.config/nvim/init.lua"
printf '%s\n' 'old data' > "$home3/.local/share/nvim/data-marker"
printf '%s\n' 'old state' > "$home3/.local/state/nvim/state-marker"
printf '%s\n' 'old cache' > "$home3/.cache/nvim/cache-marker"
output4="$tmp/output4"
if HOME="$home3" PATH="$fake_bin:/usr/bin:/bin" sh "$script" --replace >"$output4" 2>&1; then
  backup_root="$home3/.local/state/lazyvim-nordic-installer/backups"
  if backup_contains "$backup_root" 'config/init.lua' 'old config' \
    && backup_contains "$backup_root" 'data/data-marker' 'old data' \
    && backup_contains "$backup_root" 'state/state-marker' 'old state' \
    && backup_contains "$backup_root" 'cache/cache-marker' 'old cache'; then
    ok "--replace backs up existing Neovim config, data, state, and cache"
  else
    fail "--replace did not preserve all existing Neovim files"
  fi
  if grep -q 'AlexvZyl/nordic.nvim' "$home3/.config/nvim/lua/plugins/nordic.lua"; then
    ok "--replace installs LazyVim with Nordic after backup"
  else
    fail "--replace did not install the new configuration"
  fi
else
  fail "--replace failed: $(cat "$output4")"
fi

# --- unsupported Neovim versions are rejected before installation -------
home4="$tmp/home4"
mkdir -p "$home4"
output5="$tmp/output5"
if HOME="$home4" FAKE_NVIM_VERSION=0.10.4 PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" >"$output5" 2>&1; then
  fail "Neovim older than 0.11.2 should be rejected"
elif [ ! -e "$home4/.config/nvim" ]; then
  ok "unsupported Neovim version is rejected before installation"
else
  fail "unsupported Neovim version left a partial configuration"
fi

# --- unsupported Git versions are rejected before installation ----------
home5="$tmp/home5"
mkdir -p "$home5"
output6="$tmp/output6"
if HOME="$home5" FAKE_GIT_VERSION=2.18.0 PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" >"$output6" 2>&1; then
  fail "Git older than 2.19.0 should be rejected"
elif [ ! -e "$home5/.config/nvim" ]; then
  ok "unsupported Git version is rejected before installation"
else
  fail "unsupported Git version left a partial configuration"
fi

# --- --with-iterm installs the font and updates every iTerm profile ------
home6="$tmp/home6"
mkdir -p "$home6"
output7="$tmp/output7"
call_log7="$tmp/calls7"
if HOME="$home6" FAKE_CALL_LOG="$call_log7" PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" --with-iterm >"$output7" 2>&1; then
  if grep -q 'brew install --cask font-jetbrains-mono-nerd-font' "$call_log7" \
    && grep -q 'New Bookmarks.0.Normal Font -string JetBrainsMonoNFM-Regular 12' "$call_log7" \
    && grep -q 'New Bookmarks.1.Normal Font -string JetBrainsMonoNFM-Regular 12' "$call_log7" \
    && grep -q 'defaults import com.googlecode.iterm2' "$call_log7"; then
    ok "--with-iterm installs the Nerd Font and updates all iTerm profiles"
  else
    fail "--with-iterm did not complete the expected font and profile setup"
  fi
  if find "$home6/Library/Application Support/iTerm2/Preferences Backups" \
    -type f -name 'com.googlecode.iterm2-before-nerd-font-*.plist' | grep -q .; then
    ok "--with-iterm backs up iTerm preferences"
  else
    fail "--with-iterm did not create an iTerm preferences backup"
  fi
else
  fail "--with-iterm failed: $(cat "$output7")"
fi

# --- --with-iterm fails safely before mutation on non-macOS systems -----
home7="$tmp/home7"
mkdir -p "$home7"
output8="$tmp/output8"
if HOME="$home7" FAKE_UNAME=Linux PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" --with-iterm >"$output8" 2>&1; then
  fail "--with-iterm should be rejected outside macOS"
elif [ ! -e "$home7/.config/nvim" ]; then
  ok "--with-iterm is rejected before mutation outside macOS"
else
  fail "unsupported --with-iterm run left a Neovim configuration behind"
fi

# --- --help documents the public interface without running setup --------
help_output="$tmp/help-output"
if HOME="$tmp/help-home" PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" --help >"$help_output" 2>&1 \
  && grep -q -- '--replace' "$help_output" \
  && grep -q -- '--with-iterm' "$help_output"; then
  ok "--help documents replacement and optional iTerm setup"
else
  fail "--help did not describe the public interface"
fi

# --- --replace also backs up orphaned data when config is absent --------
home8="$tmp/home8"
mkdir -p "$home8/.local/share/nvim" "$home8/.local/state/nvim" "$home8/.cache/nvim"
printf '%s\n' 'orphaned data' > "$home8/.local/share/nvim/data-marker"
printf '%s\n' 'orphaned state' > "$home8/.local/state/nvim/state-marker"
printf '%s\n' 'orphaned cache' > "$home8/.cache/nvim/cache-marker"
output9="$tmp/output9"
if HOME="$home8" PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" --replace >"$output9" 2>&1; then
  backup_root8="$home8/.local/state/lazyvim-nordic-installer/backups"
  if backup_contains "$backup_root8" 'data/data-marker' 'orphaned data' \
    && backup_contains "$backup_root8" 'state/state-marker' 'orphaned state' \
    && backup_contains "$backup_root8" 'cache/cache-marker' 'orphaned cache'; then
    ok "--replace backs up Neovim data, state, and cache without an existing config"
  else
    fail "--replace left orphaned Neovim directories outside the backup"
  fi
else
  fail "--replace with orphaned Neovim directories failed: $(cat "$output9")"
fi

# --- orphaned Neovim files require explicit replacement ----------------
home9="$tmp/home9"
mkdir -p "$home9/.local/share/nvim" "$home9/.local/state/nvim" "$home9/.cache/nvim"
printf '%s\n' 'orphaned data' > "$home9/.local/share/nvim/data-marker"
printf '%s\n' 'orphaned state' > "$home9/.local/state/nvim/state-marker"
printf '%s\n' 'orphaned cache' > "$home9/.cache/nvim/cache-marker"
output10="$tmp/output10"
if HOME="$home9" PATH="$fake_bin:/usr/bin:/bin" \
  sh "$script" >"$output10" 2>&1; then
  fail "orphaned Neovim directories should require --replace"
elif grep -q -- '--replace' "$output10" \
  && [ "$(cat "$home9/.local/share/nvim/data-marker")" = 'orphaned data' ] \
  && [ "$(cat "$home9/.local/state/nvim/state-marker")" = 'orphaned state' ] \
  && [ "$(cat "$home9/.cache/nvim/cache-marker")" = 'orphaned cache' ] \
  && [ ! -e "$home9/.config/nvim" ]; then
  ok "orphaned Neovim directories are refused and preserved without --replace"
else
  fail "orphaned Neovim directories were modified without --replace"
fi

# --- inherited NVIM_APPNAME does not redirect headless setup -----------
home10="$tmp/home10"
mkdir -p "$home10"
output11="$tmp/output11"
if HOME="$home10" NVIM_APPNAME=alternate FAKE_EXPECT_NVIM_APPNAME=nvim \
  PATH="$fake_bin:/usr/bin:/bin" sh "$script" >"$output11" 2>&1; then
  ok "headless setup targets the installed nvim profile despite NVIM_APPNAME"
else
  fail "headless setup inherited NVIM_APPNAME: $(cat "$output11")"
fi

printf '\n%d failure(s)\n' "$fails"
[ "$fails" -eq 0 ]
