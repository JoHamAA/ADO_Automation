import json

path = r'c:\MCP_Story_Automation\.tmp\dfw_sprint34.json'
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except Exception:
    with open(path, 'r', encoding='utf-16') as f:
        data = json.load(f)

print(f"Total count: {len(data)}")
by_type = {}
for item in data:
    fields = item['fields']
    w_type = fields.get('System.WorkItemType', 'N/A')
    by_type[w_type] = by_type.get(w_type, 0) + 1

print("By type:", by_type)

stories = [item for item in data if item['fields'].get('System.WorkItemType') in ['User Story', 'Bug', 'Defect']]
print(f"\nStories/Bugs count ({len(stories)}):")
for item in stories:
    fields = item['fields']
    w_type = fields.get('System.WorkItemType', 'N/A')
    state = fields.get('System.State', 'N/A')
    assigned = fields.get('System.AssignedTo', {}).get('displayName', 'Unassigned')
    title = fields.get('System.Title', 'N/A')
    w_id = fields.get('System.Id', 'N/A')
    print(f"{w_id} | {w_type} | {state} | {assigned} | {title}")

