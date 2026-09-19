package kr.pigmarketbrief

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.content.Intent
import android.location.Geocoder
import android.location.LocationManager
import android.os.CancellationSignal
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.Cache
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.NumberFormat
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.roundToInt

private const val DATA_ROOT="https://noah981.github.io/pig-market-brief/data"
private val Ink=Color(0xFF171719);private val Forest=Color(0xFF17634C);private val Mint=Color(0xFFE2F1E8);private val Paper=Color(0xFFF5F5F7);private val Amber=Color(0xFFFF9F0A);private val Blue=Color(0xFF0A84FF);private val Red=Color(0xFFFF453A)
fun comma(v:Int)=NumberFormat.getIntegerInstance(Locale.KOREA).format(v)

data class PigPrice(val date:String="",val price:Int?=null,val previous:Int?=null,val change:Int?=null,val changePct:Double?=null,val monthAverage:Int?=null,val previousMonth:Int?=null,val lastYearMonth:Int?=null,val status:String="집계중",val updatedAt:String="",val previousDate:String="",val basis:String="기준 확인 필요")
data class HistPoint(val date:String,val price:Int,val resolution:String="day")
data class RegionBrief(val name:String,val min:Double?,val max:Double?,val humidity:Double?,val rain:Double?,val risks:List<String>,val checks:List<String>)
data class DiseaseAlert(val disease:String,val source:String,val level:EvidenceLevel,val summary:String,val url:String,val scope:String,val countryCode:String?=null)
data class GradePrice(val grade:String,val price:Int?)
data class AppData(val pig:PigPrice=PigPrice(),val history:List<HistPoint> = emptyList(),val regions:List<RegionBrief> = emptyList(),val diseases:List<DiseaseAlert> = emptyList(),val grades:List<GradePrice> = emptyList(),val jeju:List<Triple<String,String,String>> = emptyList(),val stale:Boolean=false,val error:String?=null)
data class FarmRecord(val at:String,val stage:String,val weight:Double?,val days:Int?,val fcr:Double?,val mortality:Double?,val intake:Double?,val symptom:String,val action:String,val result:String)

object DataRepository{
 suspend fun load(ctx:Context):AppData=withContext(Dispatchers.IO){
  val client=NetworkStore.client
  var usedCache=false
  fun get(name:String):String? { val result=NetworkStore.get(ctx,name); if(result.cached)usedCache=true; return result.raw }

  val priceRaw=get("pig-price.json");val historyRaw=get("pig-price-history.json");val briefRaw=get("briefing.json");val diseaseRaw=get("disease-alerts.json");val gradeRaw=get("pig-grade-detail.json");val jejuRaw=get("kape-jeju.json")
  if(priceRaw==null&&historyRaw==null)return@withContext AppData(error="공식 데이터 서버에 연결할 수 없습니다. 저장된 기록은 계속 사용할 수 있습니다.")
  try{
   val p=JSONObject(priceRaw?:"{}")
   fun pos(name:String)=p.optInt(name,0).takeIf{it>0}
   val pig=PigPrice(p.optString("date"),pos("price"),pos("previousPrice"),if(p.has("change"))p.optInt("change") else null,if(p.has("changePct"))p.optDouble("changePct") else null,pos("monthAverage"),pos("previousMonthAverage"),pos("lastYearMonthAverage"),p.optString("displayStatus",p.optString("status","집계중")),p.optString("updatedAt"),p.optString("previousDate"),p.optString("scope","기준 확인 필요"))
   val hs=mutableListOf<HistPoint>();JSONObject(historyRaw?:"{}").optJSONArray("rows")?.let{a->for(i in 0 until a.length()){val x=a.getJSONObject(i);if(x.optInt("price")>0 && validDay(x.optString("date")))hs+=HistPoint(x.optString("date"),x.optInt("price"),x.optString("resolution","day"))}}
   val rs=mutableListOf<RegionBrief>()
   JSONObject(briefRaw?:"{}").optJSONArray("regions")?.let{a->for(i in 0 until a.length()){
    val x=a.getJSONObject(i)
    fun arr(name:String)=x.optJSONArray(name)?.let{z->List(z.length()){j->z.optString(j)}}?: emptyList()
    fun number(name:String)=x.optDouble(name).takeUnless{it.isNaN()}
    rs+=RegionBrief(x.optString("region"),number("tempMin"),number("tempMax"),number("humidityMax"),number("rainProbabilityMax"),arr("riskFactors"),arr("top3"))
   }}
   val ds=mutableListOf<DiseaseAlert>();JSONObject(diseaseRaw?:"{}").optJSONArray("items")?.let{a->for(i in 0 until a.length()){val x=a.getJSONObject(i);val raw=x.optString("evidenceLevel",x.optString("level"));val lv=when{raw.contains("공식")||raw=="OFFICIAL"->EvidenceLevel.OFFICIAL;raw.contains("관찰")->EvidenceLevel.FARM_OBSERVATION;else->EvidenceLevel.PUBLIC_UNCONFIRMED};val code=x.optString("countryCode").trim().uppercase(Locale.ROOT).takeIf{it in Locale.getISOCountries()};val strictScope=classifyCountry(code);ds+=DiseaseAlert(x.optString("disease"),x.optString("source"),lv,x.optString("summary"),x.optString("sourceUrl"),strictScope,code)}}
   val gs=mutableListOf<GradePrice>();val go=JSONObject(gradeRaw?:"{}").optJSONObject("prices");go?.keys()?.forEachRemaining{k->gs+=GradePrice(k,go.optDouble(k).roundToInt().takeIf{it>0})}
   val js=mutableListOf<Triple<String,String,String>>();JSONObject(jejuRaw?:"{}").optJSONArray("rows")?.let{a->for(i in 0 until a.length()){val x=a.getJSONObject(i);js+=Triple(x.optString("gradeName"),x.optString("publicTotPrice","집계중"),x.optString("blackTotPrice","집계중"))}}
   ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE).edit().putInt("widget_price",pig.price?:0).putInt("widget_change",pig.change?:0).putString("widget_date",pig.date).putLong("last_success",System.currentTimeMillis()).apply()
   PigPriceWidget.updateAll(ctx)
   AppData(pig,hs.sortedBy{it.date},rs,ds,gs,js,stale=usedCache,error=if(usedCache)"마지막 저장 데이터 · 일부 연결 지연" else null)
  }catch(e:Exception){AppData(error="데이터 형식을 확인하는 중 문제가 생겼습니다: ${e.message}")}
 }
}

class MainActivity:ComponentActivity(){
 override fun onCreate(savedInstanceState:Bundle?){
  super.onCreate(savedInstanceState)
  scheduleBackgroundSync(this)
  setContent { DondonTheme { DondonApp() } }
 }
}
@Composable fun TodayPigTheme(content: @Composable () -> Unit){
 val dark=isSystemInDarkTheme()
 MaterialTheme(colorScheme=if(dark) darkColorScheme(primary=Color(0xFF64A6FF),secondary=Color(0xFFFFB340),background=Color(0xFF0F1012),surface=Color(0xFF1C1C1E),onSurface=Color(0xFFF5F5F7),error=Color(0xFFFF6961)) else lightColorScheme(primary=Forest,onPrimary=Color.White,secondary=Amber,background=Paper,surface=Color.White,onSurface=Ink,error=Red),content=content)
}

