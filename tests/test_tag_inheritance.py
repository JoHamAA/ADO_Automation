"""Tests for tag-inheritance REST, audit, reporting, and CLI behavior."""

from __future__ import annotations

from dataclasses import replace

import pytest

from eo_review.ado_client import AdoError
from eo_review.config import Config, TeamConfig
from tag_inheritance import cli
from tag_inheritance.audit import audit_team, synchronize
from tag_inheritance.client import PARENT_RELATION, TagInheritanceClient
from tag_inheritance.console import render_audit
from tag_inheritance.models import ImageTagMatch, TagWorkItem, TeamTagAudit, compare_tags


def make_item(
    item_id: int,
    tags: tuple[str, ...] = (),
    work_item_type: str = "User Story",
    parent_ids: tuple[int, ...] = (),
) -> TagWorkItem:
    return TagWorkItem(
        item_id,
        f"Item {item_id}",
        work_item_type,
        tags,
        revision=7,
        parent_ids=parent_ids,
    )


def make_config() -> Config:
    return Config(
        "https://example.invalid",
        "Project",
        {
            "dfw": TeamConfig(
                "dfw", "DFW", "Team_DFW", "Project\\DFW", gdc="S-DFW"
            ),
            "hyd": TeamConfig(
                "hyd", "HYD", "Team_HYD", "Project\\HYD", gdc="S-HYD"
            ),
        },
        "WEBHOOK",
    )


class FakeAuditClient:
    def __init__(self, stories, parents, image_matches=None, image_error=None):
        self.stories = stories
        self.parents = parents
        self.image_matches = image_matches or {}
        self.image_error = image_error

    def current_iteration(self, team_name):
        return {"name": f"{team_name}_Sprint", "path": f"Project\\{team_name}"}

    def iteration_by_number(self, team_name, team_iteration_path, sprint_number):
        return {
            "name": f"{team_name}_Sprint_{sprint_number}_2026",
            "path": f"{team_iteration_path}\\{team_name}_Sprint_{sprint_number}_2026",
        }

    def story_ids_in_iteration(self, iteration_path):
        return [story.id for story in self.stories]

    def fetch_tag_work_items(self, ids, include_relations=False):
        source = self.stories if include_relations else self.parents
        return [item for item in source if item.id in ids]

    def image_tag_matches(self, story):
        if story.id == self.image_error:
            from tag_inheritance.image_tags import ImageTagError

            raise ImageTagError("Tesseract OCR is not installed or is not on PATH.")
        return self.image_matches.get(story.id, ())


def test_client_parses_parent_relation_and_exact_tags():
    item = TagInheritanceClient._to_tag_work_item(
        {
            "id": 10,
            "rev": 4,
            "fields": {
                "System.Title": "Story",
                "System.WorkItemType": "User Story",
                "System.Tags": "Cloud; cloud; Data Platform",
                "Microsoft.VSTS.Common.Notes": '<img src="notes.png">',
            },
            "relations": [
                {
                    "rel": PARENT_RELATION,
                    "url": "https://example.invalid/_apis/wit/workItems/99",
                }
            ],
        }
    )

    assert item.tags == ("Cloud", "cloud", "Data Platform")
    assert item.parent_ids == (99,)
    assert item.notes == '<img src="notes.png">'


def test_client_fetches_all_discussion_pages(monkeypatch):
    client = object.__new__(TagInheritanceClient)
    client.org_url = "https://example.invalid"
    client.project = "Project"
    requested = []
    payloads = iter(
        [
            {
                "comments": [{"id": 7, "text": "first"}],
                "continuationToken": "next page",
            },
            {"comments": [{"id": 8, "text": "second"}]},
        ]
    )

    def fake_request(method, url):
        requested.append(url)
        return next(payloads)

    monkeypatch.setattr(client, "_request", fake_request)

    assert client.fetch_discussion_comments(123) == [
        ("Discussion comment 7", "first"),
        ("Discussion comment 8", "second"),
    ]
    assert len(requested) == 2
    assert "continuationToken=next+page" in requested[1]


def test_client_resolves_matching_iteration_from_team_tree(monkeypatch):
    client = object.__new__(TagInheritanceClient)
    client.org_url = "https://example.invalid"
    client.project = "Project"
    requested = []

    def fake_request(method, url):
        requested.append(url)
        return {
            "name": "PaxHub_DFW",
            "path": "\\Project\\Iteration\\PaxHub_DFW",
            "children": [
                {
                    "name": "DFW_Sprint_38_2026",
                    "path": "\\Project\\Iteration\\PaxHub_DFW\\DFW_Sprint_38_2026",
                },
                {
                    "name": "DFW_Sprint_39_2026",
                    "path": "\\Project\\Iteration\\PaxHub_DFW\\DFW_Sprint_39_2026",
                },
            ],
        }

    monkeypatch.setattr(
        client,
        "_request",
        fake_request,
    )

    assert client.iteration_by_number(
        "PaxHub_DFW", "Project\\PaxHub_DFW", 39
    ) == {
        "name": "DFW_Sprint_39_2026",
        "path": "Project\\PaxHub_DFW\\DFW_Sprint_39_2026",
    }
    assert "classificationnodes/iterations/PaxHub_DFW" in requested[0]
    assert "%24depth=2" in requested[0]


