"""Unit tests for CLI argument validation and card construction."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from eo_review.cli import build_parser  # noqa: E402
from eo_review.models import UNASSIGNED, Story, TeamReview  # noqa: E402
from eo_review.rules import evaluate  # noqa: E402
from eo_review.teams import build_card  # noqa: E402


def make_story(**overrides) -> Story:
    defaults = dict(
        id=1000,
        title="PaxHub - Test - Story",
        state="Accepted",
        assignee="Doe, Jane",
        upn="123456@corpaa.aa.com",
    )
    defaults.update(overrides)
    return Story(**defaults)


def make_review(stories) -> TeamReview:
    return TeamReview("dfw", "DFW", "DFW_Sprint_35_2026", "path", stories, evaluate(stories))


def make_review_with_po(stories, po_name: str) -> TeamReview:
    return TeamReview(
        "dfw",
        "DFW",
        "DFW_Sprint_35_2026",
        "path",
        stories,
        evaluate(stories, po_name=po_name),
    )


class TestArgumentValidation:
    @pytest.mark.parametrize(
        "value,expected",
        [("DFW", "dfw"), ("dfw", "dfw"), ("DfW", "dfw"), ("HYD", "hyd"), ("Both", "both")],
    )
    def test_valid_values_are_normalised(self, value, expected):
        assert build_parser().parse_args([value]).team == expected

    @pytest.mark.parametrize("value", ["ORD", "all", "dfw hyd", "", "DFW,HYD", "none"])
    def test_invalid_values_exit_without_running(self, value):
        with pytest.raises(SystemExit) as exc:
            build_parser().parse_args([value])
        assert exc.value.code == 2

    def test_team_argument_is_required(self):
        with pytest.raises(SystemExit):
            build_parser().parse_args([])

    def test_console_is_the_default_and_post_is_opt_in(self):
        assert build_parser().parse_args(["DFW"]).post is False
        assert build_parser().parse_args(["DFW", "--post"]).post is True


class TestCardConstruction:
    def test_clean_card_is_normal_importance_with_no_mentions(self):
        card = build_card(make_review([make_story(id=1), make_story(id=2)]))
        content = card["attachments"][0]["content"]
        assert card["importance"] == "normal"
        assert "msteams" not in content
        assert content["body"][0]["color"] == "Good"
        assert "All 2 stories are Accepted" in content["body"][1]["text"]

    def test_findings_card_is_high_importance_with_mentions(self):
        card = build_card(make_review([make_story(id=1, state="In-Progress")]))
        content = card["attachments"][0]["content"]
        assert card["importance"] == "high"
        assert content["body"][0]["text"] == "! IMPORTANT"
        assert content["body"][0]["color"] == "Attention"
        assert "Close of Business" in content["body"][2]["text"]
        entities = content["msteams"]["entities"]
        assert entities[0]["mentioned"]["id"] == "123456@corpaa.aa.com"

    def test_each_person_is_mentioned_once_across_multiple_findings(self):
        stories = [
            make_story(id=1, state="In-Progress"),
            make_story(id=2, state="Defined"),
        ]
        content = build_card(make_review(stories))["attachments"][0]["content"]
        assert len(content["msteams"]["entities"]) == 1

    def test_unassigned_finding_emits_no_mention_entity(self):
        stories = [make_story(id=1, state="Defined", assignee=UNASSIGNED, upn=None)]
        content = build_card(make_review(stories))["attachments"][0]["content"]
        assert "msteams" not in content
        assert "<at>" not in content["body"][3]["text"]

    def test_story_link_is_rendered_as_markdown(self):
        content = build_card(make_review([make_story(id=42, state="Defined")]))
        text = content["attachments"][0]["content"]["body"][3]["text"]
        assert "[42](https://dev.azure.com/AmericanAirlines/PassengerDataHub" in text

    def test_completed_story_finding_names_the_team_po(self):
        content = build_card(
            make_review_with_po(
                [make_story(id=42, state="Completed", attachment_count=1)],
                po_name="Hamandi, Joseph",
            )
        )
        text = content["attachments"][0]["content"]["body"][3]["text"]
        assert text.startswith("@Hamandi, Joseph - [42]")
        assert "Doe, Jane" not in text
