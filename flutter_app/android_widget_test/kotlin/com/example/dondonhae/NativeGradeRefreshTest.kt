package com.example.dondonhae
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
@RunWith(RobolectricTestRunner::class)
@Config(sdk=[34])
class NativeGradeRefreshTest {
    private val html="""<input name="searchStartDate" value="2026-10-02"><table id="table-type1">"""+listOf("1+","1","2","등외").joinToString(""){"<tr><td>$it</td><td>10</td><td>6,500</td></tr>"}+"</table>"
    @Test fun exactOfficialDateAndFourGradesAreRequired(){
        assertEquals(4,NativeGradeRefresh.parse(html,"20261002")!!.getJSONArray("history").length())
        assertNull(NativeGradeRefresh.parse(html,"20261003"))
        assertNull(NativeGradeRefresh.parse(html.replace("<td>등외</td>","<td>평균</td>"),"20261002"))
        assertNull(NativeGradeRefresh.parse("rate limited","20261002"))
    }
    @Test fun delayedGradeCannotReplaceNewerCache(){
        val latest=NativeGradeRefresh.parse(html.replace("2026-10-02","2026-10-05"),"20261005")!!
        val older=NativeGradeRefresh.parse(html,"20261002")!!
        assertEquals("20261005",org.json.JSONObject(NativeGradeRefresh.merge(latest.toString(),older,null)).getString("date"))
    }
}
