"""Local OCR and keyword matching for images embedded in story Notes/Discussion."""

from __future__ import annotations

import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import threading
import time
from typing import Callable, Iterable, List, Optional, Tuple

from .models import ImageTagMatch

IMAGE_KEYWORD_TAGS = (("mutation", "Mutation"),)
MARKDOWN_IMAGE_PATTERN = re.compile(
    r"!\[[^\]]*\]\(\s*(?:<([^>]+)>|([^\s)]+))",
)
KEYWORD_PATTERNS = tuple(
    (re.compile(rf"(?<!\w){re.escape(keyword)}(?!\w)", re.IGNORECASE), tag, keyword)
    for keyword, tag in IMAGE_KEYWORD_TAGS
)
_OCR_LOCAL = threading.local()
OCR_MAX_SIDE = 1280
# Per-engine onnxruntime threads; 0 lets onnxruntime use every core.
OCR_THREADS = 0
DEFAULT_CACHE_PATH = Path(__file__).resolve().parent.parent / ".cache" / "ocr_keywords.json"


class ImageTagError(RuntimeError):
    """An image could not be retrieved or scanned reliably."""


class KeywordCache:
    """Disk cache of keyword hits per image URL; OCR text itself is never stored."""

    def __init__(self, path: Path = DEFAULT_CACHE_PATH) -> None:
        self.path = Path(path)
        # Keyword config is part of the key so edits to IMAGE_KEYWORD_TAGS invalidate entries.
        self._config = "|".join(f"{keyword}={tag}" for keyword, tag in IMAGE_KEYWORD_TAGS)
        self._entries: dict[str, list[list[str]]] = {}
        self._lock = threading.Lock()
        try:
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                self._entries = loaded
        except (OSError, ValueError):
            pass

    def _key(self, image_url: str) -> str:
        return hashlib.sha256(f"{self._config}\n{image_url}".encode("utf-8")).hexdigest()

    def get(self, image_url: str) -> Optional[Tuple[Tuple[str, str], ...]]:
        entry = self._entries.get(self._key(image_url))
        if entry is None:
            return None
        return tuple((str(tag), str(keyword)) for tag, keyword in entry)

    def set(self, image_url: str, hits: Iterable[Tuple[str, str]]) -> None:
        with self._lock:
            self._entries[self._key(image_url)] = [list(hit) for hit in hits]
            try:
                self.path.parent.mkdir(parents=True, exist_ok=True)
                temp_path = self.path.with_suffix(".tmp")
                temp_path.write_text(json.dumps(self._entries), encoding="utf-8")
                os.replace(temp_path, self.path)
            except OSError:
                # A cache write failure must never fail the audit.
                pass


