import sys
import threading
from types import SimpleNamespace

import tag_inheritance.image_tags as image_tags
from tag_inheritance.image_tags import (
    ImageTagError,
    extract_image_sources,
    keyword_tags,
    ocr_image,
    scan_image_sources,
)


def test_extracts_and_deduplicates_img_sources_from_html():
    content = (
        '<p><img src="https://example.invalid/a.png"></p>'
        '<img SRC="https://example.invalid/a.png"><img src="b.jpg">'
    )

    assert extract_image_sources(content) == (
        "https://example.invalid/a.png",
        "b.jpg",
    )


def test_extracts_markdown_images_but_not_regular_links():
    content = (
        "![screenshot](https://example.invalid/image.png) "
        "![another](<https://example.invalid/other image.png>) "
        "[regular link](https://example.invalid/link.png)"
    )

    assert extract_image_sources(content) == (
        "https://example.invalid/image.png",
        "https://example.invalid/other image.png",
    )


def test_keyword_matching_is_case_insensitive_and_word_bounded():
    assert keyword_tags("MUTATION found") == (("Mutation", "mutation"),)
    assert keyword_tags("mutational change") == ()


def test_ocr_image_uses_local_rapidocr_engine(monkeypatch):
    captured = {}

    class FakeRapidOCR:
        def __init__(self, **kwargs):
            captured["init"] = kwargs

        def __call__(self, image_bytes, **kwargs):
            captured["image_bytes"] = image_bytes
            captured["call"] = kwargs
            return ([[None, "Mutation found", 0.99], [None, "Other text", 0.9]], None)

    monkeypatch.setattr(image_tags, "_OCR_LOCAL", threading.local())
    monkeypatch.setitem(
        sys.modules,
        "rapidocr_onnxruntime",
        SimpleNamespace(RapidOCR=FakeRapidOCR),
    )

    assert ocr_image(b"local-image-bytes") == "Mutation found\nOther text"
    assert captured["image_bytes"] == b"local-image-bytes"
    assert captured["call"] == {"use_cls": False}
    assert captured["init"]["det_limit_type"] == "max"


def test_scans_each_unique_image_once_and_preserves_source_labels():
    downloaded = []
    sources = [
        ("Notes", '<img src="image.png">'),
        ("Discussion comment 7", '<img src="image.png">'),
    ]

    matches = scan_image_sources(
        sources,
        lambda url: downloaded.append(url) or b"image",
        lambda image: "Mutation in screenshot",
    )

    assert downloaded == ["image.png"]
    assert [(match.tag, match.source) for match in matches] == [
        ("Mutation", "Notes"),
        ("Mutation", "Discussion comment 7"),
    ]


def test_scan_failure_is_not_treated_as_a_keyword_miss():
    def fail_download(url):
        raise OSError("download failed")

    try:
        scan_image_sources([("Notes", '<img src="image.png">')], fail_download)
    except ImageTagError as exc:
        assert "Could not scan an image" in str(exc)
    else:
        raise AssertionError("expected image scan failure")

def test_stops_after_first_image_with_mutation():
    downloaded = []
    sources = [("Notes", '<img src="a.png"><img src="b.png">')]

    matches = scan_image_sources(
        sources,
        lambda url: downloaded.append(url) or b"image",
        lambda image: "mutation",
    )

    assert downloaded == ["a.png"]
    assert [match.tag for match in matches] == ["Mutation"]


def test_keyword_cache_avoids_download_and_ocr(tmp_path):
    from tag_inheritance.image_tags import KeywordCache

    cache_path = tmp_path / "cache.json"
    sources = [("Notes", '<img src="a.png">')]
    scan_image_sources(sources, lambda url: b"x", lambda image: "mutation", cache=KeywordCache(cache_path))

    def fail(*_):
        raise AssertionError("cache should be used")

    matches = scan_image_sources(sources, fail, fail, cache=KeywordCache(cache_path))

    assert [match.tag for match in matches] == ["Mutation"]


def test_discussion_comment_with_keyword_and_image_skips_ocr():
    def fail(*_):
        raise AssertionError("OCR must be skipped")

    sources = [
        ("Discussion comment 7", '<div>Mutation test passed</div><img src="a.png">'),
        ("Discussion comment 8", '<img src="b.png">'),
    ]

    matches = scan_image_sources(sources, fail, fail)

    assert [(m.tag, m.source) for m in matches] == [("Mutation", "Discussion comment 7")]


def test_keyword_in_image_url_or_without_image_does_not_skip_ocr():
    ocr_calls = []
    sources = [
        ("Discussion comment 1", '<img src="mutation-shot.png">'),
        ("Discussion comment 2", "mutation mentioned but no image"),
        ("Notes", '<p>mutation</p><img src="notes.png">'),
    ]

    scan_image_sources(
        sources,
        lambda url: b"x",
        lambda image: ocr_calls.append(1) or "nothing",
    )

    assert len(ocr_calls) == 2


import pytest


@pytest.mark.parametrize(
    "comment",
    [
        "There will be no mutation for this story",
        "There won't be any mutation",
        "There wont be any mutation changes",
        "Mutation is not required here",
        "mutation n/a",
        "Not applicable: mutation testing skipped",
        "We don\u2019t need mutation",
        "Tests passed without mutation",
        "<div>Done</div><div>no mutation</div>",
    ],
)
def test_negated_mutation_comment_does_not_skip_ocr(comment):
    ocr_calls = []
    sources = [("Discussion comment 1", f'{comment}<img src="a.png">')]

    matches = scan_image_sources(
        sources,
        lambda url: b"x",
        lambda image: ocr_calls.append(1) or "nothing",
    )

    assert ocr_calls == [1]
    assert matches == ()


@pytest.mark.parametrize(
    "comment",
    [
        "Mutation test passed",
        "No failures, mutation results attached",
        "Ran the mutation run, see screenshot",
    ],
)
def test_affirmed_mutation_comment_skips_ocr(comment):
    def fail(*_):
        raise AssertionError("OCR must be skipped")

    sources = [("Discussion comment 1", f'{comment}<img src="a.png">')]

    assert scan_image_sources(sources, fail, fail)[0].tag == "Mutation"
