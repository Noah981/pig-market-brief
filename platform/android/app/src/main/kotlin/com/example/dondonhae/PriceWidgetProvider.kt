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
import java.util.concurrent.TimeUnit
import android.util.TypedValue
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager

private const val PRICE_URL="https://noah981.github.io/pig-market-brief/data/pig-price.json"
private const val PRICE_HISTORY_URL="https://noah981.github.io/pig-market-brief/data/pig-price-history.json"
private const val DISEASE_URL="https://noah981.github.io/pig-market-brief/data/disease-alerts.json"
private const val PREFS="dondonhae_price_widget"

object PriceWidgetStore{
 private fun prefs(c:Context)=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE)
 private fun ensureSeed(c:Context){
  val p=prefs(c);if(p.getInt("price",0)>0)return
  try{
   val json=JSONObject(c.resources.openRawResource(R.raw.dondonhae_price_seed).bufferedReader().use{it.readText()})
   val price=json.optInt("price",0);val previous=json.optInt("previousPrice",0);val date=json.optString("date","")
   if(price>0&&previous>0&&date.length==8){val rows=json.optJSONArray("history");val history=if(rows==null)"" else (0 until rows.length()).mapNotNull{rows.optInt(it).takeIf{x->x>0}}.takeLast(7).joinToString(",");p.edit().putInt("price",price).putInt("previousPrice",previous).putInt("change",price-previous).putString("date",date).putString("price_key","$date|$price").apply{if(history.isNotEmpty())putString("history",history)}.apply()}
  }catch(_:Exception){}
 }
 fun saveAndRender(c:Context,args:Map<*,*>?){
  val price=(args?.get("price") as? Number)?.toInt()?:return
  if(price<=0)return
  val date=args["date"]?.toString()?:"";val stored=prefs(c).getString("date","")?:""
  // 앱의 오래된 캐시가 백그라운드에서 받은 최신 위젯 값을 되돌리지 않게 한다.
  if(date.length==8&&stored.length==8&&date<stored){render(c);return}
  val history=(args["history"] as? List<*>)?.mapNotNull{(it as? Number)?.toInt()}?.filter{it>0}?.takeLast(7)?.joinToString(",")
  prefs(c).edit().putInt("price",price).putInt("previousPrice",(args["previousPrice"] as? Number)?.toInt()?:0).putInt("change",(args["change"] as? Number)?.toInt()?:0).putString("date",date).putString("price_key","$date|$price").apply{if(!history.isNullOrEmpty())putString("history",history)}.apply()
  render(c)
 }
 fun fetch(c:Context){
  try{
   val connection=(URL(PRICE_URL+"?v="+System.currentTimeMillis()).openConnection() as HttpURLConnection).apply{connectTimeout=12000;readTimeout=12000;requestMethod="GET"}
   if(connection.responseCode!=200)return
   val json=JSONObject(connection.inputStream.bufferedReader().use{it.readText()})
   val price=json.optInt("price",0);val previous=json.optInt("previousPrice",0);val date=json.optString("date","")
   if(price<=0||previous<=0||date.length!=8)return
   val change=price-previous;val key="$date|$price";val p=prefs(c);val oldKey=p.getString("price_key","")
   val history=fetchHistory()
   p.edit().putInt("price",price).putInt("previousPrice",previous).putInt("change",change).putString("date",date).putString("price_key",key).apply{if(history.isNotEmpty())putString("history",history.joinToString(","))}.apply()
   render(c)
   if(oldKey!=null&&oldKey.isNotEmpty()&&oldKey!=key)notifyPrice(c,price,change,date,key)
  }catch(_:Exception){}
 }
 fun render(c:Context){
  ensureSeed(c);val p=prefs(c);val price=p.getInt("price",0);if(price<=0)return
  val change=p.getInt("change",0);val date=p.getString("date","")?:"";val history=p.getString("history","")?.split(",")?.mapNotNull{it.toIntOrNull()}?.filter{it>0}?:emptyList();val manager=AppWidgetManager.getInstance(c)
  val small=manager.getAppWidgetIds(ComponentName(c,PriceWidgetSmallProvider::class.java));for(id in small)manager.updateAppWidget(id,views(c,R.layout.widget_price_small,price,change,date,history,false,manager.getAppWidgetOptions(id)))
  val wide=manager.getAppWidgetIds(ComponentName(c,PriceWidgetWideProvider::class.java));for(id in wide)manager.updateAppWidget(id,views(c,R.layout.widget_price_wide,price,change,date,history,true,manager.getAppWidgetOptions(id)))
 }
 private fun views(c:Context,layout:Int,price:Int,change:Int,date:String,history:List<Int>,wide:Boolean,options:android.os.Bundle)=RemoteViews(c.packageName,layout).apply{
  val minWidth=options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,if(wide)280 else 150);val minHeight=options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,if(wide)110 else 150);val compact=wide&&(minWidth<330||minHeight<125)
  setTextViewText(R.id.widget_price,NumberFormat.getNumberInstance(Locale.KOREA).format(price)+"원")
  setTextViewText(R.id.widget_change,(if(change>=0)"▲ " else "▼ ")+NumberFormat.getNumberInstance(Locale.KOREA).format(kotlin.math.abs(change))+"원")
  setTextColor(R.id.widget_change,Color.parseColor(if(change>=0)"#F72F62" else "#1677E8"))
  setTextViewText(R.id.widget_date,dateLabel(date))
  setOnClickPendingIntent(R.id.widget_root,openPrice(c))
  setViewPadding(R.id.widget_root,dp(c,if(compact)14 else 16),dp(c,if(compact)12 else 16),dp(c,if(compact)14 else 16),dp(c,if(compact)12 else 16))
  setTextViewTextSize(R.id.widget_price,TypedValue.COMPLEX_UNIT_DIP,(if(wide){if(compact)36 else 43}else 29).toFloat())
  setTextViewTextSize(R.id.widget_change,TypedValue.COMPLEX_UNIT_DIP,(if(wide){if(compact)16 else 18}else 13).toFloat())
  setTextViewTextSize(R.id.widget_date,TypedValue.COMPLEX_UNIT_DIP,(if(wide)10 else 9).toFloat())
  if(wide){setTextViewTextSize(R.id.widget_title,TypedValue.COMPLEX_UNIT_DIP,(if(compact)16 else 18).toFloat());setTextViewTextSize(R.id.widget_change_basis,TypedValue.COMPLEX_UNIT_DIP,(if(compact)10 else 12).toFloat());setTextViewTextSize(R.id.widget_tagline,TypedValue.COMPLEX_UNIT_DIP,(if(compact)9 else 10).toFloat());setImageViewBitmap(R.id.widget_sparkline,sparkline(history,change))}
 }
 private fun dp(c:Context,value:Int)=(value*c.resources.displayMetrics.density).toInt()
 private fun openPrice(c:Context):PendingIntent{val i=Intent(c,MainActivity::class.java).putExtra("open_price",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP);return PendingIntent.getActivity(c,4101,i,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)}
 private fun dateLabel(date:String):String{if(date.length!=8)return "마지막 확인 기준";return try{val cal=Calendar.getInstance().apply{set(date.substring(0,4).toInt(),date.substring(4,6).toInt()-1,date.substring(6,8).toInt())};val weekdays=arrayOf("일","월","화","수","목","금","토");"${date.substring(4,6)}. ${date.substring(6,8)}. (${weekdays[cal.get(Calendar.DAY_OF_WEEK)-1]}) 기준"}catch(_:Exception){"${date.substring(4,6)}.${date.substring(6,8)}. 기준"}}
 private fun fetchHistory():List<Int>{return try{val connection=(URL(PRICE_HISTORY_URL+"?v="+System.currentTimeMillis()).openConnection() as HttpURLConnection).apply{connectTimeout=12000;readTimeout=12000;requestMethod="GET"};if(connection.responseCode!=200)return emptyList();val rows=JSONObject(connection.inputStream.bufferedReader().use{it.readText()}).optJSONArray("rows")?:return emptyList();val result=mutableListOf<Pair<String,Int>>();for(i in 0 until rows.length()){val x=rows.optJSONObject(i)?:continue;if(x.optBoolean("verified",false)&&x.optString("resolution","day")!="month"&&x.optString("date").length==8&&x.optInt("price")>0)result.add(x.optString("date") to x.optInt("price"))};result.sortedBy{it.first}.takeLast(7).map{it.second}}catch(_:Exception){emptyList()}}
 private fun sparkline(history:List<Int>,change:Int):Bitmap{val b=Bitmap.createBitmap(244,120,Bitmap.Config.ARGB_8888);val canvas=Canvas(b);val line=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.parseColor("#F45B68");strokeWidth=6f;style=Paint.Style.STROKE;strokeCap=Paint.Cap.ROUND;strokeJoin=Paint.Join.ROUND};val fill=Paint(Paint.ANTI_ALIAS_FLAG).apply{shader=LinearGradient(0f,25f,0f,112f,Color.parseColor("#42F45B68"),Color.TRANSPARENT,Shader.TileMode.CLAMP);style=Paint.Style.FILL};val values=if(history.size>=2)history.map{it.toFloat()}else listOf(6400f,(6400+change).toFloat());val low=values.minOrNull()?:0f;val high=values.maxOrNull()?:1f;val range=(high-low).coerceAtLeast(1f);val ys=values.map{100f-(it-low)/range*72f};val step=220f/(ys.size-1);val path=Path();ys.forEachIndexed{i,y->val x=12f+i*step;if(i==0)path.moveTo(x,y)else path.lineTo(x,y)};val area=Path(path).apply{lineTo(232f,112f);lineTo(12f,112f);close()};canvas.drawPath(area,fill);canvas.drawPath(path,line);val dot=Paint(Paint.ANTI_ALIAS_FLAG).apply{color=Color.parseColor("#F45B68");style=Paint.Style.FILL};ys.forEachIndexed{i,y->canvas.drawCircle(12f+i*step,y,7f,dot)};return b}
 private fun notifyPrice(c:Context,price:Int,change:Int,date:String,key:String){val p=prefs(c);if(p.getString("notified_key","")==key)return;val previous=p.getInt("previousPrice",0);val pct=if(previous>0)change.toDouble()/previous*100 else 0.0;val nm=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager;if(Build.VERSION.SDK_INT>=26)nm.createNotificationChannel(NotificationChannel("pig_price","돈가 업데이트",NotificationManager.IMPORTANCE_HIGH));val body="${NumberFormat.getNumberInstance(Locale.KOREA).format(price)}원/kg · ${if(change>=0)"▲" else "▼"} ${kotlin.math.abs(change)}원 (${String.format(Locale.KOREA,"%.1f",pct)}%)";val dateText=if(date.length==8)"${date.substring(4,6)}월 ${date.substring(6,8)}일 기준" else "최근 확정 기준";val n=if(Build.VERSION.SDK_INT>=26)Notification.Builder(c,"pig_price") else Notification.Builder(c);n.setSmallIcon(R.mipmap.ic_launcher).setContentTitle("돈돈해 | 오늘의 전국 돈가").setContentText(body).setStyle(Notification.BigTextStyle().bigText("$body\n$dateText\n오늘 시황을 확인하세요.")).setContentIntent(openPrice(c)).setAutoCancel(true);nm.notify(key.hashCode(),n.build());p.edit().putString("notified_key",key).apply()}
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
 private fun notify(c:Context,x:JSONObject,key:String){val nm=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager;if(Build.VERSION.SDK_INT>=26)nm.createNotificationChannel(NotificationChannel("disease","질병 알림",NotificationManager.IMPORTANCE_HIGH));val disease=x.optString("disease","가축질병");val region=x.optString("region","국내");val intent=Intent(c,MainActivity::class.java).putExtra("open_disease",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP);val pending=PendingIntent.getActivity(c,4201,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE);val n=if(Build.VERSION.SDK_INT>=26)Notification.Builder(c,"disease") else Notification.Builder(c);n.setSmallIcon(R.mipmap.ic_launcher).setContentTitle("돈돈해 | 국내 신규 질병정보").setContentText("${region}에서 $disease 공식 발생정보가 확인됐습니다.").setStyle(Notification.BigTextStyle().bigText("${region}에서 $disease 공식 발생정보가 확인됐습니다.\n공식 원문과 방역지침을 확인하세요.")).setContentIntent(pending).setAutoCancel(true);nm.notify(key.hashCode(),n.build())}
}

