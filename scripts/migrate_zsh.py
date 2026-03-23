"""Zsh migration: auto-migrate legacy zsh init files during dotfiles apply.

This module handles the one-time migration of legacy ~/.zshenv, ~/.zprofile,
and ~/.zshrc files into unmanaged local overlay files. It strips known-obsolete
patterns (antidote, prezto, zinit, GLOBAL_RCS) and framework-owned sourcing
infrastructure, and recovers content from backup
checkouts when the original file was a symlink.

After the first successful apply, these functions are effectively no-ops for
the migrated user. For new users without legacy configs, they never run.
"""
from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any


def _load_json(path: Path) -> Any:
    """Thin wrapper — avoids circular import from dotfiles module."""
    import json

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {"entries": []}
    except json.JSONDecodeError:
        return {"entries": []}


def _path_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def _normalize_relpath(path: Path) -> str:
    return path.as_posix().lstrip("/")


def _utc_now() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


AUTO_MIGRATED_ZSH_FILES = {
    ".zshenv": ".config/dotfiles/local.zshenv.sh",
    ".zprofile": ".config/dotfiles/local.zprofile.sh",
    ".zshrc": ".config/dotfiles/local.zsh.zsh",
}


def zsh_backup_content_source(
    home: Path,
    backups_root: Path,
    backup_source: Path,
    target_rel: str,
    original_kind: str,
) -> tuple[str, Path] | tuple[None, None]:
    candidate_paths: list[Path] = []

    if original_kind == "file" and backup_source.is_file():
        candidate_paths.append(backup_source)

    if original_kind == "symlink" and backup_source.is_symlink():
        try:
            raw_link_target = Path(os.readlink(backup_source))
        except OSError:
            raw_link_target = None

        if raw_link_target is not None:
            original_target = home / target_rel
            if raw_link_target.is_absolute():
                resolved_link_target = raw_link_target.resolve(strict=False)
            else:
                resolved_link_target = (original_target.parent / raw_link_target).resolve(strict=False)

            dotfiles_home = (home / ".dotfiles").resolve(strict=False)
            try:
                checkout_relative = resolved_link_target.relative_to(dotfiles_home)
            except ValueError:
                checkout_relative = None

            if checkout_relative is not None:
                for checkout_backup in sorted(backups_root.glob("checkout-*"), reverse=True):
                    checkout_candidate = checkout_backup / checkout_relative
                    if checkout_candidate.is_file():
                        candidate_paths.append(checkout_candidate)

            if resolved_link_target.is_file():
                candidate_paths.append(resolved_link_target)

    seen: set[str] = set()
    for candidate in candidate_paths:
        key = str(candidate)
        if key in seen:
            continue
        seen.add(key)
        try:
            content = candidate.read_text(encoding="utf-8")
        except OSError:
            continue
        if content.strip():
            return content, candidate

    return None, None


