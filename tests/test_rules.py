"""Unit tests for the EO rule engine. No network access required."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from eo_review.models import UNASSIGNED, Story, TeamReview  # noqa: E402
from eo_review.rules import (  # noqa: E402
    NEEDS_PO_ACCEPTANCE,
    evaluate,
    evaluate_story,
    stories_needing_comment_check,
)


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


class TestRule1ProofOfWork:
    def test_completed_without_evidence_is_flagged(self):
        findings = evaluate_story(make_story(state="Completed"))
        assert len(findings) == 1
        assert "Missing proof of work" in findings[0].issue
        assert "PO must review and move it to Accepted" in findings[0].issue

    def test_completed_without_evidence_mentions_configured_po(self):
        findings = evaluate_story(make_story(state="Completed"), po_name="Hamandi, Joseph")
        assert "@Hamandi, Joseph" in findings[0].issue

    def test_completed_with_attachment_needs_po_acceptance(self):
        findings = evaluate_story(make_story(state="Completed", attachment_count=1))
        assert len(findings) == 1
        assert findings[0].issue == NEEDS_PO_ACCEPTANCE

    def test_completed_with_attachment_mentions_configured_po(self):
        findings = evaluate_story(
            make_story(state="Completed", attachment_count=1), po_name="Kumar, Vinod"
        )
        assert findings[0].assignee == "@Kumar, Vinod"
        assert findings[0].issue == NEEDS_PO_ACCEPTANCE

    def test_completed_with_comment_image_needs_po_acceptance(self):
        story = make_story(state="Completed", has_comment_image=True)
        findings = evaluate_story(story)
        assert len(findings) == 1
        assert findings[0].issue == NEEDS_PO_ACCEPTANCE

    def test_accepted_is_never_checked_for_proof(self):
        assert evaluate_story(make_story(state="Accepted")) == []


class TestRule2RequiresUpdate:
    @pytest.mark.parametrize("state", ["Backlog", "Defined", "In-Progress"])
    def test_non_terminal_states_are_flagged(self, state):
        findings = evaluate_story(make_story(state=state))
        assert len(findings) == 1
        assert "Requires update" in findings[0].issue
        assert "Mark it as Completed" in findings[0].issue
        assert state in findings[0].issue

    def test_accepted_is_not_flagged_by_rule_2(self):
        assert evaluate_story(make_story(state="Accepted", attachment_count=1)) == []

    def test_a_story_never_produces_two_findings(self):
        assert len(evaluate_story(make_story(state="Completed"))) == 1


class TestSorting:
    def test_unassigned_sorts_first(self):
        stories = [
            make_story(id=2, state="Defined", assignee="Alpha, Ann"),
            make_story(id=1, state="Defined", assignee=UNASSIGNED, upn=None),
        ]
        findings = evaluate(stories)
        assert findings[0].assignee == UNASSIGNED

    def test_sorted_by_person_then_id(self):
        stories = [
            make_story(id=30, state="Defined", assignee="Zeta, Zoe"),
            make_story(id=20, state="Defined", assignee="Alpha, Ann"),
            make_story(id=10, state="Defined", assignee="Alpha, Ann"),
        ]
        assert [f.story.id for f in evaluate(stories)] == [10, 20, 30]

    def test_unassigned_upn_is_none_so_no_mention_is_emitted(self):
        story = make_story(state="Defined", assignee=UNASSIGNED, upn=None)
        assert evaluate_story(story)[0].upn is None

    def test_completed_with_proof_is_sorted_under_po_not_engineer(self):
        stories = [
            make_story(id=2, state="Defined", assignee="Alpha, Ann"),
            make_story(id=1, state="Completed", attachment_count=1, assignee="Zeta, Zoe"),
        ]
        findings = evaluate(stories, po_name="Kumar, Vinod")
        assert [finding.assignee for finding in findings] == ["@Kumar, Vinod", "Alpha, Ann"]


class TestCommentCheckOptimisation:
    def test_only_completed_without_attachments_need_a_comment_call(self):
        stories = [
            make_story(id=1, state="Completed"),
            make_story(id=2, state="Completed", attachment_count=2),
            make_story(id=3, state="In-Progress"),
            make_story(id=4, state="Accepted"),
        ]
        assert [s.id for s in stories_needing_comment_check(stories)] == [1]


class TestReviewOutcome:
    def test_all_accepted_is_clean(self):
        stories = [make_story(id=1), make_story(id=2)]
        review = TeamReview("dfw", "DFW", "S35", "path", stories, evaluate(stories))
        assert review.is_clean and not review.is_empty

    def test_no_stories_is_empty_not_clean(self):
        review = TeamReview("dfw", "DFW", "S35", "path", [], [])
        assert review.is_empty and not review.is_clean

    def test_findings_mean_not_clean(self):
        stories = [make_story(id=1, state="In-Progress")]
        review = TeamReview("dfw", "DFW", "S35", "path", stories, evaluate(stories))
        assert not review.is_clean
