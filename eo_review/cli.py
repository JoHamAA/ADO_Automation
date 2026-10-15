"""Command-line entry point for the PAX End-of-Iteration review.

Usage:
    python -m eo_review DFW
    python -m eo_review hyd --post
    python -m eo_review Both --post

The team argument is mandatory and must be DFW, HYD or BOTH (any casing).
Nothing is queried or sent for any other value.
"""

from __future__ import annotations

import argparse
import sys
from typing import List, Sequence

from .ado_client import AdoClient, AdoError
from .config import ConfigError, load_config
from .console import render
from .models import TeamReview
from .review import run_team_review
from .teams import TeamsError, build_card, post_card

VALID_ARGS = ("dfw", "hyd", "both")

EXIT_OK = 0
EXIT_BAD_USAGE = 2
EXIT_RUNTIME_ERROR = 3
EXIT_NO_STORIES = 4


class StrictTeamAction(argparse.Action):
    """Accept only DFW / HYD / BOTH, case-insensitively."""

    def __call__(self, parser, namespace, values, option_string=None):
        normalized = str(values).strip().lower()
        if normalized not in VALID_ARGS:
            parser.error(
                f"invalid team '{values}'. Must be one of: DFW, HYD, BOTH "
                "(case-insensitive). Nothing was executed."
            )
        setattr(namespace, self.dest, normalized)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="eo_review",
        description="End-of-Iteration review for the PaxHub (PAX) backlog.",
    )
    parser.add_argument(
        "team",
        action=StrictTeamAction,
        metavar="{DFW|HYD|BOTH}",
        help="Team to review. Case-insensitive. Required.",
    )
    parser.add_argument(
        "--post",
        action="store_true",
        help="Send the review to the Teams channel. Console-only output otherwise.",
    )
    parser.add_argument(
        "--config",
        default=None,
        help="Path to config.yaml (defaults to .github/config.yaml). Read-only.",
    )
    return parser


def _teams_for(argument: str) -> List[str]:
    return ["dfw", "hyd"] if argument == "both" else [argument]


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        config = load_config(args.config)
        client = AdoClient(config.org_url, config.project)
        # Fail before any query if posting was requested without a webhook.
        webhook_url = config.webhook_url() if args.post else None

        reviews: List[TeamReview] = [
            run_team_review(client, config, team) for team in _teams_for(args.team)
        ]
    except (ConfigError, AdoError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_RUNTIME_ERROR

    exit_code = EXIT_OK
    for review in reviews:
        print(render(review))
        print()

        if review.is_empty:
            # Never broadcast a false all-clear.
            print(
                f"SKIPPED: nothing posted for {review.team_label} "
                "(no stories in iteration).",
                file=sys.stderr,
            )
            exit_code = EXIT_NO_STORIES
            continue

        if args.post:
            try:
                post_card(webhook_url, build_card(review))
            except (TeamsError, OSError) as exc:
                print(f"ERROR posting {review.team_label}: {exc}", file=sys.stderr)
                exit_code = EXIT_RUNTIME_ERROR
            else:
                print(f"POSTED: {review.team_label} review sent to Teams.")

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
