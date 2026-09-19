package kr.pigmarketbrief

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.LocationManager
import android.os.CancellationSignal
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.roundToInt

private val Coral=Color(0xFF17634C)
private val Rose=Color(0xFFE2F1E8)
private val Ivory=Color(0xFFFAFAF5)
private val Sky=Color(0xFFEAF5FF)
private val Sage=Color(0xFFEAF8EF)
private val Apricot=Color(0xFFFFF2DF)
private val DeepInk=Color(0xFF17171C)
private val Muted=Color(0xFF71717A)

@Composable fun DondonTheme(content: @Composable () -> Unit){val dark=isSystemInDarkTheme();MaterialTheme(colorScheme=if(dark)darkColorScheme(primary=Color(0xFF8DD5AD),background=Color(0xFF111113),surface=Color(0xFF202024),onSurface=Color(0xFFF8F7F5))else lightColorScheme(primary=Coral,onPrimary=Color.White,background=Ivory,surface=Color.White,onSurface=DeepInk),content=content)}

@Composable fun LegacyDondonApp(){
 val ctx=LocalContext.current;val scope=rememberCoroutineScope();val prefs=remember{ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE)};var tab by remember{mutableIntStateOf(0)};var data by remember{mutableStateOf<AppData?>(null)};var loading by remember{mutableStateOf(true)};var region by remember{mutableStateOf(prefs.getString("region","경상북도")?:"경상북도")};var refreshed by remember{mutableStateOf<String?>(null)}
 suspend fun refresh(){if(loading&&data!=null)return;loading=true;val next=DataRepository.load(ctx);data=next;loading=false;refreshed=if(next.error==null)"최신 데이터로 갱신했습니다" else "연결 오류 · 마지막 정상값을 유지합니다"}
 LaunchedEffect(Unit){refresh()}
 AutoLocationBootstrap(region){province,district->region=province;prefs.edit().putString("region",province).putString("district",district).putBoolean("location_initialized",true).apply()}
 Scaffold(containerColor=MaterialTheme.colorScheme.background,bottomBar={DondonNavigation(tab){tab=it}},floatingActionButton={if(tab!=0){SmallFloatingActionButton(onClick={scope.launch{refresh()}},containerColor=Coral,contentColor=Color.White){if(loading)CircularProgressIndicator(Modifier.size(18.dp),strokeWidth=2.dp,color=Color.White)else Text("↻",fontSize=22.sp)}}}){pad->
  Column(Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState())){
   if(loading&&data==null)DondonLoading() else when(tab){0->DondonHome(data?:AppData(),region,{tab=it},{scope.launch{refresh()}});1->DondonPrice(data?:AppData());2->InputMarketScreen();3->FarmHub(data?:AppData(),region);else->ScheduleRegionScreen(data?:AppData(),region){region=it;prefs.edit().putString("region",it).apply()}}
   refreshed?.let{Surface(Modifier.padding(18.dp).fillMaxWidth(),color=if(it.startsWith("최신"))Sage else Apricot,shape=RoundedCornerShape(16.dp)){Text(it,Modifier.padding(12.dp),fontSize=12.sp,fontWeight=FontWeight.Bold)};LaunchedEffect(it){kotlinx.coroutines.delay(2200);refreshed=null}}
   Spacer(Modifier.height(24.dp))
  }
 }
}

