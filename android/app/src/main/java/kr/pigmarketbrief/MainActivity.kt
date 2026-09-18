package kr.pigmarketbrief

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import kotlinx.coroutines.Dispatchers
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
private val Ink=Color(0xFF14201B);private val Forest=Color(0xFF0E5A43);private val Mint=Color(0xFFBFE8D1);private val Paper=Color(0xFFF5F7F3);private val Amber=Color(0xFFE9A23B);private val Blue=Color(0xFF3976D2);private val Red=Color(0xFFC14949)
fun comma(v:Int)=NumberFormat.getIntegerInstance(Locale.KOREA).format(v)

data class PigPrice(val date:String="",val price:Int?=null,val previous:Int?=null,val change:Int?=null,val changePct:Double?=null,val monthAverage:Int?=null,val previousMonth:Int?=null,val lastYearMonth:Int?=null,val status:String="집계중",val updatedAt:String="")
data class HistPoint(val date:String,val price:Int)
data class RegionBrief(val name:String,val min:Double?,val max:Double?,val humidity:Double?,val rain:Double?,val risks:List<String>,val checks:List<String>)
data class DiseaseAlert(val disease:String,val source:String,val level:EvidenceLevel,val summary:String,val url:String)
data class GradePrice(val grade:String,val price:Int?)
data class AppData(val pig:PigPrice=PigPrice(),val history:List<HistPoint> = emptyList(),val regions:List<RegionBrief> = emptyList(),val diseases:List<DiseaseAlert> = emptyList(),val grades:List<GradePrice> = emptyList(),val jeju:List<Triple<String,String,String>> = emptyList(),val stale:Boolean=false,val error:String?=null)
data class FarmRecord(val at:String,val stage:String,val weight:Double?,val days:Int?,val fcr:Double?,val mortality:Double?,val intake:Double?,val symptom:String,val action:String,val result:String)

object DataRepository{
 suspend fun load(ctx:Context):AppData=withContext(Dispatchers.IO){
  val client=OkHttpClient.Builder().cache(Cache(File(ctx.cacheDir,"http"),12L*1024*1024)).connectTimeout(8,TimeUnit.SECONDS).readTimeout(12,TimeUnit.SECONDS).build()
  fun get(name:String):String?=try{client.newCall(Request.Builder().url("$DATA_ROOT/$name").build()).execute().use{if(it.isSuccessful)it.body?.string()else null}}catch(_:Exception){null}
  val priceRaw=get("pig-price.json");val historyRaw=get("pig-price-history.json");val briefRaw=get("briefing.json");val diseaseRaw=get("disease-alerts.json");val gradeRaw=get("pig-grade-detail.json");val jejuRaw=get("kape-jeju.json")
  if(priceRaw==null&&historyRaw==null)return@withContext AppData(error="공식 데이터 서버에 연결할 수 없습니다. 저장된 기록은 계속 사용할 수 있습니다.")
  try{
   val p=JSONObject(priceRaw?:"{}")
   fun pos(name:String)=p.optInt(name,0).takeIf{it>0}
   val pig=PigPrice(p.optString("date"),pos("price"),pos("previousPrice"),if(p.has("change"))p.optInt("change") else null,if(p.has("changePct"))p.optDouble("changePct") else null,pos("monthAverage"),pos("previousMonthAverage"),pos("lastYearMonthAverage"),p.optString("displayStatus",p.optString("status","집계중")),p.optString("updatedAt"))
   val hs=mutableListOf<HistPoint>();JSONObject(historyRaw?:"{}").optJSONArray("rows")?.let{a->for(i in 0 until a.length()){val x=a.getJSONObject(i);if(x.optInt("price")>0)hs+=HistPoint(x.optString("date"),x.optInt("price"))}}
   val rs=mutableListOf<RegionBrief>()
   JSONObject(briefRaw?:"{}").optJSONArray("regions")?.let{a->for(i in 0 until a.length()){
    val x=a.getJSONObject(i)
    fun arr(name:String)=x.optJSONArray(name)?.let{z->List(z.length()){j->z.optString(j)}}?: emptyList()
    fun number(name:String)=x.optDouble(name).takeUnless{it.isNaN()}
    rs+=RegionBrief(x.optString("region"),number("tempMin"),number("tempMax"),number("humidityMax"),number("rainProbabilityMax"),arr("riskFactors"),arr("top3"))
   }}
   val ds=mutableListOf<DiseaseAlert>();JSONObject(diseaseRaw?:"{}").optJSONArray("items")?.let{a->for(i in 0 until a.length()){val x=a.getJSONObject(i);val raw=x.optString("evidenceLevel",x.optString("level"));val lv=when{raw.contains("공식")||raw=="OFFICIAL"->EvidenceLevel.OFFICIAL;raw.contains("관찰")->EvidenceLevel.FARM_OBSERVATION;else->EvidenceLevel.PUBLIC_UNCONFIRMED};ds+=DiseaseAlert(x.optString("disease"),x.optString("source"),lv,x.optString("summary"),x.optString("sourceUrl"))}}
   val gs=mutableListOf<GradePrice>();val go=JSONObject(gradeRaw?:"{}").optJSONObject("prices");go?.keys()?.forEachRemaining{k->gs+=GradePrice(k,go.optDouble(k).roundToInt().takeIf{it>0})}
   val js=mutableListOf<Triple<String,String,String>>();JSONObject(jejuRaw?:"{}").optJSONArray("rows")?.let{a->for(i in 0 until a.length()){val x=a.getJSONObject(i);js+=Triple(x.optString("gradeName"),x.optString("publicTotPrice","집계중"),x.optString("blackTotPrice","집계중"))}}
   ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE).edit().putInt("widget_price",pig.price?:0).putInt("widget_change",pig.change?:0).putString("widget_date",pig.date).putLong("last_success",System.currentTimeMillis()).apply()
   PigPriceWidget.updateAll(ctx)
   AppData(pig,hs,rs,ds,gs,js,stale=false)
  }catch(e:Exception){AppData(error="데이터 형식을 확인하는 중 문제가 생겼습니다: ${e.message}")}
 }
}

