"""Read-only Azure DevOps REST client.

Authentication order:
1. ``ADO_PAT`` environment variable (PAT with *Work Items (Read)* scope).
2. Fallback to the signed-in Azure CLI (``az account get-access-token``).

This client only ever issues GETs and the WIQL POST (which is a read).
Nothing here can modify a work item.
"""

from __future__ import annotations

import base64
import json
import os
import re
import subprocess
from typing import Any, Dict, Iterable, List, Optional, Sequence

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from .models import UNASSIGNED, Story

API_VERSION = "7.1"
COMMENTS_API_VERSION = "7.1-preview.3"
# Azure DevOps resource ID, used when falling back to Azure CLI auth.
ADO_RESOURCE_ID = "499b84ac-1321-427f-aa17-267ca6975798"
# The work items batch endpoint rejects more than 200 ids per call.
MAX_IDS_PER_BATCH = 200
REQUEST_TIMEOUT = 60

IMAGE_PATTERN = re.compile(r"(<img\b|\.(?:jpg|jpeg|png)\b)", re.IGNORECASE)

FIELDS = (
    "System.Id",
    "System.Title",
    "System.State",
    "System.AssignedTo",
)


class AdoError(RuntimeError):
    """Raised when Azure DevOps cannot be reached or returns an error."""


def _az_cli_token() -> Optional[str]:
    """Best-effort token from the signed-in Azure CLI."""
    try:
        completed = subprocess.run(
            [
                "az",
                "account",
                "get-access-token",
                "--resource",
                ADO_RESOURCE_ID,
                "--output",
                "json",
            ],
            capture_output=True,
            text=True,
            timeout=60,
            shell=os.name == "nt",
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if completed.returncode != 0:
        return None
    try:
        return json.loads(completed.stdout).get("accessToken")
    except (ValueError, AttributeError):
        return None


def ado_auth_headers() -> Dict[str, str]:
    pat = os.environ.get("ADO_PAT", "").strip()
    if pat:
        encoded = base64.b64encode(f":{pat}".encode("utf-8")).decode("ascii")
        return {"Authorization": f"Basic {encoded}"}

    token = _az_cli_token()
    if token:
        return {"Authorization": f"Bearer {token}"}

    raise AdoError(
        "No Azure DevOps credentials. Set ADO_PAT with the required work-item scope or "
        "sign in with 'az login'."
    )


def _chunks(values: Sequence[int], size: int) -> Iterable[Sequence[int]]:
    for start in range(0, len(values), size):
        yield values[start : start + size]


class AdoClient:
    """Thin, read-only wrapper over the Azure DevOps REST API."""

    def __init__(self, org_url: str, project: str) -> None:
        self.org_url = org_url.rstrip("/")
        self.project = project
        self.session = requests.Session()
        self.session.headers.update(ado_auth_headers())
        self.session.headers.update({"Accept": "application/json"})
        retry = Retry(
            total=3,
            backoff_factor=1.0,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=frozenset(["GET", "POST"]),
        )
        self.session.mount("https://", HTTPAdapter(max_retries=retry))

    def _request(self, method: str, url: str, **kwargs: Any) -> Dict[str, Any]:
        response = self.session.request(method, url, timeout=REQUEST_TIMEOUT, **kwargs)
        # ADO answers bad credentials with an HTML sign-in page, not a 401.
        content_type = response.headers.get("Content-Type", "")
        if "application/json" not in content_type:
            raise AdoError(
                f"Unexpected non-JSON response from {url} (HTTP {response.status_code}). "
                "This usually means the credentials are invalid or expired."
            )
        if not response.ok:
            raise AdoError(f"HTTP {response.status_code} from {url}: {response.text[:400]}")
        return response.json()

    def current_iteration(self, team_name: str) -> Dict[str, str]:
        """Return ``{'name': ..., 'path': ...}`` for the team's current sprint."""
        url = (
            f"{self.org_url}/{self.project}/{team_name}/_apis/work/teamsettings/iterations"
            f"?$timeframe=current&api-version={API_VERSION}"
        )
        payload = self._request("GET", url)
        iterations = payload.get("value") or []
        if not iterations:
            raise AdoError(f"No current iteration found for team '{team_name}'.")
        iteration = iterations[0]
        return {"name": iteration.get("name", ""), "path": iteration.get("path", "")}

    def story_ids_in_iteration(self, iteration_path: str) -> List[int]:
        """IDs of every User Story under the given iteration path."""
        # WIQL paths use backslashes; the API takes them literally.
        escaped = iteration_path.replace("'", "''")
        wiql = (
            "SELECT [System.Id] FROM WorkItems "
            "WHERE [System.TeamProject] = @project "
            "AND [System.WorkItemType] = 'User Story' "
            f"AND [System.IterationPath] UNDER '{escaped}'"
        )
        url = f"{self.org_url}/{self.project}/_apis/wit/wiql?api-version={API_VERSION}"
        payload = self._request("POST", url, json={"query": wiql})
        return [int(item["id"]) for item in payload.get("workItems", [])]

    def fetch_stories(self, ids: Sequence[int]) -> List[Story]:
        """Hydrate stories, including attachment counts."""
        stories: List[Story] = []
        for batch in _chunks(list(ids), MAX_IDS_PER_BATCH):
            url = (
                f"{self.org_url}/_apis/wit/workitems"
                f"?ids={','.join(str(i) for i in batch)}"
                f"&$expand=relations&api-version={API_VERSION}"
            )
            payload = self._request("GET", url)
            for item in payload.get("value", []):
                stories.append(self._to_story(item))
        return stories

    @staticmethod
    def _to_story(item: Dict[str, Any]) -> Story:
        fields = item.get("fields", {}) or {}
        assigned = fields.get("System.AssignedTo") or {}
        relations = item.get("relations") or []
        attachments = sum(1 for rel in relations if rel.get("rel") == "AttachedFile")
        return Story(
            id=int(item["id"]),
            title=fields.get("System.Title", ""),
            state=fields.get("System.State", ""),
            assignee=assigned.get("displayName") or UNASSIGNED,
            # uniqueName is the UPN and the correct key for a Teams mention.
            upn=assigned.get("uniqueName"),
            attachment_count=attachments,
        )

    def has_comment_image(self, work_item_id: int) -> bool:
        """True when any discussion comment embeds an image."""
        url = (
            f"{self.org_url}/{self.project}/_apis/wit/workItems/{work_item_id}/comments"
            f"?api-version={COMMENTS_API_VERSION}"
        )
        payload = self._request("GET", url)
        for comment in payload.get("comments", []) or []:
            if IMAGE_PATTERN.search(comment.get("text") or ""):
                return True
        return False