_MIGRATE_LINE_STRIP_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"^\s*unsetopt\s+GLOBAL_RCS"),
    re.compile(r"^\s*source\s+.*antidote.*\.zsh"),
    re.compile(r"^\s*source\s+.*ANTIDOTE"),  # source "$ANTIDOTE_BUNDLE" (variable ref)
    re.compile(r"^\s*source\s+.*\.zpreztorc"),
    re.compile(r"^\s*source\s+.*zgen/init\.zsh"),
    re.compile(r"^\s*source\s+.*zinit"),
    re.compile(r"^\s*(export\s+)?ANTIDOTE_HOME\s*="),
    re.compile(r"^\s*(export\s+)?ANTIDOTE_BUNDLE\s*="),
    re.compile(r"""zstyle\s+['"]?:antidote:"""),
    re.compile(r"""zstyle\s+['"]?:prezto:"""),
    re.compile(r"^\s*antidote\s+(bundle|load|update|install|home|init|path|list)"),
    re.compile(r"^\s*_antidote_\w+"),  # bare _antidote_ function calls
    re.compile(r"^\s*(local|typeset)\s+.*ANTIDOTE"),  # local _ANTIDOTE_SAVING=""
    re.compile(r"^\s*(local|typeset)\s+-a\s+bundles\s*="),  # antidote bundle array
    re.compile(r"^\s*fpath_(user|system)\s*="),  # antidote fpath workaround
    re.compile(r"^\s*fpath\s*=\s*\(\s*\$fpath_user"),  # antidote fpath reassembly
    re.compile(r"^#\s*Source antidote\s*$"),  # section header
    re.compile(r"^\s*fast-theme\s+"),
    re.compile(r"^\s*if\s+\[\s+-f\s+/etc/zshrc"),
    re.compile(r"^\s*if\s+\[\s+-f\s+/etc/zsh/zshrc"),
    re.compile(r"^\s*source\s+/etc/zshrc"),
    re.compile(r"^\s*source\s+/etc/zsh/zshrc"),
    # Framework infrastructure lines — stripping these prevents the migrated
    # overlay from re-sourcing framework files or (critically) itself.
    re.compile(r"^\s*dotfiles_source_optional\s"),
    re.compile(r"^\s*dotfiles_source_optional_relaxed\s"),
    re.compile(r"^\s*dotfiles_source_dir\s"),
    re.compile(r"""^\s*\[\s+-r\s+["']?\$.*dotfiles/lib\.sh"""),
    re.compile(r"""^\s*:\s+["']\$\{DOTFILES_HOME:="""),
    re.compile(r"^\s*\[\[\s+-o\s+interactive\s*\]\]\s*\|\|\s*return"),
    re.compile(r"""^\s*\[\s+-r\s+["']\$HOME/\.profile["']\s*\]\s*&&\s*\."""),
    re.compile(r"^#\s*Canonical repo-owned zsh"),
    re.compile(r"^#\s*Managed home wrappers? delegate"),
    re.compile(r"^#\s*Keep zshenv minimal"),
    re.compile(r"^#\s*Managed wrapper.*canonical repo-owned"),
    re.compile(r"^\s*_dotfiles_wrapper_"),
    re.compile(r"^\s*unset\s+_dotfiles_wrapper_"),
    re.compile(r"""^\s*\[\s+-r\s+["']\$DOTFILES_HOME/zsh/zsh"""),
]

_MIGRATE_BLOCK_START_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"^\s*if\s+\[[\[\s].*antidote"), "fi"),
    (re.compile(r"^\s*if\s+\[[\[\s].*ANTIDOTE"), "fi"),
    (re.compile(r"^\s*if\s+!?\s*grep.*antidote", re.IGNORECASE), "fi"),
    (re.compile(r"^\s*if\s+!?\s*grep.*prezto", re.IGNORECASE), "fi"),
    (re.compile(r"^\s*if\s+type\s+antidote"), "fi"),
    (re.compile(r"^\s*function\s+antidote-"), "}"),
    (re.compile(r"^\s*function\s+_antidote_"), "}"),
    (re.compile(r"^\s*if\s+\[\s+-f\s+/etc/zshrc\b.*;\s*then\s*$"), "fi"),
    (re.compile(r"^\s*if\s+\[\s+-f\s+/etc/zsh/zshrc\b.*;\s*then\s*$"), "fi"),
    # Empty prezto config block left after source line is stripped.
    (re.compile(r"^\s*if\s+\[\[\s+-s\s+.*zpreztorc"), "fi"),
    # Antidote source error-recovery block (if [ ! $? -eq 0 ]).
    (re.compile(r"^\s*if\s+\[\s+!\s+\$\?\s+-eq\s+0"), "fi"),
    # Managed wrapper DOTFILES_HOME resolution block.
    (re.compile(r"""^\s*if\s+\[\s+-n\s+["']\$_dotfiles_wrapper_repo"""), "fi"),
]