class MainActivity:ComponentActivity(){
 override fun onCreate(savedInstanceState:Bundle?){
  super.onCreate(savedInstanceState)
  scheduleBackgroundSync(this)
  setContent { TodayPigTheme { TodayPigApp() } }
 }
}
@Composable fun TodayPigTheme(content: @Composable () -> Unit){
 MaterialTheme(colorScheme=lightColorScheme(primary=Forest,onPrimary=Color.White,secondary=Amber,background=Paper,surface=Color.White,onSurface=Ink,error=Red),content=content)
}

@Composable fun TodayPigApp(){
 val ctx=LocalContext.current;val prefs=remember{ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE)};var tab by remember{mutableIntStateOf(0)};var data by remember{mutableStateOf<AppData?>(null)};var loading by remember{mutableStateOf(true)};var region by remember{mutableStateOf(prefs.getString("region","경상북도")?:"경상북도")}
 suspend fun refresh(){loading=true;data=DataRepository.load(ctx);loading=false}
 LaunchedEffect(Unit){refresh()}
 Scaffold(containerColor=Paper,bottomBar={NavigationBar(containerColor=Color.White,tonalElevation=0.dp){listOf("오늘","가격","행동","기록","설정").forEachIndexed{i,s->NavigationBarItem(tab==i,{tab=i},{Text(listOf("●","↗","✓","▤","⚙")[i],fontWeight=FontWeight.Black)},label={Text(s,fontSize=11.sp)})}}}){pad->
  Column(Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState())){
   AppBar(region){tab=4}
   if(loading&&data==null)LoadingState() else if(data?.error!=null&&data?.pig?.price==null)ErrorState(data!!.error!!){loading=true} else when(tab){0->TodayScreen(data?:AppData(),region,{tab=it});1->MarketScreen(data?:AppData());2->ActionScreen(data?:AppData(),region);3->RecordsScreen();else->SettingsScreen(data?:AppData(),region){region=it;prefs.edit().putString("region",it).apply()}}
   Spacer(Modifier.height(24.dp))
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
@Composable fun PriceChart(rows:List<HistPoint>,period:String){val shown=when(period){"일간"->rows.takeLast(14);"주간"->rows.takeLast(49).chunked(7).mapNotNull{g->if(g.isEmpty())null else HistPoint(g.last().date,g.map{it.price}.average().roundToInt())};"월간"->monthAverages(rows).takeLast(12);else->monthAverages(rows).takeLast(36)};Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp)){Text(period,fontWeight=FontWeight.Black);if(shown.size<2)Text("공식 확정 데이터가 더 쌓이면 표시됩니다",Modifier.padding(vertical=30.dp),color=Color.Gray)else{val values=shown.map{it.price.toFloat()};val lo=values.minOrNull()?:0f;val hi=values.maxOrNull()?:1f;Canvas(Modifier.fillMaxWidth().height(190.dp).padding(vertical=16.dp)){for(i in 0..3)drawLine(Color(0xFFE5E9E5),Offset(0f,size.height*i/3),Offset(size.width,size.height*i/3),1f);val path=Path();values.forEachIndexed{i,v->val x=if(values.size==1)0f else size.width*i/(values.size-1);val y=size.height-(v-lo)/(hi-lo).coerceAtLeast(1f)*size.height;if(i==0)path.moveTo(x,y)else path.lineTo(x,y)};drawPath(path,Forest,style=Stroke(5f));drawCircle(Amber,8f,Offset(size.width,size.height-(values.last()-lo)/(hi-lo).coerceAtLeast(1f)*size.height))};Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){shown.filterIndexed{i,_->i==0||i==shown.lastIndex||i==shown.size/2}.forEach{Text(formatAxis(it.date),fontSize=10.sp,color=Color.Gray)}}}}}}
fun monthAverages(rows:List<HistPoint>)=rows.groupBy{it.date.take(6)}.toSortedMap().map{HistPoint(it.key,it.value.map{v->v.price}.average().roundToInt())}
@Composable fun CompareGrid(p:PigPrice){Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){CompareCell("전월 평균",p.previousMonth,p.monthAverage);CompareCell("전년 동월",p.lastYearMonth,p.monthAverage);CompareCell("현재월 평균",p.monthAverage,p.price)}}
@Composable fun RowScope.CompareCell(label:String,base:Int?,now:Int?){Surface(Modifier.weight(1f),color=Color.White,shape=RoundedCornerShape(16.dp)){Column(Modifier.padding(12.dp)){Text(label,fontSize=10.sp,color=Color.Gray);Text(base?.let{comma(it)}?:"집계중",fontWeight=FontWeight.Black,fontSize=14.sp);if(base!=null&&now!=null)Text("${if(now-base>=0)"+" else ""}${comma(now-base)}",fontSize=10.sp,color=if(now-base>=0)Red else Blue)}}}
@Composable fun GradePanel(grades:List<GradePrice>){Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFE7F2EC)),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(17.dp)){Text("등급별 상세",fontSize=18.sp,fontWeight=FontWeight.Black);Text("1+ / 1 / 2 / 등외",fontSize=11.sp,color=Color.Gray);if(grades.isEmpty())Text("최근 확정값 집계중",Modifier.padding(top=12.dp),fontWeight=FontWeight.Bold)else grades.sortedBy{listOf("1+","1","2","등외").indexOf(it.grade)}.forEach{Row(Modifier.fillMaxWidth().padding(top=9.dp),horizontalArrangement=Arrangement.SpaceBetween){Text(it.grade);Text(it.price?.let{v->"${comma(v)}원/kg"}?:"집계중",fontWeight=FontWeight.Black)}}}}}