@Composable fun AutoLocationBootstrap(current:String,onLocated:(String,String?)->Unit){val ctx=LocalContext.current;val prefs=remember{ctx.getSharedPreferences("todaypig",Context.MODE_PRIVATE)};val scope=rememberCoroutineScope();fun locate(){val lm=ctx.getSystemService(Context.LOCATION_SERVICE)as LocationManager;val provider=when{lm.isProviderEnabled(LocationManager.GPS_PROVIDER)->LocationManager.GPS_PROVIDER;lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)->LocationManager.NETWORK_PROVIDER;else->return};try{if(android.os.Build.VERSION.SDK_INT>=30)lm.getCurrentLocation(provider,CancellationSignal(),ctx.mainExecutor){loc->if(loc!=null)scope.launch{val a=withContext(Dispatchers.IO){try{Geocoder(ctx,Locale.KOREA).getFromLocation(loc.latitude,loc.longitude,1)?.firstOrNull()}catch(_:Exception){null}};a?.adminArea?.let{onLocated(it,a.subAdminArea?:a.locality)}}}else lm.getLastKnownLocation(provider)?.let{loc->scope.launch{val a=withContext(Dispatchers.IO){try{Geocoder(ctx,Locale.KOREA).getFromLocation(loc.latitude,loc.longitude,1)?.firstOrNull()}catch(_:Exception){null}};a?.adminArea?.let{onLocated(it,a.subAdminArea?:a.locality)}}}}catch(_:SecurityException){}}
 val launcher=rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()){r->if(r.values.any{it})locate()}
 LaunchedEffect(Unit){if(!prefs.getBoolean("location_initialized",false)){if(ContextCompat.checkSelfPermission(ctx,Manifest.permission.ACCESS_COARSE_LOCATION)==PackageManager.PERMISSION_GRANTED)locate()else launcher.launch(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION,Manifest.permission.ACCESS_FINE_LOCATION))}}
}

@Composable private fun DondonNavigation(selected:Int,on:(Int)->Unit){NavigationBar(containerColor=MaterialTheme.colorScheme.surface,tonalElevation=2.dp){listOf("홈" to "⌂","돈가" to "↗","원료" to "▥","농장관리" to "✓","일정·지역" to "⌖").forEachIndexed{i,(name,icon)->NavigationBarItem(selected==i,{on(i)},{Text(icon,fontSize=19.sp,fontWeight=FontWeight.Black)},label={Text(name,fontSize=10.sp)},colors=NavigationBarItemDefaults.colors(selectedIconColor=Coral,selectedTextColor=Coral,indicatorColor=Rose))}}}
@Composable private fun DondonLoading(){Column(Modifier.fillMaxWidth().padding(36.dp),horizontalAlignment=Alignment.CenterHorizontally){CircularProgressIndicator(color=Coral);Text("공식 데이터를 확인하고 있어요",Modifier.padding(top=14.dp),fontWeight=FontWeight.Bold)}}

@Composable fun DondonHome(d:AppData,region:String,navigate:(Int)->Unit,refresh:()->Unit){
 Column(Modifier.padding(horizontal=18.dp),verticalArrangement=Arrangement.spacedBy(16.dp)){
  DondonHero()
  DondonPriceCard(d.pig,{navigate(1)},refresh)
  MiniDailyChart(d.history)
  QuickGrid(listOf(
   QuickItem("돈가 분석","일간부터 3개년 비교",Rose,"↗",{navigate(1)}),
   QuickItem("오늘 날씨","$region 농장 기상",Sky,"☀",{navigate(4)}),
   QuickItem("농장 점검","오늘 우선순위 확인",Sage,"✓",{navigate(3)}),
   QuickItem("내 지역","GPS로 자동 연결",Apricot,"⌖",{navigate(4)})
  ))
  FeatureBanner("원료·원가 흐름","옥수수·대두박·유가·환율의 원본 단위와 갱신 상태",Rose,"원료 보기"){navigate(2)}
  val domestic=d.diseases.count{it.scope=="국내"};val overseas=d.diseases.count{it.scope=="국외"}
  Row(horizontalArrangement=Arrangement.spacedBy(10.dp)){StatCard("국내 질병",domestic.toString(),"공식/확인중 분리",Sage,Modifier.weight(1f)){navigate(3)};StatCard("국외 질병",overseas.toString(),"국가코드 기준",Sky,Modifier.weight(1f)){navigate(3)}}
  QuickGrid(listOf(QuickItem("예상 정산","출하체중·계약 기준",Rose,"₩",{navigate(3)}),QuickItem("농장 일정","백신·출하·점검",Sky,"□",{navigate(4)}),QuickItem("사료 주문","재고 소진일 계산",Sage,"▤",{navigate(4)}),QuickItem("인증 관리","유효기간·정산 적용",Apricot,"◆",{navigate(3)})))
  IssueList(d)
 }
}

