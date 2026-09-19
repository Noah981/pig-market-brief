package kr.pigmarketbrief
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
class PigPriceWidget:AppWidgetProvider(){
 companion object{fun updateAll(context:Context){val manager=AppWidgetManager.getInstance(context);val ids=manager.getAppWidgetIds(android.content.ComponentName(context,PigPriceWidget::class.java));PigPriceWidget().onUpdate(context,manager,ids)}}
 override fun onUpdate(context:Context,manager:AppWidgetManager,ids:IntArray){val p=context.getSharedPreferences("todaypig",0);ids.forEach{id->val v=RemoteViews(context.packageName,R.layout.widget_pig_price);v.setOnClickPendingIntent(R.id.widgetRoot,PendingIntent.getActivity(context,0,Intent(context,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT));val price=p.getInt("widget_price",0);val diff=p.getInt("widget_change",0);v.setTextViewText(R.id.widgetPrice,if(price>0)"${comma(price)} 원/kg" else "공식 데이터 대기");v.setTextViewText(R.id.widgetChange,if(price>0)"직전 거래일 대비 ${if(diff>0)"▲" else if(diff<0)"▼" else "―"} ${comma(kotlin.math.abs(diff))}원" else "앱에서 새로고침");v.setTextViewText(R.id.widgetGrades,"기준일 ${formatDay(p.getString("widget_date","")?:"")}");v.setTextViewText(R.id.widgetCheck,"축산물품질평가원 · 마지막 저장값");manager.updateAppWidget(id,v)}}
}