@Composable fun ActionScreen(d:AppData,region:String){var stage by remember{mutableStateOf("비육")};var cough by remember{mutableStateOf(false)};var diarrhea by remember{mutableStateOf(false)};var intake by remember{mutableStateOf(false)};var mortality by remember{mutableStateOf(false)};val r=d.regions.firstOrNull{it.name==region};val official=d.diseases.any{it.level==EvidenceLevel.OFFICIAL&&it.summary.contains(region.take(2))};val cards=FarmDecisionEngine.evaluate(FarmContext(region,stage,r?.min,r?.max,r?.humidity,r?.risks?.isNotEmpty()==true,cough,diarrhea,intake,mortality,official,d.pig.changePct));Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){Text("오늘의 행동",fontSize=32.sp,fontWeight=FontWeight.Black);Text("진단이 아니라 관찰→측정→조정→재평가 경로입니다",color=Color.Gray);Text("돈군 단계",fontWeight=FontWeight.Black);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("분만","포유자돈","이유자돈","자돈","육성","비육").forEach{FilterChip(stage==it,{stage=it},{Text(it)})}};Text("농장 관찰",fontWeight=FontWeight.Black);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("기침" to cough,"설사" to diarrhea,"섭취저하" to intake,"폐사증가" to mortality).forEach{(n,v)->FilterChip(v,{when(n){"기침"->cough=!cough;"설사"->diarrhea=!diarrhea;"섭취저하"->intake=!intake;else->mortality=!mortality}},{Text(n)})}};cards.forEachIndexed{i,c->DecisionDetail(i+1,c)};DiseaseList(d.diseases)}}
@Composable fun DecisionDetail(rank:Int,c:DecisionCard){var open by remember{mutableStateOf(rank==1)};Card(Modifier.fillMaxWidth().clickable{open=!open},shape=RoundedCornerShape(24.dp),colors=CardDefaults.cardColors(containerColor=if(rank==1)Ink else Color.White)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(9.dp)){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){EvidenceBadge(c.evidence);Text("우선순위 $rank · ${c.score}",fontSize=11.sp,color=if(rank==1)Mint else Forest,fontWeight=FontWeight.Black)};Text(c.title,fontSize=20.sp,fontWeight=FontWeight.Black,color=if(rank==1)Color.White else Ink);Text(c.why.joinToString(" · "),fontSize=12.sp,color=if(rank==1)Color.White.copy(.7f)else Color.Gray);if(open){HorizontalDivider(color=if(rank==1)Color.White.copy(.16f)else Color.LightGray);StepLine("1 관찰",c.observe.joinToString(" · "),rank==1);StepLine("2 측정",c.measure.joinToString(" · "),rank==1);StepLine("3 먼저 조정",c.firstAdjustment,rank==1);StepLine("4 지속 시 감별",c.differentials.joinToString(" · "),rank==1);StepLine("전문가 연결",c.escalation,rank==1)}}}}
@Composable fun StepLine(title:String,body:String,dark:Boolean){Column{Text(title,fontSize=11.sp,fontWeight=FontWeight.Black,color=if(dark)Mint else Forest);Text(body,fontSize=13.sp,lineHeight=19.sp,color=if(dark)Color.White else Ink)}}
@Composable fun DiseaseList(items:List<DiseaseAlert>){Text("질병·방역",fontSize=22.sp,fontWeight=FontWeight.Black);if(items.isEmpty())Text("수집된 공개정보가 없습니다.",color=Color.Gray);items.take(8).forEach{x->Surface(color=Color.White,shape=RoundedCornerShape(18.dp)){Column(Modifier.padding(14.dp)){EvidenceBadge(x.level);Text(x.disease,Modifier.padding(top=7.dp),fontWeight=FontWeight.Black);Text(x.summary,fontSize=12.sp,maxLines=3,overflow=TextOverflow.Ellipsis);Text(x.source,fontSize=10.sp,color=Color.Gray)}};};SourceNote("공식 확인과 공개정보·확인중은 합쳐 표시하지 않습니다. 앱은 질병을 확정 진단하거나 처방하지 않습니다.")}