@Composable fun TodayPigApp(){
 val ctx=LocalContext.current;val scope=rememberCoroutineScope();val prefs=remember{ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE)};var tab by remember{mutableIntStateOf(0)};var data by remember{mutableStateOf<AppData?>(null)};var loading by remember{mutableStateOf(true)};var refreshMessage by remember{mutableStateOf<String?>(null)};var region by remember{mutableStateOf(prefs.getString("region","경상북도")?:"경상북도")}
 suspend fun refresh(){if(loading&&data!=null)return;loading=true;val next=DataRepository.load(ctx);data=next;loading=false;refreshMessage=if(next.error==null)"최신 데이터로 갱신되었습니다" else "갱신하지 못했습니다 · 네트워크를 확인하세요"}
 LaunchedEffect(Unit){refresh()}
 Scaffold(containerColor=MaterialTheme.colorScheme.background,floatingActionButton={ExtendedFloatingActionButton(onClick={if(!loading)scope.launch{refresh()}},containerColor=MaterialTheme.colorScheme.onSurface,contentColor=MaterialTheme.colorScheme.surface,shape=RoundedCornerShape(18.dp),icon={if(loading)CircularProgressIndicator(Modifier.size(18.dp),strokeWidth=2.dp)else Text("↻",fontSize=20.sp)},text={Text(if(loading)"갱신 중" else "새로고침",fontWeight=FontWeight.Bold)})},bottomBar={NavigationBar(containerColor=MaterialTheme.colorScheme.surface,tonalElevation=0.dp){listOf("오늘","가격","행동","기록","설정").forEachIndexed{i,s->NavigationBarItem(tab==i,{tab=i},{Text(listOf("●","↗","✓","▤","⚙")[i],fontWeight=FontWeight.Black)},label={Text(s,fontSize=11.sp)})}}}){pad->
  Column(Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState())){
   AppBar(region){tab=4}
   if(loading&&data==null)LoadingState() else if(data?.error!=null&&data?.pig?.price==null)ErrorState(data!!.error!!){loading=true} else when(tab){0->TodayScreen(data?:AppData(),region,{tab=it});1->MarketScreen(data?:AppData());2->ActionScreen(data?:AppData(),region);3->RecordsScreen();else->SettingsScreen(data?:AppData(),region){region=it;prefs.edit().putString("region",it).apply()}}
   Spacer(Modifier.height(24.dp))
   refreshMessage?.let{Text(it,Modifier.fillMaxWidth().padding(16.dp),color=if(it.startsWith("최신"))Forest else Red,fontSize=12.sp,fontWeight=FontWeight.Bold);LaunchedEffect(it){kotlinx.coroutines.delay(2500);refreshMessage=null}}
  }
 }
}

@Composable fun AppBar(region:String,onRegion:()->Unit){Row(Modifier.fillMaxWidth().padding(horizontal=20.dp,vertical=16.dp),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically){Row(verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(38.dp).background(Forest,CircleShape),contentAlignment=Alignment.Center){Text("돈",color=Color.White,fontWeight=FontWeight.Black)};Spacer(Modifier.width(10.dp));Column{Text("오늘돈가",fontSize=19.sp,fontWeight=FontWeight.Black);Text("TODAYPIG",fontSize=9.sp,letterSpacing=1.5.sp,color=Forest)}};Surface(Modifier.clickable(onClick=onRegion),color=Color.White,shape=RoundedCornerShape(20.dp)){Text("⌖ $region",Modifier.padding(horizontal=12.dp,vertical=8.dp),fontSize=12.sp,fontWeight=FontWeight.Bold)}}}
@Composable fun LoadingState(){Column(Modifier.fillMaxWidth().padding(40.dp),horizontalAlignment=Alignment.CenterHorizontally){CircularProgressIndicator();Spacer(Modifier.height(12.dp));Text("공식 데이터 확인 중",fontWeight=FontWeight.Bold)}}
@Composable fun ErrorState(msg:String,retry:()->Unit){Column(Modifier.padding(24.dp)){Text("연결이 원활하지 않습니다",fontSize=24.sp,fontWeight=FontWeight.Black);Text(msg,Modifier.padding(vertical=12.dp));Button(retry){Text("다시 확인")}}}

@Composable fun TodayScreen(d:AppData,region:String,navigate:(Int)->Unit){
 val r=d.regions.firstOrNull{it.name==region};val ctx=FarmContext(region,"비육",r?.min,r?.max,r?.humidity,weatherWarning=r?.risks?.isNotEmpty()==true,diseaseNearby=d.diseases.any{it.level==EvidenceLevel.OFFICIAL&&it.summary.contains(region.take(2))},priceChangePct=d.pig.changePct)
 val top=FarmDecisionEngine.evaluate(ctx)
 Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(18.dp)){
  Text(LocalDateTime.now().format(DateTimeFormatter.ofPattern("M월 d일 E요일",Locale.KOREAN)),color=Forest,fontWeight=FontWeight.Bold);Text("오늘 먼저 볼 것",fontSize=34.sp,lineHeight=38.sp,fontWeight=FontWeight.Black)
  PriceHero(d.pig){navigate(1)}
  Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.Bottom){Column{Text("농장 TOP 3",fontSize=24.sp,fontWeight=FontWeight.Black);Text("가격보다 먼저, 현장 행동 순서",fontSize=12.sp,color=Color.Gray)};Text("$region 기준",fontSize=11.sp,color=Forest,fontWeight=FontWeight.Bold)}
  top.forEachIndexed{i,c->DecisionSummary(i+1,c){navigate(2)}}
  r?.let{WeatherStrip(it)}
  EvidenceStrip(d.diseases.take(3)){navigate(2)}
 }
}

