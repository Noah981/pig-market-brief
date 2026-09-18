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
        score += ["환절기: 야간 최소환기·입기구를 확인하세요. 외풍이 느껴지면 입기 방향과 최소환기량부터 조정","기침이 늘면 돈사 온도·일교차·암모니아를 먼저 확인하고 지속되면 수의사에게 호흡기 검사를 의뢰","자돈이 뭉치면 보온구역 온도와 외풍을 확인하고 보온등·바닥 보온을 점검"]; reasons.append("큰 일교차")
    if (w.get("humidityMax") or 0)>=80:
        score += ["바닥이 젖거나 결로가 보이면 누수·급수기와 최소환기를 순서대로 확인","사료 냄새·응결이 있으면 급이기와 빈 내부의 변질·곰팡이를 확인하고 오염 사료는 급여 중단","고습과 가스 냄새가 같이 나면 최소환기량과 팬 작동 상태를 우선 점검"]; reasons.append("고습")
    if (w.get("rainProbabilityMax") or 0)>=60:
        score += ["우수 유입·배수로 확인","사료빈·사료 이송라인 누수 점검","출입구 소독시설과 차량 동선 확인"]; reasons.append("강수 가능성")
    if (w.get("tempMax") or 0)>=30:
        score += ["섭취량이 떨어지면 니플 유량·수온부터 확인하고 급수 부족 여부를 먼저 배제","헐떡임이 보이면 팬·입기·쿨링 작동과 밀사를 확인하고 열스트레스 완화 조치","포유돈 섭취량이 줄면 음수량·급이 시간대를 확인하고 지속 시 수의사와 상태 점검"]; reasons.append("고온")
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
