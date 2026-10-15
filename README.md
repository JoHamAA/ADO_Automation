# EO Iteration Review (PAX)

Automates the End-of-Iteration review for the **PaxHub (PAX)** backlog so it runs
without an AI agent. Queries Azure DevOps, applies the two EO rules, and either
prints the result to the console or posts it to Teams.

The logic implemented here is the specification in
[`.github/copilot-instructions.md`](.github/copilot-instructions.md) →
*End-of-Iteration (EO) Review*.

## Setup

```powershell
python -m pip install -r requirements.txt
```

### Credentials

| Variable | Required | Purpose |
|---|---|---|
| `ADO_PAT` | Optional | Azure DevOps PAT, **Work Items (Read)** scope only. If unset, the tool falls back to the signed-in Azure CLI (`az login`). |
| `TEAMS_WEBHOOK_URL` | Only for `--post` | Teams Workflows webhook URL. |
| `ADO_ORG_URL` | Optional | Overrides the default organisation URL. |

Both secrets are read from the environment only. Never commit them, and never
put them in `config.yaml`.

```powershell
[Environment]::SetEnvironmentVariable('ADO_PAT', '<pat>', 'User')
```

## Usage

The team argument is **mandatory** and must be `DFW`, `HYD`, or `BOTH`
(any casing). Any other value exits immediately without querying or sending
anything.

```powershell
# Console only - safe, read-only, sends nothing
python -m eo_review DFW
python -m eo_review hyd
python -m eo_review Both

# Post the result to the Teams channel
python -m eo_review DFW --post
python -m eo_review Both --post
```

Console output is the default. Posting requires the explicit `--post` flag,
because every posted review @mentions real people.

### Options

| Flag | Effect |
|---|---|
| `--post` | Send the review to the Teams channel as an Adaptive Card. |
| `--config <path>` | Use an alternative `config.yaml`. Read-only. |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. |
| `2` | Invalid arguments — nothing was executed. |
| `3` | Configuration, Azure DevOps, or Teams delivery error. |
| `4` | An iteration returned zero stories; nothing was posted. |

## Rules applied

**Rule 1 — proof of work.** A story in `Completed` must have either an attached
file or an image embedded in a discussion comment. Otherwise it is flagged
*Missing proof of work*.

**Rule 2 — requires update.** A story in `Backlog`, `Defined`, or `In-Progress`
at iteration end is flagged. The assignee must mark it as Completed or state
that it is being split.

Stories in `Accepted` are compliant and are not reported. Team membership is
determined **solely by iteration path**. Only User Stories are considered.

### Result types

- **Findings** → red `! IMPORTANT` header, Close of Business instruction,
  `importance: high`, one line per finding with a real @mention.
- **Clean sprint** (every story Accepted) → green header, `importance: normal`,
  no mentions.
- **No stories at all** → nothing is posted. This signals a wrong iteration path
  or an unplanned sprint, not an all-clear, so it is reported to the console
  with exit code `4`.

## Safety

The review is strictly read-only. The client issues only `GET` requests plus the
WIQL `POST` (itself a read); no code path can modify a work item.

## Tests

```powershell
python -m pytest tests -q
```

Rule and card tests run entirely from fixtures with no network access.

## Layout

```
eo_review/
  cli.py          # argument validation and entry point
  config.py       # read-only config.yaml loader
  ado_client.py   # Azure DevOps REST client
  review.py       # orchestration
  rules.py        # pure rule engine
  models.py       # Story / Finding / TeamReview
  teams.py        # Adaptive Card builder and webhook delivery
  console.py      # console renderer
tests/
```

## Scheduling

Because it needs no agent, this can run unattended on the last day of a sprint
via Task Scheduler, an Azure DevOps pipeline, or a GitHub Action, with `ADO_PAT`
and `TEAMS_WEBHOOK_URL` supplied as secrets. Run without `--post` first if you
want to review the output before it is broadcast.

## Parent Tag Inheritance

The `tag_inheritance` command audits User Stories in the current DFW, HYD, or
both team iterations. It compares each story's tags with its parent Feature's
tags and prints every story plus a summary.

### CLI syntax

```text
python -m tag_inheritance {scan|sync} {DFW|HYD|BOTH} [SPRINT_NUMBER] [--exclude ID[,ID...]] [--config PATH]
```

