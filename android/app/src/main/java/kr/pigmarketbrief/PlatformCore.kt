package kr.pigmarketbrief

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.math.BigDecimal
import java.math.RoundingMode
import java.util.concurrent.TimeUnit

fun todayKorea():LocalDate=LocalDate.now(ZoneId.of("Asia/Seoul"))
fun parseDay(s:String):LocalDate?=try{LocalDate.parse(s,if(s.contains("-"))DateTimeFormatter.ISO_LOCAL_DATE else DateTimeFormatter.BASIC_ISO_DATE)}catch(_:Exception){null}
fun validDay(s:String)=parseDay(s)!=null
fun classifyCountry(code:String?):String=when{code=="KR"->"국내";code!=null&&code in java.util.Locale.getISOCountries()->"국외";else->"분류 확인 필요"}
fun priceStatus(p:PigPrice):String=when{p.price==null->"오늘 미확정 · 발표 대기";p.status.contains("미확정")->"미확정";parseDay(p.date)!=todayKorea()->"이전 기준일 데이터 · 오늘 발표 대기";p.status=="확정"||p.status=="오늘 확정"->"오늘 확정";else->"확정 여부 확인 필요"}
fun daysUntil(date:String,today:LocalDate=todayKorea()):Long?=parseDay(date)?.let{ChronoUnit.DAYS.between(today,it)}

data class Incentive(val name:String,val kind:String,val value:BigDecimal,val confirmed:Boolean)
data class Estimate(val base:BigDecimal,val extra:BigDecimal){val total:BigDecimal get()=base+extra}
fun estimate(heads:Int,weight:BigDecimal,price:BigDecimal,benefits:List<Incentive>,policy:String):Estimate{
 require(heads>0&&weight>BigDecimal.ZERO&&price>BigDecimal.ZERO)
 val base=weight*price*heads.toBigDecimal()
 val extras=benefits.filter{it.confirmed}.map{require(it.value>=BigDecimal.ZERO);when(it.kind){"%"->base*it.value/BigDecimal(100);"원/두"->it.value*heads.toBigDecimal();"원/kg"->it.value*weight*heads.toBigDecimal();else->it.value}}
 val extra=when(policy){"중복 가능"->extras.fold(BigDecimal.ZERO,BigDecimal::add);"가장 높은 혜택만"->extras.maxOrNull()?:BigDecimal.ZERO;else->extras.firstOrNull()?:BigDecimal.ZERO}
 return Estimate(base.setScale(0,RoundingMode.HALF_UP),extra.setScale(0,RoundingMode.HALF_UP))
}

data class StoredResponse(val raw:String?,val cached:Boolean)
object NetworkStore{
 val client=OkHttpClient.Builder().connectTimeout(5,TimeUnit.SECONDS).readTimeout(8,TimeUnit.SECONDS).callTimeout(12,TimeUnit.SECONDS).build()
 private const val ROOT="https://noah981.github.io/pig-market-brief/data"
 @Volatile var cacheOnly=false
 fun get(ctx:Context,name:String):StoredResponse{
  val prefs=ctx.getSharedPreferences("verified_feed_cache",Context.MODE_PRIVATE)
  val previous=prefs.getString(name,null)
  if(cacheOnly)return StoredResponse(previous,true)
  return try{
   val raw=client.newCall(Request.Builder().url("$ROOT/$name").build()).execute().use{require(it.isSuccessful);it.body?.string()?:error("empty")}
   val parsed=JSONObject(raw); require(!parsed.optBoolean("mock")&&!parsed.optBoolean("sample"));require(parsed.length()>0)
   when(name){"pig-price.json"->require(validDay(parsed.optString("date"))&&parsed.optInt("price")>0);"pig-price-history.json"->require(parsed.optJSONArray("rows")!=null);"disease-alerts.json"->require(parsed.optJSONArray("items")!=null)}
   prefs.edit().putString(name,raw).putLong("$name:checked",System.currentTimeMillis()).apply();StoredResponse(raw,false)
  }catch(_:Exception){StoredResponse(previous,true)}
 }
}

fun feedDue(last:String,cycle:Int,snooze:String?):LocalDate? {if(cycle !in 1..365)return null;return parseDay(snooze?:"")?:parseDay(last)?.plusDays(cycle.toLong())}
fun checkFeedReminder(ctx:Context){
 val p=ctx.getSharedPreferences("dondon_profile",Context.MODE_PRIVATE)
 if(!p.getBoolean("feed_alert",false))return
 val due=feedDue(p.getString("last_order","")?:"",p.getInt("order_cycle",0),p.getString("snooze",null))?:return
 if(due>todayKorea()||p.getString("feed_notified",null)==due.toString())return
 if(notify(ctx,"사료 주문하실 시기가 아닌가요?","평소 주문주기를 기준으로 알려드렸습니다. 주문 완료·3일 뒤 다시를 선택할 수 있어요.",3001))p.edit().putString("feed_notified",due.toString()).apply()
}
class FeedReminderWorker(ctx:Context,params:WorkerParameters):CoroutineWorker(ctx,params){override suspend fun doWork():Result{checkFeedReminder(applicationContext);return Result.success()}}
