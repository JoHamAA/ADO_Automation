import json
import urllib.request

CONTEXT = (
    "Instead of using autoscaling feature within the function app, we would like to use Azure Automation "
    "Runbooks to scale out Mongo PNR Processor when the service bus reaches a certain threshold. This story is "
    "to review how Azure Automation Runbooks work, and document any findings. Thresholds in which the "
    "application should scale out/in are defined. Proof of concept developed to explore and validate that an "
    "Azure Automation Runbook can scale a function app. Future stories to be created post spike story."
)
LINK = "https://learn.microsoft.com/en-us/azure/automation/start-runbooks"
html = (
    "<div><b>Given</b> the Mongo PNR Processor would otherwise rely on the autoscaling feature within the function app<br>"
    "<b>When</b> the spike reviews using Azure Automation Runbooks to scale the processor out and in based on a Service Bus threshold<br>"
    "<b>Then</b> the findings, the scale-out and scale-in thresholds, and a proof of concept showing a runbook can scale the function app are documented<br>"
    "<b>And</b> follow-up stories are identified for implementation</div><br>"
    f"<div><b>Context:</b> {CONTEXT}<br><br><b>Links:</b> <a href=\"{LINK}\">{LINK}</a></div>"
)

req = urllib.request.Request(
    "http://127.0.0.1:8765/stories/3244946",
    data=json.dumps({"description": html}).encode(),
    headers={"Content-Type": "application/json"},
    method="PATCH",
)
print(urllib.request.urlopen(req).read().decode())
