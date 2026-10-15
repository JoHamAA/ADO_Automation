import json
import urllib.request

def ac(title, given, when, then, and_=None):
    d = {"title": title, "given": given, "when": when, "then": then}
    if and_:
        d["and"] = and_
    return d

failover = {
    "id": 3204082,
    "title": "PaxHub - Disaster Recovery (DR) - PROD - Prepare and Validate October 2026 Failover",
    "description": {
        "given": "PaxHub PROD is operating in Azure East and the approved disaster recovery window and baseline checks are ready",
        "when": "the team performs the planned failover to Azure West on 20 Oct 2026",
        "then": "PaxHub production traffic and required dependencies operate in Azure West and representative consumer flows are validated",
        "and": "service health, data continuity, exceptions, and follow-up actions are recorded and shared",
        "context": "This story covers only the PROD transition from Azure East to Azure West, including readiness, execution, validation, and evidence. The return to Azure East on 21 Oct 2026 is covered separately by story 3224733. Confirm exercise timing, change approval, and ownership with DR coordinators.",
    },
    "acceptance_criteria": [
        ac("Complete PROD failover readiness",
           "the Azure West failover is scheduled for 20 Oct 2026",
           "DR and application owners complete preflight review",
           "required PaxHub services, Event Hub and MongoDB dependencies, access, regional endpoints, contacts, approved production change controls, and success criteria are confirmed",
           "the execution, monitoring, communication, and approved abort or recovery steps are documented before the transition"),
        ac("Move PaxHub production services to Azure West and validate critical flows",
           "baseline health is recorded and the failover is approved to proceed",
           "traffic and required dependencies are switched from Azure East to Azure West",
           "representative PaxHub requests, Event Hub publishing or consumption, MongoDB connectivity, and critical downstream consumer flows are exercised successfully",
           "the active region and routing are confirmed as Azure West"),
        ac("Confirm service health and data continuity in Azure West",
           "PaxHub is serving production traffic from Azure West after failover",
           "application and dependency health checks run",
           "availability, latency, errors, Event Hub processing and backlog, and applicable MongoDB read or write consistency are assessed against the recorded baseline",
           "delayed, duplicate, missing, or otherwise unexpected data is documented with an owner"),
        ac("Contain failed or unsafe failover conditions",
           "a regional endpoint, integration, service health, or data check fails or produces an unexpected result",
           "the failure is detected during the failover",
           "the team follows the approved mitigation or abort path, assigns an owner, and informs DR stakeholders and affected consumers",
           "PROD is left in a known, monitored state with sensitive passenger and credential data excluded from diagnostic evidence"),
        ac("Record failover evidence, consumer impact, and follow-up work",
           "the Azure West failover checks are complete",
           "results are reviewed with stakeholders",
           "timings, evidence, exceptions, consumer impacts, lessons learned, and remediation owners are recorded and the runbook is updated",
           "the resulting service state and open risks are communicated to the owners preparing the separate fallback exercise"),
    ],
}

fallback = {
    "id": 3224733,
    "title": "PaxHub - Disaster Recovery (DR) - PROD - Prepare and Validate October 2026 Fallback",
    "description": {
        "given": "the PaxHub PROD failover to Azure West has completed and the service state and recovery evidence are available",
        "when": "the team performs the planned fallback to Azure East on 21 Oct 2026",
        "then": "PaxHub production traffic and required dependencies are restored to Azure East and representative consumer flows are validated there",
        "and": "service health, data continuity, exceptions, and follow-up actions are recorded and shared",
        "context": "This story covers only the PROD return from Azure West to Azure East after the failover tracked in story 3204082. It includes fallback readiness, execution, validation, and evidence. Confirm exercise timing, change approval, and ownership with DR coordinators.",
    },
    "acceptance_criteria": [
        ac("Confirm readiness to restore Azure East",
           "the Azure West failover has completed and the fallback is scheduled for 21 Oct 2026",
           "DR and application owners review the handoff and fallback preflight",
           "Azure West service health, the current data and event baseline, Azure East endpoints, dependencies, access, contacts, approved production change controls, and success criteria are confirmed",
           "the fallback sequence, monitoring, communication, and approved abort or recovery steps are documented before proceeding"),
        ac("Restore PaxHub production services to Azure East and validate critical flows",
           "fallback readiness is confirmed and the transition is approved",
           "traffic and required dependencies are returned from Azure West to Azure East",
           "representative PaxHub requests, Event Hub publishing or consumption, MongoDB connectivity, and critical downstream consumer flows are exercised successfully",
           "the active region and routing are confirmed as Azure East"),
        ac("Verify data and event continuity after fallback",
           "PaxHub is serving production traffic from Azure East after fallback",
           "application and dependency health checks run",
           "availability, latency, errors, Event Hub processing and backlog, and applicable MongoDB read or write consistency are assessed against the handoff baseline",
           "delayed, duplicate, missing, or otherwise unexpected data is documented with an owner"),
        ac("Keep service stable when fallback checks fail",
           "an Azure East endpoint, integration, service health, or data check fails or produces an unexpected result",
           "the failure is detected during fallback",
           "the team follows the approved mitigation or abort path, keeps service in a known monitored region, assigns an owner, and informs DR stakeholders and affected consumers",
           "sensitive passenger and credential data is excluded from diagnostic evidence"),
        ac("Close out fallback evidence and consumer impact",
           "the Azure East fallback checks are complete",
           "results are reviewed with stakeholders",
           "timings, evidence, exceptions, consumer impacts, lessons learned, remediation owners, and runbook updates are recorded",
           "any unresolved recovery risks are communicated to DR stakeholders and tracked to closure"),
    ],
}

req = urllib.request.Request(
    "http://127.0.0.1:8765/stories/batch",
    data=json.dumps({"updates": [failover, fallback]}).encode(),
    headers={"Content-Type": "application/json"},
    method="PATCH",
)
print(urllib.request.urlopen(req).read().decode())
