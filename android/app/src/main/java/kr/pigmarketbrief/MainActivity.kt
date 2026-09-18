package kr.pigmarketbrief

import android.os.Bundle
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import java.util.concurrent.TimeUnit
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

private const val DATA_ROOT="https://noah981.github.io/pig-market-brief/data"
data class RegionBrief(val name:String,val min:Double,val max:Double,val humidity:Double,val rain:Double,val risks:List<String>,val checks:List<String>)
data class JejuPrice(val grade:String,val all:String,val normal:String,val black:String)
fun comma(s:String):String=s.toIntOrNull()?.let{java.text.NumberFormat.getIntegerInstance(java.util.Locale.KOREA).format(it)}?:s

data class PigPrice(val date:String="",val price:Int=0,val previousPrice:Int=0,val change:Int=0,val changePct:Double=0.0,val monthAverage:Int=0,val previousMonthAverage:Int=0,val previousMonthChange:Int=0,val lastYearMonthAverage:Int=0,val lastYearChange:Int=0)
data class HistPoint(val date:String,val price:Int)
data class MarketFactor(val title:String,val status:String,val detail:String)
data class DiseaseAlert(val disease:String,val source:String,val summary:String)
data class GradeField(val name:String,val value:Double)
data class AppData(val updated:String="",val gradeFields:List<GradeField> = emptyList(),val regions:List<RegionBrief> = emptyList(),val prices:List<JejuPrice> = emptyList(),val pig:PigPrice=PigPrice(),val history:List<HistPoint> = emptyList(),val marketSummary:String="",val marketFactors:List<MarketFactor> = emptyList(),val diseaseAlerts:List<DiseaseAlert> = emptyList(),val error:String?=null)

suspend fun loadData():AppData=withContext(Dispatchers.IO){
 try{
  val c=OkHttpClient()
  fun get(name:String)=c.newCall(Request.Builder().url("$DATA_ROOT/$name").build()).execute().use { r -> if(!r.isSuccessful) error("$name HTTP "+r.code); r.body!!.string() }
  fun optional(name:String):String? = try { get(name) } catch(e:Exception) { null }
  val gd=JSONObject(optional("pig-grade-detail.json") ?: "{\"rawFields\":{}}"); val disease=JSONObject(optional("disease-alerts.json") ?: "{\"items\":[]}"); val b=JSONObject(optional("briefing.json") ?: "{\"regions\":[],\"updatedAt\":\"\"}"); val k=JSONObject(optional("kape-jeju.json") ?: "{\"rows\":[]}") ; val p=JSONObject(optional("pig-price.json") ?: "{}"); val h=JSONObject(optional("pig-price-history.json") ?: "{\"rows\":[]}") ; val m=JSONObject(optional("market-analysis.json") ?: "{\"summary\":\"\",\"factors\":[]}")
  val rs=mutableListOf<RegionBrief>(); val a=b.getJSONArray("regions")
  for(i in 0 until a.length()){ val x=a.getJSONObject(i); fun arr(n:String)=x.optJSONArray(n)?.let{z->List(z.length()){j->z.getString(j)}}?: emptyList()
   rs+=RegionBrief(x.getString("region"),x.optDouble("tempMin"),x.optDouble("tempMax"),x.optDouble("humidityMax"),x.optDouble("rainProbabilityMax"),arr("riskFactors"),arr("top3"))
  }
  val ps=mutableListOf<JejuPrice>(); val rows=k.optJSONArray("rows")
  if(rows!=null) for(i in 0 until rows.length()){val x=rows.getJSONObject(i);ps+=JejuPrice(x.optString("gradeName"),x.optString("totPrice","-"),x.optString("publicTotPrice","-"),x.optString("blackTotPrice","-"))}
  val ha=h.optJSONArray("rows"); val hs=mutableListOf<HistPoint>(); if(ha!=null) for(i in 0 until ha.length()){val x=ha.getJSONObject(i);hs+=HistPoint(x.optString("date"),x.optInt("price"))}
  val mf=mutableListOf<MarketFactor>(); val ma=m.optJSONArray("factors"); if(ma!=null) for(i in 0 until ma.length()){val x=ma.getJSONObject(i);mf+=MarketFactor(x.optString("title"),x.optString("status"),x.optString("detail"))}
  val gf=mutableListOf<GradeField>();val gfo=gd.optJSONObject("rawFields");if(gfo!=null){gfo.keys().forEachRemaining{k->gf+=GradeField(k,gfo.optDouble(k))}};val da=mutableListOf<DiseaseAlert>();val dia=disease.optJSONArray("items");if(dia!=null)for(i in 0 until dia.length()){val x=dia.getJSONObject(i);da+=DiseaseAlert(x.optString("disease"),x.optString("source"),x.optString("summary"))};AppData(b.optString("updatedAt"),gf,rs,ps,PigPrice(p.optString("date"),p.optInt("price"),p.optInt("previousPrice"),p.optInt("change"),p.optDouble("changePct"),p.optInt("monthAverage"),p.optInt("previousMonthAverage"),p.optInt("previousMonthChange"),p.optInt("lastYearMonthAverage"),p.optInt("lastYearChange")),hs,m.optString("summary"),mf,da)
 }catch(e:Exception){AppData(error=e.message)}
}

