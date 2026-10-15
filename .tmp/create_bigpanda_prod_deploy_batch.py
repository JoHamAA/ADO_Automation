import json
import subprocess
import urllib.request

BASE = "http://127.0.0.1:8765"
ORG = "https://dev.azure.com/AmericanAirlines"
# repo -> source story IDs to link as Related
REPOS = {
    "ch-backend-pnr-processor": [3200531],
    "ch-backend-vcr-cart-updater": [3200536],
    "ch-backend-pnr-event-finder": [3200612],
    "ch-backend-vcr-event-finder": [3200630],
    "ch-backend-oms-night-flight-stats": [3200652],
    "ph-backend-acs-pax-processor-fa": [3200654],
    "ph-backend-acs-flt-processor-fa": [3200673],
    "ph-backend-pnr-processor": [3200707, 3236570],
    "ch-backend-international-outbound": [3200726],
    "ch-backend-pdp-email": [3200737],
    "ch-backend-kbyg-email": [3200740],
    "ch-backend-kbyg-term-info": [3200742],
}


def ac(title, given, when, then, and_):
    return {"title": title, "given": given, "when": when, "then": then, "and": and_}


def build(repo, sources):
    src = " and ".join(str(s) for s in sources)
    return {
        "backlog": "pax",
        "parent_id": 3171336,
        "title": f"PaxHub - BigPanda Migration - {repo} - PROD Deployment",
        "points": 1,
        "tags": ["xMatters"],
        "description": {
            "given": f"the BigPanda migration for {repo} (story {src}) is validated in NONPROD",
            "when": "the changes are deployed to PROD",
            "then": "production alerts are routed through BigPanda before reaching xMatters and direct xMatters and email-initiation paths are disabled",
            "and": "the application remains compliant with the September 30, 2026 migration requirement without interruption to operational alerting",
            "context": (
                "Direct xMatters integrations and email-initiation alerting are being retired under CHG0149837 in favor of "
                "BigPanda. The approved migration pattern requires applications to send alerts to BigPanda where alert events "
                f"are enriched, correlated, deduplicated, and routed before notification is sent to xMatters. This story "
                f"deploys the work from predecessor story {src} to PROD for {repo}: the approved "
                "ch-shared-cust-hub-logging-framework version for the application's Java runtime, the AIOps identifier "
                "(Archer Shortname or Component ID; Component ID takes precedence), and APP_NOTIFICATION_RECIPIENTS routing "
                "of applicable error IDs to aiops.prod@aa.com. "
                "Reference: BigPanda onboarding documentation "
                "(https://developer.aa.com/docs/default/Component/aiops-docs/) and the ch-shared-cust-hub-logging-framework wiki."
            ),
        },
        "acceptance_criteria": [
            ac("Deploy BigPanda alerting configuration to PROD",
               "the framework, notification, and AIOps configuration changes are validated in NONPROD",
               f"the changes are deployed to PROD for {repo}",
               "the approved logging framework version, AIOps identifier, and APP_NOTIFICATION_RECIPIENTS routing to aiops.prod@aa.com are active",
               "direct xMatters and email-initiation alerting paths are disabled"),
            ac("Handle deployment failure or invalid alerting configuration safely",
               "the deployment fails or the AIOps identifier or an error ID route is missing or invalid",
               "the issue is detected",
               "the approved rollback or mitigation path is followed with an owner assigned",
               "there is no gap in operational alerting"),
            ac("Validate BigPanda alert processing in PROD",
               "the changes are deployed to PROD",
               "representative open and clear alerts are generated",
               "the alerts are received by BigPanda",
               "alert correlation, deduplication, routing, severity handling, and downstream xMatters notifications function as expected"),
            ac("Document PROD deployment and track follow-up work",
               "the PROD deployment is validated",
               "the work is completed",
               "deployment details, configured identifiers, framework versions, and test evidence are documented",
               "any follow-up actions or unresolved issues are tracked separately"),
        ],
    }


stories = [build(repo, srcs) for repo, srcs in REPOS.items()]
req = urllib.request.Request(
    BASE + "/stories/batch",
    data=json.dumps({"stories": stories}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
results = json.loads(urllib.request.urlopen(req).read().decode())["results"]
print(json.dumps(results, indent=1))

for (repo, sources), result in zip(REPOS.items(), results):
    if "id" not in result:
        print("NO LINK (no id):", repo)
        continue
    for source in sources:
        proc = subprocess.run(
            ["az", "boards", "work-item", "relation", "add", "--id", str(result["id"]),
             "--relation-type", "Related", "--target-id", str(source),
             "--organization", ORG, "--output", "none"],
            capture_output=True, text=True, shell=True,
        )
        print(result["id"], "->", source, "ok" if proc.returncode == 0 else "FAILED " + proc.stderr[:200])
