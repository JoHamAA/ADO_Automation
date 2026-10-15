"""Azure DevOps REST operations used by the tag-inheritance command."""

from __future__ import annotations

import re
from urllib.parse import quote, urlencode, urljoin, urlparse
from typing import Any, Dict, List, Sequence, Tuple

import requests

from eo_review.ado_client import (
    API_VERSION,
    MAX_IDS_PER_BATCH,
    AdoClient,
    AdoError,
    _chunks,
)

from .image_tags import ImageTagError, ImageTagMatch, scan_image_sources
from .models import TagWorkItem, parse_tags

PARENT_RELATION = "System.LinkTypes.Hierarchy-Reverse"
COMMENTS_API_VERSION = "7.1-preview.3"
MAX_IMAGE_BYTES = 20 * 1024 * 1024


def _parent_ids(relations: Sequence[Dict[str, Any]]) -> Tuple[int, ...]:
    parent_ids: List[int] = []
    for relation in relations:
        if relation.get("rel") != PARENT_RELATION:
            continue
        try:
            parent_ids.append(int(str(relation.get("url", "")).rstrip("/").rsplit("/", 1)[-1]))
        except ValueError:
            continue
    return tuple(parent_ids)


class TagInheritanceClient(AdoClient):
    """REST client with explicit tag read and write operations."""

    def iteration_by_number(
        self,
        team_name: str,
        team_iteration_path: str,
        sprint_number: int,
    ) -> Dict[str, str]:
        """Resolve a numbered sprint beneath the team's configured iteration root."""
        path_parts = [part for part in re.split(r"[\\/]+", team_iteration_path) if part]
        if path_parts and path_parts[0].casefold() == self.project.casefold():
            path_parts = path_parts[1:]
        encoded_path = "/".join(quote(part, safe="") for part in path_parts)
        project_segment = quote(self.project, safe="")
        url = (
            f"{self.org_url}/{project_segment}/_apis/wit/classificationnodes/"
            f"iterations/{encoded_path}"
            f"?{urlencode({'$depth': 2, 'api-version': API_VERSION})}"
        )
        payload = self._request("GET", url)

        iterations = []
        pending = [
            (node, (str(node.get("name") or ""),))
            for node in payload.get("children") or []
        ]
        while pending:
            node, relative_parts = pending.pop()
            iterations.append((node, relative_parts))
            pending.extend(
                (
                    child,
                    relative_parts + (str(child.get("name") or ""),),
                )
                for child in node.get("children") or []
            )

        sprint_pattern = re.compile(rf"(?<!\d){sprint_number}(?!\d)")
        matches = [
            (item, relative_parts)
            for item, relative_parts in iterations
            if sprint_pattern.search(str(item.get("name") or ""))
        ]
        if not matches:
            raise AdoError(
                f"No iteration matching sprint {sprint_number} was found under "
                f"'{team_iteration_path}' for team '{team_name}'."
            )
        if len(matches) > 1:
            names = ", ".join(
                str(item.get("name") or item.get("path"))
                for item, _ in matches
            )
            raise AdoError(
                f"Sprint number {sprint_number} is ambiguous for team '{team_name}': {names}."
            )

        selected, relative_parts = matches[0]
        selected_name = str(selected.get("name") or "")
        team_path = team_iteration_path.rstrip("\\/")
        selected_path = "\\".join((team_path, *relative_parts))
        return {
            "name": selected_name,
            "path": selected_path,
        }

    def fetch_tag_work_items(
        self,
        ids: Sequence[int],
        include_relations: bool = False,
    ) -> List[TagWorkItem]:
        items: List[TagWorkItem] = []
        for batch in _chunks(list(ids), MAX_IDS_PER_BATCH):
            expand = "&$expand=relations" if include_relations else ""
            url = (
                f"{self.org_url}/_apis/wit/workitems"
                f"?ids={','.join(str(item_id) for item_id in batch)}"
                f"{expand}&api-version={API_VERSION}"
            )
            payload = self._request("GET", url)
            items.extend(self._to_tag_work_item(item) for item in payload.get("value", []))
        return items

    @staticmethod
    def _to_tag_work_item(item: Dict[str, Any]) -> TagWorkItem:
        fields = item.get("fields", {}) or {}
        return TagWorkItem(
            id=int(item["id"]),
            title=str(fields.get("System.Title", "")),
            work_item_type=str(fields.get("System.WorkItemType", "")),
            tags=parse_tags(fields.get("System.Tags")),
            revision=int(item.get("rev", 0)),
            parent_ids=_parent_ids(item.get("relations") or []),
            notes=str(fields.get("Microsoft.VSTS.Common.Notes") or ""),
        )

    def fetch_discussion_comments(self, story_id: int) -> List[Tuple[str, str]]:
        """Fetch every Discussion comment, following ADO continuation tokens."""
        comments: List[Tuple[str, str]] = []
        continuation_token = None
        seen_tokens = set()
        while True:
            params = {"api-version": COMMENTS_API_VERSION, "$top": "200"}
            if continuation_token:
                params["continuationToken"] = continuation_token
            url = (
                f"{self.org_url}/{self.project}/_apis/wit/workItems/{story_id}/comments?"
                f"{urlencode(params)}"
            )
            payload = self._request("GET", url)
            for comment in payload.get("comments", []) or []:
                comment_id = comment.get("id")
                label = f"Discussion comment {comment_id}" if comment_id else "Discussion"
                comments.append((label, str(comment.get("text") or "")))

            next_token = payload.get("continuationToken")
            if not next_token or next_token in seen_tokens:
                break
            seen_tokens.add(next_token)
            continuation_token = str(next_token)
        return comments

    def download_image(self, image_url: str) -> bytes:
        """Download an embedded image without sending ADO credentials off-host."""
        resolved_url = urljoin(f"{self.org_url}/", image_url)
        base = urlparse(self.org_url)
        target = urlparse(resolved_url)
        if (
            target.scheme != "https"
            or target.netloc.casefold() != base.netloc.casefold()
        ):
            raise ImageTagError("Embedded image URL is not on the configured ADO host.")

        try:
            with self.session.get(
                resolved_url,
                timeout=60,
                stream=True,
            ) as response:
                response.raise_for_status()
                content_length = response.headers.get("Content-Length")
                if content_length and int(content_length) > MAX_IMAGE_BYTES:
                    raise ImageTagError("Embedded image exceeds the 20 MB scan limit.")
                image_bytes = bytearray()
                for chunk in response.iter_content(chunk_size=64 * 1024):
                    image_bytes.extend(chunk)
                    if len(image_bytes) > MAX_IMAGE_BYTES:
                        raise ImageTagError("Embedded image exceeds the 20 MB scan limit.")
                return bytes(image_bytes)
        except requests.RequestException as exc:
            raise ImageTagError(f"Could not download embedded image: {exc}") from exc

    def image_tag_matches(self, story: TagWorkItem) -> Tuple[ImageTagMatch, ...]:
        """OCR inline images from Notes and Discussion, never generic attachments."""
        sources: List[Tuple[str, str]] = []
        if story.notes:
            sources.append(("Notes", story.notes))
        try:
            sources.extend(self.fetch_discussion_comments(story.id))
        except Exception as exc:
            raise ImageTagError(f"Could not read Discussion comments: {exc}") from exc
        base_progress = getattr(self, "progress", None)
        progress = (
            (lambda message: base_progress(f"[{story.id}] {message}"))
            if base_progress
            else None
        )
        return scan_image_sources(
            sources,
            self.download_image,
            cache=getattr(self, "ocr_cache", None),
            progress=progress,
        )

    def update_story_tags(
        self,
        story_id: int,
        revision: int,
        tags: Sequence[str],
    ) -> None:
        """Replace the tag field once, guarded by the revision shown for approval."""
        url = f"{self.org_url}/_apis/wit/workitems/{story_id}?api-version={API_VERSION}"
        patch = [
            {"op": "test", "path": "/rev", "value": revision},
            {"op": "add", "path": "/fields/System.Tags", "value": "; ".join(tags)},
        ]
        self._request(
            "PATCH",
            url,
            json=patch,
            headers={"Content-Type": "application/json-patch+json"},
        )
