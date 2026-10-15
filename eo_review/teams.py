"""Adaptive Card rendering and Teams delivery.

Card shape follows the contract documented in
``.github/copilot-instructions.md`` -> End-of-Iteration (EO) Review -> Delivery.
"""

from __future__ import annotations

from typing import Any, Dict, List

import requests

from .models import TeamReview

CARD_CONTENT_TYPE = "application/vnd.microsoft.card.adaptive"
ADAPTIVE_CARD_VERSION = "1.4"
SCHEMA = "http://adaptivecards.io/schemas/adaptive-card.json"
POST_TIMEOUT = 60

COB_NOTICE = "All updates below must be completed before Close of Business today."


class TeamsError(RuntimeError):
    """Raised when the webhook rejects the card."""


def _text_block(text: str, **kwargs: Any) -> Dict[str, Any]:
    block: Dict[str, Any] = {"type": "TextBlock", "text": text, "wrap": True}
    block.update(kwargs)
    return block


def _header(review: TeamReview) -> str:
    return f"{review.team_label} - End of Iteration Review - {review.sprint_name}"


def build_findings_card(review: TeamReview) -> Dict[str, Any]:
    """Card for a sprint with findings: red header, @mentions, high importance."""
    body: List[Dict[str, Any]] = [
        _text_block("! IMPORTANT", weight="Bolder", color="Attention"),
        _text_block(_header(review), weight="Bolder", size="Medium"),
        _text_block(COB_NOTICE),
    ]
    entities: List[Dict[str, Any]] = []
    seen_upns = set()

    for finding in review.findings:
        name = finding.assignee
        mention = f"<at>{name}</at>" if finding.upn else name
        body.append(
            _text_block(
                f"{mention} - [{finding.story.id}]({finding.story.url}) {finding.story.title} - {finding.issue}",
                spacing="Medium",
            )
        )
        # Teams needs one entity per distinct mentioned user.
        if finding.upn and finding.upn not in seen_upns:
            seen_upns.add(finding.upn)
            entities.append(
                {
                    "type": "mention",
                    "text": f"<at>{name}</at>",
                    "mentioned": {"id": finding.upn, "name": name},
                }
            )

    content: Dict[str, Any] = {
        "$schema": SCHEMA,
        "type": "AdaptiveCard",
        "version": ADAPTIVE_CARD_VERSION,
        "body": body,
    }
    if entities:
        content["msteams"] = {"entities": entities}

    return {
        "type": "message",
        "importance": "high",
        "attachments": [{"contentType": CARD_CONTENT_TYPE, "content": content}],
    }


def build_clean_card(review: TeamReview) -> Dict[str, Any]:
    """Card for a fully Accepted sprint: green header, no mentions, no ping."""
    content = {
        "$schema": SCHEMA,
        "type": "AdaptiveCard",
        "version": ADAPTIVE_CARD_VERSION,
        "body": [
            _text_block(_header(review), weight="Bolder", size="Medium", color="Good"),
            _text_block(
                f"All {review.story_count} stories are Accepted. No actions required.",
                spacing="Medium",
            ),
        ],
    }
    return {
        "type": "message",
        "importance": "normal",
        "attachments": [{"contentType": CARD_CONTENT_TYPE, "content": content}],
    }


def build_card(review: TeamReview) -> Dict[str, Any]:
    return build_clean_card(review) if review.is_clean else build_findings_card(review)


def post_card(webhook_url: str, payload: Dict[str, Any]) -> None:
    """POST the card. A successful Workflows trigger returns 202 with no body."""
    response = requests.post(
        webhook_url,
        json=payload,
        headers={"Content-Type": "application/json"},
        timeout=POST_TIMEOUT,
    )
    if not response.ok:
        raise TeamsError(
            f"Teams webhook returned HTTP {response.status_code}: {response.text[:400]}"
        )