def test_client_rejects_missing_or_ambiguous_sprint_number(monkeypatch):
    client = object.__new__(TagInheritanceClient)
    client.org_url = "https://example.invalid"
    client.project = "Project"
    monkeypatch.setattr(
        client,
        "_request",
        lambda method, url: {
            "children": [
                {
                    "name": "DFW_Sprint_39_2025",
                    "path": "\\Project\\PaxHub_DFW\\DFW_Sprint_39_2025",
                },
                {
                    "name": "DFW_Sprint_39_2026",
                    "path": "\\Project\\PaxHub_DFW\\DFW_Sprint_39_2026",
                },
            ]
        },
    )

    with pytest.raises(AdoError, match="ambiguous"):
        client.iteration_by_number("PaxHub_DFW", "Project\\PaxHub_DFW", 39)
    with pytest.raises(AdoError, match="No iteration matching sprint"):
        client.iteration_by_number("PaxHub_DFW", "Project\\PaxHub_DFW", 12)


def test_client_rejects_image_urls_outside_ado_host():
    client = object.__new__(TagInheritanceClient)
    client.org_url = "https://example.invalid"

    from tag_inheritance.image_tags import ImageTagError

    with pytest.raises(ImageTagError, match="not on the configured ADO host"):
        client.download_image("https://outside.invalid/image.png")


def test_image_scan_reads_notes_and_discussion_only(monkeypatch):
    client = object.__new__(TagInheritanceClient)
    client.fetch_discussion_comments = lambda story_id: [
        ("Discussion comment 7", '<img src="discussion.png">')
    ]
    captured = {}

    def fake_scan(sources, download_image, **kwargs):
        captured["sources"] = list(sources)
        return (ImageTagMatch("Mutation", "mutation", "Notes"),)

    monkeypatch.setattr("tag_inheritance.client.scan_image_sources", fake_scan)
    story = make_item(1)
    story = replace(story, notes='<img src="notes.png">')

    matches = client.image_tag_matches(story)

    assert captured["sources"] == [
        ("Notes", '<img src="notes.png">'),
        ("Discussion comment 7", '<img src="discussion.png">'),
    ]
    assert matches[0].tag == "Mutation"


def test_client_patch_is_revision_guarded(monkeypatch):
    client = object.__new__(TagInheritanceClient)
    client.org_url = "https://example.invalid"
    captured = {}

    def fake_request(method, url, **kwargs):
        captured.update(method=method, url=url, **kwargs)
        return {}

    monkeypatch.setattr(client, "_request", fake_request)
    client.update_story_tags(10, 7, ("Story Only", "Parent Tag"))

    assert captured["method"] == "PATCH"
    assert captured["headers"]["Content-Type"] == "application/json-patch+json"
    assert captured["json"] == [
        {"op": "test", "path": "/rev", "value": 7},
        {
            "op": "add",
            "path": "/fields/System.Tags",
            "value": "Story Only; Parent Tag",
        },
    ]


def test_audit_keeps_exclusions_visible_and_reports_invalid_parents():
    stories = [
        make_item(1, ("Story Only",), parent_ids=(101,)),
        make_item(2, parent_ids=(102,)),
        make_item(3),
    ]
    parents = [
        make_item(101, ("Run", "Parent Tag"), "Feature"),
        make_item(102, ("Wrong Parent Tag",), "Epic"),
    ]

    report = audit_team(FakeAuditClient(stories, parents), make_config(), "dfw", {1})

    assert [result.status for result in report.results] == [
        "EXCLUDED",
        "UNRESOLVED",
        "UNRESOLVED",
    ]
    assert report.results[0].tags_to_add == ("Run", "Parent Tag", "S-DFW")
    assert report.planned_updates == []
    rendered = render_audit(report)
    assert "Excluded: 1" in rendered
    assert "parent is Epic, not Feature" in rendered


def test_audit_adds_image_keyword_tag_and_keeps_its_source():
    story = make_item(1, parent_ids=(101,))
    parent = make_item(101, ("Run",), "Feature")
    match = ImageTagMatch("Mutation", "mutation", "Notes")

    report = audit_team(
        FakeAuditClient([story], [parent], {1: (match,)}),
        make_config(),
        "dfw",
        set(),
    )

    result = report.results[0]
    assert "Mutation" in result.tags_to_add
    assert result.image_tag_matches == (match,)
    assert "Mutation from Notes" in render_audit(report)


