package kr.pigmarketbrief

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.shape.RoundedCornerShape
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
data class AppData(val updated:String="",val regions:List<RegionBrief> = emptyList(),val prices:List<JejuPrice> = emptyList(),val pig:PigPrice=PigPrice(),val history:List<HistPoint> = emptyList(),val error:String?=null)

suspend fun loadData():AppData=withContext(Dispatchers.IO){
 try{
  val c=OkHttpClient()
  fun get(name:String)=c.newCall(Request.Builder().url("$DATA_ROOT/$name").build()).execute().use { r -> if(!r.isSuccessful) error("$name HTTP "+r.code); r.body!!.string() }
  fun optional(name:String):String? = try { get(name) } catch(e:Exception) { null }
  val b=JSONObject(get("briefing.json")); val k=JSONObject(optional("kape-jeju.json") ?: "{\"rows\":[]}") ; val p=JSONObject(optional("pig-price.json") ?: "{}"); val h=JSONObject(optional("pig-price-history.json") ?: "{\"rows\":[]}")
  val rs=mutableListOf<RegionBrief>(); val a=b.getJSONArray("regions")
  for(i in 0 until a.length()){ val x=a.getJSONObject(i); fun arr(n:String)=x.optJSONArray(n)?.let{z->List(z.length()){j->z.getString(j)}}?: emptyList()
   rs+=RegionBrief(x.getString("region"),x.optDouble("tempMin"),x.optDouble("tempMax"),x.optDouble("humidityMax"),x.optDouble("rainProbabilityMax"),arr("riskFactors"),arr("top3"))
  }
  val ps=mutableListOf<JejuPrice>(); val rows=k.optJSONArray("rows")
  if(rows!=null) for(i in 0 until rows.length()){val x=rows.getJSONObject(i);ps+=JejuPrice(x.optString("gradeName"),x.optString("totPrice","-"),x.optString("publicTotPrice","-"),x.optString("blackTotPrice","-"))}
  val ha=h.optJSONArray("rows"); val hs=mutableListOf<HistPoint>(); if(ha!=null) for(i in 0 until ha.length()){val x=ha.getJSONObject(i);hs+=HistPoint(x.optString("date"),x.optInt("price"))}
  AppData(b.optString("updatedAt"),rs,ps,PigPrice(p.optString("date"),p.optInt("price"),p.optInt("previousPrice"),p.optInt("change"),p.optDouble("changePct")),hs)
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
    tab==0->Home(data!!,selected);tab==1->Market(data!!);tab==2->Checklist(data!!,selected);else->Region(data!!,selected){selected=it}}
  }
 }
}
@Composable fun Home(d:AppData,selected:String){
 val r=d.regions.firstOrNull{it.name==selected}?:d.regions.firstOrNull()
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(28.dp),elevation=CardDefaults.cardElevation(4.dp)){Column(Modifier.padding(22.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
  Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Column{Text("전국 돈가",fontSize=17.sp,fontWeight=FontWeight.Black);Text("제주 제외 · 원/kg (탕박)",fontSize=12.sp,color=Color(0xFF74717B))};AssistChip(onClick={},label={Text("오늘")})}
  if(d.pig.price>0){Text(comma(d.pig.price.toString())+" 원/kg",fontSize=40.sp,fontWeight=FontWeight.Black);Text((if(d.pig.change<0)"▼ " else "▲ ")+kotlin.math.abs(d.pig.change)+"원 ("+String.format("%.2f",kotlin.math.abs(d.pig.changePct))+"%)",color=if(d.pig.change<0)Color(0xFF3478D4) else Color(0xFFFF4F78),fontSize=18.sp,fontWeight=FontWeight.Bold);Surface(color=if(d.pig.change<0)Color(0xFFEDF6FF) else Color(0xFFFFF1F5),shape=RoundedCornerShape(16.dp)){Text((if(d.pig.change<0)"전일보다 낮습니다" else "전일보다 높습니다")+" · 전일 "+comma(d.pig.previousPrice.toString())+"원",Modifier.fillMaxWidth().padding(14.dp),fontWeight=FontWeight.Bold)}} else {Text("가격 업데이트 중",fontSize=28.sp,fontWeight=FontWeight.Black);Text("확인되지 않은 가격은 표시하지 않습니다.",color=Color(0xFF74717B))}
  if(d.history.size>1) HistoryChart(d.history.takeLast(8)) else Box(Modifier.fillMaxWidth().height(105.dp),contentAlignment=Alignment.Center){Text("가격 추이 업데이트 중",color=Color(0xFF74717B))}
  Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("일간","주간","월간","연간").forEachIndexed{i,s->Surface(color=if(i==0)Color(0xFFFF4F78) else Color(0xFFF6F2F3),shape=RoundedCornerShape(30.dp),modifier=Modifier.weight(1f)){Text(s,Modifier.padding(vertical=8.dp),textAlign=androidx.compose.ui.text.style.TextAlign.Center,color=if(i==0)Color.White else Color(0xFF74717B),fontSize=12.sp,fontWeight=FontWeight.Bold)}}}
 }}
 Text("오늘 필요한 정보",fontSize=21.sp,fontWeight=FontWeight.Black)
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(10.dp)){HomeShortcut("▥","시황 보기","돈가 흐름과 시장 동향",Color(0xFFFFF1F5),Color(0xFFFF4F78),Modifier.weight(1f));HomeShortcut("☀","오늘 날씨",selected+" 농장 기상",Color(0xFFEDF6FF),Color(0xFF3478D4),Modifier.weight(1f))}
 Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(10.dp)){HomeShortcut("✓","농장점검","오늘 확인할 TOP 3",Color(0xFFEEF9F3),Color(0xFF198754),Modifier.weight(1f));HomeShortcut("⌖","지역 선택","지역별 날씨와 위험",Color(0xFFFFF5E9),Color(0xFFE58B2A),Modifier.weight(1f))}
 Card(colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text("양돈 이슈 & 오늘 브리핑",fontSize=19.sp,fontWeight=FontWeight.Black);if(r!=null){Text("날씨  ·  "+selected+" "+r.min.toInt()+"~"+r.max.toInt()+"℃ · 강수 "+r.rain.toInt()+"%",color=Color(0xFF3478D4),fontWeight=FontWeight.Bold);Text("농장  ·  "+(r.checks.firstOrNull()?:"기본관리 항목을 확인하세요."),fontWeight=FontWeight.Bold);if(r.risks.isNotEmpty())Text("주의  ·  "+r.risks.joinToString(" · "),color=Color(0xFFE58B2A),fontWeight=FontWeight.Bold)}else Text("지역 데이터 업데이트 중")}}
 if(d.updated.isNotBlank())Text("업데이트 "+d.updated.take(16).replace("T"," "),fontSize=11.sp,color=Color(0xFF74717B))
}
@Composable fun HomeShortcut(icon:String,title:String,sub:String,bg:Color,accent:Color,modifier:Modifier){Card(modifier,colors=CardDefaults.cardColors(containerColor=bg),shape=RoundedCornerShape(22.dp)){Column(Modifier.padding(16.dp).heightIn(min=112.dp),verticalArrangement=Arrangement.spacedBy(7.dp)){Text(icon,fontSize=22.sp,fontWeight=FontWeight.Black,color=accent);Text(title,fontSize=18.sp,fontWeight=FontWeight.Black,color=accent);Text(sub,fontSize=12.sp,lineHeight=17.sp)}}}
@Composable fun HistoryChart(points:List<HistPoint>){val v=points.map{it.price.toFloat()};val lo=v.minOrNull()?:0f;val hi=v.maxOrNull()?:1f;val range=(hi-lo).coerceAtLeast(1f);Canvas(Modifier.fillMaxWidth().height(115.dp)){for(i in 0..3){val y=size.height*i/3;drawLine(Color(0xFFF1E8EB),Offset(0f,y),Offset(size.width,y),1.5f)};val p=Path();v.forEachIndexed{i,n->val x=size.width*i/(v.size-1);val y=size.height-10-(n-lo)/range*(size.height-20);if(i==0)p.moveTo(x,y)else p.lineTo(x,y)};drawPath(p,Color(0xFFFF4F78),style=Stroke(5f));drawCircle(Color(0xFFFF4F78),8f,Offset(size.width,size.height-10-(v.last()-lo)/range*(size.height-20)))}}
@Composable fun Market(d:AppData){Text("시황",style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold);Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.fillMaxWidth().padding(20.dp)){Text("오늘 전국 돈가",fontWeight=FontWeight.Bold);Text("${comma(d.pig.price.toString())}원/kg",style=MaterialTheme.typography.displaySmall,fontWeight=FontWeight.Black);Text("${if(d.pig.change<0)"▼" else "▲"} ${kotlin.math.abs(d.pig.change)}원 (${String.format("%.2f",d.pig.changePct)}%)",color=if(d.pig.change<0) Color(0xFF1565C0) else Color(0xFFE94F6D),fontWeight=FontWeight.Bold);Text("전일 ${comma(d.pig.previousPrice.toString())}원")}};Text("2026 연간 돈가",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.fillMaxWidth().padding(20.dp)){Text("2026 월별 평균 돈가",fontWeight=FontWeight.Bold,fontSize=20.sp);Text("전국 · 제주 제외 · 원/kg",style=MaterialTheme.typography.bodySmall);PriceChart();Text("2월 5,284 · 3월 5,229 · 4월 6,176",fontSize=14.sp);Text("5월 6,388 · 6월 6,343 · 7월 6,236",fontSize=14.sp);Text("공식 확인 완료 월만 표시",style=MaterialTheme.typography.bodySmall)}};Text("제주 시세 · 별도",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);d.prices.forEach{Card{Column(Modifier.padding(12.dp)){Text(it.grade+" 등급");Text("제주 백돼지 ${comma(it.normal)} · 제주 흑돼지 ${comma(it.black)} 원/kg")}}}}
@Composable fun Checklist(d:AppData,selected:String){val r=d.regions.firstOrNull{it.name==selected};Text("$selected 농장점검",style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold);r?.checks?.forEachIndexed{i,s->Card{Text("${i+1}. $s",Modifier.padding(16.dp))}};Spacer(Modifier.height(8.dp));Text("기본 점검: 급이·사료 · 음수 · 환기·환경 · 질병·위생 · 모돈·자돈 · 출하·기록")}
@Composable fun Region(d:AppData,selected:String,onSelect:(String)->Unit){Text("지역",style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold);Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.fillMaxWidth().padding(20.dp),horizontalAlignment=Alignment.CenterHorizontally){Text("대한민국 지역 지도",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);Text("지도형 선택 화면 준비 중");Text("시·도 선택 → 시·군 확대",style=MaterialTheme.typography.bodyMedium)}};Text("빠른 지역 선택",style=MaterialTheme.typography.titleMedium,fontWeight=FontWeight.Bold);d.regions.sortedBy{it.name}.chunked(2).forEach{pair->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(8.dp)){pair.forEach{r->FilterChip(selected==r.name,{onSelect(r.name)},{Text(r.name)},modifier=Modifier.weight(1f))};if(pair.size==1)Spacer(Modifier.weight(1f))}}}

@Composable fun PriceChart(){val v=listOf(5284f,5229f,6176f,6388f,6343f,6236f);Column{Canvas(Modifier.fillMaxWidth().height(180.dp)){val lo=4800f;val hi=6800f;for(i in 0..4){val y=size.height*i/4;drawLine(Color(0xFFE8EAED),Offset(0f,y),Offset(size.width,y),2f)};val p=Path();v.forEachIndexed{i,n->val x=size.width*i/(v.size-1);val y=size.height-(n-lo)/(hi-lo)*size.height;if(i==0)p.moveTo(x,y)else p.lineTo(x,y);drawCircle(Color(0xFFE94F6D),8f,Offset(x,y))};drawPath(p,Color(0xFFE94F6D),style=Stroke(6f))};Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){listOf("2월","3월","4월","5월","6월","7월").forEach{Text(it,fontSize=12.sp)}}}}