class _ImageSourceParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.sources: List[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.casefold() != "img":
            return
        source = next(
            (value for name, value in attrs if name.casefold() == "src" and value),
            None,
        )
        if source and source not in self.sources:
            self.sources.append(source)


class _VisibleTextParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: List[str] = []

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def visible_text(content: str) -> str:
    """Typed comment text only, so image URLs and file names cannot trigger a match."""
    parser = _VisibleTextParser()
    parser.feed(content or "")
    parser.close()
    return re.sub(r"\]\([^)]*\)", "]", "\n".join(parser.parts))


CLAUSE_SPLIT = re.compile(r"[.!?;,\n]|\b(?:but|however|although)\b", re.IGNORECASE)
# Wording is free-form, so any negation or opt-out cue in the same clause vetoes the keyword.
NEGATION_CUES = re.compile(
    r"\b(?:no|not|never|none|nothing|without|neither|nor|zero|cannot|n/a|na|"
    r"skip(?:ped|ping|s)?|exclud(?:e|ed|es|ing)|unnecessary|avoid(?:ed|ing)?|"
    r"absent|lack(?:s|ed|ing)?|waiv(?:e|ed)|ignor(?:e|ed|ing)|"
    r"(?:won|can|don|doesn|isn|aren|didn|wasn|weren|hasn|haven|shouldn|couldn|wouldn)t)\b"
    r"|\w+n't\b",
    re.IGNORECASE,
)


def affirmed_keyword_tags(text: str) -> Tuple[Tuple[str, str], ...]:
    """Keyword hits from clauses that mention a keyword without any negation cue."""
    hits: List[Tuple[str, str]] = []
    for clause in CLAUSE_SPLIT.split((text or "").replace("\u2019", "'")):
        if NEGATION_CUES.search(clause):
            continue
        hits.extend(keyword_tags(clause))
    return tuple(dict.fromkeys(hits))


def extract_image_sources(content: str) -> Tuple[str, ...]:
    """Return unique HTML or Markdown image URLs from one Notes/comment body."""
    parser = _ImageSourceParser()
    parser.feed(content or "")
    parser.close()
    sources = list(parser.sources)
    for match in MARKDOWN_IMAGE_PATTERN.finditer(content or ""):
        source = match.group(1) or match.group(2)
        if source and source not in sources:
            sources.append(source)
    return tuple(sources)


def keyword_tags(text: str) -> Tuple[Tuple[str, str], ...]:
    """Return configured (canonical tag, matched keyword) pairs in OCR text."""
    return tuple(
        (tag, keyword)
        for pattern, tag, keyword in KEYWORD_PATTERNS
        if pattern.search(text or "")
    )


def ocr_image(image_bytes: bytes) -> str:
    """Read image text locally with RapidOCR; no external service is called."""
    try:
        from rapidocr_onnxruntime import RapidOCR
    except ImportError as exc:
        raise ImageTagError(
            "Image OCR requires rapidocr-onnxruntime from requirements.txt."
        ) from exc

    try:
        engine = getattr(_OCR_LOCAL, "engine", None)
        if engine is None:
            # One engine per worker thread; default limit_type=min would upscale small images.
            options = {"det_limit_type": "max", "det_limit_side_len": OCR_MAX_SIDE}
            if OCR_THREADS > 0:
                options["intra_op_num_threads"] = OCR_THREADS
                options["inter_op_num_threads"] = 1
            engine = _OCR_LOCAL.engine = RapidOCR(**options)
        # Screenshots are upright, so the angle classifier is wasted work.
        recognized_lines, _ = engine(image_bytes, use_cls=False)
        return "\n".join(str(line[1]) for line in recognized_lines or [])
    except Exception as exc:
        raise ImageTagError(f"Local image OCR failed: {exc}") from exc


def scan_image_sources(
    sources: Iterable[Tuple[str, str]],
    download_image: Callable[[str], bytes],
    recognize_text: Callable[[bytes], str] = ocr_image,
    cache: Optional[KeywordCache] = None,
    progress: Optional[Callable[[str], None]] = None,
) -> Tuple[ImageTagMatch, ...]:
    """OCR unique image URLs and report keyword matches with their source labels.

    Discussion comments that both mention a keyword and embed an image match without OCR.
    Stops at the first image that yields every configured keyword tag.
    """
    sources = list(sources)
    matches: List[ImageTagMatch] = []
    found_tags: set[str] = set()
    wanted_tags = {tag for _, tag in IMAGE_KEYWORD_TAGS}
    for source_label, content in sources:
        if not source_label.startswith("Discussion") or not extract_image_sources(content):
            continue
        for tag, keyword in affirmed_keyword_tags(visible_text(content)):
            found_tags.add(tag)
            matches.append(ImageTagMatch(tag, keyword, source_label))
    if wanted_tags <= found_tags:
        if progress:
            progress("keyword found in comment text; OCR skipped")
        return tuple(dict.fromkeys(matches))

    image_sources: dict[str, List[str]] = {}
    for source_label, content in sources:
        for image_url in extract_image_sources(content):
            labels = image_sources.setdefault(image_url, [])
            if source_label not in labels:
                labels.append(source_label)

    total = len(image_sources)
    for position, (image_url, source_labels) in enumerate(image_sources.items(), 1):
        hits = cache.get(image_url) if cache else None
        if hits is not None:
            if progress:
                progress(f"image {position}/{total}: cached")
        else:
            if progress:
                progress(f"image {position}/{total}: scanning")
            try:
                started = time.perf_counter()
                image_bytes = download_image(image_url)
                downloaded = time.perf_counter()
                hits = keyword_tags(recognize_text(image_bytes))
                finished = time.perf_counter()
            except ImageTagError:
                raise
            except Exception as exc:
                raise ImageTagError(
                    f"Could not scan an image from {source_labels[0]}: {exc}"
                ) from exc
            if progress:
                progress(
                    f"image {position}/{total}: {len(image_bytes) / 1024:.0f} KB, "
                    f"download {downloaded - started:.1f}s, "
                    f"OCR {finished - downloaded:.1f}s"
                )
            if cache:
                cache.set(image_url, hits)

        for tag, keyword in hits:
            found_tags.add(tag)
            matches.extend(
                ImageTagMatch(tag, keyword, source_label)
                for source_label in source_labels
            )
        if wanted_tags <= found_tags:
            break

    return tuple(dict.fromkeys(matches))