import json
import subprocess

for item_id in range(3248988, 3249000):
    result = subprocess.run([
        "az.cmd", "boards", "work-item", "show",
        "--id", str(item_id),
        "--expand", "relations",
        "--organization", "https://dev.azure.com/AmericanAirlines",
        "--output", "json",
    ], check=True, capture_output=True, text=True)
    item = json.loads(result.stdout)
    fields = item.get("fields", {})
    points = fields.get("Microsoft.VSTS.Scheduling.StoryPoints", "")
    tags = fields.get("System.Tags", "")
    iteration = fields.get("System.IterationPath", "")
    relations = []
    for relation in item.get("relations", []):
        rel_type = relation.get("rel", "")
        url = relation.get("url", "")
        if rel_type.endswith("Hyperlink"):
            continue
        relations.append((rel_type.rsplit("/", 1)[-1], url[-7:]))
    print(f"{item_id} | {points} | {tags} | {iteration} | {relations}")