@Composable fun RecordsScreen(){var page by remember{mutableStateOf("기록")};Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){Text("농장 기록",fontSize=32.sp,fontWeight=FontWeight.Black);SingleChoiceSegmentedButtonRow{listOf("기록","예상 정산","성과").forEachIndexed{i,s->SegmentedButton(page==s,{page=s},SegmentedButtonDefaults.itemShape(i,3)){Text(s)}}};when(page){"기록"->RecordForm();"예상 정산"->Settlement();else->Performance()}}}
@Composable fun RecordForm(){val ctx=LocalContext.current;var stage by remember{mutableStateOf("비육")};var weight by remember{mutableStateOf("")};var days by remember{mutableStateOf("")};var fcr by remember{mutableStateOf("")};var mortality by remember{mutableStateOf("")};var intake by remember{mutableStateOf("")};var symptom by remember{mutableStateOf("")};var action by remember{mutableStateOf("")};var result by remember{mutableStateOf("")};var saved by remember{mutableStateOf(false)};Text("한 번 기록하면 다음 위험평가의 기준이 됩니다",color=Color.Gray);SimpleField("돈군 단계",stage){stage=it};Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("출하체중 kg",weight){weight=it}};Box(Modifier.weight(1f)){SimpleField("출하일령",days){days=it}}};Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("FCR",fcr){fcr=it}};Box(Modifier.weight(1f)){SimpleField("폐사율 %",mortality){mortality=it}}};SimpleField("사료섭취량 kg",intake){intake=it};SimpleField("관찰한 증상",symptom){symptom=it};SimpleField("조치내용",action){action=it};SimpleField("조치결과",result){result=it};Button({saveRecord(ctx,FarmRecord(LocalDateTime.now().toString(),stage,weight.toDoubleOrNull(),days.toIntOrNull(),fcr.toDoubleOrNull(),mortality.toDoubleOrNull(),intake.toDoubleOrNull(),symptom,action,result));saved=true},Modifier.fillMaxWidth()){Text(if(saved)"저장됨" else "기록 저장")};SourceNote("기록은 이 기기에 저장됩니다. 익명 실증 제공은 별도 동의를 받기 전까지 꺼져 있습니다.")}
@Composable fun SimpleField(label:String,value:String,on:(String)->Unit){OutlinedTextField(value,on,Modifier.fillMaxWidth(),label={Text(label)},singleLine=true,shape=RoundedCornerShape(14.dp))}
fun saveRecord(ctx:Context,r:FarmRecord){val p=ctx.getSharedPreferences("records",Context.MODE_PRIVATE);val a=try{JSONArray(p.getString("rows","[]"))}catch(_:Exception){JSONArray()};a.put(JSONObject().put("at",r.at).put("stage",r.stage).put("weight",r.weight).put("days",r.days).put("fcr",r.fcr).put("mortality",r.mortality).put("intake",r.intake).put("symptom",r.symptom).put("action",r.action).put("result",r.result));p.edit().putString("rows",a.toString()).apply()}
@Composable fun Settlement(){
 val ctx=LocalContext.current
 val price=ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE).getInt("widget_price",0)
 var rate by remember{mutableStateOf("78")};var low by remember{mutableStateOf("0")};var anti by remember{mutableStateOf("0")};var weight by remember{mutableStateOf("90")};var heads by remember{mutableStateOf("1")}
 fun number(value:String)=value.toDoubleOrNull()?:0.0
 val total=price*(number(rate)+number(low)+number(anti))/100*number(weight)*number(heads)
 Card(colors=CardDefaults.cardColors(containerColor=Ink),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp)){Text("KAPE 기준가격",color=Mint,fontWeight=FontWeight.Bold);Text(if(price>0)"${comma(price)}원/kg" else "집계중",fontSize=32.sp,fontWeight=FontWeight.Black,color=Color.White);Text("예상 정산 ${comma(total.roundToInt())}원",fontSize=22.sp,fontWeight=FontWeight.Black,color=Color.White)}}
 SimpleField("농가/계약 기본 지급률 %",rate){rate=it};SimpleField("저탄소 인증 가산 %p",low){low=it};SimpleField("무항생제 인증 가산 %p",anti){anti=it}
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("도체중 kg",weight){weight=it}};Box(Modifier.weight(1f)){SimpleField("출하두수",heads){heads=it}}}
 SourceNote("지급률과 인증 가산은 전국 공통값이 아닙니다. 반드시 농가·계약별 기준을 직접 입력하고 실제 정산서와 대조하세요.")
}
@Composable fun Performance(){val ctx=LocalContext.current;val a=try{JSONArray(ctx.getSharedPreferences("records",Context.MODE_PRIVATE).getString("rows","[]"))}catch(_:Exception){JSONArray()};Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(18.dp)){Text("기록 ${a.length()}건",fontSize=24.sp,fontWeight=FontWeight.Black);Text("FCR·폐사율·출하일령은 동일 기준의 기록이 2건 이상 쌓이면 전후 변화로 표시됩니다.",color=Color.Gray);Text("추천 수행률 · 조기발견시간 · 대응시간도 동의한 익명 실증에서 산식과 함께 추적할 수 있도록 설계했습니다.",Modifier.padding(top=12.dp),fontSize=12.sp)}}}

