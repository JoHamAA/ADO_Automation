"""Tests for story create/update service behavior without ADO requests."""

from __future__ import annotations

from copy import deepcopy
from urllib.parse import unquote

import yaml

from eo_review.ado_client import AdoError
from story_creation.client import AdoHttpError, StoryClient
from story_creation.service import StoryService


def write_config(path):
    path.write_text(
        yaml.safe_dump(
            {
                "backlogs": {
                    "deaa": {
                        "project": "DataEngineering",
                        "areaPath": "DataEngineering\\Analytics",
                        "activeIteration": "DataEngineering",
                    }
                },
                "defaults": {
                    "workItemType": "User Story",
                    "storyPoints": 0,
                    "priority": 2,
                    "ready": "Yes",
                    "workType": "4. Software / UX",
                    "placeNewStoriesAtTopOfBacklog": True,
                },
            }
        ),
        encoding="utf-8",
    )


class FakeStoryClient:
    def __init__(self):
        self.next_id = 100
        self.items = {}
        self.created = []
        self.updated = []
        self.queries = []
        self.fail_titles = set()
        self.fail_update_ids = set()
        self.fail_readback_ids = set()
        self.ambiguous_titles = set()
        self.create_calls = 0

    def query(self, project, wiql):
        self.queries.append((project, wiql))
        return []

    def create_work_item(self, project, work_item_type, fields, parent_id=None):
        self.create_calls += 1
        if fields["System.Title"] in self.fail_titles:
            raise AdoHttpError(400, "create rejected")
        self.next_id += 1
        item_id = self.next_id
        self.created.append((project, work_item_type, deepcopy(fields), parent_id))
        self.items[item_id] = {
            "id": item_id,
            "fields": {
                **deepcopy(fields),
                "System.TeamProject": project,
                "System.WorkItemType": work_item_type,
            },
            "relations": (
                [
                    {
                        "rel": "System.LinkTypes.Hierarchy-Reverse",
                        "url": f"https://example.invalid/_apis/wit/workItems/{parent_id}",
                    }
                ]
                if parent_id is not None
                else []
            ),
        }
        if fields["System.Title"] in self.ambiguous_titles:
            raise AdoError("create response lost after ADO accepted the request")
        return {"id": item_id}

    def get_work_item(self, item_id):
        if item_id in self.fail_readback_ids:
            raise AdoError("read-back unavailable")
        return deepcopy(self.items[item_id])

    def update_work_item(self, item_id, fields):
        if item_id in self.fail_update_ids:
            raise AdoHttpError(400, "update rejected")
        self.updated.append((item_id, deepcopy(fields)))
        self.items[item_id]["fields"].update(deepcopy(fields))
        return deepcopy(self.items[item_id])


def make_service(tmp_path):
    config_path = tmp_path / "config.yaml"
    write_config(config_path)
    client = FakeStoryClient()
    return StoryService(client, config_path), client


def test_create_omits_unused_content_fields_and_applies_configured_defaults(tmp_path):
    service, client = make_service(tmp_path)

    result = service.create_story(
        {"backlog": "deaa", "title": "TO - Example - SPIKE"}
    )

    fields = client.created[0][2]
    assert result["id"] == 101
    assert result["title"] == "TO - Example - SPIKE"
    assert fields["System.AreaPath"] == "DataEngineering\\Analytics"
    assert fields["System.IterationPath"] == "DataEngineering"
    assert fields["Microsoft.VSTS.Scheduling.StoryPoints"] == 0
    assert fields["Microsoft.VSTS.Common.Priority"] == 2
    assert fields["AAIT.Ready"] == "Yes"
    assert fields["AAIT.WorkType"] == "4. Software / UX"
    assert fields["System.Tags"] == "AI-StoryWriting"
    assert fields["Microsoft.VSTS.Common.StackRank"] == 1000
    assert "System.Description" not in fields
    assert "Microsoft.VSTS.Common.AcceptanceCriteria" not in fields
    assert "System.History" not in fields


def test_create_bug_omits_story_work_type_and_preserves_explicit_fields(tmp_path):
    service, client = make_service(tmp_path)
    result = service.create_story(
        {
            "backlog": "deaa",
            "title": "Fix EMD transformation",
            "work_item_type": "Bug",
            "story_points": 2,
            "stack_rank": -10,
            "fields": {
                "Microsoft.VSTS.TCM.ReproSteps": "<div>Reported regression and criteria</div>"
            },
        }
    )

    _, item_type, fields, parent_id = client.created[0]
    assert result["status"] == "created_verified"
    assert item_type == "Bug"
    assert parent_id is None
    assert "AAIT.WorkType" not in fields
    assert fields["Microsoft.VSTS.Scheduling.StoryPoints"] == 2
    assert fields["Microsoft.VSTS.Common.StackRank"] == -10
    assert fields["Microsoft.VSTS.TCM.ReproSteps"] == (
        "<div>Reported regression and criteria</div>"
    )
    assert "Microsoft.VSTS.Common.AcceptanceCriteria" not in fields
    assert client.queries == []


