"""Configuration loader tests."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from eo_review import config as config_module  # noqa: E402
from eo_review.config import ConfigError, load_config  # noqa: E402


class TestLoadConfig:
    def test_reads_both_pax_teams(self):
        cfg = load_config()
        assert set(cfg.teams) == {"dfw", "hyd"}
        assert cfg.project == "PassengerDataHub"

    def test_team_lookup_is_case_insensitive(self):
        cfg = load_config()
        assert cfg.team("DFW").iteration_path.endswith("PaxHub_DFW")
        assert cfg.team("hyd").label == "HYD"

    def test_reads_team_po_from_roster(self):
        cfg = load_config()
        assert cfg.team("dfw").po_name == "Hamandi, Joseph"
        assert cfg.team("hyd").po_name == "Kumar, Vinod"

    def test_reads_team_gdc_tags(self):
        cfg = load_config()
        assert cfg.team("dfw").gdc == "S-DFW"
        assert cfg.team("hyd").gdc == "S-HYD"

    def test_unknown_team_raises(self):
        with pytest.raises(ConfigError):
            load_config().team("ord")

    def test_missing_file_raises(self):
        with pytest.raises(ConfigError):
            load_config(Path("does-not-exist.yaml"))


class TestWebhookResolution:
    def test_returns_value_from_environment(self, monkeypatch):
        cfg = load_config()
        monkeypatch.setenv(cfg.webhook_env_var, "https://example.invalid/hook")
        assert cfg.webhook_url() == "https://example.invalid/hook"

    def test_blank_value_is_treated_as_unset(self, monkeypatch):
        cfg = load_config()
        monkeypatch.setenv(cfg.webhook_env_var, "   ")
        with pytest.raises(ConfigError):
            cfg.webhook_url()

    def test_hint_covers_the_stale_terminal_case(self, monkeypatch):
        cfg = load_config()
        monkeypatch.delenv(cfg.webhook_env_var, raising=False)
        monkeypatch.setattr(config_module, "_persisted_windows_value", lambda name: True)
        with pytest.raises(ConfigError) as exc:
            cfg.webhook_url()
        assert "opened before it was set" in str(exc.value)

    def test_hint_explains_how_to_persist_when_never_set(self, monkeypatch):
        cfg = load_config()
        monkeypatch.delenv(cfg.webhook_env_var, raising=False)
        monkeypatch.setattr(config_module, "_persisted_windows_value", lambda name: False)
        with pytest.raises(ConfigError) as exc:
            cfg.webhook_url()
        assert "SetEnvironmentVariable" in str(exc.value)
