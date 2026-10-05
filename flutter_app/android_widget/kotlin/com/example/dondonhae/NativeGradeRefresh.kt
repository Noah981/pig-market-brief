package com.example.dondonhae

import org.json.JSONObject
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

/** Uses the same nationwide/Jeju-excluded official table as the app. */
object NativeGradeRefresh {
    private val grades=listOf("1+","1","2","등외")
    internal fun parse(html:String,requestedDate:String):JSONObject? {
        val table=Regex("""<table[^>]*id=["']table-type1["'][^>]*>([\s\S]*?)</table>""",RegexOption.IGNORE_CASE).find(html)?.groupValues?.get(1) ?: return null
        val actual=Regex("""name=["']searchStartDate["'][^>]*value=["'](\d{4})-(\d{2})-(\d{2})["']""",RegexOption.IGNORE_CASE).find(html)
        val date=actual?.let{it.groupValues[1]+it.groupValues[2]+it.groupValues[3]} ?: requestedDate
        if(date!=requestedDate)return null
        val rows=JSONArray()
        for(tr in Regex("<tr[^>]*>([\\s\\S]*?)</tr>",RegexOption.IGNORE_CASE).findAll(table)) {
            val cells=Regex("<t[hd][^>]*>([\\s\\S]*?)</t[hd]>",RegexOption.IGNORE_CASE).findAll(tr.groupValues[1]).map{it.groupValues[1].replace(Regex("<[^>]+>"),"").replace("&nbsp;"," ").trim()}.toMutableList()
            if(cells.firstOrNull()=="등급")cells.removeAt(0)
            if(cells.size<3||cells[0] !in grades)continue
            val count=cells[1].replace(",","").toDoubleOrNull() ?: continue
            val price=cells[2].replace(",","").toDoubleOrNull() ?: continue
            if(price>0&&price.isFinite()&&count>0)rows.put(JSONObject().put("grade",cells[0]).put("date",date).put("price",price).put("count",count).put("sex","all"))
        }
        if(rows.length()!=4)return null
        return JSONObject().put("date",date).put("history",rows)
    }
    fun fetch(date:String):JSONObject? {
        if(!date.matches(Regex("[0-9]{8}")))return null
        val d="${date.substring(0,4)}-${date.substring(4,6)}-${date.substring(6,8)}"
        val url="https://www.ekapepia.com/v3/price/auction/period/pig/detail.do?searchStartDate=$d&searchEndDate=$d&searchCondition=057016&searchCondition1=Y&searchCondition2="
        val connection=URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout=12000;connection.readTimeout=12000;connection.setRequestProperty("User-Agent","DonDonHae/1.8.9");connection.setRequestProperty("Accept","text/html")
        return try{if(connection.responseCode==200)parse(connection.inputStream.bufferedReader(Charsets.UTF_8).use{it.readText()},date)else null}finally{connection.disconnect()}
    }
    internal fun merge(stored:String?,current:JSONObject,previous:JSONObject?):String {
        val old=try{JSONObject(stored ?: "{}")}catch(_:Exception){JSONObject()}
        val date=current.getString("date")
        if(old.optString("date")>date)return old.toString()
        val byKey=linkedMapOf<String,JSONObject>()
        for(array in listOf(old.optJSONArray("history"),previous?.optJSONArray("history"),current.optJSONArray("history"))){
            for(i in 0 until (array?.length() ?: 0)){val row=array?.optJSONObject(i) ?: continue;byKey[row.optString("date")+":"+row.optString("grade")]=row}
        }
        old.put("date",date);old.put("history",JSONArray(byKey.values.sortedWith(compareBy({it.optString("date")},{it.optString("grade")}))))
        return old.toString()
    }
}
