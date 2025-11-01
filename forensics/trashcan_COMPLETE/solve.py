import pandas as pd
import re
from datetime import datetime

# Load CSV and parse relevant columns
df = pd.read_csv("results.csv", dtype=str, keep_default_na=False)

# Extract and sort by timestamp
rows = []
for _, r in df.iterrows():
    if r["$R File Name"].startswith("$R"):
        try:
            size = int(r["Size (Bytes)"])
            time = datetime.strptime(r["Timestamp (UTC)"].strip(), "%m-%d-%Y %H:%M:%S UTC")
            if 0 <= size <= 255:
                rows.append((time, chr(size)))
        except:
            continue

rows.sort()
raw = ''.join(ch for _, ch in rows)

# Run-length decode: copies = run_length // 3
decoded = ''.join(ch * (len(list(g)) // 3) for ch, g in 
                  [(k, list(v)) for k, v in 
                   __import__('itertools').groupby(raw)])

# Extract flag
if match := re.search(r'flag\{([0-9a-f]{32})\}', decoded):
    print(f"FLAG: flag{{{match.group(1)}}}")
else:
    print("No flag found")
    print(f"Decoded: {decoded}")