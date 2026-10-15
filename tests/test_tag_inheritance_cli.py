"""Tests for tag-inheritance command parsing and output."""

from __future__ import annotations

import pytest

from tag_inheritance.cli import _parse_exclusions, build_parser
from tag_inheritance.console import render_audit, render_plan
from tag_inheritance.models import TeamTagAudit, TagWorkItem, compare_tags


def test_exclusions_accept_commas_spaces_and_repeated_flags():
    args = build_parser().parse_args(
        ["sync", "BOTH", "--exclude", "12345,", "123532", "--exclude", "99"]
    )

    assert args.team == "both"
    assert _parse_exclusions(args.exclude) == {99, 12345, 123532}


@pytest.mark.parametrize(
    "argv,expected_sprint",
    [
        (["sync", "BOTH"], None),
        (["sync", "BOTH", "39"], 39),
        (["scan", "DFW", "39", "--exclude", "123"], 39),
    ],
)
def test_optional_sprint_number_parses(argv, expected_sprint):
    assert build_parser().parse_args(argv).sprint_number == expected_sprint


@pytest.mark.parametrize("value", ["0", "-1", "abc"])
def test_optional_sprint_number_must_be_positive_integer(value):
    with pytest.raises(SystemExit):
        build_parser().parse_args(["sync", "BOTH", value])


@pytest.mark.parametrize("value", ["abc", "0", "-2", "1,,2"])
def test_exclusions_reject_invalid_ids(value):
    with pytest.raises(ValueError):
        _parse_exclusions([[value]])


def test_console_keeps_excluded_story_visible_with_missing_tags():
    story = TagWorkItem(1, "Excluded story", "User Story", (), 1, (10,))
    parent = TagWorkItem(10, "Feature", "Feature", ("Run", "Parent Tag"), 1)
    report = TeamTagAudit(
        "dfw",
        "DFW",
        "Sprint 1",
        "Project\\Sprint 1",
        [compare_tags(story, parent, "S-DFW", excluded=True)],
    )

    output = render_audit(report)

    assert "EXCLUDED" in output
    assert "Parent Tag" in output
    assert "Excluded: 1" in output
    assert "Planned updates: 0" in output


def test_sync_preview_shows_additions_removals_and_final_tags():
    story = TagWorkItem(
        1,
        "Conflicting story",
        "User Story",
        ("S-HYD", "Run", "Story Only"),
        1,
        (10,),
    )
    parent = TagWorkItem(10, "Feature", "Feature", ("Initiative",), 1)

    output = render_plan([compare_tags(story, parent, "S-DFW")])

    assert "add: Initiative; S-DFW" in output
    assert "remove: S-HYD; Run" in output
    assert "final: Story Only; Initiative; S-DFW" in output