import json
from datetime import datetime, timezone, timedelta
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"docs/data"
RULES=json.loads((ROOT/"config/checklist_rules.json").read_text(encoding="utf-8"))
weather=json.loads((DATA/"weather.json").read_text(encoding="utf-8"))
KST=timezone(timedelta(hours=9))

def weather_actions(w):
    score=[]; reasons=[]
    if (w.get("diurnalRange") or 0)>=8:
        score += ["최소환기와 야간 환기량 점검","호흡기 증상·기침 관찰","보온구역과 외풍 점검"]; reasons.append("큰 일교차")
    if (w.get("humidityMax") or 0)>=80:
        score += ["돈사 바닥 습윤·분뇨 상태 점검","급이기 사료 변질·곰팡이 확인","환기와 습도 관리 점검"]; reasons.append("고습")
    if (w.get("rainProbabilityMax") or 0)>=60:
        score += ["우수 유입·배수로 확인","사료빈·사료 이송라인 누수 점검","출입구 소독시설과 차량 동선 확인"]; reasons.append("강수 가능성")
    if (w.get("tempMax") or 0)>=30:
        score += ["급수기 유량·니플 상태 확인","쿨링·환기설비 작동 확인","섭취량 저하와 모돈 상태 확인"]; reasons.append("고온")
    # preserve order, unique, max 6
    unique=list(dict.fromkeys(score))
    return reasons, unique[:6]

regions=[]
for w in weather.get("regions",[]):
    reasons,checks=weather_actions(w)
    regions.append({**w,"riskFactors":reasons,"farmChecks":checks,
                    "top3":checks[:3] if checks else ["급이기·급수기 청결 확인","환기 상태 확인","돈군 건강상태 관찰"]})
brief={
 "updatedAt":datetime.now(KST).isoformat(),
 "scope":"대한민국 전역 · 제주 포함",
 "weatherSource":weather.get("source"),
 "regions":regions,
 "market":{"mainlandWhitePig":{"label":"육지 백돼지","scope":"제주 제외","status":"pending_exact_api_operation","unit":"원/kg"},
           "jejuWhitePig":{"label":"제주 백돼지","scope":"제주","sourceFile":"kape-jeju.json"},
           "jejuBlackPig":{"label":"제주 흑돼지","scope":"제주","sourceFile":"kape-jeju.json"}}
}
(DATA/"briefing.json").write_text(json.dumps(brief,ensure_ascii=False,indent=2),encoding="utf-8")
print(f"briefing regions={len(regions)}")
