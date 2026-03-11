# shellcheck shell=sh

case $- in
    *i*) ;;
    *) return 0 ;;
esac

# Interactive compatibility shim for platforms that expose python3/pip3
# without python/pip frontends (common on modern macOS/Homebrew setups).

if ! command -v python >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    alias python=python3
fi

if ! command -v pip >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
    alias pip=pip3
fi
