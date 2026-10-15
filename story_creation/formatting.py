"""Gherkin content serialization for Azure DevOps rich-text fields."""

from __future__ import annotations

from html import escape
import re
from typing import Any, Mapping, Sequence


def _text(value: Any) -> str:
    return escape(str(value), quote=False)


def _gherkin_lines(values: Sequence[Any]) -> str:
    return "".join(f"<br><b>And</b> {_text(value)}" for value in values if value)


def format_description(value: Any) -> str | None:
    """Format structured description content, or preserve supplied HTML."""
    if value is None or value == "":
        return None
    if isinstance(value, str):
        return value
    if not isinstance(value, Mapping):
        raise ValueError("description must be HTML text or a Gherkin object")

    required = ("given", "when", "then", "context")
    missing = [key for key in required if not str(value.get(key, "")).strip()]
    if missing:
        raise ValueError("description requires Given, When, Then, and Context content")

    and_values = value.get("and") or []
    if isinstance(and_values, str):
        and_values = [and_values]
    description = (
        f"<div><b>Given</b> {_text(value['given'])}"
        f"<br><b>When</b> {_text(value['when'])}"
        f"<br><b>Then</b> {_text(value['then'])}"
        f"{_gherkin_lines(and_values)}</div>"
    )
    description += f"<br><div><b>Context:</b> {_text(value['context'])}</div>"
    return description


def format_acceptance_criteria(value: Any) -> str | None:
    """Format structured acceptance criteria, or preserve supplied HTML."""
    if value is None or value == "":
        return None
    if isinstance(value, str):
        return value
    if not isinstance(value, Sequence) or isinstance(value, (bytes, bytearray)):
        raise ValueError("acceptance criteria must be HTML text or a list")
    if value and len(value) < 4:
        raise ValueError("at least four acceptance criteria are required")

    blocks = []
    for criterion in value:
        if not isinstance(criterion, Mapping):
            raise ValueError("each acceptance criterion must be an object")
        required = ("title", "given", "when", "then")
        if any(not str(criterion.get(key, "")).strip() for key in required):
            raise ValueError("each criterion requires a title, Given, When, and Then")
        if re.match(
            r"^(?:scenario(?:\s+\d+)?\s*:|happy\s+path|negative\s+path)",
            str(criterion["title"]).strip(),
            re.IGNORECASE,
        ):
            raise ValueError("acceptance criterion titles must describe the behavior directly")
        and_values = criterion.get("and") or []
        if isinstance(and_values, str):
            and_values = [and_values]
        blocks.append(
            f"<div><b>{_text(criterion['title'])}</b>"
            f"<br><b>Given</b> {_text(criterion['given'])}"
            f"<br><b>When</b> {_text(criterion['when'])}"
            f"<br><b>Then</b> {_text(criterion['then'])}"
            f"{_gherkin_lines(and_values)}</div>"
        )
    return "<br>".join(blocks) if blocks else None