def test_create_epic_uses_new_state_and_omits_unsupported_defaults(tmp_path):
    service, client = make_service(tmp_path)

    result = service.create_story(
        {
            "backlog": "deaa",
            "title": "LTS data delivery to NPOX",
            "work_item_type": "Epic",
            "stack_rank": -1000000,
            "description": "<div>Scope and Gherkin acceptance criteria</div>",
        }
    )

    _, item_type, fields, parent_id = client.created[0]
    assert result["status"] == "created_verified"
    assert item_type == "Epic"
    assert parent_id is None
    assert fields["System.State"] == "New"
    assert fields["Microsoft.VSTS.Common.Priority"] == 2
    assert fields["AAIT.Ready"] == "Yes"
    assert fields["System.Description"] == "<div>Scope and Gherkin acceptance criteria</div>"
    assert "Microsoft.VSTS.Scheduling.StoryPoints" not in fields
    assert "AAIT.WorkType" not in fields
    assert "Microsoft.VSTS.Common.AcceptanceCriteria" not in fields
    assert client.queries == []


def test_create_epic_preserves_explicit_state_override(tmp_path):
    service, client = make_service(tmp_path)

    service.create_story(
        {
            "backlog": "deaa",
            "title": "LTS discovery",
            "work_item_type": "Epic",
            "state": "Discovering",
            "stack_rank": -1000000,
        }
    )

    assert client.created[0][2]["System.State"] == "Discovering"


def test_create_maps_custom_fields_and_formats_structured_gherkin(tmp_path):
    service, client = make_service(tmp_path)

    service.create_story(
        {
            "backlog": "deaa",
            "title": "TO - Example - SPIKE",
            "fields": {"points": 3, "rank": 7, "notes": "Design notes"},
            "description": {
                "given": "A PNR has legs",
                "when": "TO evaluates it",
                "then": "The longest leg is selected",
                "context": "GCD is sourced per leg",
            },
            "acceptance_criteria": [
                {
                    "title": "Select the longest leg",
                    "given": "Several eligible legs exist",
                    "when": "TO creates an offer",
                    "then": "The greatest GCD leg is targeted",
                },
                {
                    "title": "Handle unavailable distance",
                    "given": "A leg lacks a GCD value",
                    "when": "TO evaluates the itinerary",
                    "then": "The missing value is handled consistently",
                },
                {
                    "title": "Retain the correct leg mapping",
                    "given": "A PNR contains multiple legs",
                    "when": "A leg is selected",
                    "then": "Its O and D remains associated with it",
                },
                {
                    "title": "Document the downstream impact",
                    "given": "The approach is assessed",
                    "when": "The spike is complete",
                    "then": "Consumer impacts are recorded",
                },
            ],
        }
    )

    fields = client.created[0][2]
    assert fields["Microsoft.VSTS.Scheduling.StoryPoints"] == 3
    assert fields["Microsoft.VSTS.Common.StackRank"] == 7
    assert fields["System.History"] == "Design notes"
    assert "<b>Given</b> A PNR has legs" in fields["System.Description"]
    assert "<b>Context:</b> GCD is sourced per leg" in fields["System.Description"]
    assert "<b>Select the longest leg</b>" in fields[
        "Microsoft.VSTS.Common.AcceptanceCriteria"
    ]


def test_update_changes_only_supplied_fields_and_empty_update_is_noop(tmp_path):
    service, client = make_service(tmp_path)
    client.items[10] = {
        "id": 10,
        "fields": {"System.Title": "Existing", "System.TeamProject": "DataEngineering"},
        "relations": [],
    }

    result = service.update_story(
        10,
        {
            "fields": {
                "description": "<div>Updated</div>",
                "acceptance_criteria": "<div>Updated criteria</div>",
                "notes": "Updated note",
                "rank": 50,
                "points": 5,
                "unused": None,
            }
        },
    )
    no_op = service.update_story(10, {"fields": {"points": None}})

    assert result["id"] == 10
    assert client.updated == [
        (
            10,
            {
                "System.Description": "<div>Updated</div>",
                "Microsoft.VSTS.Common.AcceptanceCriteria": "<div>Updated criteria</div>",
                "System.History": "Updated note",
                "Microsoft.VSTS.Common.StackRank": 50,
                "Microsoft.VSTS.Scheduling.StoryPoints": 5,
            },
        )
    ]
    assert no_op == {"id": 10, "updated": False, "status": "no fields supplied"}


