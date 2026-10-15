"""Story creation and update orchestration over Azure DevOps REST."""

from __future__ import annotations

import os
import re
import math
from pathlib import Path
from typing import Any, Dict, Mapping, Sequence
from urllib.parse import quote

import yaml

from eo_review.ado_client import AdoError
from .client import AdoHttpError, StoryClient
from .formatting import format_acceptance_criteria, format_description

DEFAULT_ORG_URL = "https://dev.azure.com/AmericanAirlines"
DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent.parent / ".github" / "config.yaml"
PARENT_RELATION = "System.LinkTypes.Hierarchy-Reverse"

FIELD_ALIASES = {
    "title": "System.Title",
    "state": "System.State",
    "description": "System.Description",
    "acceptance_criteria": "Microsoft.VSTS.Common.AcceptanceCriteria",
    "notes": "System.History",
    "history": "System.History",
    "rank": "Microsoft.VSTS.Common.StackRank",
    "stack_rank": "Microsoft.VSTS.Common.StackRank",
    "points": "Microsoft.VSTS.Scheduling.StoryPoints",
    "story_points": "Microsoft.VSTS.Scheduling.StoryPoints",
    "priority": "Microsoft.VSTS.Common.Priority",
    "ready": "AAIT.Ready",
    "work_type": "AAIT.WorkType",
    "tags": "System.Tags",
    "area_path": "System.AreaPath",
    "iteration_path": "System.IterationPath",
}


def _field_name(name: str) -> str:
    return FIELD_ALIASES.get(name.casefold(), name)


def _normalize_tags(value: Any) -> list[str]:
    if isinstance(value, str):
        values = value.split(";")
    elif isinstance(value, Sequence):
        values = value
    else:
        return []
    return list(dict.fromkeys(str(tag).strip() for tag in values if str(tag).strip()))


def _normalized_value(value: Any) -> Any:
    if isinstance(value, str):
        return re.sub(r"\s+</div>", "</div>", value).rstrip()
    return value