def sanitize_migrated_zsh_content(content: str) -> str:
    """Strip obsolete and framework-owned patterns from migrated zsh content.

    Removes known-obsolete plugin managers (antidote, prezto, zinit, GLOBAL_RCS)
    and the dotfiles framework's own sourcing infrastructure so that migrated
    overlay files do not re-source framework files or themselves.
    """
    lines = content.splitlines(keepends=True)
    result: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]

        # Check block-level patterns first.
        block_matched = False
        for start_pat, end_keyword in _MIGRATE_BLOCK_START_PATTERNS:
            if start_pat.search(line):
                if end_keyword == "}":
                    end_re = re.compile(r"^\s*\}")
                else:
                    end_re = re.compile(r"^\s*" + re.escape(end_keyword) + r"\b")
                j = i + 1
                depth = 1
                while j < len(lines):
                    if end_re.search(lines[j]):
                        depth -= 1
                        if depth <= 0:
                            j += 1
                            break
                    if re.match(r"^\s*if\b", lines[j]) and end_keyword == "fi":
                        depth += 1
                    if end_keyword == "}" and re.search(r"\{\s*$", lines[j]):
                        depth += 1
                    j += 1
                i = j
                block_matched = True
                break

        if block_matched:
            continue

        # Check line-level patterns.
        line_matched = False
        for pat in _MIGRATE_LINE_STRIP_PATTERNS:
            if pat.search(line):
                line_matched = True
                break

        if not line_matched:
            result.append(line)
        i += 1

    # Collapse runs of consecutive blank lines (keep at most 1).
    cleaned: list[str] = []
    blank_count = 0
    for line in result:
        if line.strip() == "":
            blank_count += 1
            if blank_count <= 1:
                cleaned.append(line)
        else:
            blank_count = 0
            cleaned.append(line)

    return "".join(cleaned)


def _has_meaningful_content(content: str) -> bool:
    """Return True if *content* has at least one non-comment, non-blank line."""
    for line in content.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            return True
    return False


def auto_migrate_zsh_backup(
    home: Path,
    backups_root: Path,
    backup_source: Path,
    target_rel: str,
    original_kind: str,
    notes: list[str],
) -> None:
    destination_rel = AUTO_MIGRATED_ZSH_FILES.get(target_rel)
    if destination_rel is None:
        return

    destination = home / destination_rel
    if _path_exists(destination):
        notes.append(
            f"legacy {target_rel} was backed up at {_normalize_relpath(backup_source.relative_to(home))}; "
            f"skipped auto-migration because {destination_rel} already exists"
        )
        return

    content, _ = zsh_backup_content_source(
        home=home,
        backups_root=backups_root,
        backup_source=backup_source,
        target_rel=target_rel,
        original_kind=original_kind,
    )
    if not content:
        return

    content = sanitize_migrated_zsh_content(content)

    if not _has_meaningful_content(content):
        notes.append(
            f"legacy {target_rel} contained only framework-owned lines; "
            f"skipped creating {destination_rel}"
        )
        return

    destination.parent.mkdir(parents=True, exist_ok=True)
    header = (
        f"# Auto-migrated from backed-up {target_rel} on {_utc_now()}.\n"
        "# Obsolete plugin-manager and dotfiles-framework lines were stripped.\n"
        "# Review and trim this file -- the framework handles PATH, plugins, and completion.\n\n"
    )
    if not content.endswith("\n"):
        content += "\n"
    destination.write_text(header + content, encoding="utf-8")
    notes.append(f"auto-migrated legacy {target_rel} to {destination_rel}")


def restore_zsh_migrations_from_history(home: Path, backups_root: Path, notes: list[str]) -> None:
    if not backups_root.exists():
        return

    metadata_paths = sorted(backups_root.glob("*/metadata.json"), reverse=True)
    if not metadata_paths:
        return

    for target_rel, destination_rel in AUTO_MIGRATED_ZSH_FILES.items():
        if _path_exists(home / destination_rel):
            continue

        for metadata_path in metadata_paths:
            metadata = _load_json(metadata_path)
            entries = metadata.get("entries", [])
            if not isinstance(entries, list):
                continue
            matching_entry = next(
                (
                    entry
                    for entry in entries
                    if entry.get("target") == target_rel
                ),
                None,
            )
            if matching_entry is None:
                continue

            backup_path = matching_entry.get("backup_path")
            if not backup_path:
                continue
            backup_source = metadata_path.parent / backup_path
            auto_migrate_zsh_backup(
                home=home,
                backups_root=backups_root,
                backup_source=backup_source,
                target_rel=target_rel,
                original_kind=str(matching_entry.get("original_kind", "")),
                notes=notes,
            )
            break
