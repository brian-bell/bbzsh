# Colorized ls output and common aliases. Bash port of ls.zsh.

case "$OSTYPE" in
  darwin*|freebsd*|openbsd*|netbsd*)
    export CLICOLOR=1
    export LSCOLORS="${LSCOLORS:-Gxfxcxdxbxegedabagacad}"
    alias ls='ls -G'
    ;;
  linux*|gnu*)
    if command -v dircolors >/dev/null 2>&1; then
      eval "$(command dircolors -b)"
    fi
    alias ls='ls --color=auto'
    ;;
esac

alias ll='ls -lh'
alias la='ls -lah'
alias l='ls -la'
alias ..='cd ..'
