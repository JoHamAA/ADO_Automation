import json
import urllib.request

BASE = "http://127.0.0.1:8765"
TITLE = "PaxHub - GitHub EMU Migration - Secrets & Credentials - Move Repository Secrets to Vault/OIDC and Remove PATs and Deploy Keys - Remediation for "
GROUPS = {
    "apis": ("APIs & MGW repos", "the APIs and MGW repositories"),
    "backend": ("Backend apps & stream analytics repos", "the Backend apps and stream analytics repositories"),
    "aux": ("Auxiliary and Apigee proxy repos", "the Auxiliary and Apigee proxy repositories"),
}
TAGS = ["4Q26", "AI-StoryWriting", "GitHub EMU", "Run", "Security & Compliance"]
CONTEXT = (
    "PaxHub GitHub Actions workflows rely on repository secrets, variables, PATs and possibly deploy keys. "
    "Under EMU, repository secrets and variables do not migrate and deploy keys are disabled. Unless these are "
    "replaced before migration, pipelines and deployments will fail once their repository moves to Internal-AA. "
    "Keeping CI/CD working through the migration and removing long-lived credentials from GitHub reduces "
    "credential-leak risk and meets enterprise secret-scanning and compliance controls. "
    "References: EMU Migration Overview "
    "(https://developer.aa.com/docs/default/component/emu-migration-dashboard/migration-overview/), "
    "Migration Process (https://developer.aa.com/docs/default/component/emu-migration-dashboard/migration-process/), "
    "Post-Migration Checklist (https://developer.aa.com/docs/default/component/emu-migration-dashboard/post-migration-checklist/), "
    "Support & Escalation (https://developer.aa.com/docs/default/component/emu-migration-dashboard/support-and-escalation/). "
    "This story is one of three split from story 3232763 and covers only the repositories named in its title."
)


def ac(title, given, when, then, and_):
    return {"title": title, "given": given, "when": when, "then": then, "and": and_}


def content(scope):
    return {
        "description": {
            "given": f"workflows and integrations in {scope} depend on GitHub repository secrets, variables, PATs or deploy keys",
            "when": "the team moves secrets to HashiCorp Vault or OIDC ephemeral authentication and replaces PATs and deploy keys",
            "then": f"workflows in {scope} run without GitHub-stored secrets",
            "and": "they are ready to work unchanged after the EMU migration",
            "context": CONTEXT,
        },
        "acceptance_criteria": [
            ac("Inventory secrets and credentials for the repository group",
               f"the repository inventory for {scope}",
               "each repository's secrets, variables, PATs and deploy keys are reviewed",
               "every credential is listed with its consuming workflow or integration and its target replacement (Vault, OIDC, or not needed)",
               "credentials that are unused are identified for removal"),
            ac("Move repository secrets and variables to Vault or OIDC",
               "a workflow reads a GitHub repository secret or variable",
               "the workflow is updated",
               "it retrieves the value from HashiCorp Vault or authenticates with OIDC ephemeral credentials",
               "the workflow runs successfully in NONPROD with the new mechanism"),
            ac("Replace PATs and deploy keys with approved mechanisms",
               "a workflow or integration uses a personal PAT or a deploy key",
               "it is remediated",
               "it uses an approved EMU-compatible mechanism (OIDC, GitHub App or Vault-issued credential)",
               "the old PAT or deploy key is revoked after cutover and any failed authentication is handled without exposing credentials"),
            ac("Confirm no secrets are exposed",
               "enterprise secret scanning is enabled on all repositories in the group",
               "the remediated repositories are scanned",
               "there are no open secret-scanning findings",
               "no secret is hardcoded in code, workflow files or pipeline logs"),
            ac("Use agentic AI assisted development responsibly",
               "workflow, configuration or documentation changes are needed for this story",
               "the team implements them",
               "GitHub Copilot / Agentic AI tools are used where applicable",
               "AI-generated changes are reviewed and validated by an engineer before merge"),
            ac("Validate security vulnerabilities",
               "the changes for this story are complete",
               "security scans (SAST, dependency and secret scanning) run on the affected repositories",
               "no new Critical or High vulnerabilities and no exposed secrets are introduced",
               "any findings are remediated or documented before migration"),
        ],
    }


def send(path, method, body):
    req = urllib.request.Request(
        BASE + path, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}, method=method,
    )
    return urllib.request.urlopen(req).read().decode()


update = {"id": 3232763, "title": TITLE + GROUPS["apis"][0], "points": 2, **content(GROUPS["apis"][1])}
print(send("/stories/batch", "PATCH", {"updates": [update]}))

creates = [
    {
        "backlog": "pax", "parent_id": 3232762, "title": TITLE + GROUPS[k][0],
        "points": 2, "tags": TAGS, **content(GROUPS[k][1]),
    }
    for k in ("backend", "aux")
]
print(send("/stories/batch", "POST", {"stories": creates}))
