package kr.pigmarketbrief

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

private const val WIDGET_DATA_ROOT = "https://noah981.github.io/pig-market-brief/data"

class PigPriceWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id -> update(context, manager, id) }
    }
    private fun update(context: Context, manager: AppWidgetManager, id: Int) {
        val views=RemoteViews(context.packageName,R.layout.widget_pig_price)
        val intent=Intent(context,MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widgetRoot,PendingIntent.getActivity(context,0,intent,PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        views.setTextViewText(R.id.widgetPrice,"업데이트 중")
        manager.updateAppWidget(id,views)
        Thread {
            try {
                val client=OkHttpClient()
                fun get(name:String)=client.newCall(Request.Builder().url("$WIDGET_DATA_ROOT/$name").build()).execute().use{r->if(!r.isSuccessful)error("HTTP");r.body!!.string()}
                val p=JSONObject(get("pig-price.json"))
                val price=p.optInt("price")
                val diff=p.optInt("change"); val pm=p.optInt("previousMonthChange")
                val gd=JSONObject(get("pig-grade-detail.json")); val gp=gd.optJSONObject("prices"); val b=JSONObject(get("briefing.json")).optJSONArray("regions")
                var check="앱에서 오늘의 농장 체크 확인"
                if(b!=null) for(i in 0 until b.length()){
                    val x=b.getJSONObject(i)
                    if(x.optString("region")=="경상북도"){check=x.optJSONArray("top3")?.optString(0,check)?:check;break}
                }
                val nf=NumberFormat.getIntegerInstance(Locale.KOREA)
                views.setTextViewText(R.id.widgetPrice,if(price>0)nf.format(price)+" 원/kg" else "가격 확인 중")
                views.setTextViewText(R.id.widgetChange,"전일 "+(if(diff<0)"▼" else "▲")+nf.format(kotlin.math.abs(diff))+"원   ·   전월 "+(if(pm<0)"▼" else "▲")+nf.format(kotlin.math.abs(pm))+"원"); views.setTextViewText(R.id.widgetGrades,listOf("1+","1","2","등외").joinToString("   "){g->g+" "+(gp?.optInt(g,0)?.takeIf{x->x>0}?.let{nf.format(it)}?:"-")})
                views.setTextViewText(R.id.widgetCheck,"오늘 체크 · "+check)
            } catch(_:Exception) {
                views.setTextViewText(R.id.widgetPrice,"데이터 업데이트 지연")
                views.setTextViewText(R.id.widgetChange,"앱을 열어 다시 확인")
            }
            manager.updateAppWidget(id,views)
        }.start()
    }
}
