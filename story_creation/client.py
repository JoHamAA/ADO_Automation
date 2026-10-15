"""Write-capable Azure DevOps REST client for story operations."""

from __future__ import annotations

from typing import Any, Dict, Mapping, Sequence
from urllib.parse import quote

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from eo_review.ado_client import API_VERSION, AdoError, REQUEST_TIMEOUT, ado_auth_headers


class AdoHttpError(AdoError):
    """ADO returned an HTTP error with a known status code."""

    def __init__(self, status_code: int, message: str) -> None:
        self.status_code = status_code
        super().__init__(message)


class StoryClient:
    """Create, update, and read work items without retrying writes."""

    def __init__(self, org_url: str) -> None:
        self.org_url = org_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update(ado_auth_headers())
        self.session.headers.update({"Accept": "application/json"})
        retry = Retry(
            total=3,
            backoff_factor=0.5,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=frozenset({"GET"}),
        )
        self.session.mount("https://", HTTPAdapter(max_retries=retry))

    def _request(self, method: str, url: str, **kwargs: Any) -> Dict[str, Any]:
        try:
            response = self.session.request(
                method, url, timeout=REQUEST_TIMEOUT, **kwargs
            )
        except requests.RequestException as exc:
            raise AdoError(f"Azure DevOps {method} request failed: {exc}") from exc
        if not response.ok:
            raise AdoHttpError(
                response.status_code,
                f"HTTP {response.status_code} from Azure DevOps: "
                f"{response.text[:400]}"
            )
        if not response.content:
            return {}
        try:
            return response.json()
        except ValueError as exc:
            raise AdoError("Azure DevOps returned an invalid JSON response") from exc

    @staticmethod
    def _field_patch(fields: Mapping[str, Any]) -> list[Dict[str, Any]]:
        return [
            {"op": "add", "path": f"/fields/{name}", "value": value}
            for name, value in fields.items()
            if value is not None
        ]

    def create_work_item(
        self,
        project: str,
        work_item_type: str,
        fields: Mapping[str, Any],
        parent_id: int | None = None,
    ) -> Dict[str, Any]:
        patch = self._field_patch(fields)
        if parent_id is not None:
            patch.append(
                {
                    "op": "add",
                    "path": "/relations/-",
                    "value": {
                        "rel": "System.LinkTypes.Hierarchy-Reverse",
                        "url": f"{self.org_url}/_apis/wit/workItems/{parent_id}",
                    },
                }
            )
        if not any(op["path"] == "/fields/System.Title" for op in patch):
            raise ValueError("System.Title is required to create a work item")
        type_segment = quote(work_item_type, safe="")
        project_segment = quote(project, safe="")
        url = (
            f"{self.org_url}/{project_segment}/_apis/wit/workitems/"
            f"${type_segment}?api-version={API_VERSION}"
        )
        return self._request(
            "POST",
            url,
            json=patch,
            headers={"Content-Type": "application/json-patch+json"},
        )

    def update_work_item(
        self,
        work_item_id: int,
        fields: Mapping[str, Any],
    ) -> Dict[str, Any]:
        patch = self._field_patch(fields)
        if not patch:
            return {}
        url = (
            f"{self.org_url}/_apis/wit/workitems/{work_item_id}"
            f"?api-version={API_VERSION}"
        )
        return self._request(
            "PATCH",
            url,
            json=patch,
            headers={"Content-Type": "application/json-patch+json"},
        )

    def get_work_item(self, work_item_id: int) -> Dict[str, Any]:
        url = (
            f"{self.org_url}/_apis/wit/workitems/{work_item_id}"
            f"?$expand=relations&api-version={API_VERSION}"
        )
        return self._request("GET", url)

    def current_iteration(self, project: str, team_name: str) -> Dict[str, str]:
        project_segment = quote(project, safe="")
        team_segment = quote(team_name, safe="")
        url = (
            f"{self.org_url}/{project_segment}/{team_segment}/_apis/work/"
            f"teamsettings/iterations?$timeframe=current&api-version={API_VERSION}"
        )
        payload = self._request("GET", url)
        iterations = payload.get("value") or []
        if not iterations:
            raise AdoError(f"No current iteration found for team '{team_name}'")
        return {
            "name": str(iterations[0].get("name", "")),
            "path": str(iterations[0].get("path", "")),
        }

    def query(self, project: str, wiql: str) -> Sequence[Dict[str, Any]]:
        url = (
            f"{self.org_url}/{quote(project, safe='')}/_apis/wit/wiql"
            f"?api-version={API_VERSION}"
        )
        payload = self._request("POST", url, json={"query": wiql})
        return payload.get("workItems", []) or []