@Composable fun PriceHero(p:PigPrice,onClick:()->Unit){Card(Modifier.fillMaxWidth().clickable(onClick=onClick),shape=RoundedCornerShape(28.dp),colors=CardDefaults.cardColors(containerColor=Ink)){Column(Modifier.padding(22.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text("전국 대표 돈가",color=Mint,fontWeight=FontWeight.Black);Text("제주 제외 · 원/kg",fontSize=11.sp,color=Color.White.copy(.65f))};if(p.price!=null){Text("${comma(p.price)}",fontSize=54.sp,fontWeight=FontWeight.Black,color=Color.White);val ch=p.change?:0;Text((if(ch>0)"▲" else if(ch<0)"▼" else "—")+" ${comma(abs(ch))}원  "+(p.changePct?.let{"${abs(it)}%"}?:""),color=if(ch<0)Color(0xFF8DB8FF)else Color(0xFFFFBE78),fontWeight=FontWeight.Bold)}else{Text(if(p.status.isBlank())"집계중" else p.status,fontSize=32.sp,fontWeight=FontWeight.Black,color=Color.White);Text("확인되지 않은 값은 0원으로 표시하지 않습니다",fontSize=12.sp,color=Color.White.copy(.7f))};HorizontalDivider(color=Color.White.copy(.12f));Text("기준일 ${formatDay(p.date)} · ${shortTime(p.updatedAt)} 갱신",fontSize=11.sp,color=Color.White.copy(.65f))}}}
@Composable fun DecisionSummary(rank:Int,c:DecisionCard,onClick:()->Unit){Card(Modifier.fillMaxWidth().clickable(onClick=onClick),shape=RoundedCornerShape(22.dp),colors=CardDefaults.cardColors(containerColor=Color.White)){Row(Modifier.padding(17.dp),verticalAlignment=Alignment.Top){Box(Modifier.size(34.dp).background(if(rank==1)Forest else Paper,CircleShape),contentAlignment=Alignment.Center){Text(rank.toString(),color=if(rank==1)Color.White else Ink,fontWeight=FontWeight.Black)};Spacer(Modifier.width(13.dp));Column(Modifier.weight(1f)){Row(verticalAlignment=Alignment.CenterVertically){EvidenceBadge(c.evidence);Spacer(Modifier.width(7.dp));Text("위험 ${c.score}",fontSize=10.sp,color=Color.Gray)};Text(c.title,Modifier.padding(top=7.dp),fontSize=17.sp,fontWeight=FontWeight.Black);Text(c.why.joinToString(" · "),fontSize=12.sp,color=Color.Gray,maxLines=2);Text("확인 경로 보기  →",Modifier.padding(top=9.dp),fontSize=11.sp,color=Forest,fontWeight=FontWeight.Black)}}}}
@Composable fun EvidenceBadge(e:EvidenceLevel){val color=when(e){EvidenceLevel.OFFICIAL->Red;EvidenceLevel.PUBLIC_UNCONFIRMED->Amber;EvidenceLevel.FARM_OBSERVATION->Blue;else->Forest};Surface(color=color.copy(.12f),shape=RoundedCornerShape(8.dp)){Text(e.label,Modifier.padding(horizontal=7.dp,vertical=4.dp),fontSize=9.sp,color=color,fontWeight=FontWeight.Black)}}
@Composable fun WeatherStrip(r:RegionBrief){Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFE7F2EC)),shape=RoundedCornerShape(22.dp)){Row(Modifier.fillMaxWidth().padding(17.dp),horizontalArrangement=Arrangement.SpaceBetween){Column{Text("선택지역 환경",fontWeight=FontWeight.Black);Text(r.risks.ifEmpty{listOf("특이 기상위험 없음")}.joinToString(" · "),fontSize=11.sp,color=Forest)};Text("${r.min?.roundToInt()?:"-"}° / ${r.max?.roundToInt()?:"-"}°",fontSize=22.sp,fontWeight=FontWeight.Black)}}}
@Composable fun EvidenceStrip(items:List<DiseaseAlert>,onClick:()->Unit){Column{Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text("질병·방역 신호",fontSize=20.sp,fontWeight=FontWeight.Black);Text("전체 보기",Modifier.clickable(onClick=onClick),color=Forest,fontSize=12.sp,fontWeight=FontWeight.Bold)};Spacer(Modifier.height(8.dp));if(items.isEmpty())Text("현재 수집된 공개 신호가 없습니다.",color=Color.Gray)else items.forEach{x->Row(Modifier.fillMaxWidth().padding(vertical=7.dp),verticalAlignment=Alignment.CenterVertically){EvidenceBadge(x.level);Text(x.disease+" · "+x.summary,Modifier.padding(start=8.dp).weight(1f),maxLines=1,overflow=TextOverflow.Ellipsis,fontSize=12.sp)}}}}

@Composable fun MarketScreen(d:AppData){var period by remember{mutableStateOf("3개년 월간")};Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)){Text("가격의 위치",fontSize=32.sp,fontWeight=FontWeight.Black);Text("오늘 숫자를 역사적 범위 안에서 읽습니다",color=Color.Gray);PriceHero(d.pig){};Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(7.dp)){listOf("일간","주간","월간","3개년 월간").forEach{FilterChip(period==it,{period=it},{Text(it)})}};PriceChart(d.history,period);CompareGrid(d.pig);GradePanel(d.grades);Text("제주 가격 · 전국과 별도",fontSize=20.sp,fontWeight=FontWeight.Black);if(d.jeju.isEmpty())Text("집계중",color=Color.Gray)else d.jeju.take(5).forEach{Surface(color=Color.White,shape=RoundedCornerShape(16.dp)){Row(Modifier.fillMaxWidth().padding(14.dp),horizontalArrangement=Arrangement.SpaceBetween){Text(it.first,fontWeight=FontWeight.Bold);Text("백돼지 ${it.second} · 흑돼지 ${it.third}",fontSize=12.sp)}}};SourceNote("축산물품질평가원 경락가격 원자료 · 전국은 탕박/등외·제주 제외 기준 · 데이터 산식과 갱신상태를 함께 표시")}}
@Composable fun PriceChart(rows:List<HistPoint>,period:String){
 val shown=when(period){"일간"->rows.filter{it.resolution=="day"};"주간"->rows.takeLast(49).chunked(7).mapNotNull{g->if(g.isEmpty())null else HistPoint(g.last().date,g.map{it.price}.average().roundToInt())};"월간"->monthAverages(rows).takeLast(12);else->monthAverages(rows).takeLast(36)}
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(28.dp)){Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
  Text(period,fontSize=18.sp,fontWeight=FontWeight.Black)
  if(shown.size<2)Text("공식 확정 데이터가 더 쌓이면 표시됩니다",Modifier.padding(vertical=30.dp),color=Color.Gray) else {
   val values=shown.map{it.price.toFloat()};val lo=values.minOrNull()?:0f;val hi=values.maxOrNull()?:1f
   if(period=="3개년 월간")ThreeYearChart(shown,lo,hi) else {Canvas(Modifier.fillMaxWidth().height(190.dp).padding(vertical=16.dp)){for(i in 0..3)drawLine(Color(0xFFE5E9E5),Offset(0f,size.height*i/3),Offset(size.width,size.height*i/3),1f);val path=Path();values.forEachIndexed{i,v->val x=if(values.size==1)0f else size.width*i/(values.size-1);val y=size.height-(v-lo)/(hi-lo).coerceAtLeast(1f)*size.height;if(i==0)path.moveTo(x,y)else path.lineTo(x,y)};drawPath(path,Forest,style=Stroke(4f));drawCircle(Amber,8f,Offset(size.width,size.height-(values.last()-lo)/(hi-lo).coerceAtLeast(1f)*size.height))};Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){shown.filterIndexed{i,_->i==0||i==shown.lastIndex||i==shown.size/2}.forEach{Text(formatAxis(it.date),fontSize=10.sp,color=Color.Gray)}}}
   if(period=="3개년 월간")MonthlyPriceTable(shown)
  }
 }}
}

