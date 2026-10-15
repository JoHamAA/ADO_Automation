"""Review orchestration: query ADO, apply rules, build a TeamReview."""

from __future__ import annotations

from dataclasses import replace
from typing import List

from .ado_client import AdoClient
from .config import Config
from .models import Story, TeamReview
from .rules import evaluate, stories_needing_comment_check


def run_team_review(client: AdoClient, config: Config, team_key: str) -> TeamReview:
    """Produce the complete EO review for one team's current sprint."""
    team = config.team(team_key)
    iteration = client.current_iteration(team.name)
    sprint_path = iteration["path"] or team.iteration_path

    ids = client.story_ids_in_iteration(sprint_path)
    stories: List[Story] = client.fetch_stories(ids) if ids else []

    # Only Completed stories without attachments need the extra comments call.
    for story in stories_needing_comment_check(stories):
        if client.has_comment_image(story.id):
            index = stories.index(story)
            stories[index] = replace(story, has_comment_image=True)

    stories.sort(key=lambda s: s.id)

    return TeamReview(
        team_key=team.key,
        team_label=team.label,
        sprint_name=iteration["name"] or team.label,
        sprint_path=sprint_path,
        stories=stories,
        findings=evaluate(stories, po_name=team.po_name),
    )
