package kr.pigmarketbrief

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
data class AppData(val updated:String="",val regions:List<RegionBrief> = emptyList(),val prices:List<JejuPrice> = emptyList(),val error:String?=null)

suspend fun loadData():AppData=withContext(Dispatchers.IO){
 try{
  val c=OkHttpClient()
  fun get(name:String)=c.newCall(Request.Builder().url("$DATA_ROOT/$name").build()).execute().use{r->if(!r.isSuccessful) error("HTTP "+r.code); r.body!!.string()}
  val b=JSONObject(get("briefing.json")); val k=JSONObject(get("kape-jeju.json"))
  val rs=mutableListOf<RegionBrief>(); val a=b.getJSONArray("regions")
  for(i in 0 until a.length()){ val x=a.getJSONObject(i); fun arr(n:String)=x.optJSONArray(n)?.let{z->List(z.length()){j->z.getString(j)}}?: emptyList()
   rs+=RegionBrief(x.getString("region"),x.optDouble("tempMin"),x.optDouble("tempMax"),x.optDouble("humidityMax"),x.optDouble("rainProbabilityMax"),arr("riskFactors"),arr("top3"))
  }
  val ps=mutableListOf<JejuPrice>(); val rows=k.optJSONArray("rows")
  if(rows!=null) for(i in 0 until rows.length()){val x=rows.getJSONObject(i);ps+=JejuPrice(x.optString("gradeName"),x.optString("totPrice","-"),x.optString("publicTotPrice","-"),x.optString("blackTotPrice","-"))}
  AppData(b.optString("updatedAt"),rs,ps)
 }catch(e:Exception){AppData(error=e.message)}
}

class MainActivity:ComponentActivity(){override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{MaterialTheme{BriefingApp()}}}}

@Composable fun BriefingApp(){
 var tab by remember{mutableIntStateOf(0)}; var data by remember{mutableStateOf<AppData?>(null)}; var selected by remember{mutableStateOf("경상북도")}
 LaunchedEffect(Unit){data=loadData()}
 Scaffold(bottomBar={NavigationBar{listOf("홈","시황","농장점검","지역").forEachIndexed{i,t->NavigationBarItem(selected = tab == i, onClick = { tab = i }, icon = {}, label = { Text(t) })}}}){pad->
  Column(Modifier.padding(pad).padding(16.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)){
   Text("오늘돈가",style=MaterialTheme.typography.headlineMedium)
   when{data==null->CircularProgressIndicator();data!!.error!=null->Column(verticalArrangement=Arrangement.spacedBy(8.dp)){Text("데이터를 불러오지 못했습니다.",style=MaterialTheme.typography.titleMedium);Text("잠시 후 다시 실행해 주세요.");Text(data!!.error!!,style=MaterialTheme.typography.bodySmall)}
    tab==0->Home(data!!,selected);tab==1->Market(data!!);tab==2->Checklist(data!!,selected);else->Region(data!!,selected){selected=it}}
  }
 }
}
@Composable fun Home(d:AppData,selected:String){val r=d.regions.firstOrNull{it.name==selected}?:d.regions.firstOrNull()
 Text("$selected · 오늘의 브리핑",style=MaterialTheme.typography.titleMedium)
 Card{Column(Modifier.padding(16.dp)){Text("전국 돈가",style=MaterialTheme.typography.titleMedium);Text("전국(제주 제외) 백돼지 공식 경락가격 연결 준비 중");Text("※ 앱의 기본 돈가 기준")}}
 Card{Column(Modifier.padding(16.dp)){Text("제주 시세 · 별도",style=MaterialTheme.typography.titleMedium);d.prices.take(4).forEach{Text("${it.grade}  백돼지 ${it.normal}원/kg · 흑돼지 ${it.black}원/kg")};Text("※ 제주도는 육지 시세와 합산하지 않음")}}
 if(r!=null) Card{Column(Modifier.padding(16.dp)){Text("오늘 날씨",style=MaterialTheme.typography.titleMedium);Text("${r.min.toInt()}~${r.max.toInt()}℃ · 습도 최대 ${r.humidity.toInt()}% · 강수 ${r.rain.toInt()}%");if(r.risks.isNotEmpty())Text("체크요인: "+r.risks.joinToString(" · "))}}
 if(r!=null) Card{Column(Modifier.padding(16.dp)){Text("오늘의 농장 체크 TOP 3",style=MaterialTheme.typography.titleMedium);r.checks.forEachIndexed{i,s->Text("${i+1}. $s")}}}
 Text("업데이트 "+d.updated.take(16).replace("T"," "))
}
@Composable fun Market(d:AppData){Text("전국 돈가",style=MaterialTheme.typography.titleLarge);Text("전국(제주 제외) 백돼지 공식 경락가격 연결 준비 중");HorizontalDivider();Text("제주 시세 · 별도",style=MaterialTheme.typography.titleLarge);d.prices.forEach{Card{Column(Modifier.padding(12.dp)){Text(it.grade+" 등급");Text("제주 백돼지 ${it.normal} · 제주 흑돼지 ${it.black} 원/kg")}}}}
@Composable fun Checklist(d:AppData,selected:String){val r=d.regions.firstOrNull{it.name==selected};Text("$selected 우선 점검",style=MaterialTheme.typography.titleLarge);r?.checks?.forEachIndexed{i,s->Card{Text("${i+1}. $s",Modifier.padding(16.dp))}};Spacer(Modifier.height(8.dp));Text("기본 점검: 급이·사료 · 음수 · 환기·환경 · 질병·위생 · 모돈·자돈 · 출하·기록")}
@Composable fun Region(d:AppData,selected:String,onSelect:(String)->Unit){Text("관심지역",style=MaterialTheme.typography.titleLarge);d.regions.sortedBy{it.name}.forEach{r->FilterChip(selected==r.name,{onSelect(r.name)},{Text(r.name)});Spacer(Modifier.height(4.dp))}}
