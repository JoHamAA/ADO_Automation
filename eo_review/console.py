"""Console rendering of an EO review.

The body is rendered from the same Adaptive Card payload that gets posted, so
what appears in the terminal is exactly what the channel would receive.
"""

from __future__ import annotations

import re
from typing import Dict, List

from .models import TeamReview
from .teams import build_card

RULE = "-" * 78

# Markdown link as used in the card, e.g. [3104198](https://dev.azure.com/...)
LINK_PATTERN = re.compile(r"\[(?P<label>[^\]]+)\]\((?P<url>[^)]+)\)")


def _state_summary(review: TeamReview) -> str:
    counts: Dict[str, int] = {}
    for story in review.stories:
        counts[story.state] = counts.get(story.state, 0) + 1
    return ", ".join(f"{state}: {count}" for state, count in sorted(counts.items()))


def _card_lines(review: TeamReview) -> List[str]:
    """Flatten the card's TextBlocks into plain terminal lines."""
    content = build_card(review)["attachments"][0]["content"]
    lines: List[str] = []

    for block in content.get("body", []):
        text = block.get("text", "").replace("<at>", "@").replace("</at>", "")

        match = LINK_PATTERN.search(text)
        url = match.group("url") if match else None
        if match:
            text = LINK_PATTERN.sub(lambda m: m.group("label"), text)

        lines.append(text)
        if url:
            lines.append(f"    {url}")
            lines.append("")

    return lines


def render(review: TeamReview) -> str:
    """Summary header followed by the full message as it would appear in Teams."""
    if review.is_empty:
        return "\n".join(
            [
                RULE,
                f"{review.team_label} - End of Iteration Review - {review.sprint_name}",
                RULE,
                "no_stories_in_iteration: the query returned zero User Stories for "
                f"'{review.sprint_path}'.",
                "This indicates a wrong iteration path or an unplanned sprint, not a "
                "clean result. Nothing will be posted to Teams.",
                RULE,
            ]
        )

    importance = "normal" if review.is_clean else "high"
    lines: List[str] = [
        RULE,
        f"{review.team_label} - {review.sprint_name}",
        f"{review.story_count} stories ({_state_summary(review)})",
        f"{len(review.findings)} finding(s) | importance: {importance}",
        RULE,
        "",
    ]
    lines.extend(_card_lines(review))
    lines.append(RULE)
    return "\n".join(lines)