@Composable fun ThreeYearChart(points:List<HistPoint>,lo:Float,hi:Float){
 val years=points.map{it.date.take(4)}.distinct().sorted();val colors=listOf(Color(0xFFA8B6C8),Color(0xFF5D8FC9),Forest)
 Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){years.forEachIndexed{i,y->Row(verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(9.dp).background(colors.getOrElse(i){Forest},CircleShape));Spacer(Modifier.width(5.dp));Text(y,fontSize=11.sp,fontWeight=FontWeight.Bold)}}}
 Canvas(Modifier.fillMaxWidth().height(210.dp).padding(vertical=14.dp)){for(i in 0..3)drawLine(Color(0xFFE4E7EB),Offset(0f,size.height*i/3),Offset(size.width,size.height*i/3),1f);years.forEachIndexed{yi,year->val monthly=points.filter{it.date.startsWith(year)}.associateBy{it.date.substring(4,6).toIntOrNull()};val path=Path();var active=false;(1..12).forEach{m->val item=monthly[m];if(item==null){active=false}else{val x=size.width*(m-1)/11f;val y=size.height-(item.price-lo)/(hi-lo).coerceAtLeast(1f)*size.height;if(!active)path.moveTo(x,y)else path.lineTo(x,y);active=true;drawCircle(colors.getOrElse(yi){Forest},if(item.price==monthly.values.maxOf{it.price}||item.price==monthly.values.minOf{it.price})7f else 4f,Offset(x,y))}};drawPath(path,colors.getOrElse(yi){Forest},style=Stroke(if(yi==years.lastIndex)4f else 2.5f))}}
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){(1..12).forEach{Text("${it}월",fontSize=8.sp,color=Color.Gray)}}
}

@Composable fun MonthlyPriceTable(points:List<HistPoint>){
 val ctx=LocalContext.current;val grouped=points.groupBy{it.date.take(4)}.toSortedMap();val all=points.map{it.price};val globalHigh=all.maxOrNull();val globalLow=all.minOrNull()
 HorizontalDivider(color=Color(0xFFE7EBE8));Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically){Column{Text("월별 확정 평균",fontWeight=FontWeight.Black);Text("단위 원/kg · 없는 월은 —",fontSize=10.sp,color=Color.Gray)};TextButton({sharePriceCsv(ctx,grouped)}){Text("CSV 내보내기")}}
 grouped.forEach{(year,months)->val hi=months.maxByOrNull{it.price};val low=months.minByOrNull{it.price};Column(verticalArrangement=Arrangement.spacedBy(7.dp)){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text(year,fontSize=13.sp,fontWeight=FontWeight.Black,color=Forest);Text("평균 ${comma(months.map{it.price}.average().roundToInt())} · 최고 ${hi?.date?.takeLast(2)?.toIntOrNull()}월 · 최저 ${low?.date?.takeLast(2)?.toIntOrNull()}월",fontSize=9.sp,color=Color.Gray)};Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(7.dp)){(1..12).forEach{m->val item=months.firstOrNull{it.date.substring(4,6).toIntOrNull()==m};val tag=when(item?.price){globalHigh->"전체 최고";globalLow->"전체 최저";hi?.price->"최고";low?.price->"최저";else->null};Surface(color=if(tag!=null)Color(0xFFFFE8C2)else if(item==null)Paper else Color(0xFFEAF3EE),shape=RoundedCornerShape(12.dp)){Column(Modifier.width(70.dp).padding(vertical=9.dp),horizontalAlignment=Alignment.CenterHorizontally){Text("${m}월",fontSize=10.sp,color=Color.Gray);Text(item?.let{comma(it.price)}?:"—",fontSize=11.sp,fontWeight=FontWeight.Black);if(tag!=null)Text(tag,fontSize=8.sp,color=if(tag.contains("최고"))Red else Blue,fontWeight=FontWeight.Black)}}}}}}
 val highs=grouped.mapValues{it.value.maxByOrNull{p->p.price}};val lows=grouped.mapValues{it.value.minByOrNull{p->p.price}};Text("3개년 최고 ${points.maxByOrNull{it.price}?.let{"${it.date.take(4)}년 ${it.date.takeLast(2).toIntOrNull()}월 ${comma(it.price)}원"}?:"—"} · 최저 ${points.minByOrNull{it.price}?.let{"${it.date.take(4)}년 ${it.date.takeLast(2).toIntOrNull()}월 ${comma(it.price)}원"}?:"—"}",fontSize=11.sp,fontWeight=FontWeight.Bold)
}
fun sharePriceCsv(ctx:Context,grouped:Map<String,List<HistPoint>>){val header=(1..12).joinToString(","){"${it}월"};val body=grouped.entries.joinToString("\n"){(year,rows)->val byMonth=rows.associateBy{it.date.substring(4,6).toIntOrNull()};year+","+(1..12).joinToString(","){byMonth[it]?.price?.toString()?:""}};val csv="연도,$header\n$body";ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/csv").putExtra(Intent.EXTRA_SUBJECT,"오늘돈가 3개년 월별가격.csv").putExtra(Intent.EXTRA_TEXT,csv),"CSV 내보내기"))}
fun monthAverages(rows:List<HistPoint>)=rows.groupBy{it.date.take(6)}.toSortedMap().map{entry->val monthly=entry.value.firstOrNull{it.resolution=="month"};HistPoint(entry.key,monthly?.price?:entry.value.map{it.price}.average().roundToInt(),"month")}
@Composable fun CompareGrid(p:PigPrice){Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){CompareCell("전월 평균",p.previousMonth,p.monthAverage);CompareCell("전년 동월",p.lastYearMonth,p.monthAverage);CompareCell("현재월 평균",p.monthAverage,p.price)}}
@Composable fun RowScope.CompareCell(label:String,base:Int?,now:Int?){Surface(Modifier.weight(1f),color=Color.White,shape=RoundedCornerShape(16.dp)){Column(Modifier.padding(12.dp)){Text(label,fontSize=10.sp,color=Color.Gray);Text(base?.let{comma(it)}?:"집계중",fontWeight=FontWeight.Black,fontSize=14.sp);if(base!=null&&now!=null)Text("${if(now-base>=0)"+" else ""}${comma(now-base)}",fontSize=10.sp,color=if(now-base>=0)Red else Blue)}}}
@Composable fun GradePanel(grades:List<GradePrice>){Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFE7F2EC)),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(17.dp)){Text("등급별 상세",fontSize=18.sp,fontWeight=FontWeight.Black);Text("1+ / 1 / 2 / 등외",fontSize=11.sp,color=Color.Gray);if(grades.isEmpty())Text("최근 확정값 집계중",Modifier.padding(top=12.dp),fontWeight=FontWeight.Bold)else grades.sortedBy{listOf("1+","1","2","등외").indexOf(it.grade)}.forEach{Row(Modifier.fillMaxWidth().padding(top=9.dp),horizontalArrangement=Arrangement.SpaceBetween){Text(it.grade);Text(it.price?.let{v->"${comma(v)}원/kg"}?:"집계중",fontWeight=FontWeight.Black)}}}}}

