package kr.pigmarketbrief

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.compose.material3.*
import androidx.compose.runtime.*
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

data class PigPrice(val date:String="",val price:Int=0,val previousPrice:Int=0,val change:Int=0,val changePct:Double=0.0)
data class HistPoint(val date:String,val price:Int)
data class MarketFactor(val title:String,val status:String,val detail:String)
data class AppData(val updated:String="",val regions:List<RegionBrief> = emptyList(),val prices:List<JejuPrice> = emptyList(),val pig:PigPrice=PigPrice(),val history:List<HistPoint> = emptyList(),val marketSummary:String="",val marketFactors:List<MarketFactor> = emptyList(),val error:String?=null)

suspend fun loadData():AppData=withContext(Dispatchers.IO){
 try{
  val c=OkHttpClient()
  fun get(name:String)=c.newCall(Request.Builder().url("$DATA_ROOT/$name").build()).execute().use { r -> if(!r.isSuccessful) error("$name HTTP "+r.code); r.body!!.string() }
  fun optional(name:String):String? = try { get(name) } catch(e:Exception) { null }
  val b=JSONObject(optional("briefing.json") ?: "{\"regions\":[],\"updatedAt\":\"\"}"); val k=JSONObject(optional("kape-jeju.json") ?: "{\"rows\":[]}") ; val p=JSONObject(optional("pig-price.json") ?: "{}"); val h=JSONObject(optional("pig-price-history.json") ?: "{\"rows\":[]}") ; val m=JSONObject(optional("market-analysis.json") ?: "{\"summary\":\"\",\"factors\":[]}")
  val rs=mutableListOf<RegionBrief>(); val a=b.getJSONArray("regions")
  for(i in 0 until a.length()){ val x=a.getJSONObject(i); fun arr(n:String)=x.optJSONArray(n)?.let{z->List(z.length()){j->z.getString(j)}}?: emptyList()
   rs+=RegionBrief(x.getString("region"),x.optDouble("tempMin"),x.optDouble("tempMax"),x.optDouble("humidityMax"),x.optDouble("rainProbabilityMax"),arr("riskFactors"),arr("top3"))
  }
  val ps=mutableListOf<JejuPrice>(); val rows=k.optJSONArray("rows")
  if(rows!=null) for(i in 0 until rows.length()){val x=rows.getJSONObject(i);ps+=JejuPrice(x.optString("gradeName"),x.optString("totPrice","-"),x.optString("publicTotPrice","-"),x.optString("blackTotPrice","-"))}
  val ha=h.optJSONArray("rows"); val hs=mutableListOf<HistPoint>(); if(ha!=null) for(i in 0 until ha.length()){val x=ha.getJSONObject(i);hs+=HistPoint(x.optString("date"),x.optInt("price"))}
  val mf=mutableListOf<MarketFactor>(); val ma=m.optJSONArray("factors"); if(ma!=null) for(i in 0 until ma.length()){val x=ma.getJSONObject(i);mf+=MarketFactor(x.optString("title"),x.optString("status"),x.optString("detail"))}
  AppData(b.optString("updatedAt"),rs,ps,PigPrice(p.optString("date"),p.optInt("price"),p.optInt("previousPrice"),p.optInt("change"),p.optDouble("changePct")),hs,m.optString("summary"),mf)
 }catch(e:Exception){AppData(error=e.message)}
}

class MainActivity:ComponentActivity(){override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{
 MaterialTheme(colorScheme=lightColorScheme(primary=Color(0xFFFF4F78),secondary=Color(0xFF3478D4),background=Color(0xFFFFFBFC),surface=Color.White,surfaceVariant=Color(0xFFFFF1F5))){BriefingApp()}
}}}

