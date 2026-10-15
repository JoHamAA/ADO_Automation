import json
import urllib.request


def ac(title, given, when, then, and_):
    return {"title": title, "given": given, "when": when, "then": then, "and": and_}


story = {
    "backlog": "pax",
    "parent_id": 3107210,
    "title": "PaxHub - Migration to MongoDB - Review Azure Automation Runbook for Scaling PNR PROCESSOR (SPIKE)",
    "description": {
        "given": "the Mongo PNR Processor would otherwise rely on the autoscaling feature within the function app",
        "when": "the spike reviews using Azure Automation Runbooks to scale the processor out and in based on a Service Bus threshold",
        "then": "the findings, the scale-out and scale-in thresholds, and a proof of concept showing a runbook can scale the function app are documented",
        "and": "follow-up stories are identified for implementation",
        "context": (
            "Instead of using autoscaling feature within the function app, we would like to use Azure Automation "
            "Runbooks to scale out Mongo PNR Processor when the service bus reaches a certain threshold. This story is "
            "to review how Azure Automation Runbooks work, and document any findings. Thresholds in which the "
            "application should scale out/in are defined. Proof of concept developed to explore and validate that an "
            "Azure Automation Runbook can scale a function app. Future stories to be created post spike story."
            "<br><br>Links: <a href=\"https://learn.microsoft.com/en-us/azure/automation/start-runbooks\">"
            "https://learn.microsoft.com/en-us/azure/automation/start-runbooks</a>"
        ),
    },
    "acceptance_criteria": [
        ac("Document how Azure Automation Runbooks scale a function app",
           "Azure Automation Runbooks are proposed to replace function app autoscaling",
           "the runbook capabilities, triggers, and scaling options are reviewed",
           "how a runbook can scale the Mongo PNR Processor function app is documented",
           "limitations and alternatives are noted"),
        ac("Define Service Bus thresholds and handle invalid conditions",
           "the PNR Processor consumes from a Service Bus queue",
           "scale-out and scale-in thresholds are defined",
           "the thresholds, timing, and minimum and maximum instance counts are documented",
           "failures, missing metrics, or unexpected queue values are handled without leaving the app mis-scaled"),
        ac("Validate with a proof of concept",
           "a runbook is built in a NONPROD environment",
           "the Service Bus threshold is reached and the runbook runs",
           "the runbook scales the function app out and in as defined",
           "the setup, configuration, and results are documented"),
        ac("Record risks, permissions, cost, and follow-up work",
           "the review and proof of concept are complete",
           "results are shared with the team",
           "required permissions, cost, security, and operational risks are recorded",
           "recommended follow-up stories are identified"),
    ],
}

req = urllib.request.Request(
    "http://127.0.0.1:8765/stories",
    data=json.dumps(story).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
print(urllib.request.urlopen(req).read().decode())