@Composable fun ActionScreen(d:AppData,region:String){var stage by remember{mutableStateOf("비육")};var cough by remember{mutableStateOf(false)};var diarrhea by remember{mutableStateOf(false)};var intake by remember{mutableStateOf(false)};var mortality by remember{mutableStateOf(false)};val r=d.regions.firstOrNull{it.name==region};val official=d.diseases.any{it.level==EvidenceLevel.OFFICIAL&&it.summary.contains(region.take(2))};val cards=FarmDecisionEngine.evaluate(FarmContext(region,stage,r?.min,r?.max,r?.humidity,r?.risks?.isNotEmpty()==true,cough,diarrhea,intake,mortality,official,d.pig.changePct));Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){Text("오늘의 행동",fontSize=32.sp,fontWeight=FontWeight.Black);Text("진단이 아니라 관찰→측정→조정→재평가 경로입니다",color=Color.Gray);Text("돈군 단계",fontWeight=FontWeight.Black);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("분만","포유자돈","이유자돈","자돈","육성","비육").forEach{FilterChip(stage==it,{stage=it},{Text(it)})}};Text("농장 관찰",fontWeight=FontWeight.Black);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("기침" to cough,"설사" to diarrhea,"섭취저하" to intake,"폐사증가" to mortality).forEach{(n,v)->FilterChip(v,{when(n){"기침"->cough=!cough;"설사"->diarrhea=!diarrhea;"섭취저하"->intake=!intake;else->mortality=!mortality}},{Text(n)})}};cards.forEachIndexed{i,c->DecisionDetail(i+1,c)};DiseaseList(d.diseases)}}
@Composable fun DecisionDetail(rank:Int,c:DecisionCard){var open by remember{mutableStateOf(rank==1)};Card(Modifier.fillMaxWidth().clickable{open=!open},shape=RoundedCornerShape(24.dp),colors=CardDefaults.cardColors(containerColor=if(rank==1)Ink else Color.White)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(9.dp)){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){EvidenceBadge(c.evidence);Text("우선순위 $rank · ${c.score}",fontSize=11.sp,color=if(rank==1)Mint else Forest,fontWeight=FontWeight.Black)};Text(c.title,fontSize=20.sp,fontWeight=FontWeight.Black,color=if(rank==1)Color.White else Ink);Text(c.why.joinToString(" · "),fontSize=12.sp,color=if(rank==1)Color.White.copy(.7f)else Color.Gray);if(open){HorizontalDivider(color=if(rank==1)Color.White.copy(.16f)else Color.LightGray);StepLine("1 관찰",c.observe.joinToString(" · "),rank==1);StepLine("2 측정",c.measure.joinToString(" · "),rank==1);StepLine("3 먼저 조정",c.firstAdjustment,rank==1);StepLine("4 지속 시 감별",c.differentials.joinToString(" · "),rank==1);StepLine("전문가 연결",c.escalation,rank==1)}}}}
@Composable fun StepLine(title:String,body:String,dark:Boolean){Column{Text(title,fontSize=11.sp,fontWeight=FontWeight.Black,color=if(dark)Mint else Forest);Text(body,fontSize=13.sp,lineHeight=19.sp,color=if(dark)Color.White else Ink)}}
@Composable fun DiseaseList(items:List<DiseaseAlert>){
 var scope by remember{mutableStateOf("국내")};val filtered=if(scope=="관심")items.filter{it.disease in listOf("ASF","PRRS","PED","구제역")}else items.filter{it.scope==scope}
 Text("질병·방역",fontSize=22.sp,fontWeight=FontWeight.Black);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("국내","국외","관심","분류 확인 필요").forEach{s->FilterChip(scope==s,{scope=s},{Text(s)})}}
 if(filtered.isEmpty())Text("현재 수집된 $scope 공개정보가 없습니다.",Modifier.padding(vertical=18.dp),color=Color.Gray)
 filtered.take(12).forEach{x->Surface(color=Color.White,shape=RoundedCornerShape(20.dp)){Column(Modifier.padding(16.dp)){Row(verticalAlignment=Alignment.CenterVertically){EvidenceBadge(x.level);Spacer(Modifier.width(7.dp));Text(scope,fontSize=10.sp,color=Color.Gray)};Text(x.disease,Modifier.padding(top=9.dp),fontSize=17.sp,fontWeight=FontWeight.Black);Text(x.summary,fontSize=12.sp,maxLines=3,overflow=TextOverflow.Ellipsis);Text(x.source,Modifier.padding(top=7.dp),fontSize=10.sp,color=Color.Gray)}}}
 SourceNote("국내와 국외 신호를 분리하며 공식 확인과 공개정보·확인중도 합쳐 표시하지 않습니다. 앱은 질병을 확정 진단하거나 처방하지 않습니다.")
}