@Composable fun BriefingApp(){
 var tab by remember{mutableIntStateOf(0)}; var data by remember{mutableStateOf<AppData?>(null)}; var selected by remember{mutableStateOf("경상북도")}
 LaunchedEffect(Unit){data=loadData()}
 Scaffold(containerColor=Color(0xFFFFFBFC),bottomBar={NavigationBar(containerColor=Color.White){listOf("홈","시황","농장점검","지역").forEachIndexed{i,t->NavigationBarItem(selected = tab == i, onClick = { tab = i }, icon = {}, label = { Text(t) })}}}){pad->
  Column(Modifier.padding(pad).padding(horizontal=18.dp,vertical=16.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(16.dp)){
   Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically){Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(10.dp)){Text("🐷",fontSize=36.sp);Column{Row{Text("오늘",fontSize=28.sp,fontWeight=FontWeight.Black);Text("돈가",fontSize=28.sp,fontWeight=FontWeight.Black,color=Color(0xFFFF4F78))};Text("양돈의 오늘, 농가의 내일",fontSize=13.sp,color=Color(0xFF74717B))}};Text("오늘",color=Color(0xFFFF4F78),fontWeight=FontWeight.Bold)}
   when{data==null->CircularProgressIndicator();data!!.error!=null->Column(verticalArrangement=Arrangement.spacedBy(8.dp)){Text("데이터를 불러오지 못했습니다.",style=MaterialTheme.typography.titleMedium);Text("잠시 후 다시 실행해 주세요.");Text(data!!.error!!,style=MaterialTheme.typography.bodySmall)}
    tab==0->Home(data!!,selected){tab=it};tab==1->Market(data!!);tab==2->Checklist(data!!,selected);else->Region(data!!,selected){selected=it}}
  }
 }
}
@Composable fun Home(d:AppData,selected:String,onNavigate:(Int)->Unit){
 var period by remember{mutableStateOf("주간")}
 val chartPoints=when(period){"일간"->d.history.takeLast(2);"주간"->d.history.takeLast(7);"월간"->d.history.takeLast(30);else->d.history}
 val r=d.regions.firstOrNull{it.name==selected}?:d.regions.firstOrNull()
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(28.dp),elevation=CardDefaults.cardElevation(4.dp)){Column(Modifier.padding(22.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
  Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Column{Text("전국 돈가",fontSize=17.sp,fontWeight=FontWeight.Black);Text("제주 제외 · 원/kg (탕박)",fontSize=12.sp,color=Color(0xFF74717B))};Surface(color=Color(0xFFFFF1F5),shape=CircleShape){Text("LIVE",Modifier.padding(horizontal=12.dp,vertical=7.dp),color=Color(0xFFFF4F78),fontWeight=FontWeight.Black,fontSize=11.sp)}}
  if(d.pig.price>0){Text(comma(d.pig.price.toString())+" 원/kg",fontSize=40.sp,fontWeight=FontWeight.Black);Text((if(d.pig.change<0)"▼ " else "▲ ")+kotlin.math.abs(d.pig.change)+"원 ("+String.format("%.2f",kotlin.math.abs(d.pig.changePct))+"%)",color=if(d.pig.change<0)Color(0xFF3478D4) else Color(0xFFFF4F78),fontSize=18.sp,fontWeight=FontWeight.Bold);Surface(color=if(d.pig.change<0)Color(0xFFEDF6FF) else Color(0xFFFFF1F5),shape=RoundedCornerShape(16.dp)){Text((if(d.pig.change<0)"전일보다 낮습니다" else "전일보다 높습니다")+" · 전일 "+comma(d.pig.previousPrice.toString())+"원",Modifier.fillMaxWidth().padding(14.dp),fontWeight=FontWeight.Bold)}} else {Text("가격 업데이트 중",fontSize=28.sp,fontWeight=FontWeight.Black);Text("확인되지 않은 가격은 표시하지 않습니다.",color=Color(0xFF74717B))}
  if(chartPoints.size>1) HistoryChart(chartPoints) else Box(Modifier.fillMaxWidth().height(105.dp),contentAlignment=Alignment.Center){Text("가격 추이 업데이트 중",color=Color(0xFF74717B))}
  Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("일간","주간","월간","연간").forEach{s->Surface(color=if(period==s)Color(0xFFFF4F78) else Color(0xFFF6F2F3),shape=RoundedCornerShape(30.dp),modifier=Modifier.weight(1f).clickable{period=s}){Text(s,Modifier.padding(vertical=8.dp),textAlign=androidx.compose.ui.text.style.TextAlign.Center,color=if(period==s)Color.White else Color(0xFF74717B),fontSize=12.sp,fontWeight=FontWeight.Bold)}}}
 }}
 Text("오늘 필요한 정보",fontSize=21.sp,fontWeight=FontWeight.Black)
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(10.dp)){HomeShortcut("▥","시황 보기","돈가 흐름과 시장 동향",Color(0xFFFFF1F5),Color(0xFFFF4F78),Modifier.weight(1f)){onNavigate(1)};HomeShortcut("☀","오늘 날씨",selected+" 농장 기상",Color(0xFFEDF6FF),Color(0xFF3478D4),Modifier.weight(1f)){onNavigate(3)}}
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(10.dp)){HomeShortcut("✓","농장점검","오늘 확인할 TOP 3",Color(0xFFEEF9F3),Color(0xFF198754),Modifier.weight(1f)){onNavigate(2)};HomeShortcut("⌖","지역 선택","지역별 날씨와 위험",Color(0xFFFFF5E9),Color(0xFFE58B2A),Modifier.weight(1f)){onNavigate(3)}}
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text("양돈 이슈 & 오늘 브리핑",fontSize=19.sp,fontWeight=FontWeight.Black);if(r!=null){Text("날씨  ·  "+selected+" "+r.min.toInt()+"~"+r.max.toInt()+"℃ · 강수 "+r.rain.toInt()+"%",color=Color(0xFF3478D4),fontWeight=FontWeight.Bold);Text("농장  ·  "+(r.checks.firstOrNull()?:"기본관리 항목을 확인하세요."),fontWeight=FontWeight.Bold);if(r.risks.isNotEmpty())Text("주의  ·  "+r.risks.joinToString(" · "),color=Color(0xFFE58B2A),fontWeight=FontWeight.Bold)}else Text("지역 데이터 업데이트 중")}}
 if(d.updated.isNotBlank())Text("업데이트 "+d.updated.take(16).replace("T"," "),fontSize=11.sp,color=Color(0xFF74717B))
}
@Composable fun HomeShortcut(icon:String,title:String,sub:String,bg:Color,accent:Color,modifier:Modifier,onClick:()->Unit){Card(modifier.clickable{onClick()},colors=CardDefaults.cardColors(containerColor=bg),shape=RoundedCornerShape(22.dp),elevation=CardDefaults.cardElevation(1.dp)){Column(Modifier.padding(16.dp).heightIn(min=112.dp),verticalArrangement=Arrangement.spacedBy(7.dp)){Text(icon,fontSize=22.sp,fontWeight=FontWeight.Black,color=accent);Text(title,fontSize=18.sp,fontWeight=FontWeight.Black,color=accent);Text(sub,fontSize=12.sp,lineHeight=17.sp)}}}
@Composable fun HistoryChart(points:List<HistPoint>){val v=points.map{it.price.toFloat()};val lo=v.minOrNull()?:0f;val hi=v.maxOrNull()?:1f;val range=(hi-lo).coerceAtLeast(1f);Canvas(Modifier.fillMaxWidth().height(115.dp)){for(i in 0..3){val y=size.height*i/3;drawLine(Color(0xFFF1E8EB),Offset(0f,y),Offset(size.width,y),1.5f)};val p=Path();v.forEachIndexed{i,n->val x=size.width*i/(v.size-1);val y=size.height-10-(n-lo)/range*(size.height-20);if(i==0)p.moveTo(x,y)else p.lineTo(x,y)};drawPath(p,Color(0xFFFF4F78),style=Stroke(5f));drawCircle(Color(0xFFFF4F78),8f,Offset(size.width,size.height-10-(v.last()-lo)/range*(size.height-20)))}}
@Composable fun Market(d:AppData){
 Text("시황",fontSize=27.sp,fontWeight=FontWeight.Black);Text("가격뿐 아니라 움직인 배경까지 확인합니다.",color=Color(0xFF74717B))
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(24.dp)){Column(Modifier.fillMaxWidth().padding(20.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){Text("전국 돈가 · 제주 제외",fontWeight=FontWeight.Bold,color=Color(0xFF74717B));Text(comma(d.pig.price.toString())+" 원/kg",fontSize=38.sp,fontWeight=FontWeight.Black);Text((if(d.pig.change<0)"▼ " else "▲ ")+kotlin.math.abs(d.pig.change)+"원 ("+String.format("%.2f",kotlin.math.abs(d.pig.changePct))+"%)",color=if(d.pig.change<0)Color(0xFF3478D4) else Color(0xFFFF4F78),fontWeight=FontWeight.Black,fontSize=18.sp)}}
 Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF1F5)),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(9.dp)){Text("오늘 돈가, 왜 움직였나",fontSize=20.sp,fontWeight=FontWeight.Black,color=Color(0xFFFF4F78));Text(if(d.marketSummary.isBlank())"원인 분석 데이터 업데이트 중" else d.marketSummary,lineHeight=21.sp);d.marketFactors.forEach{x->Column(verticalArrangement=Arrangement.spacedBy(3.dp)){Row(verticalAlignment=Alignment.CenterVertically){Surface(color=when(x.status){"확인"->Color(0xFFEDF6FF);"체크"->Color(0xFFFFF5E9);else->Color(0xFFEEF9F3)},shape=RoundedCornerShape(20.dp)){Text(x.status,Modifier.padding(horizontal=8.dp,vertical=4.dp),fontSize=11.sp,fontWeight=FontWeight.Bold)};Spacer(Modifier.width(8.dp));Text(x.title,fontWeight=FontWeight.Black)};Text(x.detail,fontSize=13.sp,color=Color(0xFF55515B),lineHeight=19.sp);HorizontalDivider(color=Color(0xFFFFE4EA))}}}}
 Text("가격 추이",fontSize=20.sp,fontWeight=FontWeight.Black);Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(18.dp)){if(d.history.size>1)HistoryChart(d.history.takeLast(30)) else Text("가격 이력 업데이트 중");Text("축산물품질평가원 · 탕박 · 제주 제외",fontSize=11.sp,color=Color(0xFF74717B))}}
 Text("제주 시세 · 별도",fontSize=20.sp,fontWeight=FontWeight.Black);d.prices.take(5).forEach{Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(18.dp)){Row(Modifier.fillMaxWidth().padding(14.dp),horizontalArrangement=Arrangement.SpaceBetween){Text(it.grade+" 등급",fontWeight=FontWeight.Bold);Text("백 "+comma(it.normal)+" · 흑 "+comma(it.black),fontWeight=FontWeight.Black,color=Color(0xFFFF4F78))}}}
}
@Composable fun Checklist(d:AppData,selected:String){val r=d.regions.firstOrNull{it.name==selected};Text("농장점검",fontSize=27.sp,fontWeight=FontWeight.Black);Text(selected+" · 오늘 현장에서 먼저 볼 항목",color=Color(0xFF74717B));val items=(r?.checks?:listOf("급이·사료 상태","음수·급수기","환기·온습도")).take(3);items.forEachIndexed{i,s->var state by remember(s){mutableStateOf("미확인")};Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(17.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Row(verticalAlignment=Alignment.CenterVertically){Surface(color=Color(0xFF198754),shape=CircleShape){Text("${i+1}",Modifier.size(30.dp).wrapContentSize(),color=Color.White,fontWeight=FontWeight.Black)};Spacer(Modifier.width(10.dp));Text(s,Modifier.weight(1f),fontSize=16.sp,fontWeight=FontWeight.Bold)};Row(horizontalArrangement=Arrangement.spacedBy(7.dp)){listOf("양호","주의","불량").forEach{x->FilterChip(selected=state==x,onClick={state=x},label={Text(x)})}}}}};Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFEEF9F3)),shape=RoundedCornerShape(20.dp)){Text("기본 정밀점검 · 급이 · 음수 · 환기 · 질병 · 위생 · 모돈 · 자돈 · 출하 기록",Modifier.padding(16.dp),color=Color(0xFF198754),fontWeight=FontWeight.Bold)}}
@Composable fun Region(d:AppData,selected:String,onSelect:(String)->Unit){Text("지역 선택",fontSize=27.sp,fontWeight=FontWeight.Black);Text("대한민국 시·도를 선택해 농장 기상을 확인하세요.",color=Color(0xFF74717B));Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF4F7)),shape=RoundedCornerShape(28.dp)){Column(Modifier.fillMaxWidth().padding(18.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(12.dp)){Text("대한민국",fontSize=20.sp,fontWeight=FontWeight.Black);Text("●",fontSize=82.sp,color=Color(0xFFFFB7C8));Text("현재 선택 · "+selected,fontWeight=FontWeight.Black,color=Color(0xFFFF4F78));Text("아래 지역을 누르면 즉시 변경됩니다.",fontSize=12.sp,color=Color(0xFF74717B))}};val r=d.regions.firstOrNull{it.name==selected};if(r!=null)Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFEDF6FF)),shape=RoundedCornerShape(20.dp)){Column(Modifier.fillMaxWidth().padding(16.dp)){Text(selected,fontSize=18.sp,fontWeight=FontWeight.Black,color=Color(0xFF3478D4));Text("${r.min.toInt()}~${r.max.toInt()}℃ · 최대습도 ${r.humidity.toInt()}% · 강수 ${r.rain.toInt()}%",fontWeight=FontWeight.Bold)}};Text("시·도",fontSize=18.sp,fontWeight=FontWeight.Black);d.regions.sortedBy{it.name}.chunked(2).forEach{pair->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(8.dp)){pair.forEach{x->FilterChip(selected==x.name,{onSelect(x.name)},{Text(x.name)},modifier=Modifier.weight(1f))};if(pair.size==1)Spacer(Modifier.weight(1f))}}}

@Composable fun PriceChart(){val v=listOf(5284f,5229f,6176f,6388f,6343f,6236f);Column{Canvas(Modifier.fillMaxWidth().height(180.dp)){val lo=4800f;val hi=6800f;for(i in 0..4){val y=size.height*i/4;drawLine(Color(0xFFE8EAED),Offset(0f,y),Offset(size.width,y),2f)};val p=Path();v.forEachIndexed{i,n->val x=size.width*i/(v.size-1);val y=size.height-(n-lo)/(hi-lo)*size.height;if(i==0)p.moveTo(x,y)else p.lineTo(x,y);drawCircle(Color(0xFFE94F6D),8f,Offset(x,y))};drawPath(p,Color(0xFFE94F6D),style=Stroke(6f))};Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){listOf("2월","3월","4월","5월","6월","7월").forEach{Text(it,fontSize=12.sp)}}}}
