"""Download all JSON vocab files from KyleBing/english-vocabulary"""
import urllib.request
import os

BASE = "https://raw.githubusercontent.com/KyleBing/english-vocabulary/master/json_original/json-sentence"
OUT = os.path.dirname(os.path.abspath(__file__))
FILES = [
    # PEP junior high
    "PEPChuZhong7_1.json", "PEPChuZhong7_2.json",
    "PEPChuZhong8_1.json", "PEPChuZhong8_2.json",
    "PEPChuZhong9_1.json",
    # CET-4 (3 parts)
    "CET4_1.json", "CET4_2.json", "CET4_3.json",
    # CET-6 (3 parts)
    "CET6_1.json", "CET6_2.json", "CET6_3.json",
]

for f in FILES:
    url = f"{BASE}/{f}"
    out = os.path.join(OUT, f)
    if os.path.exists(out):
        print(f"SKIP {f} (exists)")
        continue
    print(f"GET {f} ...")
    urllib.request.urlretrieve(url, out)
    size = os.path.getsize(out)
    print(f"  OK {size:,} bytes")
print("DONE")
