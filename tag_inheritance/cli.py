"""Command-line entry point for parent Feature tag inheritance."""

from __future__ import annotations

import argparse
import os
import sys
import threading
import time
from pathlib import Path
from typing import List, Sequence, Set

from eo_review.ado_client import AdoError
from eo_review.config import ConfigError, load_config

from . import image_tags
from .audit import audit_team, selected_story_ids, synchronize
from .client import TagInheritanceClient
from .console import render_audit, render_outcomes, render_plan
from .image_tags import KeywordCache

VALID_TEAMS = ("dfw", "hyd", "both")

EXIT_OK = 0
EXIT_FINDINGS = 1
EXIT_BAD_USAGE = 2
EXIT_RUNTIME_ERROR = 3
EXIT_NO_STORIES = 4

_run_clock = {"started": 0.0, "reported": True}
_print_lock = threading.Lock()
DEFAULT_WORKERS = min(4, os.cpu_count() or 1)


def _team(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in VALID_TEAMS:
        raise argparse.ArgumentTypeError("must be DFW, HYD, or BOTH")
    return normalized


def _sprint_number(value: str) -> int:
    try:
        sprint_number = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("sprint number must be a positive integer") from exc
    if sprint_number <= 0:
        raise argparse.ArgumentTypeError("sprint number must be a positive integer")
    return sprint_number


def _worker_count(value: str) -> int:
    try:
        count = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("workers must be a positive integer") from exc
    if count <= 0:
        raise argparse.ArgumentTypeError("workers must be a positive integer")
    return count


def _parse_exclusions(groups: Sequence[Sequence[str]]) -> Set[int]:
    exclusions: Set[int] = set()
    for group in groups:
        combined = " ".join(group)
        parts = combined.split(",")
        if any(not part.strip() for part in parts):
            raise ValueError("excluded IDs must be comma-separated positive integers")
        for part in parts:
            try:
                item_id = int(part.strip())
            except ValueError as exc:
                raise ValueError(
                    "excluded IDs must be comma-separated positive integers"
                ) from exc
            if item_id <= 0:
                raise ValueError("excluded IDs must be positive integers")
            exclusions.add(item_id)
    return exclusions


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="tag_inheritance",
        description="Audit or synchronize parent Feature tags on current-iteration stories.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("scan", "sync"):
        command_parser = subparsers.add_parser(command)
        command_parser.add_argument("team", type=_team, metavar="{DFW|HYD|BOTH}")
        command_parser.add_argument(
            "sprint_number",
            nargs="?",
            type=_sprint_number,
            help="Inspect the matching past sprint number instead of the current sprint.",
        )
        command_parser.add_argument(
            "--exclude",
            action="append",
            nargs="+",
            default=[],
            metavar="ID[,ID...]",
            help="Keep story IDs visible but exclude them from synchronization.",
        )
        command_parser.add_argument(
            "--config",
            type=Path,
            default=None,
            help="Path to config.yaml (defaults to .github/config.yaml).",
        )
        command_parser.add_argument(
            "--workers",
            type=_worker_count,
            default=DEFAULT_WORKERS,
            help=f"Stories to scan concurrently (default {DEFAULT_WORKERS}).",
        )
        command_parser.add_argument(
            "--skip-images",
            action="store_true",
            help="Skip OCR of embedded images (fast; image-derived tags are not checked).",
        )
    return parser


def _teams_for(argument: str) -> List[str]:
    return ["dfw", "hyd"] if argument == "both" else [argument]


def _report_runtime() -> None:
    """Print elapsed time once, at the first of: approval prompt shown or command exit."""
    if _run_clock["reported"]:
        return
    _run_clock["reported"] = True
    minutes, seconds = divmod(time.perf_counter() - _run_clock["started"], 60)
    print(f"Total runtime: {int(minutes)}m {seconds:.1f}s", file=sys.stderr)


def main(argv: Sequence[str] | None = None) -> int:
    """Run the command; runtime excludes the approval wait and the sync writes."""
    _run_clock.update(started=time.perf_counter(), reported=False)
    try:
        return _run(argv)
    finally:
        _report_runtime()


def _run(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        excluded_ids = _parse_exclusions(args.exclude)
    except ValueError as exc:
        parser.error(str(exc))

    try:
        config = load_config(args.config)
        client = TagInheritanceClient(config.org_url, config.project)

        def progress(message: str) -> None:
            with _print_lock:
                print(message, file=sys.stderr, flush=True)

        # Split cores across workers so concurrent OCR engines don't oversubscribe the CPU.
        image_tags.OCR_THREADS = max(1, min(4, (os.cpu_count() or 4) // args.workers))

        try:
            client.ocr_cache = KeywordCache()
            client.progress = lambda message: progress(f"    {message}")
        except AttributeError:
            pass  # Test doubles may not accept extra attributes.
        reports = [
            audit_team(
                client,
                config,
                team,
                excluded_ids,
                args.sprint_number,
                scan_images=not args.skip_images,
                progress=progress,
                workers=args.workers,
            )
            for team in _teams_for(args.team)
        ]
    except (ConfigError, AdoError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_RUNTIME_ERROR

    for report in reports:
        print(render_audit(report))
        print()

    selected_ids = selected_story_ids(reports)
    unmatched = sorted(excluded_ids - selected_ids)
    for item_id in unmatched:
        print(f"UNMATCHED EXCLUSION | {item_id} | not in the selected current iteration(s)")

    if not selected_ids:
        return EXIT_NO_STORIES

    has_findings = any(
        result.tags_to_add or result.tags_to_remove or result.issue
        for report in reports
        for result in report.results
    )
    if args.command == "scan":
        return EXIT_FINDINGS if has_findings else EXIT_OK

    planned = [result for report in reports for result in report.planned_updates]
    if not planned:
        print("No eligible tag updates to apply.")
        unresolved = any(
            result.issue and not result.excluded
            for report in reports
            for result in report.results
        )
        return EXIT_FINDINGS if unresolved else EXIT_OK

    print(render_plan(planned))
    _report_runtime()
    try:
        approval = input("Type YES to apply these changes: ")
    except EOFError:
        approval = ""
    if approval != "YES":
        print("CANCELLED: no work items were changed.")
        return EXIT_OK

    outcomes = synchronize(client, planned)
    print(render_outcomes(outcomes))
    if any(not outcome.succeeded for outcome in outcomes):
        return EXIT_RUNTIME_ERROR
    unresolved = any(
        result.issue for report in reports for result in report.results
    )
    return EXIT_FINDINGS if unresolved else EXIT_OK


if __name__ == "__main__":
    raise SystemExit(main())
