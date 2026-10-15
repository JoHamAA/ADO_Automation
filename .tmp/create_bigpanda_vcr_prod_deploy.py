import json
import urllib.request


def ac(title, given, when, then, and_):
    return {"title": title, "given": given, "when": when, "then": then, "and": and_}


story = {
    "backlog": "pax",
    "parent_id": 3171336,
    "title": "PaxHub - BigPanda Migration - ch-backend-vcr-processor - PROD Deployment",
    "points": 0,
    "tags": ["xMatters"],
    "description": {
        "given": "the BigPanda migration for ch-backend-vcr-processor (story 3233545) is validated in NONPROD",
        "when": "the changes are deployed to PROD",
        "then": "production alerts are routed through BigPanda before reaching xMatters and direct xMatters and email-initiation paths are disabled",
        "and": "the application remains compliant with the September 30, 2026 migration requirement without interruption to operational alerting",
        "context": (
            "Direct xMatters integrations and email-initiation alerting are being retired under CHG0149837 in favor of "
            "BigPanda. The approved migration pattern requires applications to send alerts to BigPanda where alert events "
            "are enriched, correlated, deduplicated, and routed before notification is sent to xMatters. This story "
            "deploys the work from predecessor story 3233545 to PROD for ch-backend-vcr-processor: the approved "
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
           "the changes are deployed to PROD for ch-backend-vcr-processor",
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

req = urllib.request.Request(
    "http://127.0.0.1:8765/stories",
    data=json.dumps(story).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
print(urllib.request.urlopen(req).read().decode())
