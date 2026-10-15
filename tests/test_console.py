"""Console renderer tests: output must mirror the posted card."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from eo_review.console import render  # noqa: E402
from eo_review.models import Story, TeamReview  # noqa: E402
from eo_review.rules import evaluate  # noqa: E402


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


class TestFindingsOutput:
    def test_summary_precedes_the_message_body(self):
        output = render(make_review([make_story(id=1, state="In-Progress")]))
        assert output.index("1 finding(s)") < output.index("! IMPORTANT")

    def test_full_message_is_shown_not_only_a_summary(self):
        output = render(make_review([make_story(id=1, state="In-Progress")]))
        assert "! IMPORTANT" in output
        assert "DFW - End of Iteration Review - DFW_Sprint_35_2026" in output
        assert "Close of Business" in output
        assert "@Doe, Jane" in output
        assert "Requires update" in output

    def test_mention_markup_is_stripped_and_link_is_expanded(self):
        output = render(make_review([make_story(id=42, state="Defined")]))
        assert "<at>" not in output
        assert "](" not in output
        assert "/_workitems/edit/42" in output

    def test_state_counts_appear_in_the_summary(self):
        stories = [make_story(id=1), make_story(id=2, state="In-Progress")]
        output = render(make_review(stories))
        assert "2 stories (Accepted: 1, In-Progress: 1)" in output
        assert "importance: high" in output


class TestCleanAndEmptyOutput:
    def test_clean_sprint_shows_the_posted_wording(self):
        output = render(make_review([make_story(id=1), make_story(id=2)]))
        assert "All 2 stories are Accepted. No actions required." in output
        assert "importance: normal" in output
        assert "! IMPORTANT" not in output

    def test_empty_iteration_warns_and_states_nothing_is_posted(self):
        output = render(TeamReview("dfw", "DFW", "S35", "some/path", [], []))
        assert "no_stories_in_iteration" in output
        assert "Nothing will be posted" in output
