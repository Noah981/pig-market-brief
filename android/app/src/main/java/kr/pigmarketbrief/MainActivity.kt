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
  fun get(name:String)=c.newCall(Request.Builder().url("$DATA_ROOT/$name").build()).execute().use{r->if(!r.isSuccessful) error("HTTP "+r.code); r.body!!.string()}
  val b=JSONObject(get("briefing.json")); val k=JSONObject(get("kape-jeju.json")); val p=JSONObject(get("pig-price.json")); val h=JSONObject(get("pig-price-history.json"))
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
 MaterialTheme(colorScheme=lightColorScheme(primary=androidx.compose.ui.graphics.Color(0xFFE94F6D),secondary=androidx.compose.ui.graphics.Color(0xFF496A8A),surfaceVariant=androidx.compose.ui.graphics.Color(0xFFF7F3F4))){BriefingApp()}
}}}

@Composable fun BriefingApp(){
 var tab by remember{mutableIntStateOf(0)}; var data by remember{mutableStateOf<AppData?>(null)}; var selected by remember{mutableStateOf("경상북도")}
 LaunchedEffect(Unit){data=loadData()}
 Scaffold(bottomBar={NavigationBar{listOf("홈","시황","농장점검","지역").forEachIndexed{i,t->NavigationBarItem(selected = tab == i, onClick = { tab = i }, icon = {}, label = { Text(t) })}}}){pad->
  Column(Modifier.padding(pad).padding(horizontal=20.dp,vertical=18.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(18.dp)){
   Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically){Column{Text("오늘돈가",style=MaterialTheme.typography.headlineLarge,fontWeight=FontWeight.Bold);Text("가격은 크게, 농장 정보는 쉽게",style=MaterialTheme.typography.bodyMedium)};Text("🐷",fontSize=34.sp)}
   when{data==null->CircularProgressIndicator();data!!.error!=null->Column(verticalArrangement=Arrangement.spacedBy(8.dp)){Text("데이터를 불러오지 못했습니다.",style=MaterialTheme.typography.titleMedium);Text("잠시 후 다시 실행해 주세요.");Text(data!!.error!!,style=MaterialTheme.typography.bodySmall)}
    tab==0->Home(data!!,selected);tab==1->Market(data!!);tab==2->Checklist(data!!,selected);else->Region(data!!,selected){selected=it}}
  }
 }
}
@Composable fun Home(d:AppData,selected:String){val r=d.regions.firstOrNull{it.name==selected}?:d.regions.firstOrNull()
 Text("양돈의 오늘, 농가의 내일",style=MaterialTheme.typography.bodyLarge); Text("관심지역 · $selected",style=MaterialTheme.typography.bodyLarge)
 Card(shape=RoundedCornerShape(28.dp)){Column(Modifier.padding(24.dp)){Text("전국 돈가 (제주 제외)",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);Text("${comma(d.pig.price.toString())}원/kg",style=MaterialTheme.typography.displaySmall,fontWeight=FontWeight.Black);Text("${if(d.pig.change<0)"▼" else "▲"} ${kotlin.math.abs(d.pig.change)}원 (${String.format("%.2f",d.pig.changePct)}%)",color=if(d.pig.change<0) Color(0xFF1565C0) else Color(0xFFE94F6D),style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold);Text("전일 ${comma(d.pig.previousPrice.toString())}원",style=MaterialTheme.typography.bodyLarge)}}
 Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.padding(18.dp)){Text("시황 보기",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);Text("연간 평균 돈가와 시장 동향을 확인하세요.",style=MaterialTheme.typography.bodyLarge)}}
 if(r!=null) Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(6.dp)){Text("오늘 날씨 · $selected",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);Text("☁️  ${r.min.toInt()}~${r.max.toInt()}℃",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold);Text("최대습도 ${r.humidity.toInt()}%   강수확률 ${r.rain.toInt()}%");if(r.risks.isNotEmpty())AssistChip(onClick={},label={Text(r.risks.joinToString(" · "))})}}
 if(r!=null) Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){Text("농장점검",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);r.checks.take(3).forEachIndexed{i,s->Text("✓  $s",fontSize=17.sp)}}}
 Text("업데이트 "+d.updated.take(16).replace("T"," "))
}
@Composable fun Market(d:AppData){Text("시황",style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold);Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.fillMaxWidth().padding(20.dp)){Text("오늘 전국 돈가",fontWeight=FontWeight.Bold);Text("${comma(d.pig.price.toString())}원/kg",style=MaterialTheme.typography.displaySmall,fontWeight=FontWeight.Black);Text("${if(d.pig.change<0)"▼" else "▲"} ${kotlin.math.abs(d.pig.change)}원 (${String.format("%.2f",d.pig.changePct)}%)",color=if(d.pig.change<0) Color(0xFF1565C0) else Color(0xFFE94F6D),fontWeight=FontWeight.Bold);Text("전일 ${comma(d.pig.previousPrice.toString())}원")}};Text("2026 연간 돈가",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.fillMaxWidth().padding(20.dp)){Text("2026 월별 평균 돈가",fontWeight=FontWeight.Bold,fontSize=20.sp);Text("전국 · 제주 제외 · 원/kg",style=MaterialTheme.typography.bodySmall);PriceChart();Text("2월 5,284 · 3월 5,229 · 4월 6,176",fontSize=14.sp);Text("5월 6,388 · 6월 6,343 · 7월 6,236",fontSize=14.sp);Text("공식 확인 완료 월만 표시",style=MaterialTheme.typography.bodySmall)}};Text("제주 시세 · 별도",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);d.prices.forEach{Card{Column(Modifier.padding(12.dp)){Text(it.grade+" 등급");Text("제주 백돼지 ${comma(it.normal)} · 제주 흑돼지 ${comma(it.black)} 원/kg")}}}}
@Composable fun Checklist(d:AppData,selected:String){val r=d.regions.firstOrNull{it.name==selected};Text("$selected 농장점검",style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold);r?.checks?.forEachIndexed{i,s->Card{Text("${i+1}. $s",Modifier.padding(16.dp))}};Spacer(Modifier.height(8.dp));Text("기본 점검: 급이·사료 · 음수 · 환기·환경 · 질병·위생 · 모돈·자돈 · 출하·기록")}
@Composable fun Region(d:AppData,selected:String,onSelect:(String)->Unit){Text("지역",style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold);Card(shape=RoundedCornerShape(20.dp)){Column(Modifier.fillMaxWidth().padding(20.dp),horizontalAlignment=Alignment.CenterHorizontally){Text("대한민국 지역 지도",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);Text("지도형 선택 화면 준비 중");Text("시·도 선택 → 시·군 확대",style=MaterialTheme.typography.bodyMedium)}};Text("빠른 지역 선택",style=MaterialTheme.typography.titleMedium,fontWeight=FontWeight.Bold);d.regions.sortedBy{it.name}.chunked(2).forEach{pair->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(8.dp)){pair.forEach{r->FilterChip(selected==r.name,{onSelect(r.name)},{Text(r.name)},modifier=Modifier.weight(1f))};if(pair.size==1)Spacer(Modifier.weight(1f))}}}

@Composable fun PriceChart(){val v=listOf(5284f,5229f,6176f,6388f,6343f,6236f);Column{Canvas(Modifier.fillMaxWidth().height(180.dp)){val lo=4800f;val hi=6800f;for(i in 0..4){val y=size.height*i/4;drawLine(Color(0xFFE8EAED),Offset(0f,y),Offset(size.width,y),2f)};val p=Path();v.forEachIndexed{i,n->val x=size.width*i/(v.size-1);val y=size.height-(n-lo)/(hi-lo)*size.height;if(i==0)p.moveTo(x,y)else p.lineTo(x,y);drawCircle(Color(0xFFE94F6D),8f,Offset(x,y))};drawPath(p,Color(0xFFE94F6D),style=Stroke(6f))};Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){listOf("2월","3월","4월","5월","6월","7월").forEach{Text(it,fontSize=12.sp)}}}}
