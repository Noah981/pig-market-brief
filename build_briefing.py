import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
src=ROOT/'docs/data/briefing.sample.json'
out=ROOT/'docs/data/briefing.json'
data=json.loads(src.read_text(encoding='utf-8'))
out.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print(out)
