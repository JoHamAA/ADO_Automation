# Move Story Between Features

## Objective

Move one or more Azure DevOps User Stories from their current parent Feature to a target Feature while synchronizing Feature-level tags.

The process must:

- Remove tags associated only with the source Feature.
- Add tags from the target Feature.
- Preserve tags unique to the User Story.
- Preserve tags shared by the source and target Features.
- Prevent duplicate tags.
- Verify the final parent and tags after the update.

## Required Inputs

- User Story ID or list of User Story IDs
- Target Feature ID
- Whether the request is for preview or execution

## Tool Usage

- Prefer Azure DevOps MCP tools when they are connected and available.
- If Azure DevOps MCP tools are unavailable, use the authenticated Azure DevOps CLI.
- Do not allow unavailable MCP tools to block the operation when Azure CLI is working.
- Use one persistent terminal session when using Azure CLI.
- Do not switch between MCP and Azure CLI during an update unless the current method fails.
- Do not modify unrelated work-item fields.
- Do not modify the source or target Feature.
- Retrieve and verify the User Story after every parent or tag update.
- Do not claim success unless the final parent and tags are verified.

## Validation

For each User Story:

1. Retrieve the User Story, including:
   - Work-item type
   - Title
   - Current tags
   - Current parent relation
   - Project

2. Retrieve the current parent Feature, including:
   - Work-item type
   - Title
   - Tags
   - Project

3. Retrieve the target Feature, including:
   - Work-item type
   - Title
   - Tags
   - Project

4. Confirm:
   - The child work item is a User Story.
   - The target work item is a Feature.
   - The User Story and target Feature belong to the same project.
   - The target Feature exists and is accessible.
   - The current parent Feature can be identified.

5. Stop without making changes if validation fails.

## Tag Synchronization Logic

Azure DevOps does not automatically inherit Feature tags. Tag synchronization must be calculated explicitly.

For each User Story, calculate:

uniqueStoryTags = currentStoryTags - sourceFeatureTags

finalStoryTags = uniqueStoryTags union targetFeatureTags

The final tag calculation must:

- Preserve tags unique to the User Story.
- Preserve tags shared by the source and target Features.
- Remove tags found only on the source Feature.
- Add all tags from the target Feature.
- Deduplicate tags using case-insensitive comparison.
- Preserve the target Feature spelling and capitalization for target Feature tags.

## Preview Workflow

When preview is requested:

1. Retrieve the User Story, current parent Feature, and target Feature.
2. Calculate the proposed final tags.
3. Do not update Azure DevOps.
4. Return:
   - User Story ID and title
   - Current parent Feature
   - Target parent Feature
   - Current User Story tags
   - Source-Feature-only tags to remove
   - User Story-specific tags to preserve
   - Target Feature tags to add
   - Tags shared by both Features
   - Final calculated tag set
5. Wait for explicit user approval before execution.

## Execution Workflow

When execution is explicitly approved:

1. Retrieve the User Story, current parent Feature, and target Feature again.
2. Recalculate the final tag set using the latest ADO values.
3. Save the following original values for rollback:
   - Original parent Feature
   - Original complete User Story tag set
4. Change the User Story parent relationship to the target Feature.
5. Replace the complete User Story tag set with the calculated final tag set.
6. Retrieve the User Story after the updates.
7. Verify:
   - The target Feature is the new parent.
   - All target Feature tags are present.
   - All User Story-specific tags are preserved.
   - Source-Feature-only tags are removed.
   - Shared source and target Feature tags remain.
   - No duplicate tags exist.
8. Do not report success unless the parent and tag updates are both verified.

## Failure and Rollback Rules

- If validation fails before execution, stop without making changes.
- If the current parent cannot be identified, stop and report the issue.
- If the target Feature is invalid or inaccessible, stop without making changes.
- If the parent update fails, do not update the tags.
- If the parent changes but the tag update fails, restore the original parent and original tag set when possible.
- If verification fails, attempt to restore the original parent and original tag set.
- If rollback cannot be completed, report the exact partial state immediately.
- Never intentionally leave a User Story without a parent.
- Never report a partial update as successful.

## Batch Move Rules

When moving multiple User Stories:

- Process and validate each User Story independently.
- Do not assume all User Stories have the same source Feature.
- Do not assume all User Stories have the same unique tags.
- Calculate the final tag set separately for each User Story.
- If one User Story fails, document the failure and continue only if processing the remaining stories does not create additional risk.
- Report success or failure separately for each User Story.

## Move Story Completion

After completing the approved moves, return a summary containing:

- User Story ID and title with an ADO hyperlink
- Source Feature ID and title
- Target Feature ID and title
- Source-Feature-only tags removed
- Target Feature tags added
- User Story-specific tags preserved
- Final complete User Story tag set
- Parent verification status
- Tag verification status
- Overall result

Use the following display format:

<ADO URL>

Clearly identify any User Stories that:

- Failed validation
- Failed during execution
- Were rolled back
- Remain partially updated