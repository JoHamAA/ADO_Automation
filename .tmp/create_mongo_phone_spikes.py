import json
import urllib.request


def ac(title, given, when, then, and_):
    return {"title": title, "given": given, "when": when, "then": then, "and": and_}


stories = [
    {
        "backlog": "pax",
        "parent_id": 3107210,
        "title": "PaxHub - Migration to MongoDB - PNR PROCESSOR - Review Derivation logic for Phone Number (SPIKE)",
        "description": {
            "given": "the Customer Reservation API queries DERIVED_PHONE_NU from the edpd_ord_seg_air table and the PNR Processor derives that value before inserting it into the DB",
            "when": "the spike reviews the phone number derivation logic in ch-backend-pnr-processor",
            "then": "the derivation logic is understood and documented",
            "and": "the findings are available to the schema and implementation stories",
            "context": "Customer Reservation API currently takes an input of phoneNum, which is directly queried from sqlmi column DERIVED_PHONE_NU (from edpd_ord_seg_air table). PNR Processor currently does logic to derive this field value and insert into the DB. The purpose of this story is to understand and document this derivation logic. Repo: ch-backend-pnr-processor.",
        },
        "acceptance_criteria": [
            ac("Document the phone number derivation steps and source fields",
               "the PNR Processor derives DERIVED_PHONE_NU before inserting it into edpd_ord_seg_air",
               "the derivation code in ch-backend-pnr-processor is reviewed",
               "each step, rule, and source field used to derive the phone number is documented",
               "sample inputs and derived outputs are included"),
            ac("Document handling of missing, multiple, and malformed phone data",
               "a PNR has no phone, multiple phones, or a malformed or unexpected phone value",
               "the derivation logic processes the PNR",
               "the resulting behavior and any fallback or default rules are documented",
               "gaps or risky behavior are called out with owners"),
            ac("Map the derived value to the proposed Mongo collection",
               "the derived phone number is written to DERIVED_PHONE_NU today",
               "the target Mongo collection design is reviewed",
               "the source-to-target mapping and where the derivation should run are documented",
               "any schema or validation implications are listed"),
            ac("Record findings, open questions, and follow-up work",
               "the derivation review is complete",
               "results are shared with the team",
               "open questions, risks, and recommended follow-up stories are recorded",
               "the impact on Customer Reservation API consumers is assessed"),
        ],
    },
    {
        "backlog": "pax",
        "parent_id": 3107427,
        "title": "PaxHub - Migration to MongoDB - PNR GRAPH API - Review SQLMI Customer Reservation API and integration with PNR GRAPH API (SPIKE)",
        "description": {
            "given": "the SQLMI Customer Reservation API use case must be integrated into the PNR GRAPH API",
            "when": "the spike reviews the existing API's request inputs, response elements, response outputs, and business logic in ch-customer-reservations",
            "then": "the findings are documented with an evaluation of which responses already exist in the PNR GRAPH API and which fields must be added",
            "and": "the proposed architecture is assessed",
            "context": "We need to integrate SQLMI Customer Reservation API use case into PNR GRAPH API. This spike is to review the existing API, its request inputs, response elements, response outputs, any business logic, and document. Evaluate if any of the responses in this API already exist within PNR graph API response or if any additional response fields need to be added to cover Customer Reservation API response elements. For reference, the current proposed architecture for this is a new collection (to be created) with the PNR, create tms, create date, sequence id, and also include the phone number, so that the new graph api query can query this collection instead of the existing collections. Repo: ch-customer-reservations.",
        },
        "acceptance_criteria": [
            ac("Document the existing Customer Reservation API",
               "the SQLMI Customer Reservation API exists in ch-customer-reservations",
               "the API is reviewed",
               "request inputs, response elements, response outputs, and business logic are documented",
               "sample requests and responses are included"),
            ac("Compare response elements with the PNR GRAPH API",
               "the Customer Reservation response elements are documented",
               "they are compared with the current PNR GRAPH API response",
               "elements that already exist and elements that must be added are listed",
               "unmappable or ambiguous elements are called out with owners"),
            ac("Evaluate the proposed collection architecture",
               "the proposal is a new collection with the PNR, create tms, create date, sequence id, and phone number",
               "the proposal is assessed against the Customer Reservation query use case",
               "the new Graph API query against that collection is validated or alternatives are documented",
               "performance, data volume, and indexing considerations are noted"),
            ac("Record risks, consumer impact, and follow-up work",
               "the review is complete",
               "results are shared with the team",
               "risks, consumer impacts, open questions, and recommended follow-up stories are recorded",
               "invalid or unexpected input handling in the existing API is documented for the new query"),
        ],
    },
]

req = urllib.request.Request(
    "http://127.0.0.1:8765/stories/batch",
    data=json.dumps({"stories": stories}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
print(urllib.request.urlopen(req).read().decode())
