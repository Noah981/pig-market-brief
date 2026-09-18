package kr.pigmarketbrief

enum class EvidenceLevel { OFFICIAL, PUBLIC_UNCONFIRMED, FARM_OBSERVATION }
enum class RiskDomain { ENVIRONMENT, RESPIRATORY, ENTERIC, BIOSECURITY, PRODUCTION, SHIPMENT, MARKET }
data class FarmContext(val region:String,val stage:String,val tempMin:Double?=null,val tempMax:Double?=null,val humidity:Double?=null,val cough:Boolean=false,val diarrhea:Boolean=false,val intakeDrop:Boolean=false,val mortalityRise:Boolean=false,val diseaseNearby:Boolean=false)
data class ActionStep(val order:Int,val title:String,val detail:String,val professional:Boolean=false)
data class DecisionCard(val domain:RiskDomain,val score:Int,val title:String,val why:List<String>,val steps:List<ActionStep>,val evidence:EvidenceLevel)
object FarmDecisionEngine {
 fun evaluate(x:FarmContext):List<DecisionCard>{
  val out=mutableListOf<DecisionCard>(); val swing=if(x.tempMin!=null&&x.tempMax!=null)x.tempMax-x.tempMin else null
  if(swing!=null&&swing>=10){val steps=mutableListOf(ActionStep(1,"야간 최소환기 확인","팬 작동, 입기구 방향, 외풍 여부를 순서대로 확인"),ActionStep(2,"돈군 행동 관찰","자돈 뭉침, 기침, 복식호흡, 섭취량 저하 확인"),ActionStep(3,"공기질 측정","가능하면 CO₂·암모니아·온습도를 실제 측정"));if(x.cough)steps+=ActionStep(4,"호흡기 감별검사 상담","환경 문제가 교정돼도 기침이 지속되면 PRRS·인플루엔자·마이코플라즈마 등 감별을 수의사와 상의",true);out+=DecisionCard(RiskDomain.ENVIRONMENT,(55+(swing-10)*3+(if(x.cough)20 else 0)).toInt().coerceAtMost(100),"환절기 호흡기·환기 우선점검",listOf("일교차 "+swing.toInt()+"℃"),steps,EvidenceLevel.FARM_OBSERVATION)}
  if(x.diarrhea)out+=DecisionCard(RiskDomain.ENTERIC,if(x.mortalityRise)95 else 72,"설사 원인 구분 필요",listOf("설사 증상 입력됨"),listOf(ActionStep(1,"돈군 범위 확인","발생 일령, 분변색, 구토, 탈수, 발생 펜과 확산속도 기록"),ActionStep(2,"급수·사료 확인","급수 이상, 사료 변질·급변 여부를 먼저 확인"),ActionStep(3,"감별검사 상담","PED·로타·대장균·회장염 등 원인이 달라질 수 있어 수의사에게 검사 상담",true)),EvidenceLevel.FARM_OBSERVATION)
  if(x.diseaseNearby)out+=DecisionCard(RiskDomain.BIOSECURITY,98,"지역 질병 방역 최우선",listOf("주변 질병 발생/경보"),listOf(ActionStep(1,"출입통제","차량·사람·물품 동선을 즉시 재확인"),ActionStep(2,"소독상태 확인","소독조·차량소독·장화/의복 교체 확인"),ActionStep(3,"이상축 확인","고열·급사·출혈·수포 등 이상 시 임의 치료보다 격리 후 방역기관/수의사에 신고·상담",true)),EvidenceLevel.OFFICIAL)
  if(x.intakeDrop&&out.none{it.domain==RiskDomain.ENVIRONMENT})out+=DecisionCard(RiskDomain.PRODUCTION,60,"섭취량 저하 원인 확인",listOf("섭취량 저하"),listOf(ActionStep(1,"음수 확인","니플 작동·유량·수온 확인"),ActionStep(2,"급이 확인","브리징·허실·변질·사료전환 시점 확인"),ActionStep(3,"환경·질병 확인","온도·환기·발열·호흡기/소화기 증상 확인")),EvidenceLevel.FARM_OBSERVATION)
  return out.sortedByDescending{it.score}.take(3)
 }
}
