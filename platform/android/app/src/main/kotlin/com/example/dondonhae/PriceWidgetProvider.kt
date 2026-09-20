package com.example.dondonhae

import android.app.*
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.*
import android.graphics.*
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale

private const val PRICE_URL="https://noah981.github.io/pig-market-brief/data/pig-price.json"
private const val DISEASE_URL="https://noah981.github.io/pig-market-brief/data/disease-alerts.json"
private const val PREFS="dondonhae_price_widget"

object PriceWidgetStore{
 private fun prefs(c:Context)=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE)
 private fun ensureSeed(c:Context){
  val p=prefs(c);if(p.getInt("price",0)>0)return
  try{
   val json=JSONObject(c.resources.openRawResource(R.raw.dondonhae_price_seed).bufferedReader().use{it.readText()})
   val price=json.optInt("price",0);val previous=json.optInt("previousPrice",0);val date=json.optString("date","")
   if(price>0&&previous>0&&date.length==8)p.edit().putInt("price",price).putInt("previousPrice",previous).putInt("change",json.optInt("change",price-previous)).putString("date",date).putString("price_key","$date|$price").apply()
  }catch(_:Exception){}
 }
 fun saveAndRender(c:Context,args:Map<*,*>?){
  val price=(args?.get("price") as? Number)?.toInt()?:return
  if(price<=0)return
  val date=args["date"]?.toString()?:"";val stored=prefs(c).getString("date","")?:""
  // 앱의 오래된 캐시가 백그라운드에서 받은 최신 위젯 값을 되돌리지 않게 한다.
  if(date.length==8&&stored.length==8&&date<stored){render(c);return}
  prefs(c).edit().putInt("price",price).putInt("previousPrice",(args["previousPrice"] as? Number)?.toInt()?:0).putInt("change",(args["change"] as? Number)?.toInt()?:0).putString("date",date).putString("price_key","$date|$price").apply()
  render(c)
 }
 fun fetch(c:Context){
  try{
   val connection=(URL(PRICE_URL+"?v="+System.currentTimeMillis()).openConnection() as HttpURLConnection).apply{connectTimeout=12000;readTimeout=12000;requestMethod="GET"}
   if(connection.responseCode!=200)return
   val json=JSONObject(connection.inputStream.bufferedReader().use{it.readText()})
   val price=json.optInt("price",0);val previous=json.optInt("previousPrice",0);val date=json.optString("date","")
   if(price<=0||previous<=0||date.length!=8)return
   val change=json.optInt("change",price-previous);val key="$date|$price";val p=prefs(c);val oldKey=p.getString("price_key","")
   p.edit().putInt("price",price).putInt("previousPrice",previous).putInt("change",change).putString("date",date).putString("price_key",key).apply()
   render(c)
   if(oldKey!=null&&oldKey.isNotEmpty()&&oldKey!=key)notifyPrice(c,price,change,date,key)
  }catch(_:Exception){}
 }
 fun render(c:Context){
  ensureSeed(c);val p=prefs(c);val price=p.getInt("price",0);if(price<=0)return
  val change=p.getInt("change",0);val date=p.getString("date","")?:"";val manager=AppWidgetManager.getInstance(c)
  val small=manager.getAppWidgetIds(ComponentName(c,PriceWidgetSmallProvider::class.java));if(small.isNotEmpty())manager.updateAppWidget(small,views(c,R.layout.widget_price_small,price,change,date,false))
  val wide=manager.getAppWidgetIds(ComponentName(c,PriceWidgetWideProvider::class.java));if(wide.isNotEmpty())manager.updateAppWidget(wide,views(c,R.layout.widget_price_wide,price,change,date,true))
 }
 private fun views(c:Context,layout:Int,price:Int,change:Int,date:String,wide:Boolean)=RemoteViews(c.packageName,layout).apply{
  setTextViewText(R.id.widget_price,NumberFormat.getNumberInstance(Locale.KOREA).format(price)+"원")
  setTextViewText(R.id.widget_change,(if(change>=0)"▲ " else "▼ ")+NumberFormat.getNumberInstance(Locale.KOREA).format(kotlin.math.abs(change))+"원")
  setTextColor(R.id.widget_change,Color.parseColor(if(change>=0)"#F72F62" else "#1677E8"))
  setTextViewText(R.id.widget_date,dateLabel(date))
  setOnClickPendingIntent(R.id.widget_root,openPrice(c))
  if(wide)setImageViewBitmap(R.id.widget_sparkline,sparkline(change))
 }
 private fun openPrice(c:Context):PendingIntent{val i=Intent(c,MainActivity::class.java).putExtra("open_price",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP);return PendingIntent.getActivity(c,4101,i,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)}
 private fun dateLabel(date:String):String{if(date.length!=8)return "마지막 확인 기준";return try{val cal=Calendar.getInstance().apply{set(date.substring(0,4).toInt(),date.substring(4,6).toInt()-1,date.substring(6,8).toInt())};val weekdays=arrayOf("일","월","화","수","목","금","토");"${date.substring(4,6)}. ${date.substring(6,8)}. (${weekdays[cal.get(Calendar.DAY_OF_WEEK)-1]}) 기준"}catch(_:Exception){"${date.substring(4,6)}.${date.substring(6,8)}. 기준"}}
 private fun sparkline(change:Int):Bitmap{val b=Bitmap.createBitmap(244,120,Bitmap.Config.ARGB_8888);val canvas=Canvas(b);val line=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.parseColor("#F45B68");strokeWidth=6f;style=Paint.Style.STROKE;strokeCap=Paint.Cap.ROUND;strokeJoin=Paint.Join.ROUND};val fill=Paint(Paint.ANTI_ALIAS_FLAG).apply{shader=LinearGradient(0f,25f,0f,112f,Color.parseColor("#42F45B68"),Color.TRANSPARENT,Shader.TileMode.CLAMP);style=Paint.Style.FILL};val ys=if(change>=0)floatArrayOf(90f,43f,62f,48f,78f,39f) else floatArrayOf(82f,43f,62f,48f,67f,39f);val path=Path();ys.forEachIndexed{i,y->val x=12f+i*43f;if(i==0)path.moveTo(x,y) else path.lineTo(x,y)};val area=Path(path).apply{lineTo(227f,112f);lineTo(12f,112f);close()};canvas.drawPath(area,fill);canvas.drawPath(path,line);val dot=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.parseColor("#F45B68");style=Paint.Style.FILL};ys.forEachIndexed{i,y->canvas.drawCircle(12f+i*43f,y,7f,dot)};return b}
 private fun notifyPrice(c:Context,price:Int,change:Int,date:String,key:String){val p=prefs(c);if(p.getString("notified_key","")==key)return;val nm=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager;if(Build.VERSION.SDK_INT>=26)nm.createNotificationChannel(NotificationChannel("pig_price","돈가 업데이트",NotificationManager.IMPORTANCE_HIGH));val body="${NumberFormat.getNumberInstance(Locale.KOREA).format(price)}원/kg · 전일 대비 ${if(change>=0)"▲" else "▼"} ${kotlin.math.abs(change)}원";val n=if(Build.VERSION.SDK_INT>=26)Notification.Builder(c,"pig_price") else Notification.Builder(c);n.setSmallIcon(R.mipmap.ic_launcher).setContentTitle("돈돈해 | 오늘의 돈가").setContentText(body).setStyle(Notification.BigTextStyle().bigText("오늘 전국 돈가가 업데이트되었습니다.\n$body\n눌러서 오늘의 돈가 흐름을 확인하세요.")).setContentIntent(openPrice(c)).setAutoCancel(true);nm.notify(6442,n.build());p.edit().putString("notified_key",key).apply()}
}

