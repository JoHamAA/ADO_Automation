"""Tests for exact parent-tag inheritance rules."""

import pytest

from tag_inheritance.models import ImageTagMatch, TagWorkItem, compare_tags, parse_tags


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