@Composable private fun DondonHero(){val ctx=LocalContext.current;val bitmap=remember{val encoded=ctx.resources.openRawResource(R.raw.pig_hero).bufferedReader().use{it.readText()};val bytes=Base64.decode(encoded,Base64.DEFAULT);BitmapFactory.decodeByteArray(bytes,0,bytes.size).asImageBitmap()};Box(Modifier.fillMaxWidth().height(210.dp).padding(top=10.dp)){Image(bitmap,null,Modifier.fillMaxSize(),contentScale=ContentScale.Crop);Box(Modifier.matchParentSize().background(Color.White.copy(.08f)));Column(Modifier.align(Alignment.TopStart).padding(18.dp)){Row(verticalAlignment=Alignment.CenterVertically){PigMark();Spacer(Modifier.width(9.dp));Column{Text("돈돈해",fontSize=27.sp,fontWeight=FontWeight.Black,color=DeepInk);Text("양돈의 오늘을 든든하게",fontSize=11.sp,color=Muted)}};Spacer(Modifier.height(10.dp));Text(LocalDateTime.now().format(DateTimeFormatter.ofPattern("M월 d일 E요일 HH:mm",Locale.KOREAN)),fontSize=11.sp,color=DeepInk)};Surface(Modifier.align(Alignment.BottomStart).padding(18.dp),color=Color.White.copy(.82f),shape=RoundedCornerShape(14.dp)){Text("건강한 돼지, 든든한 내일",Modifier.padding(horizontal=12.dp,vertical=8.dp),fontSize=12.sp,fontWeight=FontWeight.Black,color=Coral)}}}
@Composable private fun PigMark(){Canvas(Modifier.size(43.dp)){drawCircle(Rose);drawOval(Coral,topLeft=Offset(7f,12f),size=androidx.compose.ui.geometry.Size(28f,22f),style=Stroke(3.5f));drawCircle(Coral,2.2f,Offset(29f,21f));drawLine(Coral,Offset(10f,15f),Offset(4f,9f),3f);drawLine(Coral,Offset(32f,14f),Offset(38f,8f),3f)}}

@Composable private fun DondonPriceCard(p:PigPrice,onClick:()->Unit,refresh:()->Unit){Card(Modifier.fillMaxWidth().clickable(onClick=onClick),shape=RoundedCornerShape(30.dp),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),elevation=CardDefaults.cardElevation(4.dp)){Column(Modifier.padding(22.dp),verticalArrangement=Arrangement.spacedBy(9.dp)){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Column{Text("생산자 돼지 경락가격",fontSize=21.sp,fontWeight=FontWeight.Black);Text("${p.basis} · 원/kg",fontSize=10.sp,color=Muted)};IconButton(refresh){Text("↻",color=Coral,fontSize=22.sp)}};if(p.price!=null){Row(verticalAlignment=Alignment.Bottom){Text(comma(p.price),fontSize=49.sp,fontWeight=FontWeight.Black);Text(" 원/kg",Modifier.padding(bottom=8.dp),fontSize=16.sp,fontWeight=FontWeight.Bold)};val ch=p.change?:0;Text("${if(ch>0)"▲" else if(ch<0)"▼" else "―"} ${comma(abs(ch))}원 (${p.changePct?.let{String.format("%.2f",abs(it))}?:"—"}%) · 직전 거래일 ${p.previous?.let{comma(it)}?:"—"}원",color=if(ch>0)Coral else Color(0xFF1976D2),fontSize=18.sp,fontWeight=FontWeight.Black)}else Text(if(p.status.isBlank())"오늘 미확정" else p.status,fontSize=30.sp,fontWeight=FontWeight.Black);Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text("${formatDay(p.date)} · ${priceStatus(p)}",fontSize=10.sp,color=Muted);Text("축산물품질평가원 · ${shortTime(p.updatedAt)} 갱신",fontSize=10.sp,color=Muted)}}}}

