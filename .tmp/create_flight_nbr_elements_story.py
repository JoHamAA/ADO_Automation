import json
import urllib.request


def ac(title, given, when, then, and_):
    return {"title": title, "given": given, "when": when, "then": then, "and": and_}


story = {
    "backlog": "pax",
    "parent_id": 3107427,
    "title": "PaxHub - Migration to MongoDB - PNR PROCESSOR - Expose Additional Flight Number Elements to BKG_FLIGHT_CUST Documents",
    "description": {
        "given": "the bkg_flight_cust document only populates the element operat_flight_nbr",
        "when": "the PNR Processor also populates flight_nbr and mkt_flight_nbr in the document",
        "then": "the entire flight key is persisted in the collection",
        "and": "a database index exists on flight_nbr and is removed from operat_flight_nbr",
        "context": (
            "Currently, we are only populating element 'operat_flight_nbr' in the bkg_flight_cust document. We want to "
            "populate additional elements 'flight_nbr' and 'mkt_flight_nbr' into the document so that the entire flight "
            "key can be persisted in the collection. Need to ensure db index is added to 'flight_nbr' and removed on "
            "'operat_flight_nbr'."
        ),
    },
    "acceptance_criteria": [
        ac("Populate all flight number elements in bkg_flight_cust documents",
           "the PNR Processor processes a booking with flight segments",
           "the bkg_flight_cust document is written",
           "flight_nbr, mkt_flight_nbr, and operat_flight_nbr are all populated from the source data",
           "the entire flight key is persisted in the collection"),
        ac("Handle missing or malformed flight number values",
           "a flight segment has a null, missing, or malformed flight number element",
           "the PNR Processor writes the document",
           "the document is written without the invalid value and without corrupting other elements",
           "the processor continues without failure and the condition is logged"),
        ac("Update the collection indexes and schema",
           "the collection currently has an index on operat_flight_nbr",
           "the index changes are applied",
           "an index exists on flight_nbr and the index on operat_flight_nbr is removed",
           "the index changes and any schema validation updates are documented"),
        ac("Confirm no consumer or query performance impact",
           "existing queries and consumers use bkg_flight_cust documents",
           "the processor and index changes are validated",
           "queries that relied on the operat_flight_nbr index continue to perform acceptably or are updated to use flight_nbr",
           "existing document consumers are unaffected by the additional elements"),
    ],
}

req = urllib.request.Request(
    "http://127.0.0.1:8765/stories",
    data=json.dumps(story).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
print(urllib.request.urlopen(req).read().decode())