@Composable fun RecordsScreen(){var page by remember{mutableStateOf("기록")};Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){Text("농장 업무",fontSize=32.sp,fontWeight=FontWeight.Black);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("기록","인증 관리","예상 정산","성과").forEach{s->FilterChip(page==s,{page=s},{Text(s)})}};when(page){"기록"->RecordForm();"인증 관리"->CertificationManager();"예상 정산"->Settlement();else->Performance()}}}
@Composable fun RecordForm(){val ctx=LocalContext.current;var stage by remember{mutableStateOf("비육")};var weight by remember{mutableStateOf("")};var days by remember{mutableStateOf("")};var fcr by remember{mutableStateOf("")};var mortality by remember{mutableStateOf("")};var intake by remember{mutableStateOf("")};var symptom by remember{mutableStateOf("")};var action by remember{mutableStateOf("")};var result by remember{mutableStateOf("")};var saved by remember{mutableStateOf(false)};Text("한 번 기록하면 다음 위험평가의 기준이 됩니다",color=Color.Gray);SimpleField("돈군 단계",stage){stage=it};Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("출하체중 kg",weight){weight=it}};Box(Modifier.weight(1f)){SimpleField("출하일령",days){days=it}}};Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("FCR",fcr){fcr=it}};Box(Modifier.weight(1f)){SimpleField("폐사율 %",mortality){mortality=it}}};SimpleField("사료섭취량 kg",intake){intake=it};SimpleField("관찰한 증상",symptom){symptom=it};SimpleField("조치내용",action){action=it};SimpleField("조치결과",result){result=it};Button({saveRecord(ctx,FarmRecord(LocalDateTime.now().toString(),stage,weight.toDoubleOrNull(),days.toIntOrNull(),fcr.toDoubleOrNull(),mortality.toDoubleOrNull(),intake.toDoubleOrNull(),symptom,action,result));saved=true},Modifier.fillMaxWidth()){Text(if(saved)"저장됨" else "기록 저장")};SourceNote("기록은 이 기기에 저장됩니다. 익명 실증 제공은 별도 동의를 받기 전까지 꺼져 있습니다.")}
@Composable fun SimpleField(label:String,value:String,on:(String)->Unit){OutlinedTextField(value,on,Modifier.fillMaxWidth(),label={Text(label)},singleLine=true,shape=RoundedCornerShape(14.dp))}
fun saveRecord(ctx:Context,r:FarmRecord){val p=ctx.getSharedPreferences("records",Context.MODE_PRIVATE);val a=try{JSONArray(p.getString("rows","[]"))}catch(_:Exception){JSONArray()};a.put(JSONObject().put("at",r.at).put("stage",r.stage).put("weight",r.weight).put("days",r.days).put("fcr",r.fcr).put("mortality",r.mortality).put("intake",r.intake).put("symptom",r.symptom).put("action",r.action).put("result",r.result));p.edit().putString("rows",a.toString()).apply()}
@Composable fun CertificationManager(){
 val ctx=LocalContext.current;val prefs=remember{ctx.getSharedPreferences("certifications",Context.MODE_PRIVATE)};var revision by remember{mutableIntStateOf(0)};var type by remember{mutableStateOf("저탄소 축산물")};var agency by remember{mutableStateOf("")};var number by remember{mutableStateOf("")};var issued by remember{mutableStateOf("")};var expires by remember{mutableStateOf("")};var status by remember{mutableStateOf("유효")};var settlement by remember{mutableStateOf(true)};var note by remember{mutableStateOf("")};val rows=remember(revision){try{JSONArray(prefs.getString("rows","[]"))}catch(_:Exception){JSONArray()}}
 Text("인증 현황",fontSize=22.sp,fontWeight=FontWeight.Black);Text("한 농가에 여러 인증을 등록하고 정산 적용 여부를 따로 관리합니다.",color=Color.Gray,fontSize=12.sp)
 Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("저탄소 축산물","무항생제 축산물","HACCP","깨끗한 축산농장","동물복지","유기축산물","지역 브랜드","조합 자체","기타").forEach{FilterChip(type==it,{type=it},{Text(it)})}}
 SimpleField("인증기관 (필수)",agency){agency=it};SimpleField("인증번호 (필수)",number){number=it};Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("인증일 YYYY-MM-DD",issued){issued=it}};Box(Modifier.weight(1f)){SimpleField("유효기간 YYYY-MM-DD",expires){expires=it}}};Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("유효","갱신 예정","만료","정지").forEach{FilterChip(status==it,{status=it},{Text(it)})}};SettingSwitch("정산 적용","이 인증을 복합 정산 후보에 포함",settlement){settlement=it};SimpleField("비고·증빙자료 위치",note){note=it}
 Button({if(agency.isNotBlank()&&number.isNotBlank()){val a=try{JSONArray(prefs.getString("rows","[]"))}catch(_:Exception){JSONArray()};a.put(JSONObject().put("type",type).put("agency",agency).put("number",number).put("issued",issued).put("expires",expires).put("status",status).put("settlement",settlement).put("note",note));prefs.edit().putString("rows",a.toString()).apply();agency="";number="";issued="";expires="";note="";revision++}},Modifier.fillMaxWidth(),enabled=agency.isNotBlank()&&number.isNotBlank()){Text("인증 저장")}
 if(rows.length()==0)Text("등록된 인증이 없습니다.",Modifier.padding(vertical=16.dp),color=Color.Gray)else for(i in rows.length()-1 downTo 0){val x=rows.getJSONObject(i);Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(18.dp)){Column(Modifier.padding(15.dp)){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text(x.optString("type"),fontWeight=FontWeight.Black);Text(x.optString("status"),color=if(x.optString("status")=="유효")Forest else Amber,fontWeight=FontWeight.Bold,fontSize=12.sp)};Text("${x.optString("agency")} · ${x.optString("number")}",fontSize=12.sp);Text("${x.optString("issued","미입력")} → ${x.optString("expires","미입력")} · 정산 ${if(x.optBoolean("settlement"))"적용" else "제외"}",fontSize=10.sp,color=Color.Gray)}}}
 SourceNote("인증자료는 이 기기에만 저장됩니다. 만료일과 증빙자료는 사용자가 입력한 값이며 인증기관의 실시간 유효성 조회 결과가 아닙니다.")
}
@Composable fun Settlement(){
 val ctx=LocalContext.current
 val price=ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE).getInt("widget_price",0)
 var mode by remember{mutableStateOf("중량×단가")};var rate by remember{mutableStateOf("78")};var averageWeight by remember{mutableStateOf("115")};var totalWeightInput by remember{mutableStateOf("")};var heads by remember{mutableStateOf("1")};var baseAmount by remember{mutableStateOf("")};var kgRate by remember{mutableStateOf(price.takeIf{it>0}?.toString()?:"")};var perHead by remember{mutableStateOf("")};var fixed by remember{mutableStateOf("")};var selectedCert by remember{mutableStateOf("저탄소 축산물")};var certValue by remember{mutableStateOf("0")};var bonuses by remember{mutableStateOf<Map<String,Double>>(emptyMap())}
 fun number(value:String)=value.toDoubleOrNull()?:0.0
 val calculatedWeight=number(averageWeight)*number(heads);val totalWeight=if(totalWeightInput.isBlank())calculatedWeight else number(totalWeightInput);val bonus=bonuses.values.sum();val core=when(mode){"중량×단가"->totalWeight*number(kgRate);"기준금액×지급률"->number(baseAmount)*number(rate)/100;"두수×두당액"->number(heads)*number(perHead);"고정 지급"->number(fixed);else->totalWeight*number(kgRate)+number(heads)*number(perHead)+number(fixed)};val total=core+bonus
 val valid=number(heads)>0&&when(mode){"중량×단가"->totalWeight>0&&number(kgRate)>0;"기준금액×지급률"->number(baseAmount)>0&&number(rate)>0;"두수×두당액"->number(perHead)>0;"고정 지급"->number(fixed)>0;else->totalWeight>0}
 val formula=when(mode){"중량×단가"->"${comma(totalWeight.roundToInt())}kg × ${comma(number(kgRate).roundToInt())}원/kg";"기준금액×지급률"->"${comma(number(baseAmount).roundToInt())}원 × ${rate}%";"두수×두당액"->"${heads}두 × ${comma(number(perHead).roundToInt())}원/두";"고정 지급"->"고정 ${comma(number(fixed).roundToInt())}원";else->"중량 지급 + 두당 지급 + 고정 지급"}
 Card(colors=CardDefaults.cardColors(containerColor=Ink),shape=RoundedCornerShape(28.dp)){Column(Modifier.padding(20.dp)){Text("예상 정산",color=Mint,fontWeight=FontWeight.Bold);Text(if(valid)"${comma(total.roundToInt())}원" else "필수값을 입력하세요",fontSize=32.sp,fontWeight=FontWeight.Black,color=Color.White);Text(if(valid)"$formula + 인증 ${comma(bonus.roundToInt())}원" else "선택한 정산 방식의 단가·중량·두수를 확인하세요",fontSize=11.sp,color=Color.White.copy(.7f))}}
 Text("정산 방식",fontSize=18.sp,fontWeight=FontWeight.Black);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("중량×단가","기준금액×지급률","두수×두당액","고정 지급","복합 지급").forEach{FilterChip(mode==it,{mode=it},{Text(it)})}}
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("출하두수 (두)",heads){heads=it}};Box(Modifier.weight(1f)){SimpleField("평균 출하체중 (kg/두)",averageWeight){averageWeight=it}}};SimpleField("총 출하체중 (kg) · 비우면 자동 ${comma(calculatedWeight.roundToInt())}",totalWeightInput){totalWeightInput=it}
 if(totalWeightInput.isNotBlank()&&abs(number(totalWeightInput)-calculatedWeight)>.5)SourceNote("직접 입력한 총 출하체중과 출하두수×평균 출하체중이 다릅니다. 직접 입력값을 계산에 사용합니다.")
 when(mode){"중량×단가"->SimpleField("kg당 지급단가 (원/kg)",kgRate){kgRate=it};"기준금액×지급률"->{SimpleField("지급률 적용 기준금액 (원)",baseAmount){baseAmount=it};SimpleField("계약 지급률 (%)",rate){rate=it}};"두수×두당액"->SimpleField("두당 지급액 (원/두)",perHead){perHead=it};"고정 지급"->SimpleField("고정 지급액 (원)",fixed){fixed=it};else->{SimpleField("kg당 지급단가 (원/kg)",kgRate){kgRate=it};SimpleField("두당 지급액 (원/두)",perHead){perHead=it};SimpleField("고정 지급액 (원)",fixed){fixed=it}}}
 Text("인증·계약 가산",fontSize=18.sp,fontWeight=FontWeight.Black)
 Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("저탄소 축산물","무항생제 축산물","HACCP","깨끗한 축산농장","동물복지","유기축산물","지역 브랜드","조합 자체","기타").forEach{FilterChip(selectedCert==it,{selectedCert=it;certValue=(bonuses[it]?:0.0).toString().removeSuffix(".0")},{Text(it)})}}
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp),verticalAlignment=Alignment.CenterVertically){Box(Modifier.weight(1f)){SimpleField("인증 지급액 (원)",certValue){certValue=it}};Button({if(number(certValue)>=0)bonuses=bonuses+(selectedCert to number(certValue))},shape=RoundedCornerShape(14.dp)){Text("추가")}}
 bonuses.filterValues{it>0}.forEach{(name,value)->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text(name,fontSize=12.sp);Text("+${comma(value.roundToInt())}원",fontSize=12.sp,fontWeight=FontWeight.Black)}}
 SourceNote("산출식: $formula${if(bonus>0)" + 인증 ${comma(bonus.roundToInt())}원" else ""}. 인증 지급액과 지급률은 전국 공통 기준이 아니라 농가·계약별 사용자 입력값입니다. 과거 도체중은 출하체중으로 자동 변환하지 않습니다.")
}
@Composable fun Performance(){val ctx=LocalContext.current;val a=try{JSONArray(ctx.getSharedPreferences("records",Context.MODE_PRIVATE).getString("rows","[]"))}catch(_:Exception){JSONArray()};Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(18.dp)){Text("기록 ${a.length()}건",fontSize=24.sp,fontWeight=FontWeight.Black);Text("FCR·폐사율·출하일령은 동일 기준의 기록이 2건 이상 쌓이면 전후 변화로 표시됩니다.",color=Color.Gray);Text("추천 수행률 · 조기발견시간 · 대응시간도 동의한 익명 실증에서 산식과 함께 추적할 수 있도록 설계했습니다.",Modifier.padding(top=12.dp),fontSize=12.sp)}}}