@Composable private fun MiniDailyChart(rows:List<HistPoint>){val points=rows.filter{it.resolution=="day"}.sortedBy{it.date}.takeLast(8);Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),shape=RoundedCornerShape(25.dp)){Column(Modifier.padding(18.dp)){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text("최근 확정 돈가",fontWeight=FontWeight.Black);Text("최근 8개 거래일",fontSize=10.sp,color=Muted)};if(points.size<2)Text("확정 데이터가 쌓이면 그래프를 표시합니다",Modifier.padding(vertical=28.dp),color=Muted)else{val lo=points.minOf{it.price}.toFloat();val hi=points.maxOf{it.price}.toFloat();Canvas(Modifier.fillMaxWidth().height(110.dp).padding(top=15.dp)){val path=Path();points.forEachIndexed{i,p->val x=size.width*i/(points.lastIndex);val y=size.height-(p.price-lo)/(hi-lo).coerceAtLeast(1f)*size.height;if(i==0)path.moveTo(x,y)else path.lineTo(x,y);drawCircle(if(i==points.lastIndex)Color.White else Coral,if(i==points.lastIndex)7f else 4f,Offset(x,y));if(i==points.lastIndex)drawCircle(Coral,8f,Offset(x,y),style=Stroke(4f))};drawPath(path,Coral,style=Stroke(4f))};Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){points.forEachIndexed{i,p->if(i%2==0||i==points.lastIndex)Text(formatDay(p.date).takeLast(5),fontSize=8.sp,color=Muted)}}}}}
}

data class QuickItem(val title:String,val subtitle:String,val color:Color,val icon:String,val on:()->Unit)
@Composable private fun QuickGrid(items:List<QuickItem>){Column(verticalArrangement=Arrangement.spacedBy(10.dp)){items.chunked(2).forEach{row->Row(horizontalArrangement=Arrangement.spacedBy(10.dp)){row.forEach{x->Card(Modifier.weight(1f).height(133.dp).clickable{x.on()},shape=RoundedCornerShape(25.dp),colors=CardDefaults.cardColors(containerColor=x.color)){Column(Modifier.padding(17.dp)){Text(x.icon,fontSize=25.sp,color=Coral,fontWeight=FontWeight.Black);Spacer(Modifier.height(9.dp));Text(x.title,fontSize=17.sp,fontWeight=FontWeight.Black);Text(x.subtitle,fontSize=11.sp,color=Muted,maxLines=2);Text("→",Modifier.align(Alignment.End),color=Coral,fontWeight=FontWeight.Black)}}};if(row.size==1)Spacer(Modifier.weight(1f))}}}}
@Composable private fun FeatureBanner(title:String,body:String,color:Color,button:String,on:()->Unit){Card(Modifier.fillMaxWidth().clickable(onClick=on),shape=RoundedCornerShape(26.dp),colors=CardDefaults.cardColors(containerColor=color)){Row(Modifier.padding(19.dp),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text(title,fontSize=21.sp,fontWeight=FontWeight.Black);Text(body,fontSize=11.sp,color=Muted)};Surface(color=Coral,shape=CircleShape){Text("→",Modifier.padding(12.dp),color=Color.White,fontWeight=FontWeight.Black)}}}}
@Composable private fun StatCard(title:String,value:String,sub:String,color:Color,modifier:Modifier=Modifier,on:()->Unit){Card(modifier.clickable(onClick=on),shape=RoundedCornerShape(23.dp),colors=CardDefaults.cardColors(containerColor=color)){Column(Modifier.padding(17.dp)){Text(title,fontWeight=FontWeight.Black);Text(value,fontSize=32.sp,fontWeight=FontWeight.Black);Text(sub,fontSize=10.sp,color=Muted)}}}
@Composable private fun IssueList(d:AppData){
 Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),shape=RoundedCornerShape(25.dp)){
  Column(Modifier.padding(18.dp)){
   Text("양돈 이슈 & 공지",fontSize=19.sp,fontWeight=FontWeight.Black)
   if(d.diseases.isEmpty()) Text("현재 수집된 공지가 없습니다",Modifier.padding(top=12.dp),color=Muted)
   else d.diseases.take(3).forEach{x->
    Row(Modifier.fillMaxWidth().padding(vertical=8.dp)){
     Surface(color=when(x.scope){"국내"->Rose;"국외"->Sky;else->Apricot},shape=RoundedCornerShape(8.dp)){Text(x.scope,Modifier.padding(horizontal=7.dp,vertical=4.dp),fontSize=9.sp,fontWeight=FontWeight.Bold)}
     Text(x.disease+" · "+x.summary,Modifier.padding(start=8.dp).weight(1f),maxLines=1,overflow=TextOverflow.Ellipsis,fontSize=11.sp)
    }
   }
  }
 }
}

