import html
import json
import urllib.request

BASE = "http://127.0.0.1:8765"
ENV_NOTE = "Can move this secret to 'Environment' secrets instead of migrating to Hashicorp vault."
SP_NOTES = [
    "May need to convert AZURE_SP_CREDENTIALS_PROD to AZURE_SP_CREDENTIALS",
    "Will need value for other secrets to migrate to HC vault",
]
MGW_SECRETS = [
    "AAINTERNAL_READONLY_PAT", "TOWER_URL", "TOWER_TOKEN_URL", "TOWER_USR", "TOWER_PWD",
    "AZURE_SP_CREDENTIALS_PROD", "ARTIFACTS_USER", "ARTIFACTS_PWD", "azure_sp", "artifacts_credentials",
]

# repo, notes, secrets
REPOS = [
    ("ph-security-bot", [ENV_NOTE], ["CH_SECURITY_BOT_PAT"]),
    ("ph-acs-flight-statistics-agg-asp", [ENV_NOTE], ["PM_MONGO_URI"]),
    ("ch-paxhub-poc-webapp", [ENV_NOTE], ["AZURE_SQLMI_CONN_STRING", "EMAILME_SECRET_CONFIG"]),
    ("ch-az-custevents-internal-mgw", [], MGW_SECRETS),
    ("ch-az-custevents-mgw", SP_NOTES, MGW_SECRETS),
    ("ch-az-custevents-aks-mgw", SP_NOTES, MGW_SECRETS),
    ("aa-ct-paxhub-wiki", ["Can move these to 'Environment' secrets"],
     ["AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET", "AZURE_SUBSCRIPTION_ID", "AZURE_TENANT_ID", "KG_PR_TOKEN", "MODELS_TOKEN"]),
]


def ac(title, given, when, then, and_):
    return {"title": title, "given": given, "when": when, "then": then, "and": and_}


def description_html(repo, notes, secrets):
    url = f"https://github.com/AAInternal/{repo}"
    e = html.escape
    parts = [
        f"<div><b>Given</b> the {e(repo)} repository uses the GitHub secrets listed below<br>"
        "<b>When</b> the team reviews each secret and moves it to HashiCorp Vault or Environment secrets as appropriate<br>"
        f"<b>Then</b> workflows in {e(repo)} run without relying on repository-level GitHub secrets<br>"
        "<b>And</b> each secret's disposition is documented</div><br>",
        f'<div><b>Context:</b> Repository: <a href="{url}">{url}</a>',
    ]
    if notes:
        parts.append("<br><br><b>Notes:</b><ul>" + "".join(f"<li>{e(n)}</li>" for n in notes) + "</ul>")
    else:
        parts.append("<br><br>")
    parts.append("<b>Required secrets:</b><ul>" + "".join(f"<li>{e(s)}</li>" for s in secrets) + "</ul></div>")
    return "".join(parts)


def build(repo, notes, secrets):
    return {
        "backlog": "pax",
        "parent_id": 3171324,
        "points": 1,
        "title": f"PaxHub - GitHub EMU Migration - Secrets & Credentials - Review and Manage Required Secrets for {repo}",
        "description": description_html(repo, notes, secrets),
        "acceptance_criteria": [
            ac("Review each required secret and record its disposition",
               f"the required secrets for {repo} are listed",
               "each secret is reviewed",
               "it is recorded whether the secret is migrated to HashiCorp Vault or moved to Environment secrets, and where it is consumed",
               "unused secrets are identified for removal"),
            ac("Handle missing values and credential conversions safely",
               "a secret value is unavailable, invalid, or needs conversion for the new location",
               "the secret is migrated or managed",
               "the gap is resolved or escalated to the owner without exposing the secret value",
               "workflows continue to run or the failure is reported with a clear owner"),
            ac("Update workflows and documentation and validate in NONPROD",
               "the secret locations are decided",
               "the repository workflows and documentation are updated",
               "workflows run successfully in NONPROD using the new secret sources",
               "the changes and secret locations are documented"),
            ac("Confirm no secrets are exposed",
               "secret scanning is enabled on the repository",
               "the remediated repository is scanned",
               "there are no open secret-scanning findings",
               "no secret is hardcoded in code, workflow files, or pipeline logs"),
        ],
    }


stories = [build(*r) for r in REPOS]
req = urllib.request.Request(
    BASE + "/stories/batch",
    data=json.dumps({"stories": stories}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
for r in json.loads(urllib.request.urlopen(req).read().decode())["results"]:
    print(r.get("id"), "|", r.get("status"), "|", r.get("title"), "|", r.get("error", ""))