class StoryService:
    """Create or update stories; omitted fields are left unchanged."""

    def __init__(
        self,
        client: StoryClient,
        config_path: Path | None = None,
    ) -> None:
        self.client = client
        self.config_path = config_path or DEFAULT_CONFIG_PATH
        with self.config_path.open("r", encoding="utf-8") as handle:
            self.config = yaml.safe_load(handle) or {}
        self.org_url = os.environ.get("ADO_ORG_URL", DEFAULT_ORG_URL).rstrip("/")

    def _backlog(self, backlog_key: str) -> Mapping[str, Any]:
        backlog = (self.config.get("backlogs") or {}).get(backlog_key.casefold())
        if not isinstance(backlog, Mapping):
            raise ValueError(f"Unknown backlog '{backlog_key}'")
        return backlog

    def _target(
        self,
        backlog_key: str,
        request: Mapping[str, Any],
        parent: Mapping[str, Any] | None = None,
    ) -> tuple[str, str, str, Mapping[str, Any]]:
        backlog = self._backlog(backlog_key)
        project = str(request.get("project") or backlog.get("project") or "")
        if not project:
            raise ValueError(f"Project is not configured for backlog '{backlog_key}'")
        parent_area = (parent or {}).get("System.AreaPath")
        requested_area = request.get("area_path") or request.get("area")
        if parent_area and requested_area and str(requested_area) != str(parent_area):
            raise ValueError("area_path must match the supplied parent Feature")
        area = str(parent_area or requested_area or backlog.get("areaPath") or project)
        iteration = request.get("iteration_path") or request.get("iteration")
        if not iteration:
            iteration = backlog.get("activeIteration")
            if not iteration or str(iteration).startswith("@"):
                active_team = str(backlog.get("activeTeam") or "")
                team = (backlog.get("teams") or {}).get(active_team) or {}
                team_name = team.get("name")
                if team_name:
                    current = self.client.current_iteration(project, str(team_name))
                    iteration = current.get("path")
                else:
                    iteration = project
        return project, area, str(iteration), backlog

    def _prepare_fields(
        self,
        request: Mapping[str, Any],
        *,
        create: bool,
        title: str | None = None,
    ) -> Dict[str, Any]:
        fields: Dict[str, Any] = {}
        provided = request.get("fields") or {}
        if not isinstance(provided, Mapping):
            raise ValueError("fields must be an object")
        for name, value in provided.items():
            if value is not None:
                fields[_field_name(str(name))] = value

        for name in ("description", "acceptance_criteria", "notes"):
            if name not in request or request[name] is None:
                continue
            value = request[name]
            if name == "description":
                value = format_description(value)
            elif name == "acceptance_criteria":
                value = format_acceptance_criteria(value)
            if value is not None:
                fields[FIELD_ALIASES[name]] = value

        for name, field_name in FIELD_ALIASES.items():
            if name in ("description", "acceptance_criteria", "notes", "history"):
                continue
            if name in request and request[name] is not None:
                fields[field_name] = request[name]

        if create:
            fields["System.Title"] = title or fields.get("System.Title")
        return {name: value for name, value in fields.items() if value is not None}

    def _parent(self, parent_id: int | None, project: str) -> Mapping[str, Any] | None:
        if parent_id is None:
            return None
        item = self.client.get_work_item(parent_id)
        fields = item.get("fields") or {}
        if fields.get("System.WorkItemType") != "Feature":
            raise ValueError(f"Parent {parent_id} is not a Feature")
        if project and fields.get("System.TeamProject") not in (None, project):
            raise ValueError(f"Parent {parent_id} is not in project '{project}'")
        return fields

    def _minimum_rank(self, project: str, area: str, iteration: str) -> float | None:
        safe_project = project.replace("'", "''")
        safe_area = area.replace("'", "''")
        safe_iteration = iteration.replace("'", "''")
        wiql = (
            "SELECT [System.Id] FROM WorkItems "
            f"WHERE [System.TeamProject] = '{safe_project}' "
            "AND [System.WorkItemType] = 'User Story' "
            f"AND [System.AreaPath] UNDER '{safe_area}' "
            f"AND [System.IterationPath] UNDER '{safe_iteration}' "
            "ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
        )
        matches = self.client.query(project, wiql)
        if not matches:
            return None
        item = self.client.get_work_item(int(matches[0]["id"]))
        rank = (item.get("fields") or {}).get("Microsoft.VSTS.Common.StackRank")
        try:
            return float(rank)
        except (TypeError, ValueError):
            return None

    def _verify_fields(
        self,
        work_item: Mapping[str, Any],
        expected: Mapping[str, Any],
        *,
        skip: Sequence[str] = (),
    ) -> None:
        actual_fields = work_item.get("fields") or {}
        for name, expected_value in expected.items():
            if name in skip:
                continue
            actual_value = actual_fields.get(name)
            if name == "System.Tags":
                if set(_normalize_tags(actual_value)) != set(_normalize_tags(expected_value)):
                    raise AdoError("Verification failed for field 'System.Tags'")
                continue
            if _normalized_value(actual_value) != _normalized_value(expected_value):
                raise AdoError(f"Verification failed for field '{name}'")

    def create_story(self, request: Mapping[str, Any]) -> Dict[str, Any]:
        title = str(request.get("title") or "").strip()
        if not title:
            raise ValueError("title is required to create a story")
        backlog_key = str(request.get("backlog") or "pax")
        work_item_type = str(
            request.get("work_item_type")
            or (self.config.get("defaults") or {}).get("workItemType")
            or "User Story"
        )
        parent_id = request.get("parent_id")
        parent_fields = self._parent(int(parent_id), "") if parent_id is not None else None
        project, area, iteration, backlog = self._target(
            backlog_key, request, parent=parent_fields
        )
        if parent_fields is not None and parent_fields.get("System.TeamProject") not in (
            None,
            project,
        ):
            raise ValueError(f"Parent {parent_id} is not in project '{project}'")

        defaults = self.config.get("defaults") or {}
        ready_value = defaults.get("ready", "Yes")
        if isinstance(ready_value, bool):
            ready_value = "Yes" if ready_value else "No"
        fields: Dict[str, Any] = {
            "System.Title": title,
            "System.State": "Backlog",
            "System.AreaPath": area,
            "System.IterationPath": iteration,
            "Microsoft.VSTS.Scheduling.StoryPoints": defaults.get("storyPoints", 0),
            "Microsoft.VSTS.Common.Priority": defaults.get("priority", 2),
            "AAIT.Ready": ready_value,
            "AAIT.WorkType": defaults.get("workType", "4. Software / UX"),
        }
        explicit_fields = self._prepare_fields(request, create=True, title=title)
        fields.update(explicit_fields)

        if parent_fields is not None:
            parent_tags = _normalize_tags(parent_fields.get("System.Tags"))
            tags = _normalize_tags(fields.get("System.Tags", []))
            fields["System.Tags"] = list(
                dict.fromkeys(["AI-StoryWriting", *parent_tags, *tags])
            )
        else:
            tags = _normalize_tags(fields.get("System.Tags", []))
            fields["System.Tags"] = list(dict.fromkeys(["AI-StoryWriting", *tags]))
        if isinstance(fields.get("System.Tags"), list):
            fields["System.Tags"] = "; ".join(fields["System.Tags"])

        rank_name = "Microsoft.VSTS.Common.StackRank"
        if (
            rank_name not in fields
            and (self.config.get("defaults") or {}).get("placeNewStoriesAtTopOfBacklog", False)
        ):
            minimum = self._minimum_rank(project, area, iteration)
            rank_fallback = minimum is None
            fields[rank_name] = math.floor(minimum) - 1 if minimum is not None else 1000
        else:
            rank_fallback = False

        try:
            created = self.client.create_work_item(
                project,
                work_item_type,
                fields,
                int(parent_id) if parent_id is not None else None,
            )
        except AdoHttpError as exc:
            status = "create_failed" if exc.status_code < 500 else "create_outcome_unknown"
            return self._write_result(status, title, project, error=str(exc))
        except (AdoError, OSError) as exc:
            return self._write_result(
                "create_outcome_unknown", title, project, error=str(exc)
            )

        try:
            work_item_id = int(created.get("id") or 0)
        except (TypeError, ValueError):
            work_item_id = 0
        if work_item_id <= 0:
            return self._write_result(
                "create_outcome_unknown",
                title,
                project,
                error="ADO did not return a usable work-item ID; do not retry automatically",
            )

        try:
            persisted = self.client.get_work_item(work_item_id)
            self._verify_fields(persisted, fields, skip=("System.History",))
            if persisted.get("fields", {}).get("System.WorkItemType") != work_item_type:
                raise AdoError("Verification failed for work item type")
            if parent_id is not None:
                relations = persisted.get("relations") or []
                expected_parent_url = f"/_apis/wit/workItems/{parent_id}".casefold()
                if not any(
                    relation.get("rel") == PARENT_RELATION
                    and expected_parent_url in str(relation.get("url", "")).casefold()
                    for relation in relations
                ):
                    raise AdoError("Verification failed for parent relation")
        except (AdoError, OSError, ValueError, TypeError) as exc:
            return self._write_result(
                "created_unverified",
                title,
                project,
                work_item_id=work_item_id,
                error=str(exc),
            )

        result = self._result(work_item_id, title, project)
        result["status"] = "created_verified"
        if rank_fallback:
            result["rank_fallback"] = True
        return result

    def update_story(self, work_item_id: int, request: Mapping[str, Any]) -> Dict[str, Any]:
        fields = self._prepare_fields(request, create=False)
        if not fields:
            return {"id": work_item_id, "updated": False, "status": "no fields supplied"}
        try:
            self.client.update_work_item(work_item_id, fields)
        except AdoHttpError as exc:
            status = "update_failed" if exc.status_code < 500 else "update_outcome_unknown"
            return self._write_result(
                status, "", "", work_item_id=work_item_id, error=str(exc)
            )
        except (AdoError, OSError) as exc:
            return self._write_result(
                "update_outcome_unknown", "", "", work_item_id=work_item_id, error=str(exc)
            )
        try:
            persisted = self.client.get_work_item(work_item_id)
            self._verify_fields(persisted, fields, skip=("System.History",))
        except (AdoError, OSError, ValueError, TypeError) as exc:
            persisted = None
            verification_error = str(exc)
        else:
            verification_error = None
        persisted_fields = (persisted or {}).get("fields") or {}
        project = str(persisted_fields.get("System.TeamProject") or "")
        title = str(persisted_fields.get("System.Title") or "")
        if verification_error:
            return self._write_result(
                "updated_unverified",
                title,
                project,
                work_item_id=work_item_id,
                error=verification_error,
            )
        result = self._result(work_item_id, title, project)
        result["status"] = "updated_verified"
        return result

    def create_batch(self, requests: Sequence[Mapping[str, Any]]) -> list[Dict[str, Any]]:
        request_list = list(requests)
        results: list[Dict[str, Any] | None] = [None] * len(request_list)
        rank_field = "Microsoft.VSTS.Common.StackRank"
        rank_enabled = bool(
            (self.config.get("defaults") or {}).get("placeNewStoriesAtTopOfBacklog", False)
        )
        scopes: Dict[tuple[str, str, str], list[int]] = {}

        for index, request in enumerate(request_list):
            if not rank_enabled or self._has_explicit_rank(request):
                continue
            try:
                scope = self._rank_scope(request)
                scopes.setdefault(scope, []).append(index)
            except (AdoError, OSError, ValueError) as exc:
                results[index] = {
                    "status": "failed",
                    "title": request.get("title"),
                    "error": str(exc),
                }

        scope_ranks: Dict[tuple[str, str, str], tuple[float | None, str | None]] = {}
        for scope in scopes:
            try:
                scope_ranks[scope] = (
                    self._minimum_rank(*scope),
                    None,
                )
            except (AdoError, OSError, ValueError) as exc:
                scope_ranks[scope] = (None, str(exc))

        for scope, indexes in scopes.items():
            minimum, error = scope_ranks[scope]
            if error:
                for index in indexes:
                    results[index] = {
                        "status": "failed",
                        "title": request_list[index].get("title"),
                        "error": f"StackRank preflight failed: {error}",
                    }
                continue
            next_rank = math.floor(minimum) - 1 if minimum is not None else 1000
            for index in indexes:
                request = dict(request_list[index])
                fields = dict(request.get("fields") or {})
                fields[rank_field] = next_rank
                request["fields"] = fields
                if minimum is None:
                    request["_rank_fallback"] = True
                request_list[index] = request
                next_rank -= 1

        for index, request in enumerate(request_list):
            if results[index] is not None:
                continue
            try:
                created = self.create_story(request)
                created_result = {"status": "created", **created}
                if request.get("_rank_fallback"):
                    created_result["rank_fallback"] = True
                results[index] = created_result
            except (AdoError, OSError, ValueError) as exc:
                results[index] = {
                    "status": "failed",
                    "title": request.get("title"),
                    "error": str(exc),
                }
        return [result for result in results if result is not None]

    def update_batch(self, requests: Sequence[Mapping[str, Any]]) -> list[Dict[str, Any]]:
        results = []
        for request in requests:
            item_id = request.get("id") or request.get("work_item_id")
            if item_id is None:
                results.append(
                    {"status": "failed", "error": "id is required for an update"}
                )
                continue
            try:
                update_fields = {
                    key: value
                    for key, value in request.items()
                    if key not in ("id", "work_item_id")
                }
                updated = self.update_story(int(item_id), update_fields)
                results.append({"status": "updated", **updated})
            except (AdoError, OSError, ValueError) as exc:
                results.append(
                    {"status": "failed", "id": item_id, "error": str(exc)}
                )
        return results

    @staticmethod
    def _has_explicit_rank(request: Mapping[str, Any]) -> bool:
        rank_field = "Microsoft.VSTS.Common.StackRank"
        if any(
            _field_name(str(name)) == rank_field and value is not None
            for name, value in (request.get("fields") or {}).items()
        ):
            return True
        return request.get("rank") is not None or request.get("stack_rank") is not None

    def _rank_scope(self, request: Mapping[str, Any]) -> tuple[str, str, str]:
        parent_id = request.get("parent_id")
        parent = self._parent(int(parent_id), "") if parent_id is not None else None
        project, area, iteration, _ = self._target(
            str(request.get("backlog") or "pax"), request, parent
        )
        if parent is not None and parent.get("System.TeamProject") not in (None, project):
            raise ValueError(f"Parent {parent_id} is not in project '{project}'")
        return project, area, iteration

    def _result(self, work_item_id: int, title: str, project: str) -> Dict[str, Any]:
        project_path = quote(project.strip("/"), safe="")
        return {
            "id": work_item_id,
            "title": title,
            "url": f"{self.org_url}/{project_path}/_workitems/edit/{work_item_id}",
        }

    def _write_result(
        self,
        status: str,
        title: str,
        project: str,
        *,
        work_item_id: int | None = None,
        error: str,
    ) -> Dict[str, Any]:
        if work_item_id is None:
            return {
                "status": status,
                "id": None,
                "title": title,
                "url": None,
                "error": error,
            }
        return {
            "status": status,
            **self._result(work_item_id, title, project),
            "error": error,
        }