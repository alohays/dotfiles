# Server-profile interactive safety hooks.
if command -v tty >/dev/null 2>&1; then
    gpg_tty=$(tty 2>/dev/null || true)
    case "$gpg_tty" in
        ''|'not a tty') ;;
        *) GPG_TTY=$gpg_tty; export GPG_TTY ;;
    esac
fi