def test_batch_continues_after_one_story_fails(tmp_path):
    service, client = make_service(tmp_path)
    client.fail_titles.add("Fail")

    results = service.create_batch(
        [
            {"backlog": "deaa", "title": "First"},
            {"backlog": "deaa", "title": "Fail"},
            {"backlog": "deaa", "title": "Last"},
        ]
    )

    assert [result["status"] for result in results] == [
        "created_verified",
        "create_failed",
        "created_verified",
    ]
    assert [result.get("title") for result in results] == ["First", "Fail", "Last"]
    assert len(client.queries) == 1
    assert [item[2]["Microsoft.VSTS.Common.StackRank"] for item in client.created] == [
        1000,
        998,
    ]


def test_update_batch_continues_after_one_story_fails(tmp_path):
    service, client = make_service(tmp_path)
    client.items[10] = {"id": 10, "fields": {}, "relations": []}
    client.items[11] = {"id": 11, "fields": {}, "relations": []}
    client.items[12] = {"id": 12, "fields": {}, "relations": []}
    client.fail_update_ids.add(11)

    results = service.update_batch(
        [
            {"id": 10, "fields": {"points": 2}},
            {"id": 11, "fields": {"points": 3}},
            {"id": 12, "fields": {"points": 4}},
        ]
    )

    assert [result["status"] for result in results] == [
        "updated_verified",
        "update_failed",
        "updated_verified",
    ]


def test_tag_verification_accepts_ado_tag_reordering(tmp_path):
    service, _ = make_service(tmp_path)

    service._verify_fields(
        {"fields": {"System.Tags": "Parent; AI-StoryWriting; Release"}},
        {"System.Tags": "AI-StoryWriting; Release; Parent"},
    )


def test_create_preserves_id_when_post_succeeds_but_readback_fails(tmp_path):
    service, client = make_service(tmp_path)
    client.fail_readback_ids.add(101)

    result = service.create_story(
        {"backlog": "deaa", "title": "Created but not readable"}
    )

    assert result["status"] == "created_unverified"
    assert result["id"] == 101
    assert result["url"].endswith("/DataEngineering/_workitems/edit/101")
    assert result["error"] == "read-back unavailable"
    assert len(client.created) == 1


def test_create_outcome_is_unknown_without_retry_when_post_response_is_lost(tmp_path):
    service, client = make_service(tmp_path)
    client.ambiguous_titles.add("Response lost")

    result = service.create_story(
        {"backlog": "deaa", "title": "Response lost"}
    )

    assert result["status"] == "create_outcome_unknown"
    assert result["id"] is None
    assert len(client.created) == 1
    assert client.create_calls == 1


def test_update_preserves_id_when_patch_succeeds_but_readback_fails(tmp_path):
    service, client = make_service(tmp_path)
    client.items[10] = {"id": 10, "fields": {}, "relations": []}
    client.fail_readback_ids.add(10)

    result = service.update_story(10, {"fields": {"points": 4}})

    assert result["status"] == "updated_unverified"
    assert result["id"] == 10
    assert result["error"] == "read-back unavailable"
    assert client.updated == [(10, {"Microsoft.VSTS.Scheduling.StoryPoints": 4})]


class AdoResponse:
    ok = True
    status_code = 200
    text = ""
    content = b"{}"

    def __init__(self, payload):
        self.payload = payload

    def json(self):
        return self.payload


class MockAdoSession:
    def __init__(self):
        self.calls = []
        self.item_fields = {}

    def request(self, method, url, **kwargs):
        self.calls.append((method, url, kwargs))
        if method == "POST":
            for operation in kwargs["json"]:
                if operation["path"].startswith("/fields/"):
                    field_name = unquote(operation["path"].removeprefix("/fields/"))
                    self.item_fields[field_name] = operation["value"]
            return AdoResponse({"id": 202})
        readback_fields = {
            **self.item_fields,
            "System.WorkItemType": "User Story",
            "System.TeamProject": "DataEngineering",
        }
        if "System.Tags" in readback_fields:
            tags = readback_fields["System.Tags"].split("; ")
            readback_fields["System.Tags"] = "; ".join(reversed(tags))
        return AdoResponse({"id": 202, "fields": readback_fields, "relations": []})


def test_story_service_create_round_trips_through_mocked_ado_rest(tmp_path):
    service, _ = make_service(tmp_path)
    client = object.__new__(StoryClient)
    client.org_url = "https://example.invalid"
    client.session = MockAdoSession()
    service.client = client

    result = service.create_story(
        {
            "backlog": "deaa",
            "title": "REST round-trip",
            "rank": 25,
            "tags": ["Tag A", "Tag B"],
        }
    )

    assert result["status"] == "created_verified"
    assert result["id"] == 202
    assert result["url"].endswith("/DataEngineering/_workitems/edit/202")
    assert [call[0] for call in client.session.calls] == ["POST", "GET"]