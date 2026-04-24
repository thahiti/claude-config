#!/usr/bin/env python3
"""
Merge two Claude Code settings.json files.

Usage:
    merge-settings.py <repo-settings> <local-settings>

Outputs merged JSON to stdout. Exits non-zero on error.

Merge semantics — see ../SKILL.md for full table. Summary:
- permissions.{allow,deny,ask,additionalDirectories}: union (dedup, repo order first)
- env: local wins (machine-specific secrets)
- hooks: per-event/matcher merge, concat + dedup by (type, command|prompt)
- enabledPlugins, extraKnownMarketplaces: union, repo wins on collision
- statusLine, scalars: repo wins if present, else keep local
- Keys only in local: preserved
"""

import json
import sys
from pathlib import Path


def union_list(repo_list, local_list):
    """Repo order first, then local-only items. Dedup by string equality."""
    seen = set()
    result = []
    for item in (repo_list or []) + (local_list or []):
        key = json.dumps(item, sort_keys=True)
        if key not in seen:
            seen.add(key)
            result.append(item)
    return result


def merge_permissions(repo, local):
    merged = {}
    array_fields = ["allow", "deny", "ask", "additionalDirectories"]
    for f in array_fields:
        r = repo.get(f) if repo else None
        l = local.get(f) if local else None
        if r is not None or l is not None:
            merged[f] = union_list(r, l)

    # Non-array fields: repo wins if present
    all_keys = set((repo or {}).keys()) | set((local or {}).keys())
    for k in all_keys - set(array_fields):
        if repo and k in repo:
            merged[k] = repo[k]
        else:
            merged[k] = local[k]
    return merged


def merge_hooks(repo, local):
    """Merge hooks: per event, per matcher, concat + dedup hook configs."""
    if not repo:
        return local or {}
    if not local:
        return repo

    merged = {}
    all_events = set(repo.keys()) | set(local.keys())
    for event in all_events:
        repo_entries = repo.get(event, []) or []
        local_entries = local.get(event, []) or []

        # Group by matcher
        by_matcher = {}
        for entry in repo_entries + local_entries:
            m = entry.get("matcher", "")
            by_matcher.setdefault(m, {"matcher": m, "hooks": []})
            for h in entry.get("hooks", []):
                existing = by_matcher[m]["hooks"]
                # Dedup by (type, command | prompt | url | server+tool)
                key = (
                    h.get("type"),
                    h.get("command")
                    or h.get("prompt")
                    or h.get("url")
                    or f"{h.get('server')}::{h.get('tool')}",
                )
                if not any(
                    (
                        e.get("type"),
                        e.get("command")
                        or e.get("prompt")
                        or e.get("url")
                        or f"{e.get('server')}::{e.get('tool')}",
                    )
                    == key
                    for e in existing
                ):
                    existing.append(h)

        # Drop matcher entries with empty hooks (can happen if both sides empty)
        merged[event] = [v for v in by_matcher.values() if v["hooks"] or v["matcher"] == ""]
    return merged


def merge_env(repo, local):
    """Local wins — env contains machine-specific secrets."""
    merged = dict(repo or {})
    merged.update(local or {})
    return merged


def merge_object_repo_wins(repo, local):
    """Shallow object merge, repo wins on collision."""
    merged = dict(local or {})
    merged.update(repo or {})
    return merged


def merge_settings(repo, local):
    merged = {}
    all_keys = set(repo.keys()) | set(local.keys())

    for key in all_keys:
        r = repo.get(key)
        l = local.get(key)

        if key == "permissions":
            merged[key] = merge_permissions(r or {}, l or {})
        elif key == "hooks":
            merged[key] = merge_hooks(r, l)
        elif key == "env":
            merged[key] = merge_env(r, l)
        elif key in ("enabledPlugins", "extraKnownMarketplaces", "pluginConfigs"):
            merged[key] = merge_object_repo_wins(r, l)
        else:
            # Default: repo wins if present, else keep local
            merged[key] = r if r is not None else l

    return merged


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <repo-settings> <local-settings>", file=sys.stderr)
        sys.exit(2)

    repo_path = Path(sys.argv[1])
    local_path = Path(sys.argv[2])

    if not repo_path.is_file():
        print(f"repo settings not found: {repo_path}", file=sys.stderr)
        sys.exit(1)

    with repo_path.open() as f:
        repo = json.load(f)

    if local_path.is_file():
        with local_path.open() as f:
            local = json.load(f)
    else:
        local = {}

    merged = merge_settings(repo, local)
    json.dump(merged, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