| Argument or option | Purpose |
|---|---|
| `scan` | Read-only audit. Reports compliant, missing, conflicting, excluded, and unresolved stories. |
| `sync` | Runs the audit, previews changes, requests approval, updates stories, and verifies the persisted tags. |
| `DFW` | Scans the current `PaxHub_DFW` iteration and requires `S-DFW`. |
| `HYD` | Scans the current `PaxHub_HYD` iteration and requires `S-HYD`. |
| `BOTH` | Scans the selected iteration for both teams and reports each team separately. |
| `SPRINT_NUMBER` | Optional positive sprint number. When supplied, scans the matching past or current sprint for each selected team; otherwise uses the current sprint. |
| `--exclude` | Keeps specified story IDs visible but prevents them from being updated. |
| `--config PATH` | Uses an alternative configuration file instead of `.github/config.yaml`. |

Team and command values are case-insensitive.

### Scan commands

```powershell
# Scan one team
python -m tag_inheritance scan DFW
python -m tag_inheritance scan HYD

# Scan both teams
python -m tag_inheritance scan BOTH
python -m tag_inheritance scan BOTH 39

# Exclude one or more stories while keeping them in the report
python -m tag_inheritance scan BOTH --exclude 12345, 123532
python -m tag_inheritance scan DFW --exclude 12345 --exclude 123532

# Use another configuration file
python -m tag_inheritance scan BOTH --config .\config\pax.yaml
```

`scan` never modifies Azure DevOps. Every story is printed with one of these
statuses:

| Status | Meaning |
|---|---|
| `COMPLIANT` | Parent inheritance, team ownership, and classification are correct. |
| `MISSING` | One or more required tags need to be added. |
| `CONFLICT` | A wrong team or `Run`/`Initiative` tag must be removed or replaced. |
| `EXCLUDED` | The story remains visible but is omitted from synchronization. |
| `UNRESOLVED` | The parent relationship or parent classification is invalid, so the story cannot be safely updated. |

### Synchronization commands

```powershell
# Preview changes for one team, approve, update, and verify
python -m tag_inheritance sync DFW
python -m tag_inheritance sync HYD
python -m tag_inheritance sync BOTH 39

# Synchronize both teams while excluding selected stories
python -m tag_inheritance sync BOTH --exclude 12345,123532
```

`--exclude` accepts comma-separated IDs, spaces after commas, and repeated
flags. Excluded stories remain visible as `EXCLUDED`, including their missing
tags, but are never included in the update plan. IDs outside the selected
current iterations are reported as unmatched exclusions.

Tag comparison is exact and case-sensitive. For example, `Cloud` and `cloud`
are distinct tags. Existing story-specific tags are preserved in their current
order, and missing parent tags are appended.

Two managed tag groups are exclusive:

- Stories in the DFW current iteration must have `S-DFW`, while HYD stories
  must have `S-HYD`. A tag for the other team is removed.
- Each parent Feature must have exactly one of `Run` or `Initiative`. The story
  receives the parent's classification and the conflicting classification is
  removed. A Feature with both or neither is unresolved and its story is
  skipped.

These managed conflicts are the only tags removed. Parent Feature team tags are
not inherited; team ownership always comes from the scanned current iteration.

`sync` displays each proposed addition, removal, final tag set, and the total
number of stories to change. It writes only after the operator types the exact
approval phrase `YES`. Each update uses the story revision shown during the
scan to reject concurrent edits, then reads the story back to verify the final
tags. One failure does not prevent the remaining approved stories from being
attempted.

### Image keyword tags

The tag audit also checks inline images in each story's Notes field and
Discussion comments. It uses local RapidOCR/ONNX Runtime and currently maps the
case-insensitive whole word `mutation` to the `Mutation` tag. Add future keyword
and tag pairs to `IMAGE_KEYWORD_TAGS` in `tag_inheritance/image_tags.py`.

The OCR runtime is installed from `requirements.txt`; no separate executable is
needed. OCR runs locally, does not call an LLM or consume AI tokens, and images
are downloaded only from the configured Azure DevOps host, with a 20 MB limit.
If image retrieval or OCR fails, that story is marked unresolved and is excluded
from the sync plan; other stories continue through the audit.

```text
PROPOSED TAG UPDATES
12345 | add: Initiative; S-DFW | remove: Run; S-HYD | final: Story Only; Initiative; S-DFW
Stories to update: 1
Type YES to apply these changes:
```

