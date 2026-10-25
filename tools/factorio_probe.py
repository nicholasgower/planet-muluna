#!/usr/bin/env python3
"""Build a Factorio mod directory, dump final prototypes, and inspect load order.

This is a development helper for data-stage bugs in planet-muluna. It is not
shipped with the mod. The most useful command is ``dump``:

    python3 tools/factorio_probe.py dump

By default it uses the installed mod directory and its mod-list.json, selects
the highest version of every enabled mod, links them into a scratch directory,
and runs Factorio with ``--dump-data``. That runs the complete data stage but
does not generate or load a map, so it finishes in seconds. The result is a JSON
copy of the final ``data.raw`` that can be inspected with tools/proto_query.py.

Use ``--add-mod`` to append a development mod such as the FUnit companion mod
to the generated mod list. It is appended at the end so its data-final-fixes
runs after the normal mods.

    python3 tools/factorio_probe.py dump \\
        --add-mod test-mods/planet-muluna-funit

The ``load-order`` command turns a Factorio log into a compact list of when each
mod ran its data-stage files:

    python3 tools/factorio_probe.py load-order /tmp/opencode/factorio-probe/stdout.log

Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Iterable, NoReturn

DEFAULT_FACTORIO_BIN = os.environ.get(
    "FACTORIO_BIN", "/opt/factorio_space_age_21/bin/x64/factorio"
)
DEFAULT_MODS_DIR = os.environ.get(
    "FACTORIO_MODS", "/opt/factorio_space_age_21/mods"
)
DEFAULT_WORK_DIR = os.environ.get(
    "FACTORIO_PROBE_DIR", "/tmp/opencode/factorio-probe"
)

# These are shipped with Factorio and are not present in the mods directory.
BUILTIN_MODS = {"base", "elevated-rails", "quality", "recycler", "space-age"}

VERSION_RE = re.compile(r"^\d+(?:\.\d+)*$")
LOAD_LINE_RE = re.compile(
    r"^\s*(?P<time>[\d.]+) Loading mod "
    r"(?P<name>\S+) (?P<version>\S+) "
    r"\((?P<stage>settings|data|data-updates|data-final-fixes)\.lua\)"
)


def fail(message: str) -> NoReturn:
    print(f"factorio_probe: {message}", file=sys.stderr)
    raise SystemExit(2)


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def mod_info_from_path(path: Path) -> dict:
    """Read info.json from a mod directory or zip."""
    path = path.resolve()
    if path.is_dir():
        info = path / "info.json"
        if not info.is_file():
            fail(f"{path} is not a mod directory (no info.json).")
        with info.open(encoding="utf-8") as handle:
            return json.load(handle)

    if path.suffix.lower() != ".zip":
        fail(f"{path} is neither a mod directory nor a .zip file.")

    try:
        with zipfile.ZipFile(path) as archive:
            candidates = [
                name
                for name in archive.namelist()
                if name == "info.json"
                or (name.endswith("/info.json") and name.count("/") == 1)
            ]
            if not candidates:
                fail(f"{path} does not contain an info.json.")
            with archive.open(sorted(candidates, key=len)[0]) as handle:
                return json.load(handle)
    except zipfile.BadZipFile:
        fail(f"{path} is not a valid zip file.")


def mod_name_from_path(path: Path) -> str:
    return mod_info_from_path(path)["name"]


def required_dependency_name(dependency: str) -> str | None:
    """Return the mod name for a required dependency, or None for optional ones."""
    dependency = dependency.strip()
    if not dependency or dependency[0] in "?!+" or dependency.startswith("(?)"):
        return None
    return re.split(r"[ <>=]", dependency, maxsplit=1)[0]


def choose_mod_source(mods_dir: Path, name: str) -> Path | None:
    """Return the directory or highest-version zip for a mod name."""
    directory = mods_dir / name
    if directory.exists():
        return directory

    candidates: list[tuple[tuple[int, ...], Path]] = []
    prefix = name + "_"
    for entry in mods_dir.iterdir():
        if not entry.is_file() or entry.suffix.lower() != ".zip":
            continue
        if not entry.name.startswith(prefix):
            continue
        version = entry.name[len(prefix) : -len(".zip")]
        if VERSION_RE.fullmatch(version):
            candidates.append((version_key(version), entry))

    if not candidates:
        return None
    candidates.sort(key=lambda item: item[0])
    return candidates[-1][1]


def safe_symlink(source: Path, destination: Path) -> None:
    if destination.is_symlink() or destination.exists():
        try:
            if destination.resolve() == source.resolve():
                return
        except OSError:
            pass
        fail(
            f"two enabled mods resolve to the same directory name: "
            f"{destination.name} ({source})"
        )
    destination.symlink_to(source)


def load_mod_list(path: Path) -> dict:
    if not path.is_file():
        fail(f"mod list not found: {path}")
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def build_mod_directory(
    source_dir: Path,
    mod_list_path: Path,
    destination: Path,
    add_mods: Iterable[Path],
) -> dict:
    """Create a scratch mod directory from a mod list and optional extra mods."""
    if not source_dir.is_dir():
        fail(f"mod directory not found: {source_dir}")
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)

    mod_list = load_mod_list(mod_list_path)
    entries = [dict(entry) for entry in mod_list.get("mods", [])]
    by_name = {entry.get("name"): entry for entry in entries}

    # Extra mods are appended so their data-final-fixes runs last. Their plain
    # required dependencies are pulled in from the source mod directory too, so
    # a development mod works even when its test-only dependencies are absent
    # from the installed mod-list (for example funit).
    extra_paths: dict[str, Path] = {}
    extra_infos: list[dict] = []
    for extra in add_mods:
        extra = extra.resolve()
        info = mod_info_from_path(extra)
        name = info["name"]
        extra_paths[name] = extra
        extra_infos.append(info)
        if name in by_name:
            by_name[name]["enabled"] = True
        else:
            entry = {"name": name, "enabled": True}
            entries.append(entry)
            by_name[name] = entry

    processed_dependencies: set[str] = set()
    queue = list(extra_infos)
    while queue:
        info = queue.pop(0)
        for dependency in info.get("dependencies") or []:
            name = required_dependency_name(dependency)
            if not name or name in BUILTIN_MODS or name in processed_dependencies:
                continue
            processed_dependencies.add(name)
            entry = by_name.get(name)
            if entry is None:
                entry = {"name": name, "enabled": True}
                entries.append(entry)
                by_name[name] = entry
            else:
                entry["enabled"] = True
            if name in extra_paths:
                continue
            source = choose_mod_source(source_dir, name)
            if source is not None:
                queue.append(mod_info_from_path(source))

    linked: list[str] = []
    for entry in entries:
        name = entry.get("name")
        if not entry.get("enabled") or not name:
            continue
        # Extra mods may live outside the source directory; link them below.
        if name in extra_paths:
            continue
        source = choose_mod_source(source_dir, name)
        if source is None:
            if name in BUILTIN_MODS:
                continue
            fail(
                f"enabled mod {name!r} is not installed in {source_dir}; "
                "disable it or install it first"
            )
        safe_symlink(source, destination / source.name)
        linked.append(name)

    for name, extra in extra_paths.items():
        safe_symlink(extra, destination / extra.name)
        linked.append(name)

    with (destination / "mod-list.json").open("w", encoding="utf-8") as handle:
        json.dump({"mods": entries}, handle, indent=2)
        handle.write("\n")

    return {
        "mod_dir": str(destination),
        "mod_list": str(mod_list_path),
        "linked_mods": linked,
        "extra_mods": [mod_name_from_path(path) for path in add_mods],
        "entries": entries,
    }


def write_config(work_dir: Path) -> Path:
    write_data = work_dir / "write-data"
    (write_data / "script-output").mkdir(parents=True, exist_ok=True)
    config = work_dir / "config.ini"
    config.write_text(
        "\n".join(
            [
                "; generated by tools/factorio_probe.py",
                "; version=13",
                "[path]",
                "read-data=__PATH__executable__/../../data",
                f"write-data={write_data}",
                "",
                "[general]",
                "locale=en",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return config


def run_dump(args: argparse.Namespace) -> int:
    factorio_bin = Path(args.factorio_bin).expanduser().resolve()
    if not factorio_bin.is_file() or not os.access(factorio_bin, os.X_OK):
        fail(f"Factorio binary not found or not executable: {factorio_bin}")

    source_dir = Path(args.mods_dir).expanduser().resolve()
    mod_list = Path(args.mod_list).expanduser().resolve()
    work_dir = Path(args.work_dir).expanduser().resolve()
    add_mods = [Path(path).expanduser().resolve() for path in args.add_mod]

    work_dir.mkdir(parents=True, exist_ok=True)
    mod_dir = work_dir / "mods"
    info = build_mod_directory(source_dir, mod_list, mod_dir, add_mods)
    config = write_config(work_dir)

    log_path = work_dir / "stdout.log"
    dump_path = work_dir / "write-data" / "script-output" / "data-raw-dump.json"
    if dump_path.exists():
        dump_path.unlink()

    command = [
        str(factorio_bin),
        "--config",
        str(config),
        "--mod-directory",
        str(mod_dir),
        "--dump-data",
        "--no-log-rotation",
    ]

    print(f"factorio_probe: dumping with {len(info['entries'])} mod-list entries", file=sys.stderr)
    print(f"  binary: {factorio_bin}", file=sys.stderr)
    print(f"  mods:   {mod_dir}", file=sys.stderr)
    print(f"  log:    {log_path}", file=sys.stderr)

    timed_out = False
    with log_path.open("w", encoding="utf-8") as log_handle:
        try:
            completed = subprocess.run(
                command,
                stdout=log_handle,
                stderr=subprocess.STDOUT,
                timeout=args.timeout,
                check=False,
            )
            exit_code = completed.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
            exit_code = 124

    if timed_out:
        print(
            f"factorio_probe: data stage did not finish within {args.timeout}s",
            file=sys.stderr,
        )
    elif not dump_path.is_file():
        print(
            f"factorio_probe: no data dump was produced; Factorio exited {exit_code}.",
            file=sys.stderr,
        )
        tail = log_path.read_text(encoding="utf-8", errors="replace").splitlines()[-50:]
        if tail:
            print("\n".join(tail), file=sys.stderr)
        return 1

    result = {
        "status": "passed" if dump_path.is_file() else "failed",
        "dump": str(dump_path),
        "log": str(log_path),
        "mod_dir": str(mod_dir),
        "mod_list": str(mod_list),
        "exit_code": exit_code,
        "timed_out": timed_out,
        **{key: info[key] for key in ("linked_mods", "extra_mods")},
    }

    if args.json:
        print(json.dumps(result))
    else:
        print(f"dump: {dump_path}")
        print(f"log:  {log_path}")
        if info["extra_mods"]:
            print(f"extra mods: {', '.join(info['extra_mods'])}")
        if not args.quiet:
            print(
                "query it with: python3 tools/proto_query.py --dump "
                f"{dump_path} machines --data-ports"
            )

    return 0 if dump_path.is_file() else 1


def run_load_order(args: argparse.Namespace) -> int:
    log_path = Path(args.log).expanduser().resolve()
    if not log_path.is_file():
        fail(f"log not found: {log_path}")

    stages = set(args.stage or ["settings", "data", "data-updates", "data-final-fixes"])
    mod_filter = args.mod.lower() if args.mod else None
    rows: list[dict[str, str]] = []
    for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = LOAD_LINE_RE.match(line)
        if not match:
            continue
        row = match.groupdict()
        if row["stage"] not in stages:
            continue
        if mod_filter and mod_filter not in row["name"].lower():
            continue
        rows.append(row)

    if args.json:
        print(json.dumps(rows))
        return 0

    if not rows:
        print("No matching data-stage load lines found.", file=sys.stderr)
        return 1

    for row in rows:
        print(f"{row['stage']:<18} {row['time']:>8}s  {row['name']} {row['version']}")
    return 0


def add_common_dump_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--factorio-bin",
        default=DEFAULT_FACTORIO_BIN,
        help=f"Factorio executable (default: {DEFAULT_FACTORIO_BIN})",
    )
    parser.add_argument(
        "--mods-dir",
        default=DEFAULT_MODS_DIR,
        help=f"source mod directory (default: {DEFAULT_MODS_DIR})",
    )
    parser.add_argument(
        "--mod-list",
        default=None,
        help="mod-list.json to follow (default: <mods-dir>/mod-list.json)",
    )
    parser.add_argument(
        "--work-dir",
        default=DEFAULT_WORK_DIR,
        help=f"scratch directory (default: {DEFAULT_WORK_DIR})",
    )
    parser.add_argument(
        "--add-mod",
        action="append",
        default=[],
        metavar="PATH",
        help="append a mod directory or zip to the generated mod list (repeatable)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=900,
        help="data-stage timeout in seconds (default: 900)",
    )
    parser.add_argument("--json", action="store_true", help="print a JSON result")
    parser.add_argument(
        "--quiet", action="store_true", help="do not print the follow-up query hint"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Dump Factorio's final prototypes for a mod set, or inspect a "
            "Factorio data-stage log."
        )
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    dump = subparsers.add_parser(
        "dump",
        help="build a mod directory and run Factorio --dump-data",
        description=(
            "Build a scratch mod directory from a mod-list, select the highest "
            "version of each enabled mod, and run Factorio --dump-data."
        ),
    )
    add_common_dump_arguments(dump)
    dump.set_defaults(func=run_dump)

    load_order = subparsers.add_parser(
        "load-order",
        help="show data-stage load order from a Factorio log",
        description=(
            "Extract settings/data/data-updates/data-final-fixes load order "
            "from a Factorio log."
        ),
    )
    load_order.add_argument("log", help="Factorio log file")
    load_order.add_argument(
        "--stage",
        action="append",
        choices=["settings", "data", "data-updates", "data-final-fixes"],
        help="only show this stage (repeatable; default: all)",
    )
    load_order.add_argument("--mod", help="only show mods whose name contains TEXT")
    load_order.add_argument("--json", action="store_true", help="print JSON")
    load_order.set_defaults(func=run_load_order)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command in {"dump"} and args.mod_list is None:
        args.mod_list = str(Path(args.mods_dir).expanduser().resolve() / "mod-list.json")

    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
