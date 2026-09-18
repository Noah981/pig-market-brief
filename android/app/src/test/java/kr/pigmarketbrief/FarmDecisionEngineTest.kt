package kr.pigmarketbrief

import org.junit.Assert.*
import org.junit.Test

class FarmDecisionEngineTest {
 @Test fun largeSwingCreatesEnvironmentPriority(){
  val r=FarmDecisionEngine.evaluate(FarmContext("김천","자돈",5.0,18.0,70.0))
  assertTrue(r.any{it.domain==RiskDomain.ENVIRONMENT})
  assertTrue(r.first{it.domain==RiskDomain.ENVIRONMENT}.steps.size>=3)
 }
 @Test fun coughEscalatesToProfessionalStep(){
  val r=FarmDecisionEngine.evaluate(FarmContext("김천","자돈",5.0,18.0,70.0,cough=true))
  assertTrue(r.flatMap{it.steps}.any{it.professional})
 }
 @Test fun nearbyDiseaseDominatesPriority(){
  val r=FarmDecisionEngine.evaluate(FarmContext("김천","비육",10.0,15.0,60.0,diseaseNearby=true,intakeDrop=true))
  assertEquals(RiskDomain.BIOSECURITY,r.first().domain)
  assertEquals(EvidenceLevel.OFFICIAL,r.first().evidence)
 }
 @Test fun diarrheaWithMortalityIsHighRisk(){
  val r=FarmDecisionEngine.evaluate(FarmContext("김천","자돈",10.0,15.0,60.0,diarrhea=true,mortalityRise=true))
  assertTrue(r.first{it.domain==RiskDomain.ENTERIC}.score>=90)
 }
 @Test fun staleSignalReducesPriority(){
  val fresh=FarmDecisionEngine.evaluate(FarmContext("경북","자돈",5.0,18.0,70.0,signal=TimedSignal(1.0,2.0,1.0,EvidenceLevel.OFFICIAL))).first()
  val stale=FarmDecisionEngine.evaluate(FarmContext("경북","자돈",5.0,18.0,70.0,signal=TimedSignal(1.0,120.0,1.0,EvidenceLevel.OFFICIAL))).first()
  assertTrue(fresh.score>stale.score)
 }
 @Test fun decisionContainsClosedLoopPath(){
  val r=FarmDecisionEngine.evaluate(FarmContext("경북","자돈",4.0,17.0,70.0,cough=true)).first()
  assertTrue(r.observe.isNotEmpty());assertTrue(r.measure.isNotEmpty());assertTrue(r.firstAdjustment.isNotBlank());assertTrue(r.escalation.isNotBlank())
 }
}