Any response other than uppercase `YES` cancels the operation without writing.

Stories with no parent, multiple parents, an unreadable parent, or a parent
that is not a Feature are shown as `UNRESOLVED`, skipped, and produce a nonzero
exit status. The `sync` operation requires an `ADO_PAT` with **Work Items
(Read & write)** scope; `scan` needs read scope only. Azure CLI authentication
can also be used. When `ADO_PAT` is unset, the command runs
`az account get-access-token` and reads the signed-in Azure CLI token cache.

### Tag command exit codes

| Code | Meaning |
|---|---|
| `0` | Scan is compliant, synchronization verified, or synchronization was cancelled. |
| `1` | Missing inherited tags or unresolved parent findings remain. |
| `2` | Invalid command arguments or exclusions. |
| `3` | Configuration, REST, update, or verification failure. |
| `4` | No stories were found in the selected current iteration(s). |

## Story REST Service

The local service creates stories individually or as a batch and supports sparse
updates to existing work items. It binds to loopback only:

```powershell
python -m pip install -r requirements.txt
python -m story_creation
```

The interactive API documentation is available at
[`http://127.0.0.1:8765/docs`](http://127.0.0.1:8765/docs). Authentication uses
`ADO_PAT` with Work Items read/write access or the signed-in Azure CLI token.
Keep `ADO_PAT` in the environment; never send it in a request body.

Endpoints:

| Method | Path | Behavior |
|---|---|---|
| `POST` | `/stories` | Create one story. |
| `POST` | `/stories/batch` | Create each supplied story in order and return an outcome per story. |
| `PATCH` | `/stories/{id}` | Update only the fields supplied for an existing work item. |
| `PATCH` | `/stories/batch` | Apply sparse updates to multiple existing work items and return an outcome per item. |
| `GET` | `/health` | Check that the local service is running. |

For a batch, obtain one user approval for the complete proposed set, then call
the batch endpoint. The service continues after an individual failure and
returns each successful ID, title, and link alongside any failed item. It reads
the minimum StackRank once per target backlog scope and assigns descending
integer ranks within the batch. Duplicate titles are allowed. ADO writes are
never automatically retried.

Create/update results report `created_verified` or `updated_verified` after a
successful read-back. If ADO confirms a write but read-back fails, the service
returns `created_unverified` or `updated_unverified` with the known ID and link.
If a write request loses its response, it returns `create_outcome_unknown` or
`update_outcome_unknown` and does not retry. A definite ADO 4xx rejection is
reported as `create_failed` or `update_failed`.

Create requests require a title. `backlog` selects a configured backlog such as
`pax` or `deaa`; project, area, iteration, parent, and the usual story fields
can be overridden when needed. Omitted fields use configured create defaults or
are left unset. For example:

```json
{
  "backlog": "deaa",
  "title": "TO - Example - SPIKE",
  "description": {
    "given": "TO has a PNR with multiple legs",
    "when": "The spike evaluates leg selection",
    "then": "A recommended approach is documented",
    "context": "Assess the leg-level source and return-flight handling"
  },
  "acceptance_criteria": [
    {"title": "Assess source mapping", "given": "...", "when": "...", "then": "..."},
    {"title": "Select the target leg", "given": "...", "when": "...", "then": "..."},
    {"title": "Handle data gaps", "given": "...", "when": "...", "then": "..."},
    {"title": "Document impacts", "given": "...", "when": "...", "then": "..."}
  ],
  "points": 0,
  "notes": "Initial spike notes"
}
```

Structured descriptions and criteria are serialized as ADO HTML with bold
Gherkin keywords, `<br>` line breaks, and a bold `Context:` block. At least four
structured acceptance criteria are required. Existing HTML may be supplied
unchanged. Unused request properties are ignored; use the `fields` object for
other ADO field references.

Updates use the same aliases or ADO field references and only patch values that
are present and non-null. Batch updates use an `updates` array with an ID on each
item. For example:

```json
{
  "updates": [{
    "id": 12345,
    "description": {"given": "...", "when": "...", "then": "...", "context": "..."},
    "acceptance_criteria": "<div>Existing ADO HTML</div>",
    "notes": "Append a work-item history note",
    "rank": 123456,
    "points": 3
  }]
}
```

Notes are written to `System.History` and are append-only. An update with no
usable fields is a no-op. The service reads each created or updated work item
back by ID and returns concise linked results.
