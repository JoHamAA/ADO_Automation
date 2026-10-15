"""Tests for the local story service HTTP request contract."""

from story_creation.api import (
    BatchCreateRequest,
    BatchUpdateRequest,
    CreateStoryRequest,
    UpdateStoryRequest,
    _request_values,
    create_app,
)


class FakeService:
    def __init__(self):
        self.created = []
        self.updated = []

    def create_story(self, request):
        self.created.append(request)
        return {"id": 1, "title": request["title"], "url": "https://example.invalid/1"}

    def create_batch(self, requests):
        self.created.extend(requests)
        return [{"status": "created", "id": i + 1, "title": item["title"]} for i, item in enumerate(requests)]

    def update_story(self, item_id, request):
        self.updated.append((item_id, request))
        return {"id": item_id, "updated": True}

    def update_batch(self, requests):
        return [
            {
                "status": "updated",
                **self.update_story(
                    item["id"],
                    {key: value for key, value in item.items() if key != "id"},
                ),
            }
            for item in requests
        ]


def get_route(app, path, method):
    return next(
        route
        for route in app.routes
        if getattr(route, "path", None) == path
        and method in (getattr(route, "methods", None) or set())
    )


def test_create_request_ignores_unused_optional_properties():
    request = CreateStoryRequest.model_validate(
        {"title": "Story", "unknown_optional": "ignored"}
    )

    values = _request_values(request)

    assert values["title"] == "Story"
    assert values["fields"] == {}
    assert "unknown_optional" not in values


def test_batch_endpoint_iterates_all_story_requests():
    service = FakeService()
    app = create_app(lambda: service)
    route = get_route(app, "/stories/batch", "POST")
    request = BatchCreateRequest.model_validate(
        {"stories": [{"title": "First"}, {"title": "Second"}]}
    )

    result = route.endpoint(request)

    assert [item["title"] for item in service.created] == ["First", "Second"]
    assert [item["title"] for item in result["results"]] == ["First", "Second"]


def test_batch_update_endpoint_keeps_sparse_fields_per_story():
    service = FakeService()
    app = create_app(lambda: service)
    route = get_route(app, "/stories/batch", "PATCH")
    request = BatchUpdateRequest.model_validate(
        {"updates": [{"id": 12, "points": 3}, {"id": 13, "notes": "reviewed"}]}
    )

    result = route.endpoint(request)

    assert service.updated == [
        (12, {"points": 3.0}),
        (13, {"notes": "reviewed"}),
    ]
    assert [item["status"] for item in result["results"]] == [
        "updated",
        "updated",
    ]
    paths = [route.path for route in app.routes if hasattr(route, "path")]
    assert paths.index("/stories/batch") < paths.index("/stories/{work_item_id}")


def test_update_request_omits_unused_fields_but_keeps_requested_patch():
    request = UpdateStoryRequest.model_validate(
        {"fields": {"points": 3}, "unused": "ignored"}
    )

    values = _request_values(request, exclude_unset=True)

    assert values == {"fields": {"points": 3}}