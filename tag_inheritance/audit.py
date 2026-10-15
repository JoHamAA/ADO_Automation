"""Current-iteration tag auditing and verified synchronization."""

from __future__ import annotations

from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
import time
from typing import Callable, Dict, Iterable, List, Sequence, Set, Tuple

from eo_review.ado_client import AdoError
from eo_review.config import Config

from .client import TagInheritanceClient
from .image_tags import IMAGE_KEYWORD_TAGS, ImageTagError
from .models import (
    TagAuditResult,
    TagWorkItem,
    TeamTagAudit,
    UpdateResult,
    compare_tags,
)


def _needs_image_scan(story_tags: Sequence[str]) -> bool:
    """False when every image-derived tag is already on the story."""
    present = {tag.casefold() for tag in story_tags}
    return any(tag.casefold() not in present for _, tag in IMAGE_KEYWORD_TAGS)


def audit_team(
    client: TagInheritanceClient,
    config: Config,
    team_key: str,
    excluded_ids: Set[int],
    sprint_number: int | None = None,
    scan_images: bool = True,
    progress: Callable[[str], None] | None = None,
    workers: int = 1,
) -> TeamTagAudit:
    """Audit every User Story under one team's selected iteration."""
    team = config.team(team_key)
    iteration = (
        client.iteration_by_number(team.name, team.iteration_path, sprint_number)
        if sprint_number is not None
        else client.current_iteration(team.name)
    )
    sprint_path = iteration["path"] or team.iteration_path
    story_ids = client.story_ids_in_iteration(sprint_path)
    stories = client.fetch_tag_work_items(story_ids, include_relations=True)

    parent_ids = sorted({parent_id for story in stories for parent_id in story.parent_ids})
    parents = {
        parent.id: parent for parent in client.fetch_tag_work_items(parent_ids)
    }

    ordered = sorted(stories, key=lambda item: item.id)
    results_by_id: Dict[int, TagAuditResult] = {}
    to_scan: List[Tuple[TagWorkItem, TagWorkItem, TagAuditResult, bool]] = []
    for story in ordered:
        excluded = story.id in excluded_ids
        if len(story.parent_ids) != 1:
            issue = "no parent relation" if not story.parent_ids else "multiple parent relations"
            results_by_id[story.id] = TagAuditResult(story, None, excluded=excluded, issue=issue)
            continue

        parent = parents.get(story.parent_ids[0])
        if parent is None:
            results_by_id[story.id] = TagAuditResult(
                story, None, excluded=excluded, issue="parent could not be read"
            )
            continue
        if parent.work_item_type != "Feature":
            results_by_id[story.id] = TagAuditResult(
                story,
                parent,
                excluded=excluded,
                issue=f"parent is {parent.work_item_type or 'an unknown type'}, not Feature",
            )
            continue

        base_result = compare_tags(
            story,
            parent,
            expected_team_tag=team.gdc,
            excluded=excluded,
        )
        if base_result.issue or not scan_images or not _needs_image_scan(story.tags):
            results_by_id[story.id] = base_result
            continue
        to_scan.append((story, parent, base_result, excluded))

    def scan_story(item: Tuple[TagWorkItem, TagWorkItem, TagAuditResult, bool]) -> TagAuditResult:
        story, parent, base_result, excluded = item
        if progress:
            progress(f"[{team.key}] story {story.id}: scanning images")
        scan_started = time.perf_counter()
        try:
            image_matches = client.image_tag_matches(story)
        except ImageTagError as exc:
            return replace(base_result, issue=f"image scan failed: {exc}")
        finally:
            if progress:
                progress(
                    f"[{team.key}] story {story.id}: done in "
                    f"{time.perf_counter() - scan_started:.1f}s"
                )
        return compare_tags(
            story,
            parent,
            expected_team_tag=team.gdc,
            excluded=excluded,
            image_tag_matches=image_matches,
        )

    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        for item, result in zip(to_scan, pool.map(scan_story, to_scan)):
            results_by_id[item[0].id] = result
    results = [results_by_id[story.id] for story in ordered]

    return TeamTagAudit(
        team_key=team.key,
        team_label=team.label,
        sprint_name=iteration["name"] or team.label,
        sprint_path=sprint_path,
        results=results,
    )


def synchronize(
    client: TagInheritanceClient,
    audits: Iterable[TagAuditResult],
) -> List[UpdateResult]:
    """Apply approved changes and verify each story independently."""
    outcomes: List[UpdateResult] = []
    for audit in audits:
        try:
            client.update_story_tags(
                audit.story.id,
                audit.story.revision,
                audit.proposed_tags,
            )
            refreshed_items = client.fetch_tag_work_items([audit.story.id])
            if len(refreshed_items) != 1:
                raise AdoError("updated story could not be read back")
            refreshed = refreshed_items[0]
            expected_tags = Counter(audit.proposed_tags)
            actual_tags = Counter(refreshed.tags)
            if actual_tags != expected_tags:
                missing = list((expected_tags - actual_tags).elements())
                unexpected = list((actual_tags - expected_tags).elements())
                raise AdoError(
                    "verification mismatch: missing ["
                    + "; ".join(missing)
                    + "], unexpected ["
                    + "; ".join(unexpected)
                    + "]"
                )
        except (AdoError, OSError) as exc:
            outcomes.append(UpdateResult(audit, False, str(exc)))
        else:
            outcomes.append(UpdateResult(audit, True, "verified"))
    return outcomes


def selected_story_ids(reports: Sequence[TeamTagAudit]) -> Set[int]:
    """Return all story IDs discovered across selected team iterations."""
    return {result.story.id for report in reports for result in report.results}
