import json
import urllib.request

BASE = "http://127.0.0.1:8765"
PATH = "DataEngineering\\Comm Data Eng Bus Analytics 1"
SOURCE = "dataproducts_p.cust_lylty_master_prod_gld.mbr_email_addr_best"
CONTEXT = (
    f"Source dataset: {SOURCE}. The ETL uses the primary purchaser email address from this table, compared against "
    "the traveler email on the same booking. When the primary purchaser and traveler have the same email address, "
    "keep the traveler record and omit the primary purchaser record. No new columns are exposed; this is backend "
    "only, and the source dataset is not modified. The design comes from spike 3023079."
)


def ac(title, given, when, then, and_):
    return {"title": title, "given": given, "when": when, "then": then, "and": and_}


spike = {
    "id": 3023079,
    "description": {
        "given": "the Primary Purchaser enhancement introduces non-traveling purchaser records into the Tailored Offers Semantic Layer",
        "when": "Primary Purchaser email addresses are compared against traveler email addresses associated with the same booking",
        "then": "the required ETL changes, data model impacts, deduplication approach, downstream impacts, and implementation effort shall be identified and documented to ensure only a single email is delivered when the Primary Purchaser email matches the traveler email",
        "context": (
            f"Source dataset: {SOURCE}. The ETL should use the primary purchaser email address from this table, "
            "compared against the traveler email on the same booking. When the primary purchaser and traveler have the "
            "same email address, keep the traveler record and omit the primary purchaser record. No new columns are "
            "exposed; this is backend only, and the source dataset is not modified."
        ),
    },
}

stories = [
    {
        "title": "TO - Primary Purchaser Dedupe - Add Primary Purchaser Email Attribute from mbr_email_addr_best to Work Tables",
        "tags": ["TO", "nodeploy"],
        "description": {
            "given": "the ETL work tables do not carry the primary purchaser email address needed to compare against the traveler email",
            "when": f"the primary purchaser email attribute is added to the work tables from {SOURCE}",
            "then": "each booking's primary purchaser email is available in the work tables for the dedupe comparison",
            "and": "the source dataset is not modified and no new columns are exposed downstream",
            "context": CONTEXT,
        },
        "acceptance_criteria": [
            ac("Add the primary purchaser email attribute to the work tables",
               f"the primary purchaser email is available in {SOURCE}",
               "the ETL populates the new work-table attribute",
               "each booking's primary purchaser email is present in the work tables",
               "the source dataset is read only and unchanged"),
            ac("Handle missing or unmatched primary purchaser emails",
               "a booking has a null, blank, or unmatched primary purchaser email",
               "the ETL runs",
               "the attribute is left empty for that booking with no ETL failure",
               "the count of such bookings is logged"),
            ac("Update schema and ETL documentation",
               "the work-table attribute is added",
               "the work-table schema and ETL documentation are reviewed",
               "the attribute name, source, and purpose are documented",
               "the design is consistent with spike 3023079"),
            ac("Confirm no downstream or performance impact",
               "the attribute is backend only",
               "downstream outputs and ETL run times are compared before and after",
               "no new columns are exposed and outputs are unchanged",
               "ETL runtime stays within the existing window"),
        ],
    },
    {
        "title": "TO - Primary Purchaser Dedupe - Implement ETL Filter to Omit Primary Purchaser Records with Matching Traveler Email (NONPROD)",
        "tags": ["TO", "nodeploy"],
        "description": {
            "given": "a booking has a primary purchaser and a traveler with the same email address",
            "when": "the ETL applies the email dedupe filter in NONPROD",
            "then": "the traveler record is kept and the primary purchaser record is omitted",
            "and": "bookings where the emails differ continue to keep both records",
            "context": CONTEXT,
        },
        "acceptance_criteria": [
            ac("Keep the traveler and omit the primary purchaser on matching email",
               "the primary purchaser and traveler on a booking have the same email address",
               "the ETL filter runs in NONPROD",
               "the traveler record is kept and the primary purchaser record is omitted",
               "only a single record for that email is delivered"),
            ac("Keep both records when emails differ or are unavailable",
               "the primary purchaser and traveler emails differ, or one is null or blank",
               "the ETL filter runs",
               "both records are retained with no ETL failure",
               "case and whitespace differences in matching emails are handled consistently"),
            ac("Document the filter logic and validation results",
               "the ETL filter is implemented",
               "NONPROD results are validated against expected counts",
               "the match rule, test cases, and results are documented",
               "the logic is consistent with spike 3023079"),
            ac("Confirm no downstream or performance impact",
               "the filter is backend only",
               "NONPROD outputs and ETL run times are reviewed",
               "no new columns are exposed and the only change is the omitted duplicate purchaser records",
               "ETL runtime stays within the existing window"),
        ],
    },
    {
        "title": "TO - Primary Purchaser Dedupe - Deploy Email Dedupe ETL Filter to PROD",
        "tags": ["TO", "deploy"],
        "description": {
            "given": "the work-table attribute and ETL dedupe filter are validated in NONPROD",
            "when": "they are deployed to PROD",
            "then": "PROD omits primary purchaser records whose email matches the traveler email and keeps the traveler record",
            "and": "no new columns are exposed",
            "context": CONTEXT,
        },
        "acceptance_criteria": [
            ac("Deploy the work-table attribute and ETL filter to PROD",
               "the changes are validated and approved in NONPROD",
               "the deployment is executed in PROD",
               "the work-table attribute and ETL filter are active in PROD",
               "the deployment is recorded with the approved change"),
            ac("Handle deployment or data failures safely",
               "the deployment fails or PROD data has null or unmatched emails",
               "the issue is detected",
               "the approved rollback or mitigation path is followed with an owner assigned",
               "PROD outputs remain stable and consumers are informed"),
            ac("Validate PROD output against NONPROD expectations",
               "the first PROD ETL run completes after deployment",
               "PROD results are compared with NONPROD expectations",
               "matching-email bookings keep only the traveler record and other bookings are unchanged",
               "results are documented"),
            ac("Confirm no downstream or performance impact",
               "the change is backend only",
               "PROD outputs and ETL run times are reviewed",
               "no new columns are exposed and downstream consumers are unaffected",
               "ETL runtime stays within the existing window"),
        ],
    },
]
for s in stories:
    s.update({
        "backlog": "deaa", "project": "DataEngineering", "parent_id": 3065469,
        "area_path": PATH, "iteration_path": PATH,
    })


def send(path, method, body):
    req = urllib.request.Request(
        BASE + path, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}, method=method,
    )
    return urllib.request.urlopen(req).read().decode()


print(send("/stories/batch", "POST", {"stories": stories}))
print(send("/stories/batch", "PATCH", {"updates": [spike]}))
