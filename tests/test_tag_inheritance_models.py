"""Tests for exact parent-tag inheritance rules."""

import pytest

from tag_inheritance.models import ImageTagMatch, TagWorkItem, compare_tags, parse_tags
from tag_inheritance.quarter_tags import is_quarter_tag, quarter_tag


def make_item(
    item_id: int,
    tags: tuple[str, ...],
    title: str | None = None,
) -> TagWorkItem:
    return TagWorkItem(item_id, title or f"Item {item_id}", "User Story", tags, 1)


def test_parse_tags_trims_delimiter_formatting_but_preserves_internal_spaces():
    assert parse_tags(" Cloud Data ;cloud;  API Gateway ") == (
        "Cloud Data",
        "cloud",
        "API Gateway",
    )


def test_compare_is_case_sensitive_and_preserves_story_only_tags():
    story = make_item(1, ("cloud", "Story Only"))
    parent = make_item(2, ("Initiative", "Cloud", "Shared"))

    result = compare_tags(story, parent, "S-DFW")

    assert result.status == "MISSING"
    assert result.tags_to_add == ("Initiative", "Cloud", "Shared", "S-DFW")
    assert result.proposed_tags == (
        "cloud",
        "Story Only",
        "Initiative",
        "Cloud",
        "Shared",
        "S-DFW",
    )


def test_excluded_story_remains_visible_with_its_missing_tags():
    result = compare_tags(
        make_item(1, ()),
        make_item(2, ("Run", "Parent Tag")),
        "S-HYD",
        excluded=True,
    )

    assert result.status == "EXCLUDED"
    assert result.tags_to_add == ("Run", "Parent Tag", "S-HYD")


def test_conflicting_team_and_classification_tags_are_replaced():
    story = make_item(1, ("S-HYD", "Run", "Story Only"))
    parent = make_item(2, ("Initiative",))

    result = compare_tags(story, parent, "S-DFW")

    assert result.status == "CONFLICT"
    assert result.tags_to_remove == ("S-HYD", "Run")
    assert result.tags_to_add == ("Initiative", "S-DFW")
    assert result.proposed_tags == ("Story Only", "Initiative", "S-DFW")


def test_image_keyword_tag_is_added_once_without_case_variant_duplicate():
    story = make_item(1, ("mutation",))
    parent = make_item(2, ("Run",))
    match = ImageTagMatch("Mutation", "mutation", "Notes")

    result = compare_tags(
        story,
        parent,
        "S-DFW",
        image_tag_matches=(match, match),
    )

    assert result.tags_to_add == ("Run", "S-DFW")
    assert result.proposed_tags.count("mutation") == 1


@pytest.mark.parametrize(
    "title,expected_tag",
    [
        ("PaxHub - PROD READINESS", "PROD Readiness"),
        ("PaxHub - p r o d\t r e a d i n e s", "PROD Readiness"),
        ("PaxHub - Production Readines", "PROD Readiness"),
        ("PaxHub - Production Readiness", "PROD Readiness"),
        ("PaxHub - PROD DEPLOYMENT", "PROD Deploy"),
        ("PaxHub - Production Deployment", "PROD Deploy"),
        ("PaxHub - Production Deployement", "PROD Deploy"),
    ],
)
def test_compare_adds_title_based_production_tags(title, expected_tag):
    result = compare_tags(
        make_item(1, (), title),
        make_item(2, ("Run",)),
        "S-DFW",
    )

    assert expected_tag in result.tags_to_add


@pytest.mark.parametrize(
    "title",
    [
        "PaxHub - Nonprod readiness checks",
        "PaxHub - PROD only",
    ],
)
def test_compare_does_not_match_unrelated_production_title_text(title):
    result = compare_tags(
        make_item(1, (), title),
        make_item(2, ("Run",)),
        "S-DFW",
    )

    assert "PROD Readiness" not in result.tags_to_add
    assert "PROD Deploy" not in result.tags_to_add


@pytest.mark.parametrize("parent_tags", [(), ("Run", "Initiative")])
def test_invalid_parent_classification_is_unresolved(parent_tags):
    result = compare_tags(make_item(1, ()), make_item(2, parent_tags), "S-DFW")

    assert result.status == "UNRESOLVED"
    assert result.proposed_tags == ()


@pytest.mark.parametrize("tag", [
    "3Q26", "26Q4", "Q3 2026", "2026Q3", "4Q2026", "q4-26",
    "2026_Q_4", "Q20264", "426Q", "26 4 Q", " 4.Q.26 ",
])
def test_recognizes_standalone_quarter_year_formats(tag):
    assert is_quarter_tag(tag)


@pytest.mark.parametrize("tag", [
    "TECH-OBJ1-KR2", "MongoPNR", "Release 3Q26", "3Q26 readiness",
    "5Q26", "Q0 2026", "Q4", "2026", "Security & Compliance",
])
def test_does_not_remove_unrelated_or_non_quarter_tags(tag):
    assert not is_quarter_tag(tag)


@pytest.mark.parametrize("start,expected", [
    ("2026-03-31T00:00:00Z", "1Q26"),
    ("2026-04-01T00:00:00Z", "2Q26"),
    ("2026-07-01T00:00:00Z", "3Q26"),
    ("2026-09-30T00:00:00Z", "3Q26"),
    ("2026-10-01T00:00:00Z", "4Q26"),
    ("2026-12-31T00:00:00Z", "4Q26"),
    ("2027-01-01T00:00:00Z", "1Q27"),
])
def test_quarter_uses_iteration_calendar_start_date(start, expected):
    assert quarter_tag(start) == expected


def test_quarter_replacement_is_exclusive_and_idempotent():
    story = make_item(1, ("Run", "S-DFW", "3Q26", "26Q4", "4Q26", "Other"))
    parent = make_item(2, ("Run", "2Q26", "Shared"))
    result = compare_tags(story, parent, "S-DFW", expected_quarter_tag="4Q26")
    assert result.tags_to_remove == ("3Q26", "26Q4")
    assert result.proposed_tags == ("Run", "S-DFW", "4Q26", "Other", "Shared")
    repeated = compare_tags(
        make_item(1, result.proposed_tags), parent, "S-DFW", expected_quarter_tag="4Q26"
    )
    assert repeated.status == "COMPLIANT"