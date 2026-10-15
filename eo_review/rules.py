"""The End-of-Iteration rule engine.

Pure functions only: no network, no I/O, no globals. Everything here is
driven by the ``Story`` objects handed to it, which makes the rules
directly unit-testable from fixtures.
"""

from __future__ import annotations

from typing import List, Sequence

from .models import STATE_ACCEPTED, STATE_COMPLETED, Finding, Story

MISSING_PROOF = (
    "Missing proof of work: story is in a completed state, but has no attached "
    "file and no image in the discussion. Provide proof of work, then PO must "
    "review and move it to Accepted."
)

NEEDS_PO_ACCEPTANCE = (
    "PO acceptance needed: story is in a completed state with proof of work. "
    "PO must review and move it to Accepted."
)


def _with_po(issue: str, po_name: str | None) -> str:
    return f"{issue} @{po_name}" if po_name else issue


def _po_assignee(po_name: str | None) -> str | None:
    return f"@{po_name}" if po_name else None

REQUIRES_UPDATE = (
    "Requires update: story is {state} at iteration end. Mark it as Completed, "
    "or state that it is being split."
)


def evaluate_story(story: Story, po_name: str | None = None) -> List[Finding]:
    """Apply both EO rules to a single story."""
    findings: List[Finding] = []

    if story.state == STATE_COMPLETED:
        if not story.has_proof_of_work:
            findings.append(Finding(story=story, issue=_with_po(MISSING_PROOF, po_name)))
        else:
            findings.append(
                Finding(
                    story=story,
                    issue=NEEDS_PO_ACCEPTANCE,
                    assignee_override=_po_assignee(po_name),
                )
            )
    elif story.state != STATE_ACCEPTED:
        # Rule 2 - anything not Completed or Accepted needs an owner update.
        findings.append(
            Finding(story=story, issue=REQUIRES_UPDATE.format(state=story.state))
        )

    return findings


def evaluate(stories: Sequence[Story], po_name: str | None = None) -> List[Finding]:
    """Apply the EO rules across a sprint, sorted unassigned-first then by person."""
    findings: List[Finding] = []
    for story in stories:
        findings.extend(evaluate_story(story, po_name=po_name))

    return sorted(
        findings,
        key=lambda f: (0 if f.story.is_unassigned else 1, f.assignee.lower(), f.story.id),
    )


def stories_needing_comment_check(stories: Sequence[Story]) -> List[Story]:
    """Completed stories with no attachment - the only ones worth an API call.

    Checking comments costs one request per story, so it is skipped wherever
    an attachment has already satisfied Rule 1.
    """
    return [s for s in stories if s.state == STATE_COMPLETED and s.attachment_count == 0]