@Composable fun DondonPrice(d:AppData){Column(Modifier.padding(horizontal=18.dp),verticalArrangement=Arrangement.spacedBy(15.dp)){ScreenHeader("돈가","오늘부터 3개년까지 같은 원본으로 비교합니다");DondonPriceCard(d.pig,{},{});MarketScreen(d)}}
@Composable private fun ScreenHeader(title:String,subtitle:String){Column(Modifier.padding(top=18.dp)){Text(title,fontSize=33.sp,fontWeight=FontWeight.Black);Text(subtitle,fontSize=12.sp,color=Muted)}}

@Composable fun InputMarketScreen(){var section by remember{mutableStateOf("원료")};Column(Modifier.padding(horizontal=18.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){ScreenHeader("원료·원가 흐름","원본 단위와 발표주기를 분리해 확인합니다");Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("원료","국제 유가","국내 유류","환율","종합지수").forEach{FilterChip(section==it,{section=it},{Text(it)})}};DataUnavailablePanel(section);listOf("옥수수" to "CBOT · USD/bushel","대두박" to "CBOT · USD/short ton","소맥" to "CBOT · USD/bushel","대두" to "CBOT · USD/bushel","DDGS" to "주간/월간 수입 참고가격","채종박" to "월간 수입 참고가격","팜박" to "월간 수입 참고가격","야자유" to "Bursa Malaysia · MYR/ton","동물성 유지" to "주간/월간 공급자 자료","당밀" to "월간 수입 참고가격").forEach{(name,basis)->MarketEmptyCard(name,basis)};SourceNote("국제 선물가격은 국내 실제 구매단가가 아닙니다. 운임·보험료·관세·하역·보관비가 포함되지 않은 경우 국제 참고가격으로만 표시합니다.")}}
@Composable private fun DataUnavailablePanel(section:String){Card(colors=CardDefaults.cardColors(containerColor=Apricot),shape=RoundedCornerShape(24.dp)){Column(Modifier.padding(18.dp)){Text("$section 공식 연동 확인 필요",fontSize=18.sp,fontWeight=FontWeight.Black);Text("운영 API 키 또는 사용 허가가 확인되지 않아 가격을 생성하지 않았습니다. 연결 전까지 데이터 없음으로 표시합니다.",fontSize=12.sp,color=Muted);Text("상태 · 데이터 없음",Modifier.padding(top=8.dp),fontSize=11.sp,color=Coral,fontWeight=FontWeight.Bold)}}}
@Composable private fun MarketEmptyCard(name:String,basis:String){Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),shape=RoundedCornerShape(21.dp)){Row(Modifier.fillMaxWidth().padding(17.dp),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text(name,fontSize=17.sp,fontWeight=FontWeight.Black);Text(basis,fontSize=10.sp,color=Muted)};Column(horizontalAlignment=Alignment.End){Text("데이터 없음",fontWeight=FontWeight.Bold);Text("임의 가격 미표시",fontSize=9.sp,color=Muted)}}}}

@Composable fun FarmHub(d:AppData,region:String){var page by remember{mutableStateOf("오늘 점검")};Column(Modifier.padding(horizontal=18.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){ScreenHeader("농장관리","점검·질병·기록·인증·정산을 한곳에서");Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("오늘 점검","질병","기록·정산").forEach{FilterChip(page==it,{page=it},{Text(it)})}};when(page){"오늘 점검"->ActionScreen(d,region);"질병"->DiseaseList(d.diseases);else->RecordsScreen()}}}

@Composable fun ScheduleRegionScreen(d:AppData,region:String,onRegion:(String)->Unit){var page by remember{mutableStateOf("일정")};Column(Modifier.padding(horizontal=18.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){ScreenHeader("일정·지역","오늘 할 일과 농장 공급 일정을 놓치지 않게");Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("일정","사료 주문","내 위치").forEach{FilterChip(page==it,{page=it},{Text(it)})}};when(page){"일정"->FarmCalendar();"사료 주문"->FeedOrderCalculator();else->RegionSelector(region,onRegion,d.regions)}}}