object DiseaseAlertStore{
 private const val PREFS_NAME="dondonhae_disease_alerts"
 fun fetch(c:Context){
  try{
   val connection=(URL(DISEASE_URL+"?v="+System.currentTimeMillis()).openConnection() as HttpURLConnection).apply{connectTimeout=12000;readTimeout=12000;requestMethod="GET"}
   if(connection.responseCode!=200)return
   val root=JSONObject(connection.inputStream.bufferedReader().use{it.readText()});val rows=root.optJSONArray("items")?:JSONArray();val current=linkedSetOf<String>();val official=mutableListOf<JSONObject>()
   for(i in 0 until rows.length()){val x=rows.optJSONObject(i)?:continue;if(x.optString("countryCode")!="KR"||x.optString("evidenceLevel")!="OFFICIAL")continue;val key=listOf(x.optString("disease"),x.optString("region"),x.optString("publishedAt"),x.optString("sourceUrl")).joinToString("|");if(key.replace("|","").isEmpty())continue;current.add(key);official.add(x)}
   val prefs=c.getSharedPreferences(PREFS_NAME,Context.MODE_PRIVATE);val initialized=prefs.getBoolean("initialized",false);val previous=prefs.getStringSet("known",emptySet())?:emptySet()
   if(initialized){for(x in official){val key=listOf(x.optString("disease"),x.optString("region"),x.optString("publishedAt"),x.optString("sourceUrl")).joinToString("|");if(!previous.contains(key))notify(c,x,key)}}
   prefs.edit().putBoolean("initialized",true).putStringSet("known",current).putString("updated_at",root.optString("updatedAt")).apply()
  }catch(_:Exception){}
 }
 private fun notify(c:Context,x:JSONObject,key:String){val nm=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager;if(Build.VERSION.SDK_INT>=26)nm.createNotificationChannel(NotificationChannel("disease","질병 알림",NotificationManager.IMPORTANCE_HIGH));val disease=x.optString("disease","가축질병");val region=x.optString("region","국내");val intent=Intent(c,MainActivity::class.java).putExtra("open_disease",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP);val pending=PendingIntent.getActivity(c,4201,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE);val n=if(Build.VERSION.SDK_INT>=26)Notification.Builder(c,"disease") else Notification.Builder(c);n.setSmallIcon(R.mipmap.ic_launcher).setContentTitle("돈돈해 | 국내 신규 질병정보").setContentText("$region에서 $disease 공식 발생정보가 확인됐습니다.").setStyle(Notification.BigTextStyle().bigText("$region에서 $disease 공식 발생정보가 확인됐습니다.\n공식 원문과 방역지침을 확인하세요.")).setContentIntent(pending).setAutoCancel(true);nm.notify(key.hashCode(),n.build())}
}

