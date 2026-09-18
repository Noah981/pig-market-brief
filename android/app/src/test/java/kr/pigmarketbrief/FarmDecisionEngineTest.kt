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
}
