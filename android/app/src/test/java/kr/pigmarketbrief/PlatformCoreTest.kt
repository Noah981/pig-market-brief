package kr.pigmarketbrief
import org.junit.Assert.*
import org.junit.Test
import java.math.BigDecimal
import java.time.LocalDate
class PlatformCoreTest{
 @Test fun countryClassification(){assertEquals("국내",classifyCountry("KR"));listOf("VN","CN","JP","US").forEach{assertEquals("국외",classifyCountry(it))};assertEquals("분류 확인 필요",classifyCountry("XX"));assertEquals("분류 확인 필요",classifyCountry(null))}
 @Test fun dateValidation(){assertNull(parseDay("2026-02-30"));assertEquals(0L,daysUntil("2026-09-19",LocalDate.of(2026,9,19)));assertEquals(-1L,daysUntil("20260918",LocalDate.of(2026,9,19)))}
 @Test fun incentives(){val benefits=listOf(Incentive("계약","%",BigDecimal("3"),true),Incentive("브랜드","원/두",BigDecimal("15000"),true));val sum=estimate(100,BigDecimal("90"),BigDecimal("6000"),benefits,"중복 가능");assertEquals(BigDecimal("54000000"),sum.base);assertEquals(BigDecimal("3120000"),sum.extra);assertEquals(BigDecimal("1620000"),estimate(100,BigDecimal("90"),BigDecimal("6000"),benefits,"가장 높은 혜택만").extra);assertEquals(BigDecimal.ZERO,estimate(100,BigDecimal("90"),BigDecimal("6000"),benefits.map{it.copy(confirmed=false)},"중복 가능").extra)}
 @Test fun orderReminder(){assertEquals(LocalDate.of(2026,9,26),feedDue("2026-09-19",7,null));assertNull(feedDue("bad",7,null));assertNull(feedDue("2026-09-19",0,null));assertEquals(LocalDate.of(2026,9,22),feedDue("2026-09-19",7,"2026-09-22"))}
 @Test fun pendingMustNotBeConfirmed(){assertEquals("미확정",priceStatus(PigPrice(date=todayKorea().toString(),price=5000,status="미확정")))}
}
