#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST_PATH = Path("manifests/manifest.json")
DEFAULT_PROFILES_DIR = Path("profiles")
DEFAULT_STATE_DIR = ".local/state/alohays-dotfiles"
DEFAULT_INVENTORY_FILE = "managed-targets.json"
DEFAULT_BACKUPS_DIR = "backups"
SKIP_NAMES = {".DS_Store", ".gitkeep"}
SKIP_PARTS = {".git", "__pycache__"}


class DotfilesError(RuntimeError):
    """Raised for recoverable CLI errors."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def timestamp_token() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def path_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise DotfilesError(f"missing JSON file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise DotfilesError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def compare_symlink_target(target: Path, desired_source: Path) -> bool:
    if not target.is_symlink():
        return False
    try:
        actual = (target.parent / os.readlink(target)).resolve(strict=False)
    except OSError:
        return False
    return actual == desired_source.resolve(strict=False)


def describe_existing(target: Path) -> str:
    if target.is_symlink():
        return "symlink"
    if target.is_dir():
        return "directory"
    if target.is_file():
        return "file"
    return "missing"


def normalize_relpath(path: Path) -> str:
    return path.as_posix().lstrip("/")


def inventory_state_paths(home: Path, manifest: dict[str, Any]) -> tuple[Path, Path, Path]:
    state = manifest.get("state", {})
    state_dir = home / state.get("directory", DEFAULT_STATE_DIR)
    inventory_path = state_dir / state.get("inventory_file", DEFAULT_INVENTORY_FILE)
    backups_root = state_dir / state.get("backups_dir", DEFAULT_BACKUPS_DIR)
    return state_dir, inventory_path, backups_root


def load_manifest(repo_root: Path) -> dict[str, Any]:
    manifest_path = repo_root / DEFAULT_MANIFEST_PATH
    manifest = load_json(manifest_path)
    modules = manifest.get("modules")
    if not isinstance(modules, list):
        raise DotfilesError(f"manifest missing module list: {manifest_path}")

    module_map: dict[str, dict[str, Any]] = {}
    for raw_module in modules:
        name = raw_module.get("name")
        source_root = raw_module.get("source_root")
        if not name or not source_root:
            raise DotfilesError(f"manifest module missing name/source_root: {raw_module}")
        module_map[name] = raw_module

    manifest["module_map"] = module_map
    return manifest


def load_profile(repo_root: Path, name: str) -> dict[str, Any]:
    profile_path = repo_root / DEFAULT_PROFILES_DIR / f"{name}.json"
    profile = load_json(profile_path)
    declared_name = profile.get("name")
    if declared_name and declared_name != name:
        raise DotfilesError(
            f"profile name mismatch in {profile_path}: expected {name}, found {declared_name}"
        )
    profile["name"] = name
    return profile


def merge_unique(existing: list[str], additions: list[str]) -> list[str]:
    merged = list(existing)
    for item in additions:
        if item not in merged:
            merged.append(item)
    return merged


def resolve_profile(repo_root: Path, manifest: dict[str, Any], profile_name: str | None) -> dict[str, Any]:
    default_profiles = manifest.get("default_profiles", {})
    effective_name = profile_name
    if not effective_name or effective_name == "auto":
        if os.environ.get("SSH_CONNECTION") or os.environ.get("SSH_TTY"):
            effective_name = default_profiles.get("ssh", "ssh-server")
        else:
            system_name = platform.system().lower()
            if system_name == "darwin":
                effective_name = default_profiles.get("darwin", "macos-desktop")
            else:
                effective_name = default_profiles.get("linux", "linux-desktop")

    cache: dict[str, dict[str, Any]] = {}
    resolving: set[str] = set()

    def _resolve(name: str) -> dict[str, Any]:
        if name in cache:
            return cache[name]
        if name in resolving:
            cycle = " -> ".join(list(resolving) + [name])
            raise DotfilesError(f"profile inheritance cycle detected: {cycle}")

        resolving.add(name)
        raw_profile = load_profile(repo_root, name)
        modules: list[str] = []
        lineage: list[str] = []

        for base_profile in raw_profile.get("extends", []):
            base = _resolve(base_profile)
            lineage = merge_unique(lineage, base["lineage"])
            modules = merge_unique(modules, base["modules"])

        modules = merge_unique(modules, raw_profile.get("modules", []))
        excluded_modules = set(raw_profile.get("exclude_modules", []))
        if excluded_modules:
            modules = [module for module in modules if module not in excluded_modules]

        for module_name in modules:
            if module_name not in manifest["module_map"]:
                raise DotfilesError(f"profile {name} references unknown module {module_name}")

        lineage = merge_unique(lineage, [name])
        resolved = {
            "name": name,
            "description": raw_profile.get("description", ""),
            "modules": modules,
            "lineage": lineage,
            "metadata": raw_profile.get("metadata", {}),
        }
        resolving.remove(name)
        cache[name] = resolved
        return resolved

    return _resolve(effective_name)


def iter_module_payload(module_root: Path) -> list[tuple[Path, Path]]:
    payload_root = module_root / "home" if (module_root / "home").is_dir() else module_root
    if not payload_root.exists():
        return []

    payload: list[tuple[Path, Path]] = []
    for source in sorted(payload_root.rglob("*")):
        if not source.is_file():
            continue
        relative_source = source.relative_to(payload_root)
        if any(part in SKIP_PARTS for part in relative_source.parts):
            continue
        if source.name in SKIP_NAMES:
            continue
        if payload_root == module_root and relative_source.parts and not relative_source.parts[0].startswith("."):
            continue
        payload.append((relative_source, source))
    return payload


def build_desired_targets(
    repo_root: Path,
    home: Path,
    manifest: dict[str, Any],
    profile: dict[str, Any],
) -> tuple[dict[str, dict[str, Any]], list[str]]:
    desired: dict[str, dict[str, Any]] = {}
    notes: list[str] = []

    for module_name in profile["modules"]:
        module = manifest["module_map"][module_name]
        module_root = repo_root / module["source_root"]
        if not module_root.exists():
            notes.append(f"module {module_name} is enabled but {module_root} does not exist yet")
            continue

        payload = iter_module_payload(module_root)
        if not payload:
            notes.append(f"module {module_name} has no managed files under {module_root}")
            continue

        for relative_source, source in payload:
            target_rel = normalize_relpath(relative_source)
            desired[target_rel] = {
                "module": module_name,
                "source": source.resolve(strict=False),
                "source_rel": normalize_relpath(source.relative_to(repo_root)),
                "target": home / relative_source,
                "target_rel": target_rel,
            }
    return desired, notes


def load_previous_inventory(inventory_path: Path) -> dict[str, Any]:
    if not inventory_path.exists():
        return {"entries": []}
    inventory = load_json(inventory_path)
    if not isinstance(inventory.get("entries", []), list):
        raise DotfilesError(f"invalid inventory format: {inventory_path}")
    return inventory


def build_plan(repo_root: Path, home: Path, profile_name: str | None) -> dict[str, Any]:
    manifest = load_manifest(repo_root)
    profile = resolve_profile(repo_root, manifest, profile_name)
    _, inventory_path, backups_root = inventory_state_paths(home, manifest)
    inventory = load_previous_inventory(inventory_path)
    desired, notes = build_desired_targets(repo_root, home, manifest, profile)
    previous_entries = {entry["target"]: entry for entry in inventory.get("entries", []) if "target" in entry}

    actions: list[dict[str, Any]] = []
    for target_rel, entry in sorted(previous_entries.items()):
        if target_rel in desired:
            continue
        target = home / target_rel
        if target.is_symlink():
            actions.append({"kind": "remove-stale-symlink", "target": target_rel})
        elif target.exists():
            actions.append(
                {
                    "kind": "leave-existing-obsolete-target",
                    "target": target_rel,
                    "detail": "inventory says target was managed, but it is no longer a symlink; leaving it untouched",
                }
            )

    for target_rel, spec in sorted(desired.items()):
        target = spec["target"]
        action = {
            "target": target_rel,
            "source": spec["source_rel"],
            "module": spec["module"],
        }
        if compare_symlink_target(target, spec["source"]):
            action["kind"] = "noop"
        elif not path_exists(target):
            action["kind"] = "link"
        else:
            action["kind"] = "backup-and-link"
            action["existing"] = describe_existing(target)
        actions.append(action)

    return {
        "repo_root": str(repo_root),
        "home": str(home),
        "profile": profile,
        "inventory_path": str(inventory_path),
        "backups_root": str(backups_root),
        "desired": desired,
        "notes": notes,
        "actions": actions,
    }


def ensure_unique_destination(path: Path) -> Path:
    if not path_exists(path):
        return path
    counter = 1
    while True:
        candidate = path.with_name(f"{path.name}.{counter}")
        if not path_exists(candidate):
            return candidate
        counter += 1


def cleanup_empty_parents(start: Path, stop_at: Path) -> None:
    current = start
    while current != stop_at and current != current.parent:
        try:
            current.rmdir()
        except OSError:
            break
        current = current.parent


def apply_plan(plan: dict[str, Any], dry_run: bool) -> dict[str, Any]:
    actions = list(plan["actions"])
    if dry_run:
        return {
            "ok": True,
            "dry_run": True,
            "repo_root": plan["repo_root"],
            "home": plan["home"],
            "profile": plan["profile"],
            "inventory_path": plan["inventory_path"],
            "backup_metadata_path": None,
            "notes": plan["notes"],
            "actions": actions,
        }

    repo_root = Path(plan["repo_root"])
    home = Path(plan["home"])
    inventory_path = Path(plan["inventory_path"])
    backups_root = Path(plan["backups_root"])
    desired: dict[str, dict[str, Any]] = plan["desired"]

    backup_entries: list[dict[str, Any]] = []
    backup_run_root: Path | None = None

    for action in actions:
        if action["kind"] != "remove-stale-symlink":
            continue
        target = home / action["target"]
        if target.is_symlink():
            target.unlink()
            cleanup_empty_parents(target.parent, home)

    for action in actions:
        if action["kind"] not in {"link", "backup-and-link"}:
            continue

        spec = desired[action["target"]]
        target = Path(spec["target"])
        target.parent.mkdir(parents=True, exist_ok=True)

        if action["kind"] == "backup-and-link" and path_exists(target):
            if backup_run_root is None:
                backup_run_root = backups_root / timestamp_token()
            backup_destination = ensure_unique_destination(backup_run_root / "targets" / action["target"])
            backup_destination.parent.mkdir(parents=True, exist_ok=True)
            original_kind = describe_existing(target)
            shutil.move(str(target), str(backup_destination))
            backup_entries.append(
                {
                    "target": action["target"],
                    "backup_path": normalize_relpath(backup_destination.relative_to(backup_run_root)),
                    "original_kind": original_kind,
                    "replaced_by": spec["source_rel"],
                }
            )

        if path_exists(target):
            if target.is_dir():
                raise DotfilesError(f"cannot replace existing directory at {target}")
            target.unlink()
        target.symlink_to(Path(spec["source"]))

    inventory_payload = {
        "schema_version": 1,
        "updated_at": utc_now(),
        "repo_root": str(repo_root),
        "profile": plan["profile"]["name"],
        "entries": [
            {
                "target": target_rel,
                "source": spec["source_rel"],
                "module": spec["module"],
            }
            for target_rel, spec in sorted(desired.items())
        ],
    }
    write_json(inventory_path, inventory_payload)

    backup_metadata_path: str | None = None
    if backup_entries and backup_run_root is not None:
        metadata_path = backup_run_root / "metadata.json"
        write_json(
            metadata_path,
            {
                "schema_version": 1,
                "created_at": utc_now(),
                "repo_root": str(repo_root),
                "profile": plan["profile"]["name"],
                "entries": backup_entries,
            },
        )
        backup_metadata_path = str(metadata_path)

    return {
        "ok": True,
        "dry_run": False,
        "repo_root": str(repo_root),
        "home": str(home),
        "profile": plan["profile"],
        "inventory_path": str(inventory_path),
        "backup_metadata_path": backup_metadata_path,
        "notes": plan["notes"],
        "actions": actions,
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Apply alohays/dotfiles profiles")
    subparsers = parser.add_subparsers(dest="command", required=True)

    def add_shared_arguments(command_parser: argparse.ArgumentParser) -> None:
        command_parser.add_argument("--repo-root", default=str(DEFAULT_REPO_ROOT), help="dotfiles repository root")
        command_parser.add_argument("--home", default=os.path.expanduser("~"), help="target HOME directory")
        command_parser.add_argument("--profile", default=None, help="profile name (defaults to auto detection)")

    apply_parser = subparsers.add_parser("apply", help="apply the resolved profile to HOME")
    add_shared_arguments(apply_parser)
    apply_parser.add_argument("--dry-run", action="store_true", help="show planned actions without changing files")

    plan_parser = subparsers.add_parser("plan", help="preview what apply would do")
    add_shared_arguments(plan_parser)

    profiles_parser = subparsers.add_parser("profiles", aliases=["list-profiles"], help="list available profiles")
    profiles_parser.add_argument("--repo-root", default=str(DEFAULT_REPO_ROOT), help="dotfiles repository root")

    return parser.parse_args(argv)


def list_profiles(repo_root: Path) -> dict[str, Any]:
    manifest = load_manifest(repo_root)
    profiles_dir = repo_root / DEFAULT_PROFILES_DIR
    profiles: list[dict[str, Any]] = []
    for profile_path in sorted(profiles_dir.glob("*.json")):
        profile = load_json(profile_path)
        profiles.append(
            {
                "name": profile.get("name", profile_path.stem),
                "description": profile.get("description", ""),
                "extends": profile.get("extends", []),
                "modules": profile.get("modules", []),
            }
        )

    return {
        "ok": True,
        "default_profile": resolve_profile(repo_root, manifest, None)["name"],
        "profiles": profiles,
    }


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, indent=2, sort_keys=False))


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        if args.command in {"profiles", "list-profiles"}:
            emit(list_profiles(Path(args.repo_root).expanduser().resolve()))
            return 0

        repo_root = Path(args.repo_root).expanduser().resolve()
        home = Path(args.home).expanduser().resolve()
        dry_run = args.command == "plan" or getattr(args, "dry_run", False)
        plan = build_plan(repo_root, home, args.profile)
        emit(apply_plan(plan, dry_run=dry_run))
        return 0
    except DotfilesError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
