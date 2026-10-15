"""Read-only configuration loader.

Reads ``.github/config.yaml`` without ever writing to it. Anything secret
(PAT, Teams webhook URL) is resolved from environment variables only.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Dict

import yaml

DEFAULT_ORG_URL = "https://dev.azure.com/AmericanAirlines"
DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent.parent / ".github" / "config.yaml"

# Scoped to the PAX backlog for now, per requirements.
BACKLOG_KEY = "pax"

VALID_TEAMS = ("dfw", "hyd")


class ConfigError(RuntimeError):
    """Raised when configuration is missing or unusable."""


def _persisted_windows_value(name: str) -> bool:
    """True when the variable exists at User/Machine scope but not in this process.

    A terminal opened before the variable was persisted never inherits it, which
    is the usual cause of an apparently "unset" variable on Windows.
    """
    if os.name != "nt":
        return False
    try:
        import winreg
    except ImportError:  # pragma: no cover - Windows only
        return False

    locations = (
        (winreg.HKEY_CURRENT_USER, r"Environment"),
        (
            winreg.HKEY_LOCAL_MACHINE,
            r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment",
        ),
    )
    for root, subkey in locations:
        try:
            with winreg.OpenKey(root, subkey) as key:
                value, _ = winreg.QueryValueEx(key, name)
                if str(value).strip():
                    return True
        except OSError:
            continue
    return False


def _missing_webhook_message(name: str) -> str:
    message = (
        f"Environment variable {name} is not set in this process. "
        "It must contain the Teams Workflows webhook URL."
    )
    if _persisted_windows_value(name):
        message += (
            f"\nHINT: {name} IS saved for your account but this terminal was opened "
            "before it was set, so it did not inherit the value. Open a new terminal, "
            f"or run:\n  $env:{name} = [Environment]::GetEnvironmentVariable('{name}','User')"
        )
    else:
        message += (
            f"\nHINT: persist it with:\n"
            f"  [Environment]::SetEnvironmentVariable('{name}', '<webhook url>', 'User')\n"
            "then open a new terminal."
        )
    return message


@dataclass(frozen=True)
class TeamConfig:
    key: str
    label: str
    name: str
    iteration_path: str
    po_name: str | None = None
    gdc: str = ""


@dataclass(frozen=True)
class Config:
    org_url: str
    project: str
    teams: Dict[str, TeamConfig]
    webhook_env_var: str

    def team(self, key: str) -> TeamConfig:
        try:
            return self.teams[key.lower()]
        except KeyError:
            raise ConfigError(f"Team '{key}' is not defined in config.yaml") from None

    def webhook_url(self) -> str:
        url = os.environ.get(self.webhook_env_var, "").strip()
        if not url:
            raise ConfigError(_missing_webhook_message(self.webhook_env_var))
        return url


def load_config(path: Path | None = None) -> Config:
    """Load and validate configuration. Never mutates the file."""
    config_path = Path(path) if path else DEFAULT_CONFIG_PATH
    if not config_path.is_file():
        raise ConfigError(f"Config file not found: {config_path}")

    with config_path.open("r", encoding="utf-8") as handle:
        raw = yaml.safe_load(handle) or {}

    backlog = (raw.get("backlogs") or {}).get(BACKLOG_KEY)
    if not backlog:
        raise ConfigError(f"Backlog '{BACKLOG_KEY}' missing from {config_path}")

    project = backlog.get("project")
    if not project:
        raise ConfigError(f"'project' missing for backlog '{BACKLOG_KEY}'")

    roster = backlog.get("roster") or {}
    po_by_team: Dict[str, str] = {}
    for person, details in roster.items():
        if not isinstance(details, dict):
            continue
        if str(details.get("role") or "").upper() != "PO":
            continue
        team_key = str(details.get("team") or "").lower()
        gdc = details.get("gdc")
        if team_key and gdc:
            po_by_team[team_key] = str(person)

    teams: Dict[str, TeamConfig] = {}
    for key, team in (backlog.get("teams") or {}).items():
        normalized = str(key).lower()
        if normalized not in VALID_TEAMS:
            continue
        iteration_path = team.get("iterationPath")
        name = team.get("name")
        gdc = team.get("gdc")
        if not iteration_path or not name or not gdc:
            raise ConfigError(
                f"Team '{key}' needs 'name', 'iterationPath', and 'gdc'"
            )
        teams[normalized] = TeamConfig(
            key=normalized,
            label=normalized.upper(),
            name=name,
            iteration_path=iteration_path,
            po_name=po_by_team.get(normalized),
            gdc=str(gdc),
        )

    missing = [team for team in VALID_TEAMS if team not in teams]
    if missing:
        raise ConfigError(f"Missing team definitions in config.yaml: {', '.join(missing)}")

    webhook_env_var = (
        ((raw.get("notifications") or {}).get("teams") or {}).get("webhookUrlEnvVar")
        or "TEAMS_WEBHOOK_URL"
    )

    return Config(
        org_url=os.environ.get("ADO_ORG_URL", DEFAULT_ORG_URL).rstrip("/"),
        project=project,
        teams=teams,
        webhook_env_var=webhook_env_var,
    )
