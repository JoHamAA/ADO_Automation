"""Recognition and canonical formatting of iteration-derived quarter tags."""

import re
from datetime import datetime


_SEPARATOR = r"[\s._/-]*"
_YEAR = r"(?:[0-9]{4}|[0-9]{2})"
_QUARTER_TAG = re.compile(
    r"(?:"
    + "|".join(
        _SEPARATOR.join(parts)
        for parts in (
            (r"[1-4]", "Q", _YEAR),
            ("Q", r"[1-4]", _YEAR),
            (_YEAR, "Q", r"[1-4]"),
            (_YEAR, r"[1-4]", "Q"),
            ("Q", _YEAR, r"[1-4]"),
            (r"[1-4]", _YEAR, "Q"),
        )
    )
    + r")",
    re.IGNORECASE,
)


def is_quarter_tag(tag: str) -> bool:
    return _QUARTER_TAG.fullmatch(tag.strip()) is not None


def quarter_tag(start_date: str) -> str:
    """Use ADO's calendar date without timezone conversion."""
    start = datetime.fromisoformat(start_date.replace("Z", "+00:00"))
    return f"{(start.month - 1) // 3 + 1}Q{start.year % 100:02d}"