abstract class BasePriceWidgetProvider:AppWidgetProvider(){override fun onUpdate(c:Context,m:AppWidgetManager,ids:IntArray){PriceUpdateScheduler.schedule(c);PriceWidgetStore.render(c);asyncFetch(c)}override fun onEnabled(c:Context){PriceUpdateScheduler.schedule(c);PriceWidgetStore.render(c);asyncFetch(c)}override fun onAppWidgetOptionsChanged(c:Context,m:AppWidgetManager,id:Int,options:android.os.Bundle){PriceWidgetStore.render(c)}private fun asyncFetch(c:Context){val pending=goAsync();Thread{try{PriceWidgetStore.fetch(c.applicationContext)}finally{pending.finish()}}.start()}}
class PriceWidgetSmallProvider:BasePriceWidgetProvider()
class PriceWidgetWideProvider:BasePriceWidgetProvider()
class PriceUpdateReceiver:BroadcastReceiver(){override fun onReceive(c:Context,i:Intent){val pending=goAsync();Thread{try{PriceWidgetStore.fetch(c.applicationContext);DiseaseAlertStore.fetch(c.applicationContext)}finally{pending.finish()}}.start()}}
class PriceBootReceiver:BroadcastReceiver(){override fun onReceive(c:Context,i:Intent){PriceUpdateScheduler.schedule(c);PriceWidgetStore.render(c)}}
object PriceUpdateScheduler{fun schedule(c:Context){val alarm=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager;val intent=PendingIntent.getBroadcast(c,4102,Intent(c,PriceUpdateReceiver::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE);alarm.setInexactRepeating(AlarmManager.ELAPSED_REALTIME_WAKEUP,android.os.SystemClock.elapsedRealtime()+60_000,15*60_000L,intent)}}