@Composable fun SettingsScreen(d:AppData,selected:String,onRegion:(String)->Unit){val ctx=LocalContext.current;val prefs=remember{ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE)};var priceAlert by remember{mutableStateOf(prefs.getBoolean("price_alert",true))};var diseaseAlert by remember{mutableStateOf(prefs.getBoolean("disease_alert",true))};var consent by remember{mutableStateOf(prefs.getBoolean("research_consent",false))};Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)){Text("지역과 설정",fontSize=32.sp,fontWeight=FontWeight.Black);RegionSelector(selected,onRegion,d.regions);Text("알림",fontSize=20.sp,fontWeight=FontWeight.Black);SettingSwitch("돈가 갱신·주요 변동","백그라운드 정기 확인",priceAlert){priceAlert=it;prefs.edit().putBoolean("price_alert",it).apply();requestNotify(ctx)};SettingSwitch("공식 질병·지역 방역","공식/확인중을 구분해 표시",diseaseAlert){diseaseAlert=it;prefs.edit().putBoolean("disease_alert",it).apply();requestNotify(ctx)};SourceNote("Android 백그라운드 작업은 운영체제가 실행시각을 조정할 수 있어 즉시 알림을 보장하지 않습니다. 현재 버전은 정기 확인이며, 운영 서버와 FCM 연결 시에만 푸시 알림으로 전환됩니다.");Text("개인정보와 실증",fontSize=20.sp,fontWeight=FontWeight.Black);SettingSwitch("익명 실증 데이터 제공","명시 동의 전에는 외부 전송 없음",consent){consent=it;prefs.edit().putBoolean("research_consent",it).apply()};OutlinedButton({ctx.getSharedPreferences("records",Context.MODE_PRIVATE).edit().clear().apply()},Modifier.fillMaxWidth()){Text("농장 기록 모두 삭제")};SourceNote("최소수집 · 목적별 동의 · 철회/삭제를 기본으로 합니다. 농장명과 정확한 위치는 필수 수집하지 않습니다.");Text("데이터 상태",fontSize=20.sp,fontWeight=FontWeight.Black);Text("돈가 ${formatDay(d.pig.date)} · 질병 ${d.diseases.size}건 · 가격이력 ${d.history.size}건",fontSize=12.sp)}}
@Composable fun RegionSelector(selected:String,on:(String)->Unit,regions:List<RegionBrief>){
 val ctx=LocalContext.current;val scope=rememberCoroutineScope();val prefs=remember{ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE)};var district by remember{mutableStateOf(prefs.getString("district",null))};var showMap by remember{mutableStateOf(false)};var locating by remember{mutableStateOf(false)};var locationMessage by remember{mutableStateOf<String?>(null)}
 fun locate(){locating=true;locationMessage=null;val lm=ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
  try{val provider=when{lm.isProviderEnabled(LocationManager.GPS_PROVIDER)->LocationManager.GPS_PROVIDER;lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)->LocationManager.NETWORK_PROVIDER;else->{locating=false;locationMessage="휴대폰 위치 서비스를 켜주세요";return}}
   if(android.os.Build.VERSION.SDK_INT>=30)lm.getCurrentLocation(provider,CancellationSignal(),ctx.mainExecutor){loc->if(loc==null){locating=false;locationMessage="현재 위치를 확인하지 못했습니다"}else scope.launch{val address=withContext(Dispatchers.IO){try{Geocoder(ctx,Locale.KOREA).getFromLocation(loc.latitude,loc.longitude,1)?.firstOrNull()}catch(_:Exception){null}};val province=address?.adminArea;val city=address?.subAdminArea?:address?.locality;if(province.isNullOrBlank()){locationMessage="행정구역을 확인하지 못했습니다"}else{district=city;prefs.edit().putString("district",city).apply();on(province);locationMessage="${province}${city?.let{" · $it"}?:""}로 연결했습니다"};locating=false}}
   else{val loc=lm.getLastKnownLocation(provider);if(loc==null){locating=false;locationMessage="최근 위치가 없습니다. 잠시 후 다시 시도하세요"}else scope.launch{val address=withContext(Dispatchers.IO){try{Geocoder(ctx,Locale.KOREA).getFromLocation(loc.latitude,loc.longitude,1)?.firstOrNull()}catch(_:Exception){null}};address?.adminArea?.let{on(it)};district=address?.subAdminArea?:address?.locality;locating=false}}
  }catch(_:SecurityException){locating=false;locationMessage="위치 권한이 필요합니다"}}
 val permissionLauncher=rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()){result->if(result.values.any{it})locate()else locationMessage="위치 권한이 거부되었습니다. 지역을 직접 선택할 수 있습니다."}
 Card(colors=CardDefaults.cardColors(containerColor=Ink),shape=RoundedCornerShape(26.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){Text("현재 업무 지역",color=Mint,fontSize=12.sp,fontWeight=FontWeight.Bold);Text("$selected${district?.let{" · $it"}?:""}",color=Color.White,fontSize=24.sp,fontWeight=FontWeight.Black);Button({if(ContextCompat.checkSelfPermission(ctx,Manifest.permission.ACCESS_COARSE_LOCATION)==PackageManager.PERMISSION_GRANTED)locate()else permissionLauncher.launch(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION,Manifest.permission.ACCESS_FINE_LOCATION))},Modifier.fillMaxWidth(),enabled=!locating){if(locating)CircularProgressIndicator(Modifier.size(18.dp),strokeWidth=2.dp)else Text("⌖ 내 위치로 지역 연결")};locationMessage?.let{Text(it,fontSize=11.sp,color=Color.White.copy(.75f))}}}
 Text("직접 선택",fontWeight=FontWeight.Black);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){regions.map{it.name}.distinct().forEach{name->FilterChip(selected==name,{district=null;prefs.edit().remove("district").apply();on(name)},{Text(name)})}}
 OutlinedButton({showMap=!showMap},Modifier.fillMaxWidth()){Text(if(showMap)"행정경계 지도 닫기" else "행정경계 지도에서 선택")}
 if(showMap)AdministrativeBoundaryMap(selected,district){province,city->district=city;prefs.edit().putString("district",city).apply();on(province)}
 Text("기본 화면에서는 경계 지도를 불러오지 않아 렉을 줄입니다. 위치 좌표는 저장하지 않고 변환된 행정구역명만 날씨·방역·TOP3·위젯에 사용합니다.",fontSize=11.sp,color=Color.Gray)
}
@Composable fun SettingSwitch(title:String,sub:String,checked:Boolean,on:(Boolean)->Unit){Surface(color=Color.White,shape=RoundedCornerShape(18.dp)){Row(Modifier.fillMaxWidth().padding(14.dp),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text(title,fontWeight=FontWeight.Black);Text(sub,fontSize=11.sp,color=Color.Gray)};Switch(checked,on)}}}
fun requestNotify(ctx:Context){if(android.os.Build.VERSION.SDK_INT>=33&&ctx is ComponentActivity&&ContextCompat.checkSelfPermission(ctx,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)ctx.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),77)}
@Composable fun SourceNote(text:String){Surface(color=Color(0xFFFFF4DF),shape=RoundedCornerShape(15.dp)){Text(text,Modifier.padding(12.dp),fontSize=11.sp,lineHeight=16.sp,color=Color(0xFF6C4B18))}}
fun formatDay(s:String)=parseDay(s)?.toString()?.replace("-",".") ?: "기준일 확인 필요"
fun formatAxis(s:String)=if(s.length>=6)"${s.take(4)}.${s.substring(4,6)}" else s
fun shortTime(s:String)=if(s.length>=16)s.substring(11,16) else "시각 확인중"