def test_audit_uses_requested_sprint_number():
    report = audit_team(
        FakeAuditClient([], []),
        make_config(),
        "dfw",
        set(),
        sprint_number=39,
    )

    assert report.sprint_name == "Team_DFW_Sprint_39_2026"
    assert report.sprint_path == "Project\\DFW\\Team_DFW_Sprint_39_2026"


def test_audit_blocks_story_update_when_image_scan_fails():
    story = make_item(1, parent_ids=(101,))
    parent = make_item(101, ("Run",), "Feature")

    report = audit_team(
        FakeAuditClient([story], [parent], image_error=1),
        make_config(),
        "dfw",
        set(),
    )

    result = report.results[0]
    assert result.status == "UNRESOLVED"
    assert "image scan failed" in result.issue
    assert report.planned_updates == []


class FakeSyncClient:
    def __init__(self, refreshed, failure_id=None):
        self.refreshed = refreshed
        self.failure_id = failure_id
        self.updates = []

    def update_story_tags(self, story_id, revision, tags):
        if story_id == self.failure_id:
            raise AdoError("revision conflict")
        self.updates.append((story_id, revision, tuple(tags)))

    def fetch_tag_work_items(self, ids, include_relations=False):
        return [self.refreshed[item_id] for item_id in ids if item_id in self.refreshed]


def test_synchronize_continues_after_failure_and_verifies_success():
    parent = make_item(100, ("Run", "Parent Tag"), "Feature")
    first = compare_tags(make_item(1), parent, "S-DFW")
    second = compare_tags(make_item(2), parent, "S-DFW")
    client = FakeSyncClient(
        {2: replace(second.story, tags=("Run", "Parent Tag", "S-DFW"))},
        failure_id=1,
    )

    outcomes = synchronize(client, [first, second])

    assert [outcome.succeeded for outcome in outcomes] == [False, True]
    assert outcomes[0].detail == "revision conflict"
    assert client.updates == [(2, 7, ("Run", "Parent Tag", "S-DFW"))]


def test_synchronize_accepts_azure_devops_tag_reordering():
    story = make_item(1, ("AI-StoryWriting", "xMatters", "3Q26", "Run"))
    parent = make_item(
        100,
        ("Run", "Security & Compliance"),
        "Feature",
    )
    audit = compare_tags(story, parent, "S-DFW")
    client = FakeSyncClient(
        {
            1: replace(
                story,
                tags=(
                    "3Q26",
                    "AI-StoryWriting",
                    "Run",
                    "S-DFW",
                    "Security & Compliance",
                    "xMatters",
                ),
            )
        }
    )

    outcomes = synchronize(client, [audit])

    assert outcomes[0].succeeded is True
    assert outcomes[0].detail == "verified"


def test_synchronize_fails_verification_when_removed_tag_remains():
    story = make_item(1, ("S-HYD", "Run"))
    parent = make_item(100, ("Initiative",), "Feature")
    audit = compare_tags(story, parent, "S-DFW")
    client = FakeSyncClient(
        {1: replace(story, tags=("S-HYD", "Initiative", "S-DFW"))}
    )

    outcomes = synchronize(client, [audit])

    assert outcomes[0].succeeded is False
    assert outcomes[0].detail == "verification mismatch: missing [], unexpected [S-HYD]"


@pytest.mark.parametrize(
    "groups,expected",
    [
        ([["12345,", "123532"]], {12345, 123532}),
        ([["1,2"], ["3"]], {1, 2, 3}),
    ],
)
def test_parse_exclusions_accepts_spaced_and_repeated_values(groups, expected):
    assert cli._parse_exclusions(groups) == expected


@pytest.mark.parametrize("groups", [[['abc']], [["1,,2"]], [["0"]], [["-2"]]])
def test_parse_exclusions_rejects_invalid_ids(groups):
    with pytest.raises(ValueError):
        cli._parse_exclusions(groups)


def test_sync_requires_exact_yes_before_writing(monkeypatch, capsys):
    parent = make_item(100, ("Run", "Parent Tag"), "Feature")
    audit = compare_tags(make_item(1), parent, "S-DFW")
    report = TeamTagAudit("dfw", "DFW", "Sprint", "Path", [audit])
    synchronized = []

    monkeypatch.setattr(cli, "load_config", lambda path: make_config())
    monkeypatch.setattr(cli, "TagInheritanceClient", lambda org, project: object())
    monkeypatch.setattr(
        cli,
        "audit_team",
        lambda client, config, team, excluded, sprint_number=None: report,
    )
    monkeypatch.setattr(cli, "synchronize", lambda client, planned: synchronized.append(planned))
    monkeypatch.setattr("builtins.input", lambda prompt: "yes")

    assert cli.main(["sync", "DFW"]) == cli.EXIT_OK
    assert synchronized == []
    assert "CANCELLED" in capsys.readouterr().out