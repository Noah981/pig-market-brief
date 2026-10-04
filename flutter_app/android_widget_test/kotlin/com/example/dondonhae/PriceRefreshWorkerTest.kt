package com.example.dondonhae

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.text.SimpleDateFormat
import java.util.Locale

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PriceRefreshWorkerTest {
    private fun row(date: String, price: Int) = """{"status":"ok","scope":"전국·탕박·등외제외·제주제외","date":"$date","price":$price,"change":25,"changePct":0.4}"""
    private val now = SimpleDateFormat("yyyyMMdd", Locale.US).parse("20261005")!!
    @Test fun nextOfficialDayChangesPriceAndRetainsHistory() {
        val old = JSONObject().put("price", JSONObject(row("20261001", 6027))).put("history", JSONObject("""{"rows":[{"date":"20261001","price":6027}]}"""))
        val merged = JSONObject(PriceRefreshWorker.mergeVerifiedPrice(old.toString(), row("20261005", 6052), now)!!)
        assertEquals("20261005", merged.getJSONObject("price").getString("date"))
        assertEquals(6052, merged.getJSONObject("price").getInt("price"))
        assertEquals(1, merged.getJSONObject("history").getJSONArray("rows").length())
    }
    @Test fun oldOrInvalidFeedsCannotReplaceVerifiedQuote() {
        val old = JSONObject().put("price", JSONObject(row("20261005", 6052))).toString()
        assertEquals("20261005", JSONObject(PriceRefreshWorker.mergeVerifiedPrice(old, row("20261001", 6027), now)!!).getJSONObject("price").getString("date"))
        assertNull(PriceRefreshWorker.mergeVerifiedPrice(old, row("20261006", 6000), now))
        assertNull(PriceRefreshWorker.mergeVerifiedPrice(old, row("20260230", 6000), now))
        assertNull(PriceRefreshWorker.mergeVerifiedPrice(old, row("20261005", 0), now))
        assertNull(PriceRefreshWorker.mergeVerifiedPrice(old, "{}", now))
    }
    @Test fun holidayKeepsRealBasisInsteadOfInventingTodaysQuote() {
        val merged = JSONObject(PriceRefreshWorker.mergeVerifiedPrice(null, row("20261001", 6027), now)!!)
        assertEquals("20261001", merged.getJSONObject("price").getString("date"))
        assertEquals(6027, merged.getJSONObject("price").getInt("price"))
    }
}