class MainActivity:ComponentActivity(){override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);if(android.os.Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(this,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),77);scheduleDiseaseWorker(this);setContent{
 MaterialTheme(colorScheme=lightColorScheme(primary=Color(0xFFFF4F78),secondary=Color(0xFF3478D4),background=Color(0xFFFFFBFC),surface=Color.White,surfaceVariant=Color(0xFFFFF1F5))){BriefingApp()}
}}}

lateinit var LocalAppContext:Context
@Composable fun BriefingApp(){
 LocalAppContext=LocalContext.current
 var tab by remember{mutableIntStateOf(0)}; var data by remember{mutableStateOf<AppData?>(null)}; var selected by remember{mutableStateOf("경상북도")}
 LaunchedEffect(Unit){data=loadData();val x=data;if(x!=null)notifyNewDiseaseAlerts(LocalAppContext,x.diseaseAlerts)}
 Scaffold(containerColor=Color(0xFFFFFBFC),bottomBar={NavigationBar(containerColor=Color.White){listOf("홈","시황","농장점검","지역").forEachIndexed{i,t->NavigationBarItem(selected = tab == i, onClick = { tab = i }, icon = {}, label = { Text(t,fontSize=10.sp) })}}}){pad->
  Column(Modifier.padding(pad).padding(horizontal=18.dp,vertical=16.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(16.dp)){
   HeroHeader()
   when{data==null->CircularProgressIndicator();data!!.error!=null->Column(verticalArrangement=Arrangement.spacedBy(8.dp)){Text("데이터를 불러오지 못했습니다.",style=MaterialTheme.typography.titleMedium);Text("잠시 후 다시 실행해 주세요.");Text(data!!.error!!,style=MaterialTheme.typography.bodySmall)}
    tab==0->Home(data!!,selected){tab=it};tab==1->Market(data!!);tab==2->Checklist(data!!,selected);else->Region(data!!,selected){selected=it}}
  }
 }
}
@Composable fun HeroHeader(){val now=java.time.LocalDateTime.now();val ds=now.format(java.time.format.DateTimeFormatter.ofPattern("yyyy년 M월 d일 (E) HH:mm",java.util.Locale.KOREAN));Box(Modifier.fillMaxWidth().height(150.dp)){Column(Modifier.align(Alignment.TopStart).padding(top=22.dp)){Row(verticalAlignment=Alignment.CenterVertically){PigLogo(43.dp);Spacer(Modifier.width(8.dp));Text("오늘",fontSize=32.sp,fontWeight=FontWeight.Black);Text("돈가",fontSize=32.sp,fontWeight=FontWeight.Black,color=Color(0xFFFF3D68))};Text("양돈의 오늘, 농가의 내일",fontSize=12.sp,color=Color(0xFF66636B))};Text(ds,Modifier.align(Alignment.TopEnd),fontSize=11.sp,fontWeight=FontWeight.Bold);PigPortrait(Modifier.align(Alignment.CenterEnd).padding(top=30.dp,end=18.dp).size(105.dp));Column(Modifier.align(Alignment.BottomEnd).padding(end=5.dp,bottom=8.dp),horizontalAlignment=Alignment.End){Text("건강한 돼지,",fontSize=12.sp,fontWeight=FontWeight.Bold);Text("더 큰 내일",fontSize=14.sp,fontWeight=FontWeight.Black);HorizontalDivider(Modifier.width(58.dp),color=Color(0xFFFF4F78),thickness=2.dp)}}}

@Composable fun PigLogo(s:androidx.compose.ui.unit.Dp){Canvas(Modifier.size(s)){val pink=Color(0xFFFF4F78);drawOval(pink,Offset(size.width*.15f,size.height*.23f),Size(size.width*.7f,size.height*.62f),style=Stroke(4f));drawCircle(pink,size.width*.08f,Offset(size.width*.42f,size.height*.58f));drawCircle(pink,size.width*.08f,Offset(size.width*.58f,size.height*.58f));drawLine(pink,Offset(size.width*.2f,size.height*.28f),Offset(size.width*.12f,size.height*.08f),5f);drawLine(pink,Offset(size.width*.8f,size.height*.28f),Offset(size.width*.88f,size.height*.08f),5f)}}
@Composable fun PigPortrait(modifier:Modifier=Modifier){Canvas(modifier){val skin=Color(0xFFFFC7C8);val shade=Color(0xFFF2A9AC);drawOval(Color(0xFFFFE5E6),Offset(size.width*.04f,size.height*.04f),Size(size.width*.92f,size.height*.92f));val ear=Path().apply{moveTo(size.width*.18f,size.height*.34f);lineTo(size.width*.03f,size.height*.06f);lineTo(size.width*.37f,size.height*.18f);close()};drawPath(ear,skin);val ear2=Path().apply{moveTo(size.width*.82f,size.height*.34f);lineTo(size.width*.97f,size.height*.06f);lineTo(size.width*.63f,size.height*.18f);close()};drawPath(ear2,skin);drawOval(skin,Offset(size.width*.2f,size.height*.13f),Size(size.width*.6f,size.height*.72f));drawCircle(Color(0xFF2E2729),size.width*.035f,Offset(size.width*.39f,size.height*.43f));drawCircle(Color(0xFF2E2729),size.width*.035f,Offset(size.width*.61f,size.height*.43f));drawOval(shade,Offset(size.width*.33f,size.height*.55f),Size(size.width*.34f,size.height*.22f));drawCircle(Color(0xFF6C4C50),size.width*.025f,Offset(size.width*.44f,size.height*.65f));drawCircle(Color(0xFF6C4C50),size.width*.025f,Offset(size.width*.56f,size.height*.65f))}}
fun monthlyAverage(rows:List<HistPoint>):List<HistPoint>{return rows.filter{x->x.date.length>=6&&x.price>0}.groupBy{x->x.date.take(6)}.toSortedMap().map{entry->HistPoint(entry.key, kotlin.math.round(entry.value.map{x->x.price}.average()).toInt())}}
fun monthLabel(date:String):String=if(date.length>=6) date.substring(4,6).toIntOrNull()?.let{x->x.toString()+"월"}?:date else date
@Composable fun LabeledPriceChart(points:List<HistPoint>,period:String){val v=points.map{x->x.price.toFloat()};val lo=(v.minOrNull()?:0f);val hi=(v.maxOrNull()?:1f);val range=(hi-lo).coerceAtLeast(1f);Column(verticalArrangement=Arrangement.spacedBy(8.dp)){Canvas(Modifier.fillMaxWidth().height(155.dp)){for(i in 0..3){val y=size.height*i/3;drawLine(Color(0xFFF1E8EB),Offset(0f,y),Offset(size.width,y),1.5f)};val p=Path();v.forEachIndexed{i,n->val x=if(v.size==1)size.width/2 else size.width*i/(v.size-1);val y=size.height-16-(n-lo)/range*(size.height-32);if(i==0)p.moveTo(x,y)else p.lineTo(x,y);drawCircle(Color.White,7f,Offset(x,y));drawCircle(Color(0xFFFF3D6E),7f,Offset(x,y),style=Stroke(4f))};drawPath(p,Color(0xFFFF3D6E),style=Stroke(5f))};if(period=="월간"||period=="연간"){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){points.forEach{x->Text(monthLabel(x.date),fontSize=10.sp,color=Color(0xFF74717B))}};Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(12.dp)){points.forEach{x->Surface(color=Color(0xFFFFF1F5),shape=RoundedCornerShape(12.dp)){Text(monthLabel(x.date)+" "+comma(x.price.toString())+"원",Modifier.padding(horizontal=9.dp,vertical=6.dp),fontSize=11.sp,fontWeight=FontWeight.Bold,color=Color(0xFFFF3D6E))}}}}else{Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){points.takeLast(7).forEach{x->Text(x.date.takeLast(4),fontSize=10.sp,color=Color(0xFF74717B))}}};Text("축산유통정보(KAPE) 경락가격 기준",fontSize=10.sp,color=Color(0xFF8A8790))}}
@Composable fun CompareBox(title:String,value:Int,diff:Int,modifier:Modifier){Card(modifier,colors=CardDefaults.cardColors(containerColor=Color(0xFFF8F6F7)),shape=RoundedCornerShape(14.dp)){Column(Modifier.padding(9.dp)){Text(title,fontSize=10.sp,color=Color(0xFF74717B));Text(if(value>0)comma(value.toString())+"원" else "-",fontSize=13.sp,fontWeight=FontWeight.Black);if(diff!=0)Text((if(diff>0)"▲ " else "▼ ")+comma(kotlin.math.abs(diff).toString())+"원",fontSize=11.sp,fontWeight=FontWeight.Bold,color=if(diff>0)Color(0xFFFF4F78) else Color(0xFF3478D4))}}}
@Composable fun GradeDetailPanel(d:AppData){Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF7F9)),shape=RoundedCornerShape(18.dp)){Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(7.dp)){Text("등급별 경락가격 상세",fontSize=17.sp,fontWeight=FontWeight.Black);Text("1+ · 1 · 2 · 등외 · 축산물품질평가원 원자료",fontSize=11.sp,color=Color(0xFF74717B));if(d.gradeFields.isEmpty())Text("상세가격 업데이트 중") else d.gradeFields.take(12).forEach{Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text(it.name,fontSize=12.sp);Text(comma(kotlin.math.round(it.value).toInt().toString())+"원",fontWeight=FontWeight.Bold)}}}}}
@Composable fun Home(d:AppData,selected:String,onNavigate:(Int)->Unit){
 var period by remember{mutableStateOf("월간")};var gradeOpen by remember{mutableStateOf(false)}
 val chartPoints=when(period){"일간"->d.history.takeLast(2);"주간"->d.history.takeLast(7);"월간"->monthlyAverage(d.history);"연간"->monthlyAverage(d.history);else->d.history}
 val r=d.regions.firstOrNull{it.name==selected}?:d.regions.firstOrNull()
 Card(modifier=Modifier.clickable{gradeOpen=!gradeOpen},colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(30.dp),elevation=CardDefaults.cardElevation(6.dp)){Column(Modifier.padding(22.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
  Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Column{Text("전국 돈가 (제주 제외)",fontSize=24.sp,fontWeight=FontWeight.Black);Text("단위: 원/kg (탕박) · 경락가격을 누르면 등급별 상세",fontSize=11.sp,color=Color(0xFF74717B))};Surface(color=Color(0xFFEDF6FF),shape=RoundedCornerShape(15.dp)){Text(if(d.pig.change<0)"▮▮▮ 전일 대비 하락" else "▮▮▮ 전일 대비 상승",Modifier.padding(horizontal=11.dp,vertical=8.dp),color=if(d.pig.change<0)Color(0xFF1876D2) else Color(0xFFFF3D68),fontWeight=FontWeight.Black,fontSize=11.sp)}}
  if(d.pig.price>0){Text(comma(d.pig.price.toString())+" 원/kg",fontSize=50.sp,fontWeight=FontWeight.Black);Text((if(d.pig.change<0)"▼ " else "▲ ")+kotlin.math.abs(d.pig.change)+"원 ("+String.format("%.2f",kotlin.math.abs(d.pig.changePct))+"%)",color=if(d.pig.change<0)Color(0xFF3478D4) else Color(0xFFFF4F78),fontSize=18.sp,fontWeight=FontWeight.Bold);Surface(color=if(d.pig.change<0)Color(0xFFEDF6FF) else Color(0xFFFFF1F5),shape=RoundedCornerShape(16.dp)){Text("전일 "+comma(d.pig.previousPrice.toString())+"원 · "+(if(d.pig.change<0)"시장 조정 구간을 확인하세요." else "상승 흐름을 확인하세요."),Modifier.fillMaxWidth().padding(14.dp),fontWeight=FontWeight.Bold)}} else {Text("가격 업데이트 중",fontSize=28.sp,fontWeight=FontWeight.Black);Text("확인되지 않은 가격은 표시하지 않습니다.",color=Color(0xFF74717B))}
  if(d.pig.monthAverage>0){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(7.dp)){CompareBox("이번달 평균",d.pig.monthAverage,0,Modifier.weight(1f));CompareBox("전월 대비",d.pig.previousMonthAverage,d.pig.previousMonthChange,Modifier.weight(1f));CompareBox("전년 동월",d.pig.lastYearMonthAverage,d.pig.lastYearChange,Modifier.weight(1f))}};if(chartPoints.size>1) LabeledPriceChart(chartPoints,period) else Box(Modifier.fillMaxWidth().height(105.dp),contentAlignment=Alignment.Center){Text("가격 추이 업데이트 중",color=Color(0xFF74717B))}
  if(gradeOpen){GradeDetailPanel(d)};Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("일간","주간","월간","연간").forEach{s->Surface(color=if(period==s)Color(0xFFFF4F78) else Color(0xFFF6F2F3),shape=RoundedCornerShape(30.dp),modifier=Modifier.weight(1f).clickable{period=s}){Text(s,Modifier.padding(vertical=8.dp),textAlign=androidx.compose.ui.text.style.TextAlign.Center,color=if(period==s)Color.White else Color(0xFF74717B),fontSize=12.sp,fontWeight=FontWeight.Bold)}}}
 }}
 Text("오늘 필요한 정보",fontSize=22.sp,fontWeight=FontWeight.Black)
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(10.dp)){HomeShortcut("▥","시황 보기","2026년 연간 평균 돈가와 시장 동향을 확인하세요.",Color(0xFFFFF1F5),Color(0xFFFF4F78),Modifier.weight(1f)){onNavigate(1)};HomeShortcut("☀","오늘 날씨",selected+" 지역 날씨와 농장 관리 유의사항을 확인하세요.",Color(0xFFEDF6FF),Color(0xFF3478D4),Modifier.weight(1f)){onNavigate(3)}}
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(10.dp)){HomeShortcut("✓","농장점검","계절별 점검 항목으로 내 농장을 더 건강하게 관리하세요.",Color(0xFFEEF9F3),Color(0xFF198754),Modifier.weight(1f)){onNavigate(2)};HomeShortcut("●","지역 선택","지도로 지역을 선택하고 해당 지역 정보를 확인하세요.",Color(0xFFFFF5E9),Color(0xFFE58B2A),Modifier.weight(1f)){onNavigate(3)}}
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text("양돈 이슈 & 오늘 브리핑",fontSize=19.sp,fontWeight=FontWeight.Black);if(r!=null){Text("날씨  ·  "+selected+" "+r.min.toInt()+"~"+r.max.toInt()+"℃ · 강수 "+r.rain.toInt()+"%",color=Color(0xFF3478D4),fontWeight=FontWeight.Bold);Text("농장  ·  "+(r.checks.firstOrNull()?:"기본관리 항목을 확인하세요."),fontWeight=FontWeight.Bold);if(r.risks.isNotEmpty())Text("주의  ·  "+r.risks.joinToString(" · "),color=Color(0xFFE58B2A),fontWeight=FontWeight.Bold)}else Text("지역 데이터 업데이트 중")}}
 if(d.updated.isNotBlank())Text("업데이트 "+d.updated.take(16).replace("T"," "),fontSize=11.sp,color=Color(0xFF74717B))
}
@Composable fun HomeShortcut(icon:String,title:String,sub:String,bg:Color,accent:Color,modifier:Modifier,onClick:()->Unit){Card(modifier.clickable{onClick()},colors=CardDefaults.cardColors(containerColor=bg),shape=RoundedCornerShape(22.dp),elevation=CardDefaults.cardElevation(1.dp)){Column(Modifier.padding(16.dp).heightIn(min=112.dp),verticalArrangement=Arrangement.spacedBy(7.dp)){Text(icon,fontSize=22.sp,fontWeight=FontWeight.Black,color=accent);Text(title,fontSize=18.sp,fontWeight=FontWeight.Black,color=accent);Text(sub,fontSize=12.sp,lineHeight=17.sp)}}}
@Composable fun HistoryChart(points:List<HistPoint>){val v=points.map{it.price.toFloat()};val lo=v.minOrNull()?:0f;val hi=v.maxOrNull()?:1f;val range=(hi-lo).coerceAtLeast(1f);Canvas(Modifier.fillMaxWidth().height(150.dp)){for(i in 0..3){val y=size.height*i/3;drawLine(Color(0xFFF1E8EB),Offset(0f,y),Offset(size.width,y),1.5f)};val p=Path();v.forEachIndexed{i,n->val x=size.width*i/(v.size-1);val y=size.height-10-(n-lo)/range*(size.height-20);if(i==0)p.moveTo(x,y)else p.lineTo(x,y)};drawPath(p,Color(0xFFFF4F78),style=Stroke(5f));drawCircle(Color(0xFFFF4F78),8f,Offset(size.width,size.height-10-(v.last()-lo)/range*(size.height-20)))}}
@Composable fun Market(d:AppData){
 Text("시황",fontSize=27.sp,fontWeight=FontWeight.Black);Text("가격뿐 아니라 움직인 배경까지 확인합니다.",color=Color(0xFF74717B))
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(24.dp)){Column(Modifier.fillMaxWidth().padding(20.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){Text("전국 돈가 · 제주 제외",fontWeight=FontWeight.Bold,color=Color(0xFF74717B));Text(comma(d.pig.price.toString())+" 원/kg",fontSize=38.sp,fontWeight=FontWeight.Black);Text((if(d.pig.change<0)"▼ " else "▲ ")+kotlin.math.abs(d.pig.change)+"원 ("+String.format("%.2f",kotlin.math.abs(d.pig.changePct))+"%)",color=if(d.pig.change<0)Color(0xFF3478D4) else Color(0xFFFF4F78),fontWeight=FontWeight.Black,fontSize=18.sp)}}
 Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF1F5)),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(9.dp)){Text("오늘 돈가, 왜 움직였나",fontSize=20.sp,fontWeight=FontWeight.Black,color=Color(0xFFFF4F78));Text(if(d.marketSummary.isBlank())"원인 분석 데이터 업데이트 중" else d.marketSummary,lineHeight=21.sp);d.marketFactors.forEach{x->Column(verticalArrangement=Arrangement.spacedBy(3.dp)){Row(verticalAlignment=Alignment.CenterVertically){Surface(color=when(x.status){"확인"->Color(0xFFEDF6FF);"체크"->Color(0xFFFFF5E9);else->Color(0xFFEEF9F3)},shape=RoundedCornerShape(20.dp)){Text(x.status,Modifier.padding(horizontal=8.dp,vertical=4.dp),fontSize=11.sp,fontWeight=FontWeight.Bold)};Spacer(Modifier.width(8.dp));Text(x.title,fontWeight=FontWeight.Black)};Text(x.detail,fontSize=13.sp,color=Color(0xFF55515B),lineHeight=19.sp);HorizontalDivider(color=Color(0xFFFFE4EA))}}}}
 Text("가격 추이",fontSize=20.sp,fontWeight=FontWeight.Black);Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(18.dp)){if(d.history.size>1)HistoryChart(d.history.takeLast(30)) else Text("가격 이력 업데이트 중");Text("축산물품질평가원 · 탕박 · 제주 제외",fontSize=11.sp,color=Color(0xFF74717B))}}
 Text("제주 시세 · 별도",fontSize=20.sp,fontWeight=FontWeight.Black);d.prices.take(5).forEach{Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(18.dp)){Row(Modifier.fillMaxWidth().padding(14.dp),horizontalArrangement=Arrangement.SpaceBetween){Text(it.grade+" 등급",fontWeight=FontWeight.Bold);Text("백 "+comma(it.normal)+" · 흑 "+comma(it.black),fontWeight=FontWeight.Black,color=Color(0xFFFF4F78))}}}
}
@Composable fun SettlementCalculator(kapePrice:Int){
 val ctx=LocalContext.current
 val prefs=remember{ctx.getSharedPreferences("settlement",Context.MODE_PRIVATE)}
 var base by remember{mutableStateOf(prefs.getFloat("base",78f).toString())}
 var low by remember{mutableStateOf(prefs.getFloat("low",0f).toString())}
 var anti by remember{mutableStateOf(prefs.getFloat("anti",0f).toString())}
 var lowOn by remember{mutableStateOf(false)};var antiOn by remember{mutableStateOf(false)}
 var weight by remember{mutableStateOf("90")};var heads by remember{mutableStateOf("1")}
 var alertOn by remember{mutableStateOf(prefs.getBoolean("alert",false))}
 fun num(s:String)=s.toDoubleOrNull()?:0.0
 val rate=num(base)+(if(lowOn)num(low) else 0.0)+(if(antiOn)num(anti) else 0.0)
 val perKg=kapePrice*rate/100.0;val total=perKg*num(weight)*num(heads)
 Text("농가 예상 정산",fontSize=27.sp,fontWeight=FontWeight.Black)
 Text("KAPE 기준 돈가 × 농가 지급률 + 인증 가산",color=Color(0xFF74717B))
 Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF1F5)),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp)){Text("오늘 KAPE 기준",fontWeight=FontWeight.Bold);Text(comma(kapePrice.toString())+" 원/kg",fontSize=34.sp,fontWeight=FontWeight.Black,color=Color(0xFFFF4F78));Text("인증 가산은 계약 기준을 직접 입력하세요.",fontSize=12.sp,color=Color(0xFF74717B))}}
 NumberField("기본 지급률 (%)",base){base=it}
 Row(verticalAlignment=Alignment.CenterVertically){Switch(lowOn,{lowOn=it});Text("저탄소 인증",Modifier.weight(1f),fontWeight=FontWeight.Bold);Box(Modifier.width(115.dp)){NumberField("가산 %p",low){low=it}}}
 Row(verticalAlignment=Alignment.CenterVertically){Switch(antiOn,{antiOn=it});Text("무항생제 인증",Modifier.weight(1f),fontWeight=FontWeight.Bold);Box(Modifier.width(115.dp)){NumberField("가산 %p",anti){anti=it}}}
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){NumberField("도체중 kg",weight){weight=it}};Box(Modifier.weight(1f)){NumberField("출하두수",heads){heads=it}}}
 Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFEEF9F3)),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp)){Text("최종 지급률 "+String.format("%.2f",rate)+"%",fontWeight=FontWeight.Black);Text("예상 정산단가 "+comma(kotlin.math.round(perKg).toInt().toString())+" 원/kg",fontSize=21.sp,fontWeight=FontWeight.Black,color=Color(0xFF198754));Text("예상 총 정산액 "+comma(kotlin.math.round(total).toInt().toString())+" 원",fontSize=18.sp,fontWeight=FontWeight.Black)}}
 Button(onClick={prefs.edit().putFloat("base",num(base).toFloat()).putFloat("low",num(low).toFloat()).putFloat("anti",num(anti).toFloat()).apply()},modifier=Modifier.fillMaxWidth()){Text("지급 기준 저장")}
 Text("알림 설정",fontSize=21.sp,fontWeight=FontWeight.Black)
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(16.dp)){Row(verticalAlignment=Alignment.CenterVertically){Switch(alertOn,{alertOn=it;prefs.edit().putBoolean("alert",it).apply();if(it)showTestPriceNotification(ctx,kapePrice)});Text("돈가 · ASF 등 질병 알림",Modifier.padding(start=8.dp),fontWeight=FontWeight.Black)};OutlinedButton(onClick={showTestPriceNotification(ctx,kapePrice)},modifier=Modifier.fillMaxWidth()){Text("알림 테스트")}}}
}
@Composable fun NumberField(label:String,value:String,onValue:(String)->Unit){OutlinedTextField(value=value,onValueChange={x->onValue(x.filter{ch->ch.isDigit()||ch=='.'})},label={Text(label)},singleLine=true,modifier=Modifier.fillMaxWidth())}
fun notifyNewDiseaseAlerts(ctx:Context,alerts:List<DiseaseAlert>){if(alerts.isEmpty())return;val prefs=ctx.getSharedPreferences("settlement",Context.MODE_PRIVATE);if(!prefs.getBoolean("alert",false))return;val key=alerts.first().disease+"|"+alerts.first().summary.hashCode();if(prefs.getString("lastDisease","")==key)return;val nm=ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager;val id="disease_alert";if(android.os.Build.VERSION.SDK_INT>=26)nm.createNotificationChannel(NotificationChannel(id,"가축질병 긴급알림",NotificationManager.IMPORTANCE_HIGH));if(android.os.Build.VERSION.SDK_INT<33||ContextCompat.checkSelfPermission(ctx,Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED){nm.notify(2001,NotificationCompat.Builder(ctx,id).setSmallIcon(android.R.drawable.ic_dialog_alert).setContentTitle("가축질병 알림 · "+alerts.first().disease).setContentText(alerts.first().summary.take(90)).setStyle(NotificationCompat.BigTextStyle().bigText(alerts.first().summary)).setPriority(NotificationCompat.PRIORITY_HIGH).setAutoCancel(true).build());prefs.edit().putString("lastDisease",key).apply()}}
fun showTestPriceNotification(ctx:Context,price:Int){val nm=ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager;val id="pig_price";if(android.os.Build.VERSION.SDK_INT>=26)nm.createNotificationChannel(NotificationChannel(id,"오늘돈가 알림",NotificationManager.IMPORTANCE_DEFAULT));if(android.os.Build.VERSION.SDK_INT<33||ContextCompat.checkSelfPermission(ctx,Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED){nm.notify(1001,NotificationCompat.Builder(ctx,id).setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle("오늘돈가 업데이트").setContentText("KAPE 기준 "+comma(price.toString())+"원/kg · 앱에서 시황을 확인하세요.").setAutoCancel(true).build())}}
@Composable fun Checklist(d:AppData,selected:String){val r=d.regions.firstOrNull{it.name==selected};Text("농장 정밀점검",fontSize=27.sp,fontWeight=FontWeight.Black);Text(selected+" · 구간별로 확인하고 주의/불량을 남기세요.",color=Color(0xFF74717B));val sections=listOf("급이·사료" to listOf("급이기 막힘·브리징","사료 허실·바닥 낙하","사료 변질·곰팡이·냄새","사료 전환 시점·섭취량"),"음수" to listOf("니플 작동·유량","급수기 높이·접근성","수질·배관 오염","더운 시간대 음수상태"),"환기·환경" to listOf("돈사 온도·일교차","최소환기·팬 작동","암모니아·가스·결로","밀사·바닥 습도"),"질병·위생" to listOf("기침·호흡기 증상","설사·분변 상태","위축돈·폐사 증가","차량·사람·물품 방역"),"모돈·분만" to listOf("모돈 BCS","포유돈 섭취량","변비·음수","포유자돈 보온·설사"),"자돈" to listOf("입질사료 접근성","초기 섭취량","보온·온도","돈군 균일도"),"육성·비육·출하" to listOf("일당증체·섭취량","출하체중·출하일령","폐사율","FCR·사료효율"));var bad by remember{mutableIntStateOf(0)};sections.forEach{sec->Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(9.dp)){Text(sec.first,fontSize=18.sp,fontWeight=FontWeight.Black,color=Color(0xFF198754));sec.second.forEach{item->var state by remember(item){mutableStateOf("미확인")};Column{Text(item,fontWeight=FontWeight.Bold);Row(horizontalArrangement=Arrangement.spacedBy(5.dp)){listOf("양호","주의","불량").forEach{x->FilterChip(selected=state==x,onClick={state=x},label={Text(x,fontSize=11.sp)})}}}}}}};if(r!=null&&r.checks.isNotEmpty())Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF5E9)),shape=RoundedCornerShape(20.dp)){Column(Modifier.padding(16.dp)){Text("오늘 기상 연동 우선점검",fontWeight=FontWeight.Black,color=Color(0xFFE58B2A));r.checks.forEach{Text("• "+it,fontSize=13.sp)}}};Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFEEF9F3)),shape=RoundedCornerShape(20.dp)){Text("기록 항목 · 출하체중 · 출하일령 · FCR · 폐사율 · 사료섭취량 · 질병증상 · 개선조치",Modifier.padding(16.dp),color=Color(0xFF198754),fontWeight=FontWeight.Bold)}}
@Composable fun Region(d:AppData,selected:String,onSelect:(String)->Unit){Text("지역 선택",fontSize=27.sp,fontWeight=FontWeight.Black);Text("지도에서 시·도를 선택하면 해당 지역의 날씨와 농장 관리 정보를 보여줍니다.",color=Color(0xFF74717B));val spots=listOf(Triple("서울특별시",.34f,.18f),Triple("인천광역시",.23f,.20f),Triple("경기도",.39f,.24f),Triple("강원특별자치도",.65f,.18f),Triple("충청북도",.53f,.37f),Triple("충청남도",.31f,.42f),Triple("대전광역시",.43f,.48f),Triple("세종특별자치시",.39f,.39f),Triple("경상북도",.68f,.48f),Triple("대구광역시",.66f,.58f),Triple("전북특별자치도",.36f,.59f),Triple("광주광역시",.27f,.70f),Triple("전라남도",.31f,.77f),Triple("경상남도",.57f,.70f),Triple("울산광역시",.76f,.64f),Triple("부산광역시",.69f,.73f),Triple("제주특별자치도",.35f,.92f));Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFF4F8FC)),shape=RoundedCornerShape(28.dp)){BoxWithConstraints(Modifier.fillMaxWidth().height(510.dp).padding(12.dp)){Canvas(Modifier.matchParentSize()){val p=Path();p.moveTo(size.width*.36f,size.height*.08f);p.lineTo(size.width*.66f,size.height*.08f);p.lineTo(size.width*.82f,size.height*.27f);p.lineTo(size.width*.78f,size.height*.57f);p.lineTo(size.width*.68f,size.height*.77f);p.lineTo(size.width*.48f,size.height*.84f);p.lineTo(size.width*.29f,size.height*.76f);p.lineTo(size.width*.18f,size.height*.56f);p.lineTo(size.width*.22f,size.height*.31f);p.close();drawPath(p,Color(0xFFDDEBF7));drawPath(p,Color(0xFF8EABC4),style=Stroke(3f));drawOval(Color(0xFFDDEBF7),Offset(size.width*.25f,size.height*.88f),Size(size.width*.25f,size.height*.06f));};spots.forEach{x->val short=x.first.replace("특별자치도","").replace("광역시","").replace("특별시","");Surface(modifier=Modifier.offset(maxWidth*x.second-24.dp,510.dp*x.third-14.dp).clickable{onSelect(x.first)},color=if(selected==x.first)Color(0xFFFF4F78) else Color.White,shape=RoundedCornerShape(12.dp),shadowElevation=3.dp){Text(short,Modifier.padding(horizontal=7.dp,vertical=5.dp),fontSize=10.sp,fontWeight=FontWeight.Black,color=if(selected==x.first)Color.White else Color(0xFF35506B))}}}};val rr=d.regions.firstOrNull{it.name==selected};if(rr!=null){Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(24.dp),elevation=CardDefaults.cardElevation(3.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(9.dp)){Text(selected,fontSize=22.sp,fontWeight=FontWeight.Black);Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text("기온",color=Color.Gray);Text(rr.min.toInt().toString()+"~"+rr.max.toInt()+"℃",fontWeight=FontWeight.Black);Text("습도",color=Color.Gray);Text(rr.humidity.toInt().toString()+"%",fontWeight=FontWeight.Black)};Text("강수확률 "+rr.rain.toInt()+"%",fontWeight=FontWeight.Bold,color=Color(0xFF3478D4));if(rr.risks.isNotEmpty())Text("주의 · "+rr.risks.joinToString(" · "),color=Color(0xFFE58B2A),fontWeight=FontWeight.Bold);HorizontalDivider();Text("오늘 농장 관리",fontSize=17.sp,fontWeight=FontWeight.Black);rr.checks.forEach{Text("✓ "+it,fontSize=13.sp)}}}}}

class DiseaseWorker(ctx:Context,params:WorkerParameters):CoroutineWorker(ctx,params){
 override suspend fun doWork():Result=withContext(Dispatchers.IO){
  try{
   val body=OkHttpClient().newCall(Request.Builder().url("$DATA_ROOT/disease-alerts.json").cacheControl(okhttp3.CacheControl.FORCE_NETWORK).build()).execute().use{if(!it.isSuccessful) return@withContext Result.retry();it.body!!.string()}
   val root=JSONObject(body);val arr=root.optJSONArray("items")?:return@withContext Result.success();if(arr.length()==0)return@withContext Result.success()
   val x=arr.getJSONObject(0);val alert=DiseaseAlert(x.optString("disease"),x.optString("source"),x.optString("summary"));notifyNewDiseaseAlerts(applicationContext,listOf(alert));Result.success()
  }catch(e:Exception){Result.retry()}
 }
}
fun scheduleDiseaseWorker(ctx:Context){
 val req=PeriodicWorkRequestBuilder<DiseaseWorker>(15,TimeUnit.MINUTES).setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build()
 WorkManager.getInstance(ctx).enqueueUniquePeriodicWork("disease-fast-watch",ExistingPeriodicWorkPolicy.UPDATE,req)
}
