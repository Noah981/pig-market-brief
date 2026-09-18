import os, json, urllib.parse, urllib.request, xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/"docs/data/kape-jeju.json"
KST=timezone(timedelta(hours=9))
BASE="http://data.ekape.or.kr/openapi-data/service/user/grade/auct/pigJejuGrade"
FIELDS=["gradeCode","gradeName","totPrice","totCnt","publicTotPrice","publicTotCnt","blackTotPrice","blackTotCnt",
"totFemalePrice","totFemaleCnt","totMalePrice","totMaleCnt","totBarrowPrice","totBarrowCnt",
"publicFemalePrice","publicFemaleCnt","publicMalePrice","publicMaleCnt","publicBarrowPrice","publicBarrowCnt",
"blackFemalePrice","blackFemaleCnt","blackMalePrice","blackMaleCnt","blackBarrowPrice","blackBarrowCnt"]
def main():
 key=os.environ.get("KAPE_SERVICE_KEY")
 if not key: raise SystemExit("KAPE_SERVICE_KEY missing")
 d=datetime.now(KST).strftime("%Y%m%d")
 params=urllib.parse.urlencode({"startYmd":d,"endYmd":d,"skinYn":"Y"})
 url=BASE+"?serviceKey="+key+"&"+params
 try:
  with urllib.request.urlopen(url,timeout=10) as r: raw=r.read()
  root=ET.fromstring(raw); rows=[]
  for item in root.findall(".//item"):
   row={k:(item.findtext(k)) for k in FIELDS if item.find(k) is not None}; rows.append(row)
  payload={"source":"축산물품질평가원","scope":"제주 돼지도체 등급별 경락가격","date":d,"skinYn":"Y","rows":rows,"status":"ok"}
 except Exception as e:
  payload={"source":"축산물품질평가원","scope":"제주 돼지도체 등급별 경락가격","date":d,"skinYn":"Y","rows":[],"status":"error","error":str(e)[:200]}
 OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
if __name__=="__main__": main()
