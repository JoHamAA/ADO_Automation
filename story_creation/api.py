"""Local REST API for batched story creation and partial field updates."""

from __future__ import annotations

import os
from typing import Any, Dict, List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, ConfigDict, Field

from eo_review.ado_client import AdoError

from .client import StoryClient
from .service import DEFAULT_ORG_URL, StoryService


class APIModel(BaseModel):
    model_config = ConfigDict(extra="ignore")


class CreateStoryRequest(APIModel):
    title: str
    backlog: str = "pax"
    work_item_type: str | None = None
    project: str | None = None
    area_path: str | None = None
    iteration_path: str | None = None
    parent_id: int | None = None
    fields: Dict[str, Any] = Field(default_factory=dict)
    description: Any = None
    acceptance_criteria: Any = None
    notes: str | None = None
    state: str | None = None
    rank: float | None = None
    stack_rank: float | None = None
    points: float | None = None
    story_points: float | None = None
    priority: int | None = None
    ready: str | None = None
    work_type: str | None = None
    tags: str | List[str] | None = None


class BatchCreateRequest(APIModel):
    stories: List[CreateStoryRequest] = Field(default_factory=list)


class UpdateStoryRequest(APIModel):
    fields: Dict[str, Any] = Field(default_factory=dict)
    description: Any = None
    acceptance_criteria: Any = None
    notes: str | None = None
    title: str | None = None
    state: str | None = None
    rank: float | None = None
    stack_rank: float | None = None
    points: float | None = None
    story_points: float | None = None
    priority: int | None = None
    ready: str | None = None
    work_type: str | None = None
    tags: str | List[str] | None = None
    area_path: str | None = None
    iteration_path: str | None = None


class BatchUpdateItem(UpdateStoryRequest):
    id: int


class BatchUpdateRequest(APIModel):
    updates: List[BatchUpdateItem] = Field(default_factory=list)


def _service() -> StoryService:
    client = StoryClient(os.environ.get("ADO_ORG_URL", DEFAULT_ORG_URL))
    return StoryService(client)


def _request_values(request: BaseModel, *, exclude_unset: bool = False) -> Dict[str, Any]:
    return request.model_dump(exclude_none=True, exclude_unset=exclude_unset)


def create_app(service_factory=_service) -> FastAPI:
    app = FastAPI(title="Story Creation Service", version="1.0.0")

    @app.get("/health")
    def health() -> Dict[str, str]:
        return {"status": "ok"}

    @app.post("/stories")
    def create_story(request: CreateStoryRequest) -> Dict[str, Any]:
        try:
            return service_factory().create_story(_request_values(request))
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except AdoError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc

    @app.post("/stories/batch")
    def create_stories(request: BatchCreateRequest) -> Dict[str, Any]:
        if not request.stories:
            return {"results": []}
        results = service_factory().create_batch(
            [_request_values(story) for story in request.stories]
        )
        return {"results": results}

    @app.patch("/stories/batch")
    def update_stories(request: BatchUpdateRequest) -> Dict[str, Any]:
        if not request.updates:
            return {"results": []}
        results = service_factory().update_batch(
            [
                _request_values(item, exclude_unset=True)
                for item in request.updates
            ]
        )
        return {"results": results}

    @app.patch("/stories/{work_item_id}")
    def update_story(
        work_item_id: int,
        request: UpdateStoryRequest,
    ) -> Dict[str, Any]:
        try:
            return service_factory().update_story(
                work_item_id,
                _request_values(request, exclude_unset=True),
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except AdoError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc

    return app


app = create_app()