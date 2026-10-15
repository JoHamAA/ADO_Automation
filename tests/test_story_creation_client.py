"""Tests for Azure DevOps story REST request construction."""

from story_creation.client import StoryClient


class FakeResponse:
    ok = True
    status_code = 200
    text = ""
    content = b"{}"

    def json(self):
        return {"id": 44}


class FakeSession:
    def __init__(self):
        self.calls = []

    def request(self, method, url, **kwargs):
        self.calls.append((method, url, kwargs))
        return FakeResponse()


def make_client():
    client = object.__new__(StoryClient)
    client.org_url = "https://example.invalid"
    client.session = FakeSession()
    return client


def test_create_sends_only_supplied_fields_and_optional_parent():
    client = make_client()

    result = client.create_work_item(
        "Data Engineering",
        "User Story",
        {"System.Title": "A title", "System.Description": None},
        parent_id=12,
    )

    method, url, kwargs = client.session.calls[0]
    assert result == {"id": 44}
    assert method == "POST"
    assert "/Data%20Engineering/_apis/wit/workitems/$User%20Story" in url
    assert kwargs["headers"]["Content-Type"] == "application/json-patch+json"
    assert kwargs["json"] == [
        {"op": "add", "path": "/fields/System.Title", "value": "A title"},
        {
            "op": "add",
            "path": "/relations/-",
            "value": {
                "rel": "System.LinkTypes.Hierarchy-Reverse",
                "url": "https://example.invalid/_apis/wit/workItems/12",
            },
        },
    ]


def test_update_omits_unsupplied_and_none_fields():
    client = make_client()

    client.update_work_item(
        44,
        {
            "System.Description": "Updated",
            "Microsoft.VSTS.Scheduling.StoryPoints": 3,
            "System.History": None,
        },
    )

    method, url, kwargs = client.session.calls[0]
    assert method == "PATCH"
    assert "/workitems/44?api-version=" in url
    assert kwargs["json"] == [
        {"op": "add", "path": "/fields/System.Description", "value": "Updated"},
        {
            "op": "add",
            "path": "/fields/Microsoft.VSTS.Scheduling.StoryPoints",
            "value": 3,
        },
    ]


def test_update_with_no_fields_is_a_no_op():
    client = make_client()

    assert client.update_work_item(44, {}) == {}
    assert client.session.calls == []