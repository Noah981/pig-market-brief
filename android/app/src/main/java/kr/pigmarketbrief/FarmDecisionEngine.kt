package kr.pigmarketbrief

import kotlin.math.max

enum class EvidenceLevel(val label: String) { OFFICIAL("공식 발생 확인"), PUBLIC_UNCONFIRMED("공개정보 · 확인중"), FARM_OBSERVATION("농장 관찰"), MODEL_INFERENCE("데이터 기반 주의") }
enum class RiskDomain { ENVIRONMENT, RESPIRATORY, ENTERIC, BIOSECURITY, PRODUCTION, SHIPMENT, MARKET }
data class TimedSignal(val confidence:Double,val ageHours:Double,val spatialRelevance:Double,val evidence:EvidenceLevel)
data class FarmContext(
 val region:String,val stage:String,val tempMin:Double?=null,val tempMax:Double?=null,val humidity:Double?=null,
 val weatherWarning:Boolean=false,val cough:Boolean=false,val diarrhea:Boolean=false,val intakeDrop:Boolean=false,
 val mortalityRise:Boolean=false,val diseaseNearby:Boolean=false,val priceChangePct:Double?=null,val shipmentDueDays:Int?=null,
 val recentFcr:Double?=null,val baselineFcr:Double?=null,val signal:TimedSignal?=null)
data class ActionStep(val order:Int,val title:String,val detail:String,val professional:Boolean=false)
data class DecisionCard(
 val domain:RiskDomain,val score:Int,val title:String,val why:List<String>,val observe:List<String>,val measure:List<String>,
 val firstAdjustment:String,val differentials:List<String>,val escalation:String,val evidence:EvidenceLevel,val steps:List<ActionStep>)

