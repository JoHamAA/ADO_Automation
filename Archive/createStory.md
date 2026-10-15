## Story Instructions
- All stories will follow the gherkin format in both description and acceptance criteria using the structure defined below
- When a user requests a new story they will provide the name along with the context

## Single-Request Mode (Default)
- Treat one user request as sufficient input when it includes: story title, context, and parent Feature ID
- Do not ask follow-up questions for standard required fields when defaults are defined in this file
- Only ask a follow-up question if a hard validation or authorization failure prevents creation

## Minimal Input Contract
- Expected input from user: Title, Context, Parent Feature ID
- Optional user overrides: Story Points, Work Type, Priority, Ready
- If optional overrides are not supplied, use defaults in this file automatically
## Gherkin Format Structure
- Format to put into the story description
**Given** <text>
**When** <text>
**Then** <text>
**Context**: <text>

- Format to put into story acceptance criteria
**Scenario #: <AcceptanceCriteriaName>**
**Given** <text>
**When** <text>
**Then** <text>

**Scenario #: <AcceptanceCriteriaName>**
**Given** <text>
**When** <text>
**Then** <text>
## Story tags
- If the story is given a feature/parent upon creation the story will then have all tags the parent has

## Execution Order (No Guesswork)
- 1) Validate the parent work item exists, is a Feature in PassengerDataHub, and read its actual `System.AreaPath`; use that parent area path for creation
- 2) Validate the requested iteration path and read tags from the parent Feature
- 3) Immediately before creation, perform an exact duplicate check using both title and work item type; stop with `duplicate_exists` if a match exists
- 4) Create the User Story with required fields and defaults from this file using the authenticated `az boards` CLI
- 5) Explicitly add Parent relation from story to Feature
- 6) Move story to top of backlog by assigning a lower StackRank than the current top story
- 7) Read the created item with relations and verify its ID, title, type, state, area, iteration, tags, StackRank, and parent relation
- 8) Return one concise completion line with story ID, title, and hyperlink
## Parent Linking
- When a story is created under a Feature (FEA), a Parent relation must be explicitly added between the story and the FEA; creating the work item alone does not link it
## Required Fields (PassengerDataHub "User Story" type)
- `Microsoft.VSTS.Scheduling.StoryPoints` is required and must be set (ask the user or default to 0 if not provided)
- `AAIT.WorkType` is required and must be set to one of the project's valid values, use "4. Software / UX" as the default unless specified
- `Microsoft.VSTS.Common.Priority` should be set to 2 unless the user specifies a different priority
- `AAIT.Ready` should be set to "Yes" unless the user specifies otherwise
## Backlog Position
- Every newly created story must be moved to position #1 (top) of the PassengerDataHub backlog
- Achieve this by setting `Microsoft.VSTS.Common.StackRank` on the new story to a value lower than the current lowest `Microsoft.VSTS.Common.StackRank` among existing backlog items (query the minimum first, then subtract an offset, e.g. 1 or 1000, to guarantee it sorts above everything else)
## Rich-Text Field Formatting
- `System.Description` and `Microsoft.VSTS.Common.AcceptanceCriteria` are HTML-formatted fields
- Do not use literal newlines (`\n`) when setting these fields via CLI/API — they are silently dropped or truncate the content
- Use `<br>` for line breaks and `<b></b>` for bold text (e.g. **Given** becomes `<b>Given</b>`)
## Story Name
- Do not blindly use terse or shorthand user-provided titles as the final ADO title
- All stories within a given feature follow a similar format of team - feature initiative - story name; inspect the parent Feature and nearby sibling stories before creation and align the new title to that convention
- For PAX MongoDB migration work, prefer `PaxHub - Migration to MongoDB - <Component/Environment> - <Action/Outcome>` unless the user explicitly says to preserve the exact title
- Before creating, include the normalized final title in the preflight summary
## Story Creation complete
- Upon creating all stories send a list back to the user of what was created using the format "User Story" <storyNumber> - "Story Name" as a hyperlink to ADO

## Deterministic Story Creation Execution
- Do not create ADO stories through large ad hoc PowerShell commands with embedded HTML
- Use a repository-owned story creation script when available; if no script exists, use a temporary request file or temporary script instead of a long inline command
- Temporary PowerShell scripts must be run with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>` so local execution policy does not block the workflow
- The creation workflow must print compact milestone lines for `PARENT`, `DUPLICATE`, `RANK`, `CREATE`, `LINK`, and `VERIFY`
- The workflow must create exactly once, then verify by exact created ID; if verification cannot complete, do not report success
- If StackRank parsing fails or ADO returns a non-numeric shape, use a deterministic low fallback rank and report that fallback in the verification summary

## Required Verification Before Reporting Success
- Verify and report ID, URL, final normalized title, work item type, state, area path, iteration path, tags, StackRank, parent relation when applicable, persisted description, and persisted acceptance criteria
- If verification cannot be completed, say so and do not claim success

## Failure Handling (Keep It Short)
- If a command fails, perform one automatic retry with corrected syntax/parameters
- If create output is missing or ambiguous, run the exact-title duplicate check before retrying; retry only when no item exists
- Do not fall back from `az boards` to `az rest` unless explicitly requested
- If retry fails, return one concise blocker message with the exact missing requirement or permission issue
- Do not continue exploratory trial-and-error loops after the single retry