@Composable fun SettingsScreen(d:AppData,selected:String,onRegion:(String)->Unit){val ctx=LocalContext.current;val prefs=remember{ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE)};var priceAlert by remember{mutableStateOf(prefs.getBoolean("price_alert",true))};var diseaseAlert by remember{mutableStateOf(prefs.getBoolean("disease_alert",true))};var consent by remember{mutableStateOf(prefs.getBoolean("research_consent",false))};Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)){Text("지역과 설정",fontSize=32.sp,fontWeight=FontWeight.Black);RegionSelector(selected,onRegion,d.regions);Text("알림",fontSize=20.sp,fontWeight=FontWeight.Black);SettingSwitch("돈가 갱신·주요 변동","백그라운드 정기 확인",priceAlert){priceAlert=it;prefs.edit().putBoolean("price_alert",it).apply();requestNotify(ctx)};SettingSwitch("공식 질병·지역 방역","공식/확인중을 구분해 표시",diseaseAlert){diseaseAlert=it;prefs.edit().putBoolean("disease_alert",it).apply();requestNotify(ctx)};SourceNote("Android 백그라운드 작업은 운영체제가 실행시각을 조정할 수 있어 즉시 알림을 보장하지 않습니다. 현재 버전은 정기 확인이며, 운영 서버와 FCM 연결 시에만 푸시 알림으로 전환됩니다.");Text("개인정보와 실증",fontSize=20.sp,fontWeight=FontWeight.Black);SettingSwitch("익명 실증 데이터 제공","명시 동의 전에는 외부 전송 없음",consent){consent=it;prefs.edit().putBoolean("research_consent",it).apply()};OutlinedButton({ctx.getSharedPreferences("records",Context.MODE_PRIVATE).edit().clear().apply()},Modifier.fillMaxWidth()){Text("농장 기록 모두 삭제")};SourceNote("최소수집 · 목적별 동의 · 철회/삭제를 기본으로 합니다. 농장명과 정확한 위치는 필수 수집하지 않습니다.");Text("데이터 상태",fontSize=20.sp,fontWeight=FontWeight.Black);Text("돈가 ${formatDay(d.pig.date)} · 질병 ${d.diseases.size}건 · 가격이력 ${d.history.size}건",fontSize=12.sp)}}
@Composable fun RegionSelector(selected:String,on:(String)->Unit,regions:List<RegionBrief>){val names=(regions.map{it.name}+listOf("서울특별시","부산광역시","대구광역시","인천광역시","광주광역시","대전광역시","울산광역시","세종특별자치시","경기도","강원특별자치도","충청북도","충청남도","전북특별자치도","전라남도","경상북도","경상남도","제주특별자치도")).distinct();KoreaMap(selected,on);Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){names.forEach{FilterChip(selected==it,{on(it)},{Text(it.replace("특별자치도","").replace("광역시","").replace("특별시",""))})}}}
@Composable fun KoreaMap(selected:String,on:(String)->Unit){val spots=listOf("경기도" to Pair(.38f,.18f),"강원특별자치도" to Pair(.64f,.16f),"충청남도" to Pair(.32f,.38f),"충청북도" to Pair(.55f,.35f),"전북특별자치도" to Pair(.38f,.56f),"경상북도" to Pair(.68f,.48f),"전라남도" to Pair(.32f,.75f),"경상남도" to Pair(.59f,.69f),"제주특별자치도" to Pair(.34f,.91f));Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFE7F2EC)),shape=RoundedCornerShape(24.dp)){BoxWithConstraints(Modifier.fillMaxWidth().height(360.dp)){Canvas(Modifier.matchParentSize().padding(24.dp)){val p=Path();p.moveTo(size.width*.34f,size.height*.04f);p.cubicTo(size.width*.55f,0f,size.width*.8f,size.height*.15f,size.width*.75f,size.height*.34f);p.cubicTo(size.width*.85f,size.height*.5f,size.width*.68f,size.height*.57f,size.width*.67f,size.height*.74f);p.cubicTo(size.width*.53f,size.height*.9f,size.width*.28f,size.height*.86f,size.width*.24f,size.height*.68f);p.cubicTo(size.width*.12f,size.height*.56f,size.width*.27f,size.height*.46f,size.width*.2f,size.height*.31f);p.cubicTo(size.width*.2f,size.height*.18f,size.width*.34f,size.height*.15f,size.width*.34f,size.height*.04f);drawPath(p,Color.White);drawPath(p,Forest.copy(.45f),style=Stroke(3f));drawOval(Color.White,Offset(size.width*.23f,size.height*.91f),Size(size.width*.25f,size.height*.045f))};spots.forEach{(name,pos)->Surface(Modifier.offset(maxWidth*pos.first-22.dp,360.dp*pos.second-13.dp).clickable{on(name)},color=if(selected==name)Forest else Color.White,shape=RoundedCornerShape(10.dp),shadowElevation=2.dp){Text(name.take(2),Modifier.padding(horizontal=7.dp,vertical=5.dp),fontSize=10.sp,color=if(selected==name)Color.White else Ink,fontWeight=FontWeight.Black)}}}}}
@Composable fun SettingSwitch(title:String,sub:String,checked:Boolean,on:(Boolean)->Unit){Surface(color=Color.White,shape=RoundedCornerShape(18.dp)){Row(Modifier.fillMaxWidth().padding(14.dp),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text(title,fontWeight=FontWeight.Black);Text(sub,fontSize=11.sp,color=Color.Gray)};Switch(checked,on)}}}
fun requestNotify(ctx:Context){if(android.os.Build.VERSION.SDK_INT>=33&&ctx is ComponentActivity&&ContextCompat.checkSelfPermission(ctx,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)ctx.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),77)}
@Composable fun SourceNote(text:String){Surface(color=Color(0xFFFFF4DF),shape=RoundedCornerShape(15.dp)){Text(text,Modifier.padding(12.dp),fontSize=11.sp,lineHeight=16.sp,color=Color(0xFF6C4B18))}}
fun formatDay(s:String)=if(s.length>=8)"${s.take(4)}.${s.substring(4,6)}.${s.substring(6,8)}" else "확인중"
fun formatAxis(s:String)=if(s.length>=6)"${s.take(4)}.${s.substring(4,6)}" else s
fun shortTime(s:String)=if(s.length>=16)s.substring(11,16) else "시각 확인중"

