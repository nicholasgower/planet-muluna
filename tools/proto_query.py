#!/usr/bin/env python3
"""Query a Factorio ``--dump-data`` JSON file.

This is a development helper for data-stage bugs in planet-muluna. It is not
shipped with the mod. It reads the JSON produced by Factorio's ``--dump-data``
option, normally via ``tools/factorio_probe.py dump``.

Useful commands:

    # Machines that received a Muluna-style data port
    python3 tools/proto_query.py --dump DUMP.json machines --data-ports

    # Fluid recipes without an explicit fluidbox_index
    python3 tools/proto_query.py --dump DUMP.json recipes \\
        --category crafting-with-fluid --missing-fluidbox-index

    # Verify that regular fluids cannot use an advanced machine's data port
    python3 tools/proto_query.py --dump DUMP.json data-port-invariant

    # Read the data-stage FUnit result bag
    python3 tools/proto_query.py --dump DUMP.json funit-results

Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, NoReturn

DEFAULT_DUMP = os.environ.get(
    "FACTORIO_DUMP",
    "/tmp/opencode/factorio-probe/write-data/script-output/data-raw-dump.json",
)
FUNIT_RESULTS = "planet-muluna-funit-results"
EXPLORATION_CONDITIONS = "muluna-interstellar-science-pack-conditions"


def fail(message: str) -> NoReturn:
    print(f"proto_query: {message}", file=sys.stderr)
    raise SystemExit(2)


def load_dump(path: str) -> dict[str, Any]:
    dump_path = Path(path).expanduser().resolve()
    if not dump_path.is_file():
        fail(
            f"prototype dump not found: {dump_path}\n"
            "Run tools/factorio_probe.py dump (or tools/ci/funit.sh --data-only) first."
        )
    try:
        with dump_path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        fail(f"could not read {dump_path}: {error}")


def has_data_category(value: Any) -> bool:
    """Connection categories may be a string or a list of strings."""
    if value == "data":
        return True
    if isinstance(value, list):
        return "data" in value
    return False


def data_port_indexes(machine: dict[str, Any]) -> dict[str, list[int]]:
    """Return input/output data-port ordinals for an assembling machine.

    Recipe fluidbox indexes count input and output fluidboxes separately.
    """
    ports: dict[str, list[int]] = {"input": [], "output": []}
    input_index = 0
    output_index = 0
    for box in machine.get("fluid_boxes") or []:
        production_type = box.get("production_type")
        if production_type == "input":
            input_index += 1
        elif production_type == "output":
            output_index += 1

        is_data = has_data_category(box.get("connection_category"))
        for connection in box.get("pipe_connections") or []:
            if has_data_category(connection.get("connection_category")):
                is_data = True
                break

        if is_data and production_type in ports:
            ports[production_type].append(
                input_index if production_type == "input" else output_index
            )
    return ports


def machine_categories(machine: dict[str, Any]) -> list[str]:
    return list(machine.get("crafting_categories") or [])


def recipe_categories(recipe: dict[str, Any]) -> list[str]:
    return list(recipe.get("categories") or ["crafting"])


def is_craftable(machine: dict[str, Any], recipe: dict[str, Any]) -> bool:
    """Recipe categories are alternatives, so any shared category is enough."""
    available = set(machine_categories(machine))
    return any(category in available for category in recipe_categories(recipe))


def fluid_entries(recipe: dict[str, Any], kind: str) -> list[dict[str, Any]]:
    key = "ingredients" if kind == "ingredient" else "results"
    return [entry for entry in recipe.get(key) or [] if entry.get("type") == "fluid"]


def may_use_index(entry: dict[str, Any], index: int) -> bool:
    primary = entry.get("fluidbox_index")
    if primary in (None, 0):
        return True
    if primary == index:
        return True
    return index in (entry.get("optional_fluidbox_indexes") or [])


def advanced_machines(
    dump: dict[str, Any], wanted_categories: list[str]
) -> list[tuple[str, dict[str, Any], dict[str, list[int]]]]:
    wanted = set(wanted_categories)
    result = []
    for name, machine in (dump.get("assembling-machine") or {}).items():
        ports = data_port_indexes(machine)
        if not ports["input"] and not ports["output"]:
            continue
        if not wanted.intersection(machine_categories(machine)):
            continue
        result.append((name, machine, ports))
    return sorted(result, key=lambda item: item[0])


def format_fluid(entry: dict[str, Any]) -> str:
    parts = [str(entry.get("name"))]
    primary = entry.get("fluidbox_index")
    if primary not in (None, 0):
        parts.append(f"index={primary}")
    optional = entry.get("optional_fluidbox_indexes") or []
    if optional:
        parts.append(f"optional={optional[0]}..{optional[-1]}")
    return " ".join(parts)


def command_machines(dump: dict[str, Any], args: argparse.Namespace) -> int:
    rows = []
    for name, machine in sorted((dump.get("assembling-machine") or {}).items()):
        categories = machine_categories(machine)
        if args.category and not all(category in categories for category in args.category):
            continue
        if args.advanced and not (
            "crafting-with-fluid" in categories
            or "crafting-with-fluid-and-data" in categories
        ):
            continue
        ports = data_port_indexes(machine)
        if args.data_ports and not ports["input"] and not ports["output"]:
            continue
        rows.append(
            {
                "name": name,
                "data_ports": ports,
                "crafting_categories": categories,
            }
        )

    if args.json:
        print(json.dumps(rows, indent=2))
        return 0

    if not rows:
        print("No matching assembling machines.")
        return 0

    for row in rows:
        ports = row["data_ports"]
        port_text = []
        if ports["input"]:
            port_text.append("input=" + ",".join(map(str, ports["input"])))
        if ports["output"]:
            port_text.append("output=" + ",".join(map(str, ports["output"])))
        suffix = f"  ({'; '.join(port_text)})" if port_text else ""
        print(f"{row['name']}{suffix}")
        if args.categories:
            print("  categories: " + ", ".join(row["crafting_categories"]))
    return 0


def command_recipes(dump: dict[str, Any], args: argparse.Namespace) -> int:
    craftable_machine = None
    if args.craftable_in:
        craftable_machine = (dump.get("assembling-machine") or {}).get(args.craftable_in)
        if not craftable_machine:
            fail(f"assembling machine not found: {args.craftable_in}")

    rows = []
    for name, recipe in sorted((dump.get("recipe") or {}).items()):
        categories = recipe_categories(recipe)
        if args.category and not all(category in categories for category in args.category):
            continue
        if args.name and args.name.lower() not in name.lower():
            continue
        if craftable_machine and not is_craftable(craftable_machine, recipe):
            continue

        ingredients = fluid_entries(recipe, "ingredient")
        products = fluid_entries(recipe, "product")
        if args.fluid:
            matching = [
                entry
                for entry in ingredients + products
                if entry.get("name") == args.fluid
            ]
            if not matching:
                continue
        if args.missing_fluidbox_index:
            missing = [
                entry
                for entry in ingredients + products
                if entry.get("fluidbox_index") in (None, 0)
            ]
            if not missing:
                continue

        rows.append(
            {
                "name": name,
                "categories": categories,
                "fluid_ingredients": ingredients,
                "fluid_products": products,
            }
        )

    if args.json:
        print(json.dumps(rows, indent=2))
        return 0

    if not rows:
        print("No matching recipes.")
        return 0

    for row in rows:
        print(row["name"])
        if args.categories:
            print("  categories: " + ", ".join(row["categories"]))
        if row["fluid_ingredients"]:
            print(
                "  ingredients: "
                + "; ".join(format_fluid(entry) for entry in row["fluid_ingredients"])
            )
        if row["fluid_products"]:
            print(
                "  products: "
                + "; ".join(format_fluid(entry) for entry in row["fluid_products"])
            )
    return 0


def command_data_port_invariant(dump: dict[str, Any], args: argparse.Namespace) -> int:
    machines = advanced_machines(dump, args.machine_category)
    violations = []

    for machine_name, machine, ports in machines:
        for recipe_name, recipe in (dump.get("recipe") or {}).items():
            if not is_craftable(machine, recipe):
                continue
            for kind, port_key in (("ingredient", "input"), ("product", "output")):
                for entry in fluid_entries(recipe, kind):
                    for index in ports[port_key]:
                        # A fluid may use the data port only when it explicitly
                        # names that index. Anything else can be auto-assigned.
                        if may_use_index(entry, index) and entry.get("fluidbox_index") != index:
                            violations.append(
                                {
                                    "recipe": recipe_name,
                                    "kind": kind,
                                    "fluid": entry.get("name"),
                                    "machine": machine_name,
                                    "data_port_index": index,
                                    "fluidbox_index": entry.get("fluidbox_index"),
                                    "optional_fluidbox_indexes": entry.get(
                                        "optional_fluidbox_indexes"
                                    ),
                                }
                            )

    result = {
        "status": "failed" if violations else "passed",
        "machines": [name for name, _machine, _ports in machines],
        "violations": violations,
    }

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        if machines:
            print("advanced data-port machines: " + ", ".join(result["machines"]))
        else:
            print("advanced data-port machines: none")
        if violations:
            print(f"violations: {len(violations)}")
            for violation in violations:
                print(
                    "  {recipe} ({kind} {fluid}) can use data port {index} "
                    "on {machine}".format(
                        recipe=violation["recipe"],
                        kind=violation["kind"],
                        fluid=violation["fluid"],
                        index=violation["data_port_index"],
                        machine=violation["machine"],
                    )
                )
        else:
            print("violations: 0")

    return 1 if violations else 0


def command_funit_results(dump: dict[str, Any], args: argparse.Namespace) -> int:
    bag = (dump.get("mod-data") or {}).get(FUNIT_RESULTS)
    checks = (bag or {}).get("data") or {}

    total = 0
    successes = 0
    failures = 0
    failing_ids = []
    for suite in sorted(checks):
        for check_id in sorted(checks[suite]):
            check = checks[suite][check_id]
            total += 1
            if check.get("ok"):
                successes += 1
            else:
                failures += 1
                failing_ids.append(f"{suite}/{check_id}")

    if not bag:
        status = "missing"
    elif total == 0:
        status = "empty"
    elif failures:
        status = "failed"
    else:
        status = "passed"

    result = {
        "status": status,
        "data_only": True,
        "tests": total,
        "success": successes,
        "failures": failures,
        "errors": 0,
        "failing_test_ids": failing_ids,
        "dump": str(Path(args.dump).expanduser().resolve()),
    }
    if args.log:
        result["log"] = str(Path(args.log).expanduser().resolve())

    if args.json:
        print(json.dumps(result, separators=(",", ":")))
    else:
        print("Data fixture summary")
        print(f"  {'status:':<10} {status}")
        print(f"  {'tests:':<10} {total}")
        print(f"  {'success:':<10} {successes}")
        print(f"  {'failures:':<10} {failures}")
        print(f"  {'errors:':<10} 0")
        print(f"  {'dump:':<10} {result['dump']}")
        if args.log:
            print(f"  {'log:':<10} {result['log']}")
        if failing_ids:
            print("  failing tests:")
            for check_id in failing_ids:
                print(f"    - {check_id}")
        if status == "missing":
            print(
                f"  {FUNIT_RESULTS} mod-data is missing; "
                "is planet-muluna-funit loaded?",
                file=sys.stderr,
            )
        elif status == "empty":
            print(
                "  the result bag is empty; are the data fixtures enabled?",
                file=sys.stderr,
            )

    return 0 if status == "passed" else 1


def command_exploration_science(dump: dict[str, Any], args: argparse.Namespace) -> int:
    mod_data = (dump.get("mod-data") or {}).get(EXPLORATION_CONDITIONS)
    if not mod_data:
        print(
            f"{EXPLORATION_CONDITIONS} mod-data is missing; "
            "is planet-muluna loaded?",
            file=sys.stderr,
        )
        return 1

    conditions = mod_data.get("data") or {}
    packs = []
    for index, pack in enumerate(conditions.get("packs") or [], 1):
        row = {
            "index": index,
            "key": pack.get("key"),
            "item": pack.get("item"),
            "planet": pack.get("planet"),
            "representative": pack.get("representative"),
            "technologies": list(pack.get("technologies") or []),
        }
        for flag in ("baseline", "legacy", "forced"):
            if pack.get(flag):
                row[flag] = True
        packs.append(row)

    result: dict[str, Any] = {
        "gated_technology": conditions.get("gated_technology"),
        "required_science_packs": conditions.get("required_science_packs"),
        "packs": packs,
    }

    if args.rejected:
        result["rejected_items"] = list(
            (conditions.get("diagnostics") or {}).get("rejected_items") or []
        )

    if args.legacy:
        diagnostics = conditions.get("diagnostics") or {}
        legacy_technologies = list(diagnostics.get("legacy_technologies") or [])
        technologies = dump.get("technology") or {}
        result["legacy_extras"] = list(diagnostics.get("legacy_extras") or [])
        result["legacy_technologies"] = legacy_technologies
        result["missing_legacy_technologies"] = [
            name for name in legacy_technologies if name not in technologies
        ]

    missing_required = [
        name
        for name in args.require_pack
        if not any(pack.get("item") == name or pack.get("key") == name for pack in packs)
    ]
    if missing_required:
        result["missing_required_packs"] = missing_required

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(
            "Exploration science packs ({count}, required {required})".format(
                count=len(packs),
                required=result["required_science_packs"],
            )
        )
        for pack in packs:
            flags = [
                flag
                for flag in ("baseline", "legacy", "forced")
                if pack.get(flag)
            ]
            suffix = " [" + ", ".join(flags) + "]" if flags else ""
            print(
                "  {index}. {item} (planet={planet}) representative={representative}{suffix}".format(
                    index=pack["index"],
                    item=pack.get("item") or pack.get("key"),
                    planet=pack.get("planet"),
                    representative=pack.get("representative"),
                    suffix=suffix,
                )
            )
            print("     technologies: " + ", ".join(pack["technologies"]))

        if args.rejected:
            rejected = result.get("rejected_items") or []
            print(f"Rejected items ({len(rejected)})")
            for item in rejected:
                detail = item.get("detail")
                suffix = f" ({detail})" if detail else ""
                print(
                    "  {item}: {reason}{suffix}".format(
                        item=item.get("item"),
                        reason=item.get("reason"),
                        suffix=suffix,
                    )
                )

        if args.legacy:
            extras = result.get("legacy_extras") or []
            missing = result.get("missing_legacy_technologies") or []
            print(
                "Legacy technologies ({total}, missing {missing})".format(
                    total=len(result.get("legacy_technologies") or []),
                    missing=len(missing),
                )
            )
            print("  extras: " + (", ".join(extras) if extras else "none"))
            print("  missing: " + (", ".join(missing) if missing else "none"))

        if missing_required:
            print(
                "Missing required packs: " + ", ".join(missing_required),
                file=sys.stderr,
            )

    return 1 if missing_required else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Query a Factorio --dump-data JSON file."
    )
    parser.add_argument(
        "--dump",
        default=DEFAULT_DUMP,
        help=f"data-raw-dump.json path (default: {DEFAULT_DUMP})",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    machines = subparsers.add_parser("machines", help="list assembling machines")
    machines.add_argument(
        "--data-ports", action="store_true", help="only machines with data ports"
    )
    machines.add_argument(
        "--advanced",
        action="store_true",
        help="only machines with crafting-with-fluid or crafting-with-fluid-and-data",
    )
    machines.add_argument(
        "--category",
        action="append",
        default=[],
        help="only machines that have this crafting category (repeatable)",
    )
    machines.add_argument(
        "--categories", action="store_true", help="print crafting categories"
    )
    machines.add_argument("--json", action="store_true", help="print JSON")
    machines.set_defaults(func=command_machines)

    recipes = subparsers.add_parser("recipes", help="list recipes")
    recipes.add_argument(
        "--category",
        action="append",
        default=[],
        help="only recipes that have this category (repeatable)",
    )
    recipes.add_argument("--fluid", help="only recipes that use this fluid name")
    recipes.add_argument(
        "--missing-fluidbox-index",
        action="store_true",
        help="only recipes with a fluid entry that has no fluidbox_index",
    )
    recipes.add_argument("--name", help="only recipes whose name contains TEXT")
    recipes.add_argument(
        "--craftable-in", metavar="MACHINE", help="only recipes craftable in MACHINE"
    )
    recipes.add_argument(
        "--categories", action="store_true", help="print recipe categories"
    )
    recipes.add_argument("--json", action="store_true", help="print JSON")
    recipes.set_defaults(func=command_recipes)

    invariant = subparsers.add_parser(
        "data-port-invariant",
        help="check that regular fluids cannot use advanced data ports",
        description=(
            "For machines that have a data port and one of the requested "
            "categories, report fluid entries that could be auto-assigned to "
            "the data port instead of naming a different index explicitly."
        ),
    )
    invariant.add_argument(
        "--machine-category",
        action="append",
        default=None,
        help=(
            "machine category to include (repeatable; default: crafting-with-fluid "
            "and crafting-with-fluid-and-data)"
        ),
    )
    invariant.add_argument("--json", action="store_true", help="print JSON")
    invariant.set_defaults(func=command_data_port_invariant)

    results = subparsers.add_parser(
        "funit-results",
        help="summarize the planet-muluna-funit data-stage result bag",
    )
    results.add_argument("--log", help="Factorio log path to include in the summary")
    results.add_argument("--json", action="store_true", help="print JSON")
    results.set_defaults(func=command_funit_results)

    exploration = subparsers.add_parser(
        "exploration-science",
        help="show the discovered exploration science pack groups",
    )
    exploration.add_argument(
        "--rejected",
        action="store_true",
        help="include rejected lab science pack items and their reasons",
    )
    exploration.add_argument(
        "--legacy",
        action="store_true",
        help="include legacy extras and missing legacy technology names",
    )
    exploration.add_argument(
        "--require-pack",
        action="append",
        default=[],
        metavar="NAME",
        help="exit 1 when NAME is not an item or key in the pack list (repeatable)",
    )
    exploration.add_argument("--json", action="store_true", help="print JSON")
    exploration.set_defaults(func=command_exploration_science)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "data-port-invariant" and args.machine_category is None:
        args.machine_category = ["crafting-with-fluid", "crafting-with-fluid-and-data"]
    dump = load_dump(args.dump)
    return args.func(dump, args)


if __name__ == "__main__":
    raise SystemExit(main())
