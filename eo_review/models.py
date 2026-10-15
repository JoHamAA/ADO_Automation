"""Domain models for the End-of-Iteration review.

These are deliberately plain data containers so that the rule engine in
``rules.py`` can be exercised from fixtures without any network access.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional

UNASSIGNED = "UNASSIGNED"

# User Story workflow: Backlog -> Defined -> In-Progress -> Completed -> Accepted
STATE_COMPLETED = "Completed"
STATE_ACCEPTED = "Accepted"


@dataclass(frozen=True)
class Story:
    """A single ADO User Story with only the fields the review needs."""

    id: int
    title: str
    state: str
    assignee: str = UNASSIGNED
    upn: Optional[str] = None
    attachment_count: int = 0
    has_comment_image: bool = False

    @property
    def is_unassigned(self) -> bool:
        return self.assignee == UNASSIGNED or not self.assignee

    @property
    def has_proof_of_work(self) -> bool:
        return self.attachment_count > 0 or self.has_comment_image

    @property
    def url(self) -> str:
        return (
            "https://dev.azure.com/AmericanAirlines/PassengerDataHub"
            f"/_workitems/edit/{self.id}"
        )


@dataclass(frozen=True)
class Finding:
    """One reportable problem with one story."""

    story: Story
    issue: str
    assignee_override: Optional[str] = None
    upn_override: Optional[str] = None

    @property
    def assignee(self) -> str:
        if self.assignee_override:
            return self.assignee_override
        return UNASSIGNED if self.story.is_unassigned else self.story.assignee

    @property
    def upn(self) -> Optional[str]:
        if self.assignee_override:
            return self.upn_override
        return None if self.story.is_unassigned else self.story.upn


@dataclass
class TeamReview:
    """The complete review outcome for one team's sprint."""

    team_key: str
    team_label: str
    sprint_name: str
    sprint_path: str
    stories: List[Story] = field(default_factory=list)
    findings: List[Finding] = field(default_factory=list)

    @property
    def story_count(self) -> int:
        return len(self.stories)

    @property
    def is_empty(self) -> bool:
        """No stories at all - a likely misconfiguration, never an all-clear."""
        return self.story_count == 0

    @property
    def is_clean(self) -> bool:
        """At least one story and every one of them Accepted."""
        return not self.is_empty and not self.findings
