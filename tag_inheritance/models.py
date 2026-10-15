"""Domain models and tag comparison rules for inheritance audits."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List, Optional, Sequence, Tuple

from rapidfuzz import fuzz

TEAM_TAGS = ("S-DFW", "S-HYD")
CLASSIFICATION_TAGS = ("Run", "Initiative")
TITLE_TAG_MATCHES = (
    ("readiness", "PROD Readiness"),
    ("deployment", "PROD Deploy"),
    ("deploy", "PROD Deploy"),
)
TITLE_MATCH_THRESHOLD = 90
PRODUCTION_MARKER = re.compile(r"(?<![a-z0-9])(?:production|prod)")


def parse_tags(value: str | None) -> Tuple[str, ...]:
    """Parse ADO's semicolon-delimited tag field without changing tag identity."""
    return tuple(tag.strip() for tag in (value or "").split(";") if tag.strip())


def _title_tags(title: str) -> Tuple[str, ...]:
    normalized_title = "".join(title.casefold().split())
    matched_tags = []
    for marker in PRODUCTION_MARKER.finditer(normalized_title):
        descriptor_match = re.match(r"[^a-z0-9]*([a-z0-9]+)", normalized_title[marker.end():])
        if descriptor_match is None:
            continue

        descriptor = descriptor_match.group(1)
        for target, tag in TITLE_TAG_MATCHES:
            min_length = max(1, len(target) - 2)
            max_length = min(len(descriptor), len(target) + 2)
            for length in range(min_length, max_length + 1):
                candidate = descriptor[:length]
                if fuzz.ratio(candidate, target) >= TITLE_MATCH_THRESHOLD:
                    matched_tags.append(tag)
                    break

    return tuple(dict.fromkeys(matched_tags))


@dataclass(frozen=True)
class TagWorkItem:
    """Work-item data needed to compare and update inherited tags."""

    id: int
    title: str
    work_item_type: str
    tags: Tuple[str, ...]
    revision: int
    parent_ids: Tuple[int, ...] = ()
    notes: str = ""


@dataclass(frozen=True)
class ImageTagMatch:
    """A keyword recognized in an image and the Notes/Discussion source."""

    tag: str
    keyword: str
    source: str


@dataclass(frozen=True)
class TagAuditResult:
    """Inheritance status for one User Story."""

    story: TagWorkItem
    parent: Optional[TagWorkItem]
    tags_to_add: Tuple[str, ...] = ()
    tags_to_remove: Tuple[str, ...] = ()
    excluded: bool = False
    issue: Optional[str] = None
    image_tag_matches: Tuple[ImageTagMatch, ...] = ()

    @property
    def status(self) -> str:
        if self.excluded:
            return "EXCLUDED"
        if self.issue:
            return "UNRESOLVED"
        if self.tags_to_remove:
            return "CONFLICT"
        if self.tags_to_add:
            return "MISSING"
        return "COMPLIANT"

    @property
    def proposed_tags(self) -> Tuple[str, ...]:
        """Remove conflicting managed tags, preserving all other story tags."""
        retained = tuple(tag for tag in self.story.tags if tag not in self.tags_to_remove)
        return retained + self.tags_to_add


@dataclass
class TeamTagAudit:
    """Tag-inheritance audit results for one team's current iteration."""

    team_key: str
    team_label: str
    sprint_name: str
    sprint_path: str
    results: List[TagAuditResult]

    @property
    def planned_updates(self) -> List[TagAuditResult]:
        return [
            result
            for result in self.results
            if (result.tags_to_add or result.tags_to_remove)
            and not result.excluded
            and not result.issue
        ]


@dataclass(frozen=True)
class UpdateResult:
    """Verified outcome of one attempted story update."""

    audit: TagAuditResult
    succeeded: bool
    detail: str


def compare_tags(
    story: TagWorkItem,
    parent: TagWorkItem,
    expected_team_tag: str,
    excluded: bool = False,
    image_tag_matches: Sequence[ImageTagMatch] = (),
) -> TagAuditResult:
    """Apply additive inheritance plus exclusive team and classification rules."""
    parent_classifications = tuple(
        tag for tag in CLASSIFICATION_TAGS if tag in parent.tags
    )
    if len(parent_classifications) != 1:
        found = ", ".join(parent_classifications) if parent_classifications else "none"
        return TagAuditResult(
            story=story,
            parent=parent,
            excluded=excluded,
            issue=(
                "parent must have exactly one of Run or Initiative "
                f"(found: {found})"
            ),
        )

    expected_classification = parent_classifications[0]
    tags_to_remove = tuple(
        tag
        for tag in story.tags
        if (tag in TEAM_TAGS and tag != expected_team_tag)
        or (tag in CLASSIFICATION_TAGS and tag != expected_classification)
    )
    retained = tuple(tag for tag in story.tags if tag not in tags_to_remove)

    tags_to_add = tuple(
        tag
        for tag in parent.tags
        if tag not in TEAM_TAGS and tag not in retained
    )
    if expected_team_tag not in retained and expected_team_tag not in tags_to_add:
        tags_to_add += (expected_team_tag,)
    tags_to_add += tuple(
        tag
        for tag in _title_tags(story.title)
        if tag not in retained and tag not in tags_to_add
    )
    present_tags = {tag.casefold() for tag in retained + tags_to_add}
    for match in image_tag_matches:
        if match.tag.casefold() not in present_tags:
            tags_to_add += (match.tag,)
            present_tags.add(match.tag.casefold())

    return TagAuditResult(
        story=story,
        parent=parent,
        tags_to_add=tags_to_add,
        tags_to_remove=tags_to_remove,
        excluded=excluded,
        image_tag_matches=tuple(image_tag_matches),
    )