class SyncWorker(ctx:Context,params:WorkerParameters):CoroutineWorker(ctx,params){override suspend fun doWork():Result=try{
 val data=DataRepository.load(applicationContext)
 val prefs=applicationContext.getSharedPreferences("todaypig",Context.MODE_PRIVATE)
 if(data.error==null){
  val priceKey="${data.pig.date}:${data.pig.price}"
  if(prefs.getBoolean("price_alert",false)&&data.pig.price!=null&&prefs.getString("notified_price",null)!=priceKey){
   if(notify(applicationContext,"돈가 정보가 갱신됐습니다","${formatDay(data.pig.date)} 기준 ${comma(data.pig.price)}원/kg",1001))prefs.edit().putString("notified_price",priceKey).apply()
  }
  val official=data.diseases.filter{it.level==EvidenceLevel.OFFICIAL&&it.scope=="국내"}
  val seen=prefs.getStringSet("seen_disease",emptySet())!!.toMutableSet()
  val fresh=official.filter{it.url+it.summary !in seen}
  if(prefs.getBoolean("disease_alert",false)&&fresh.isNotEmpty()){
   if(notify(applicationContext,"국내 공식 질병·방역 소식",fresh.first().summary,2001)) { seen.addAll(fresh.map{it.url+it.summary});prefs.edit().putStringSet("seen_disease",seen.toList().takeLast(500).toSet()).apply() }
  }
 }
 checkFeedReminder(applicationContext)
 if(data.error!=null)Result.retry()else Result.success()
}catch(_:Exception){Result.retry()}}
fun scheduleBackgroundSync(ctx:Context){val req=PeriodicWorkRequestBuilder<SyncWorker>(1,TimeUnit.HOURS).setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build();WorkManager.getInstance(ctx).enqueueUniquePeriodicWork("todaypig-sync",ExistingPeriodicWorkPolicy.KEEP,req);WorkManager.getInstance(ctx).enqueueUniquePeriodicWork("dondon-feed",ExistingPeriodicWorkPolicy.KEEP,PeriodicWorkRequestBuilder<FeedReminderWorker>(1,TimeUnit.HOURS).build())}
fun notify(ctx:Context,title:String,text:String,idNum:Int):Boolean{
 if(android.os.Build.VERSION.SDK_INT>=33&&ContextCompat.checkSelfPermission(ctx,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return false
 val nm=ctx.getSystemService(Context.NOTIFICATION_SERVICE)as NotificationManager
 if(!nm.areNotificationsEnabled())return false
 val id="dondon_updates";nm.createNotificationChannel(NotificationChannel(id,"돈돈해 주요 알림",NotificationManager.IMPORTANCE_DEFAULT))
 val intent=android.app.PendingIntent.getActivity(ctx,idNum,Intent(ctx,MainActivity::class.java),android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT)
 nm.notify(idNum,NotificationCompat.Builder(ctx,id).setSmallIcon(R.drawable.ic_notification).setContentTitle(title).setContentText(text.take(100)).setStyle(NotificationCompat.BigTextStyle().bigText(text)).setContentIntent(intent).setAutoCancel(true).build());return true
}