class SyncWorker(ctx:Context,params:WorkerParameters):CoroutineWorker(ctx,params){override suspend fun doWork():Result=try{val before=applicationContext.getSharedPreferences("todaypig",Context.MODE_PRIVATE).getInt("widget_price",0);val data=DataRepository.load(applicationContext);if(data.error!=null)Result.retry()else{val after=data.pig.price?:0;if(after>0&&before>0&&after!=before)notify(applicationContext,"돈가 갱신","전국 대표 돈가 ${comma(after)}원/kg · 앱에서 기준일을 확인하세요.",1001);val official=data.diseases.firstOrNull{it.level==EvidenceLevel.OFFICIAL};if(official!=null)notify(applicationContext,"공식 질병정보 · ${official.disease}",official.summary,2001);Result.success()}}catch(_:Exception){Result.retry()}}
fun scheduleBackgroundSync(ctx:Context){val req=PeriodicWorkRequestBuilder<SyncWorker>(1,TimeUnit.HOURS).setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build();WorkManager.getInstance(ctx).enqueueUniquePeriodicWork("todaypig-sync",ExistingPeriodicWorkPolicy.UPDATE,req)}
fun notify(ctx:Context,title:String,text:String,idNum:Int){if(android.os.Build.VERSION.SDK_INT>=33&&ContextCompat.checkSelfPermission(ctx,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return;val nm=ctx.getSystemService(Context.NOTIFICATION_SERVICE)as NotificationManager;val id="todaypig_updates";if(android.os.Build.VERSION.SDK_INT>=26)nm.createNotificationChannel(NotificationChannel(id,"오늘돈가 주요 알림",NotificationManager.IMPORTANCE_DEFAULT));nm.notify(idNum,NotificationCompat.Builder(ctx,id).setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title).setContentText(text.take(100)).setStyle(NotificationCompat.BigTextStyle().bigText(text)).setAutoCancel(true).build())}
