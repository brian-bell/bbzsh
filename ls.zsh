# Colorized ls output and common aliases.

case "$OSTYPE" in
  darwin*|freebsd*|openbsd*|netbsd*)
    export CLICOLOR=1
    export LSCOLORS="${LSCOLORS:-Gxfxcxdxbxegedabagacad}"
    alias ls='ls -G'
    ;;
  linux*|gnu*)
    if (( $+commands[dircolors] )); then
      eval "$(command dircolors -b)"
    fi
    alias ls='ls --color=auto'
    ;;
esac

alias ll='ls -lh'
alias la='ls -lah'
alias l='ls -la'
alias ..='cd ..'
