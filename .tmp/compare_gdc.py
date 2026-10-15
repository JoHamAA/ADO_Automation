import json
import os

path = os.path.expandvars(r"%TEMP%\pax_dfw_gdc_review.json")
data = json.load(open(path, encoding="utf-16"))
roster = {
    "Zhu, Hongtao": "S-DFW", "Vardhan, Harsha": "S-HYD", "Suresh, Anveetha": "S-HYD",
    "Saxena, Shailender": "S-DFW", "Saha, Jayanta": "S-HYD", "Rivera, Jasmine": "S-DFW",
    "Ramos, Kevin": "S-DFW", "Praneetha, Chodey": "S-HYD", "Periyasamy, Sridharan": "S-DFW",
    "Nomula, Deepthi": "S-HYD", "Nguyen, Andy": "S-DFW", "Menon, Prashant": "S-DFW",
    "Kulkarni, Sneha": "S-DFW", "Kamath, Sihi": "S-DFW", "Hoang, Cassidy": "S-DFW",
    "Harshitha, Kadam": "S-HYD", "Ghosh, Deepayan": "S-HYD", "Bulusu, Karthik": "S-HYD",
    "Bedi, Ayushman": "S-HYD"
}

mismatches = []
for item in data:
    fields = item["fields"]
    assignee = fields.get("System.AssignedTo", {}).get("displayName", "Unassigned")
    tags = [tag.strip() for tag in (fields.get("System.Tags", "") or "").split(";")]
    expected = roster.get(assignee)
    status = "OK" if expected and expected in tags else ("MISSING/WRONG" if expected else "UNMAPPED")
    print(f"{item['id']} | {assignee} | expected={expected or '-'} | tags={'; '.join(tags) or '-'} | {status}")
    if status != "OK":
        mismatches.append((item["id"], assignee, expected, tags, fields.get("System.Title", "")))

print(f"\nTotal stories: {len(data)}")
print(f"Potential corrections: {len(mismatches)}")
for item_id, assignee, expected, tags, title in mismatches:
    print(f"CORRECTION | {item_id} | {assignee} | add {expected or 'manual review'} | {title}")
