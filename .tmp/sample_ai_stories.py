import csv
import re

file_path = r'c:\MCP_Story_Automation\.github\PAX_Backlog.csv'

ai_stories = []

with open(file_path, mode='r', encoding='utf-8-sig', errors='ignore') as f:
    reader = csv.DictReader(f)
    for row in reader:
        tags = row.get('Tags', '')
        if 'AI-StoryWriting' in tags:
            ai_stories.append(row)

print(f"Total AI-StoryWriting stories: {len(ai_stories)}")

for i, story in enumerate(ai_stories[:5], 1):
    print(f"\n================ Story {i}: ID {story['ID']} - {story['Title']} ================")
    print("TAGS:", story['Tags'])
    print("DESCRIPTION:")
    desc = re.sub('<[^<]+?>', '\n', story['Description']).strip()
    desc = '\n'.join([line.strip() for line in desc.splitlines() if line.strip()])
    print(desc)
    print("\nACCEPTANCE CRITERIA:")
    ac = re.sub('<[^<]+?>', '\n', story['Acceptance Criteria']).strip()
    ac = '\n'.join([line.strip() for line in ac.splitlines() if line.strip()])
    print(ac)
