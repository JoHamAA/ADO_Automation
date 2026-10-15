import json
import os
import subprocess

path = os.path.expandvars(r"%TEMP%\pax_dfw_gdc_latest.json")
data = json.load(open(path, encoding="utf-16"))
roster = {
    "Zhu, Hongtao": "S-DFW", "Vardhan, Harsha": "S-HYD", "Suresh, Anveetha": "S-HYD",
    "Saxena, Shailender": "S-DFW", "Saha, Jayanta": "S-DFW", "Rivera, Jasmine": "S-DFW",
    "Ramos, Kevin": "S-DFW", "Praneetha, Chodey": "S-HYD", "Periyasamy, Sridharan": "S-DFW",
    "Nomula, Deepthi": "S-HYD", "Nguyen, Andy": "S-DFW", "Menon, Prashant": "S-DFW",
    "Kulkarni, Sneha": "S-DFW", "Kamath, Sihi": "S-DFW", "Hoang, Cassidy": "S-DFW",
    "Harshitha, Kadam": "S-HYD", "Ghosh, Deepayan": "S-HYD", "Bulusu, Karthik": "S-HYD",
    "Bedi, Ayushman": "S-HYD"
}

updates = []
for item in data:
    fields = item["fields"]
    assignee = fields.get("System.AssignedTo", {}).get("displayName", "Unassigned")
    expected = roster.get(assignee)
    current_tags = [tag.strip() for tag in (fields.get("System.Tags", "") or "").split(";") if tag.strip()]
    if expected and expected not in current_tags:
        new_tags = current_tags + [expected]
        tag_value = "; ".join(new_tags)
        subprocess.run([
            "az.cmd", "boards", "work-item", "update", "--id", str(item["id"]),
            "--organization", "https://dev.azure.com/AmericanAirlines",
            "--fields", f"System.Tags={tag_value}", "--output", "none"
        ], check=True)
        updates.append((item["id"], assignee, expected, tag_value))

print(f"Updated stories: {len(updates)}")
for item_id, assignee, gdc, tags in updates:
    print(f"{item_id} | {assignee} | added {gdc} | tags: {tags}")
