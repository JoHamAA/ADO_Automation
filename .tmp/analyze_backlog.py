import csv
import re
from collections import Counter

file_path = r'c:\MCP_Story_Automation\.github\PAX_Backlog.csv'

titles = []
descriptions = []
acceptance_criterias = []
tags_list = []
work_types = Counter()

with open(file_path, mode='r', encoding='utf-8-sig', errors='ignore') as f:
    reader = csv.DictReader(f)
    for row in reader:
        titles.append(row.get('Title', ''))
        desc = row.get('Description', '')
        ac = row.get('Acceptance Criteria', '')
        tags = row.get('Tags', '')
        
        if desc:
            descriptions.append(desc)
        if ac:
            acceptance_criterias.append(ac)
        if tags:
            for t in tags.split(';'):
                if t.strip():
                    tags_list.append(t.strip())

print(f"Total Stories Parsed: {len(titles)}")
print("\n--- Top 10 Title Prefixes/Patterns ---")
prefix_counter = Counter([t.split('-')[0].strip() if '-' in t else t.split()[0] for t in titles if t])
for p, c in prefix_counter.most_common(10):
    print(f"  {p}: {c}")

print("\n--- Top 15 Tags Used ---")
for tag, count in Counter(tags_list).most_common(15):
    print(f"  {tag}: {count}")

print("\n--- Sample Description Formats ---")
for i, d in enumerate(descriptions[:5], 1):
    # Clean HTML tags for sample output
    clean_d = re.sub('<[^<]+?>', ' ', d).strip()
    clean_d = re.sub(r'\s+', ' ', clean_d)
    print(f"Sample {i}: {clean_d[:200]}...")

print("\n--- Sample Acceptance Criteria Formats ---")
for i, ac in enumerate(acceptance_criterias[:5], 1):
    clean_ac = re.sub('<[^<]+?>', ' ', ac).strip()
    clean_ac = re.sub(r'\s+', ' ', clean_ac)
    print(f"Sample {i}: {clean_ac[:200]}...")
