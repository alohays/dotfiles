# Publishing `alohays/dotfiles`

## Pre-publish checklist

Before pushing this repo to GitHub, verify all of the following:
- bootstrap install/update flow works from an isolated temp `HOME`
- replacement flow asks once, creates backups, and does not touch live `~/.dotfiles`
- manifest/profile apply works for the v1 baseline profiles
- tmux/core/server modules apply cleanly
- README/docs clearly explain the AI-era goal: standard-first defaults for agents, optional polish for humans, and a temp-`HOME`-only QA story
- docs match the current command names and profile names
- `bin/dotfiles help` still exposes `bootstrap`, `install`, `apply`, `update`, `packages`, and `tools`
- `python3 scripts/dotfiles.py profiles --repo-root .` still lists `base`, `linux-desktop`, `macos-desktop`, and `ssh-server`
- `git diff --check` is clean
- smoke/QA tests in `tests/` pass against a local repo path

## Suggested validation flow

Run the smoke checks from an isolated temp home, for example:

```sh
TMP_HOME="$(mktemp -d)"
HOME="$TMP_HOME" ./bootstrap/install.sh
HOME="$TMP_HOME" ~/.dotfiles/bin/dotfiles apply
HOME="$TMP_HOME" ~/.dotfiles/bin/dotfiles packages --all --print-plan
HOME="$TMP_HOME" ~/.dotfiles/bin/dotfiles tools plan rtk
rm -rf "$TMP_HOME"
```

Treat the temp `HOME` boundary as a hard requirement. If a validation step cannot prove it stayed away from live `~/.dotfiles`, it is not safe enough.

If you are validating replacement behavior, create a fake legacy dotfiles checkout/config inside another temp `HOME` first, then run the installer and confirm that the backup path is created.

If you are testing bootstrap from a local path before the first real publish, use a committed temp git repo (or make an initial commit in your working repo) so the default `main` clone path behaves the same way GitHub will.

For the stricter QA pass, also run:

```sh
python3 -m unittest -v tests.test_dotfiles_apply tests.test_install_smoke tests.test_install_qa
```

## GitHub repository creation

If you use GitHub CLI:

```sh
gh repo create alohays/dotfiles --public --source=. --remote=origin --push
```

If the repo already exists, set the remote and push manually:

```sh
git remote add origin git@github.com:alohays/dotfiles.git
git push -u origin main
```

HTTPS alternative:

```sh
git remote add origin https://github.com/alohays/dotfiles.git
git push -u origin main
```

## Post-publish checks

After the first push:
- confirm the default branch is `main`
- confirm `bootstrap/install.sh` is reachable via the raw GitHub URL
- re-run the remote bootstrap command in a temp `HOME`
- review `.gitignore` and repo contents to ensure no local-only or secret files were committed

## Remote bootstrap URL

The expected public install entrypoint is:

```text
https://raw.githubusercontent.com/alohays/dotfiles/main/bootstrap/install.sh
```

Example invocation:

```sh
curl -fsSL https://raw.githubusercontent.com/alohays/dotfiles/main/bootstrap/install.sh | sh -s --
```

## Release hygiene

Before tagging a release, make sure the README, profile descriptions, and publish instructions still match the shipped CLI and manifest behavior.