abstract class BasePriceWidgetProvider:AppWidgetProvider(){override fun onUpdate(c:Context,m:AppWidgetManager,ids:IntArray){PriceUpdateScheduler.schedule(c);PriceWidgetStore.render(c);asyncFetch(c)}override fun onEnabled(c:Context){PriceUpdateScheduler.schedule(c);PriceWidgetStore.render(c);asyncFetch(c)}override fun onAppWidgetOptionsChanged(c:Context,m:AppWidgetManager,id:Int,options:android.os.Bundle){PriceWidgetStore.render(c)}override fun onReceive(c:Context,i:Intent){super.onReceive(c,i);if(i.action==Intent.ACTION_CONFIGURATION_CHANGED)PriceWidgetStore.render(c)}private fun asyncFetch(c:Context){val pending=goAsync();Thread{try{PriceWidgetStore.fetch(c.applicationContext)}finally{pending.finish()}}.start()}}
class PriceWidgetSmallProvider:BasePriceWidgetProvider()
class PriceWidgetWideProvider:BasePriceWidgetProvider()
class PriceUpdateReceiver:BroadcastReceiver(){override fun onReceive(c:Context,i:Intent){val pending=goAsync();Thread{try{PriceWidgetStore.fetch(c.applicationContext);DiseaseAlertStore.fetch(c.applicationContext)}finally{pending.finish()}}.start()}}
class PriceBootReceiver:BroadcastReceiver(){override fun onReceive(c:Context,i:Intent){PriceUpdateScheduler.schedule(c);PriceWidgetStore.render(c)}}
object PriceUpdateScheduler{fun schedule(c:Context){val constraints=Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build();val request=PeriodicWorkRequest.Builder(DataRefreshWorker::class.java,30,TimeUnit.MINUTES).setConstraints(constraints).build();WorkManager.getInstance(c).enqueueUniquePeriodicWork("dondonhae_data_refresh",ExistingPeriodicWorkPolicy.UPDATE,request)}}