object FarmDecisionEngine {
 private fun reliability(s:TimedSignal?):Double { if(s==null)return 1.0; val fresh=when{ s.ageHours<=6->1.0;s.ageHours<=24->.86;s.ageHours<=72->.64;else->.38};return(s.confidence*fresh*s.spatialRelevance).coerceIn(.2,1.0) }
 private fun score(raw:Double,s:TimedSignal?)=(raw*reliability(s)).toInt().coerceIn(0,100)
 private fun card(domain:RiskDomain,raw:Double,title:String,why:List<String>,observe:List<String>,measure:List<String>,adjust:String,diff:List<String>,escalate:String,evidence:EvidenceLevel,signal:TimedSignal?)=DecisionCard(domain,score(raw,signal),title,why,observe,measure,adjust,diff,escalate,evidence,listOf(
  ActionStep(1,"관찰",observe.joinToString(" · ")),ActionStep(2,"측정",measure.joinToString(" · ")),ActionStep(3,"우선 조정",adjust),ActionStep(4,"지속 시 감별",diff.joinToString(" · ")+" — "+escalate,true)))
 fun evaluate(x:FarmContext):List<DecisionCard>{
  val out=mutableListOf<DecisionCard>();val swing=if(x.tempMin!=null&&x.tempMax!=null)x.tempMax-x.tempMin else null;val young=x.stage in setOf("분만","포유자돈","이유자돈","자돈")
  if(swing!=null&&(swing>=8||x.weatherWarning||x.cough)) out+=card(RiskDomain.ENVIRONMENT,48+max(0.0,swing-8)*3+(if(x.cough)24 else 0)+(if(young)8 else 0),"큰 일교차, 야간 환기부터 확인",listOf("예상 일교차 ${swing.toInt()}℃","${x.stage} 취약도 반영"),listOf("돈군 뭉침·외풍 회피","기침·복식호흡·발열","섭취 변화"),listOf("새벽 온도·습도","CO₂·암모니아","입기·최소환기"),"환기를 끄지 말고 외풍·입기 방향·최소환기를 한 항목씩 조정",listOf("PRRS","돼지인플루엔자","마이코플라즈마","흉막폐렴"),"호흡곤란·폐사 증가 또는 환경 교정 후 24시간 지속 시 수의사 연결",if(x.cough)EvidenceLevel.FARM_OBSERVATION else EvidenceLevel.MODEL_INFERENCE,x.signal)
  if(x.diarrhea) out+=card(RiskDomain.ENTERIC,70+(if(x.mortalityRise)25 else 0)+(if(young)5 else 0),"설사 양상 기록 후 원인 구분",listOf("설사 관찰 입력",if(x.mortalityRise)"폐사 증가 동반" else "폐사 증가 미입력"),listOf("일령·펜·확산속도","분변색·구토","탈수·체온"),listOf("급수 유량·수온","사료 변경·변질","발생률·폐사율"),"탈수 위험과 오염 동선을 먼저 관리한 뒤 급수·사료 이상 확인",listOf("PED","로타바이러스","대장균","살모넬라","회장염"),"빠른 확산·구토·심한 탈수·포유자돈 다발 또는 폐사 증가 시 당일 수의사 상담",EvidenceLevel.FARM_OBSERVATION,x.signal)
  if(x.diseaseNearby) out+=card(RiskDomain.BIOSECURITY,100.0,"지역 방역 위험, 출입통제 최우선",listOf("선택지역 관련 방역 신호"),listOf("고열·급사·출혈","수포","집단 활력 급변"),listOf("출입 기록","소독액 농도·교체시각","체온·발생두수"),"차량·사람·물품 동선을 통제하고 농장 내외 구역 교차 차단",listOf("ASF","구제역","돼지열병","돈단독"),"신고대상 의심증상 시 임의 치료·이동보다 격리 후 방역기관 또는 수의사에 즉시 연락",x.signal?.evidence?:EvidenceLevel.OFFICIAL,x.signal)
  if(x.intakeDrop) out+=card(RiskDomain.PRODUCTION,64+(if(x.mortalityRise)20 else 0),"섭취량 저하 원인 순서대로 확인",listOf("섭취량 저하 관찰"),listOf("급이기 접근·잔량","음수 행동","발열·기침·설사"),listOf("니플 유량·수온","전일 대비 급이량","온습도·CO₂"),"급수 → 급이기 → 사료 → 환경 순으로 조치 전후를 기록",listOf("급수 장애","사료 브리징·변질","고온 스트레스","질병"),"12시간 내 회복되지 않거나 발열·폐사·호흡곤란 동반 시 수의사 연결",EvidenceLevel.FARM_OBSERVATION,x.signal)
  val fd=if(x.recentFcr!=null&&x.baselineFcr!=null)x.recentFcr-x.baselineFcr else null
  if(fd!=null&&fd>=.15)out+=card(RiskDomain.PRODUCTION,58+fd*45,"FCR 악화 구간 원인 추적",listOf("기준 대비 ${"%.2f".format(fd)} 악화"),listOf("허실·선별채식","증체 편차","만성 증상"),listOf("사료투입량·재고","기간 증체","폐사보정"),"산식과 재고를 검증한 뒤 허실·급수·환경 점검",listOf("측정오차","사료허실","질병","밀사"),"2개 기록주기 이상 지속 시 영양·수의 전문가와 분석",EvidenceLevel.MODEL_INFERENCE,x.signal)
  if(x.shipmentDueDays!=null&&x.shipmentDueDays<=3&&(x.priceChangePct?:0.0)>=2.0)out+=card(RiskDomain.SHIPMENT,56.0,"출하 예정군 체중 분포 확인",listOf("출하 ${x.shipmentDueDays}일 전","돈가 변동 ${x.priceChangePct}%"),listOf("과체중·미달돈","절식 가능시간"),listOf("표본체중","이전 등급결과"),"계약·도축장 기준 확인 후 표본체중으로 출하군 선별",listOf("체중 편차","절식 실패","출하 스트레스"),"계약 지급기준이 불명확하면 출하 담당자와 확인",EvidenceLevel.MODEL_INFERENCE,x.signal)
  if(out.isEmpty())out+=card(RiskDomain.ENVIRONMENT,32.0,"기본 환경과 섭취 변화 확인",listOf("긴급 신호 없음"),listOf("돈군 분포","기침·설사","급이기 접근"),listOf("온도·습도","급수 유량","사료 잔량"),"평소 기준에서 벗어난 항목만 기록하고 한 번에 하나씩 조정",listOf("환경","급수","급이","초기 질병징후"),"급격한 활력·섭취 저하 또는 폐사 증가 시 수의사 상담",EvidenceLevel.MODEL_INFERENCE,x.signal)
  return out.sortedWith(compareByDescending<DecisionCard>{it.score}.thenBy{it.domain.ordinal}).take(3)
 }
}