@Composable fun FarmCalendar(){
 val ctx=LocalContext.current;val prefs=remember{ctx.getSharedPreferences("farm_schedule",Context.MODE_PRIVATE)};var revision by remember{mutableIntStateOf(0)};var title by remember{mutableStateOf("")};var date by remember{mutableStateOf(LocalDate.now().toString())};var category by remember{mutableStateOf("사료 주문")};val rows=remember(revision){try{JSONArray(prefs.getString("rows","[]"))}catch(_:Exception){JSONArray()}}
 Text("새 일정",fontSize=21.sp,fontWeight=FontWeight.Black)
 Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("사료 주문","출하·입식","백신·소독·구충","농장 점검","인증 갱신","교육·회의","기타").forEach{FilterChip(category==it,{category=it},{Text(it)})}}
 SimpleField("일정명",title){title=it};SimpleField("날짜 YYYY-MM-DD",date){date=it}
 Button({if(title.isNotBlank()){val a=try{JSONArray(prefs.getString("rows","[]"))}catch(_:Exception){JSONArray()};a.put(JSONObject().put("title",title).put("date",date).put("category",category).put("done",false));prefs.edit().putString("rows",a.toString()).apply();title="";revision++}},Modifier.fillMaxWidth(),enabled=title.isNotBlank()){Text("일정 저장")}
 Text("일정 목록",fontSize=20.sp,fontWeight=FontWeight.Black)
 if(rows.length()==0) Text("등록된 일정이 없습니다",color=Muted)
 else (0 until rows.length()).map{rows.getJSONObject(it)}.sortedBy{it.optString("date")}.forEach{x->
  Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),shape=RoundedCornerShape(18.dp)){Row(Modifier.fillMaxWidth().padding(15.dp)){Column(Modifier.weight(1f)){Text(x.optString("title"),fontWeight=FontWeight.Black);Text("${x.optString("date")} · ${x.optString("category")}",fontSize=10.sp,color=Muted)};Text(if(x.optBoolean("done"))"완료" else "예정",color=if(x.optBoolean("done"))Color(0xFF16844B) else Coral,fontWeight=FontWeight.Bold)}}
 }
}

@Composable fun FeedOrderCalculator(){
 var farm by remember{mutableStateOf("")};var feed by remember{mutableStateOf("")};var heads by remember{mutableStateOf("")};var intake by remember{mutableStateOf("")};var stock by remember{mutableStateOf("")};var lead by remember{mutableStateOf("2")};var safety by remember{mutableStateOf("2")};var minimum by remember{mutableStateOf("1000")}
 fun n(s:String)=s.toDoubleOrNull()?:0.0
 val daily=n(heads)*n(intake);val stockDays=if(daily>0)n(stock)/daily else 0.0;val depletion=LocalDate.now().plusDays(stockDays.toLong());val order=depletion.minusDays((n(lead)+n(safety)).toLong());val suggested=if(daily>0)ceil(daily*7/n(minimum).coerceAtLeast(1.0))*n(minimum) else 0.0
 Card(colors=CardDefaults.cardColors(containerColor=Rose),shape=RoundedCornerShape(25.dp)){Column(Modifier.padding(18.dp)){Text("주문 예상",fontWeight=FontWeight.Bold,color=Coral);Text(if(daily>0)order.toString() else "입력값을 확인하세요",fontSize=28.sp,fontWeight=FontWeight.Black);Text(if(daily>0)"소진 $depletion · 재고 ${String.format("%.1f",stockDays)}일 · 권장 ${comma(suggested.roundToInt())}kg" else "두수·섭취량·재고가 필요합니다",fontSize=11.sp,color=Muted)}}
 SimpleField("농장명",farm){farm=it};SimpleField("사료 품목",feed){feed=it}
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("두수 (두)",heads){heads=it}};Box(Modifier.weight(1f)){SimpleField("두당 섭취량 (kg/일)",intake){intake=it}}}
 SimpleField("현재 재고 (kg)",stock){stock=it}
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Box(Modifier.weight(1f)){SimpleField("배송 소요일",lead){lead=it}};Box(Modifier.weight(1f)){SimpleField("안전재고 일수",safety){safety=it}}}
 SimpleField("최소 주문 단위 (kg)",minimum){minimum=it}
 SourceNote("일일 예상 사용량 = 두수 × 두당 일일 섭취량. 주문 권장일 = 예상 소진일 - 배송 소요일 - 안전재고 일수. 실제 섭취량 변동을 반영하지 않은 예상값입니다.")
}
