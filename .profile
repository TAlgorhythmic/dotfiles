# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.
#
# setup-arch.sh symlinks this to ~/.zprofile as well, so it has to stay
# POSIX sh: no [[ ]], no arrays. Anything zsh-specific belongs in ~/.zshrc.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# Prepend a directory to PATH, but only once: a login shell that re-reads this
# file (su -l, a nested login) would otherwise stack duplicate entries.
prepend_path() {
    [ -d "$1" ] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

# user's private bins. Prepended in this order so ~/.local/bin ends up ahead
# of ~/bin, as it was before.
prepend_path "$HOME/bin"
prepend_path "$HOME/.local/bin"
export PATH

unset -f prepend_path

export EDITOR=nvim
export VISUAL=nvim

# Start the compositor on the first VT, replacing this shell. Guarded on the
# binary existing: a failed `exec` takes the login shell down with it, which
# on tty1 means no way back in.
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
    if command -v start-hyprland >/dev/null 2>&1; then
        exec start-hyprland
    fi
fi
