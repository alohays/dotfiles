# shellcheck shell=sh

[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/lib.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/lib.sh"

dotfiles_apply_base_env() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt localoptions nonomatch
    fi

    : "${DOTFILES_HOME:=$HOME/.dotfiles}"
    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"
    : "${XDG_STATE_HOME:=$HOME/.local/state}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"

    export DOTFILES_HOME XDG_CONFIG_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_HOME

    case "$(dotfiles_os_name)" in
        Darwin)
            homebrew_prefixes=${DOTFILES_HOMEBREW_PREFIXES:-}
            if [ -z "$homebrew_prefixes" ] && [ -n "${HOMEBREW_PREFIX:-}" ]; then
                homebrew_prefixes=$HOMEBREW_PREFIX:/opt/homebrew:/usr/local
            fi
            dotfiles_prepend_prefix_bins "${homebrew_prefixes:-/opt/homebrew:/usr/local}"
            ;;
    esac

    dotfiles_prepend_path "$DOTFILES_HOME/bin"
    dotfiles_prepend_path "$HOME/.volta/bin"
    dotfiles_prepend_path "$HOME/.asdf/bin"
    dotfiles_prepend_path "$HOME/.asdf/shims"
    dotfiles_prepend_path "$HOME/.pyenv/bin"
    dotfiles_prepend_path "$HOME/.pyenv/shims"
    dotfiles_prepend_path "$HOME/.nodenv/bin"
    dotfiles_prepend_path "$HOME/.nodenv/shims"
    dotfiles_prepend_path "$HOME/.local/share/mise/shims"
    dotfiles_prepend_path "$HOME/.yarn/bin"
    dotfiles_prepend_path "$HOME/.npm-global/bin"
    dotfiles_prepend_path "$HOME/bin"
    dotfiles_prepend_path "$HOME/.local/bin"

    nvm_root=${NVM_DIR:-$HOME/.nvm}
    nvm_bin=
    for dir in \
        "$nvm_root/current/bin" \
        "$nvm_root/versions/node/"*/bin
    do
        [ -d "$dir" ] || continue
        nvm_bin=$dir
    done
    [ -n "$nvm_bin" ] && dotfiles_prepend_path "$nvm_bin"

    fnm_root_candidates="${FNM_DIR:-$HOME/.fnm}:${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
    fnm_root=
    while [ -n "$fnm_root_candidates" ]; do
        case $fnm_root_candidates in
            *:*)
                dir=${fnm_root_candidates%%:*}
                fnm_root_candidates=${fnm_root_candidates#*:}
                ;;
            *)
                dir=$fnm_root_candidates
                fnm_root_candidates=
                ;;
        esac
        [ -n "$dir" ] || continue
        [ -d "$dir" ] || continue
        fnm_root=$dir
        break
    done
    if [ -n "$fnm_root" ]; then
        fnm_bin=
        for dir in \
            "$fnm_root/current/bin" \
            "$fnm_root/aliases/default/bin" \
            "$fnm_root/node-versions/"*/installation/bin
        do
            [ -d "$dir" ] || continue
            fnm_bin=$dir
        done
        [ -n "$fnm_bin" ] && dotfiles_prepend_path "$fnm_bin"
    fi

    dotfiles_prepend_first_path \
        "$HOME/.mambaforge/condabin" \
        "$HOME/mambaforge/condabin" \
        "$HOME/.miniforge3/condabin" \
        "$HOME/miniforge3/condabin" \
        "$HOME/.miniconda3/condabin" \
        "$HOME/miniconda3/condabin" \
        "/opt/miniforge3/condabin" \
        "/opt/miniconda3/condabin" \
        "/usr/local/miniconda3/condabin"
    export PATH

    if [ -z "${CONDA_EXE:-}" ]; then
        for conda_exe in \
            "$HOME/.mambaforge/bin/conda" \
            "$HOME/mambaforge/bin/conda" \
            "$HOME/.miniforge3/bin/conda" \
            "$HOME/miniforge3/bin/conda" \
            "$HOME/.miniconda3/bin/conda" \
            "$HOME/miniconda3/bin/conda" \
            "/opt/miniforge3/bin/conda" \
            "/opt/miniconda3/bin/conda" \
            "/usr/local/miniconda3/bin/conda"
        do
            if [ -x "$conda_exe" ]; then
                CONDA_EXE=$conda_exe
                export CONDA_EXE
                break
            fi
        done
    fi
}

dotfiles_apply_base_env

if [ "${DOTFILES_ENV_SH_LOADED:-0}" = "1" ]; then
    return 0
fi
DOTFILES_ENV_SH_LOADED=1
export DOTFILES_ENV_SH_LOADED

if [ -z "${EDITOR:-}" ]; then
    if command -v nvim >/dev/null 2>&1; then
        EDITOR=nvim
    elif command -v vim >/dev/null 2>&1; then
        EDITOR=vim
    elif command -v nano >/dev/null 2>&1; then
        EDITOR=nano
    else
        EDITOR=vi
    fi
fi
: "${VISUAL:=$EDITOR}"
: "${PAGER:=less}"
: "${LESS:=-FRX}"
: "${GIT_EDITOR:=$EDITOR}"

export EDITOR VISUAL PAGER LESS GIT_EDITOR

dotfiles_source_optional_relaxed "$XDG_CONFIG_HOME/dotfiles/local.env.sh"
