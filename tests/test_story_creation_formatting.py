"""Tests for story description and acceptance-criteria formatting."""

import pytest

from story_creation.formatting import format_acceptance_criteria, format_description


def test_format_description_uses_html_breaks_bold_keywords_and_context():
    rendered = format_description(
        {
            "given": "A <PNR>",
            "when": "TO evaluates a leg",
            "then": "The leg is selected",
            "and": ["The result is saved"],
            "context": "GCD is a spherical distance",
        }
    )

    assert rendered == (
        "<div><b>Given</b> A &lt;PNR&gt;<br><b>When</b> TO evaluates a leg"
        "<br><b>Then</b> The leg is selected<br><b>And</b> The result is saved"
        "</div><br><div><b>Context:</b> GCD is a spherical distance</div>"
    )
    assert "\n" not in rendered


def test_format_acceptance_criteria_bolds_titles_and_gherkin_keywords():
    rendered = format_acceptance_criteria(
        [
            {
                "title": "Select the longest eligible leg",
                "given": "Multiple legs have GCD values",
                "when": "TO evaluates an offer",
                "then": "The longest eligible leg is selected",
            },
            {
                "title": "Handle unavailable GCD",
                "given": "A leg has no GCD value",
                "when": "TO evaluates an offer",
                "then": "The leg is not treated as the longest",
            },
            {
                "title": "Preserve itinerary mapping",
                "given": "A PNR has multiple legs",
                "when": "TO evaluates an offer",
                "then": "The selected O and D remains associated with its leg",
            },
            {
                "title": "Document consumer impact",
                "given": "The selection approach is assessed",
                "when": "The spike is completed",
                "then": "Consumer impacts are documented",
            },
        ]
    )

    assert rendered.startswith("<div><b>Select the longest eligible leg</b>")
    assert "<br><b>Given</b>" in rendered
    assert "<br><b>When</b>" in rendered
    assert "<br><b>Then</b>" in rendered
    assert "Scenario:" not in rendered


@pytest.mark.parametrize(
    "formatter,value",
    [
        (format_description, None),
        (format_description, ""),
        (format_acceptance_criteria, None),
        (format_acceptance_criteria, []),
    ],
)
def test_unused_content_fields_are_omitted(formatter, value):
    assert formatter(value) is None


def test_malformed_supplied_gherkin_is_reported():
    with pytest.raises(ValueError, match="Given, When, Then, and Context"):
        format_description({"given": "Starting"})