"""Console rendering for tag inheritance audits and synchronization."""

from __future__ import annotations

from typing import Iterable, Sequence

from .models import TagAuditResult, TeamTagAudit, UpdateResult

RULE = "-" * 78


def _tags(tags: Sequence[str]) -> str:
    return "; ".join(tags) if tags else "(none)"


def render_audit(report: TeamTagAudit) -> str:
    """Render every story and an actionable team summary."""
    lines = [
        RULE,
        f"{report.team_label} - Tag Inheritance - {report.sprint_name}",
        f"Iteration: {report.sprint_path}",
        RULE,
    ]
    for result in report.results:
        parent_id = result.parent.id if result.parent else "-"
        detail = (
            f"add: {_tags(result.tags_to_add)} | "
            f"remove: {_tags(result.tags_to_remove)}"
        )
        if result.issue:
            detail += f" | issue: {result.issue}"
        if result.image_tag_matches:
            image_details = "; ".join(
                f'{match.tag} from {match.source}'
                for match in result.image_tag_matches
            )
            detail += f" | image keywords: {image_details}"
        lines.append(
            f"{result.status:<10} | {result.story.id} | parent {parent_id} | "
            f"{result.story.title} | {detail}"
        )

    compliant = sum(result.status == "COMPLIANT" for result in report.results)
    missing = sum(result.status == "MISSING" for result in report.results)
    conflicts = sum(result.status == "CONFLICT" for result in report.results)
    excluded = sum(result.status == "EXCLUDED" for result in report.results)
    unresolved = sum(bool(result.issue) and not result.excluded for result in report.results)
    lines.extend(
        [
            RULE,
            f"Total: {len(report.results)} | Compliant: {compliant} | Missing: {missing} | "
            f"Conflicts: {conflicts} | Excluded: {excluded} | Unresolved: {unresolved} | "
            f"Planned updates: {len(report.planned_updates)}",
            RULE,
        ]
    )
    return "\n".join(lines)


def render_plan(audits: Iterable[TagAuditResult]) -> str:
    """Render the exact tag additions that require approval."""
    lines = [RULE, "PROPOSED TAG UPDATES", RULE]
    planned = list(audits)
    for audit in planned:
        image_details = ""
        if audit.image_tag_matches:
            image_details = " | image keywords: " + "; ".join(
                f'{match.tag} from {match.source}'
                for match in audit.image_tag_matches
            )
        lines.append(
            f"{audit.story.id} | add: {_tags(audit.tags_to_add)} | "
            f"remove: {_tags(audit.tags_to_remove)} | "
            f"final: {_tags(audit.proposed_tags)}{image_details}"
        )
    lines.extend([RULE, f"Stories to update: {len(planned)}", RULE])
    return "\n".join(lines)


def render_outcomes(outcomes: Sequence[UpdateResult]) -> str:
    """Render verified update results."""
    lines = [RULE, "SYNCHRONIZATION RESULTS", RULE]
    for outcome in outcomes:
        status = "UPDATED" if outcome.succeeded else "FAILED"
        lines.append(f"{status:<7} | {outcome.audit.story.id} | {outcome.detail}")
    succeeded = sum(outcome.succeeded for outcome in outcomes)
    lines.extend(
        [
            RULE,
            f"Updated: {succeeded} | Failed: {len(outcomes) - succeeded}",
            RULE,
        ]
    )
    return "\n".join(lines)
