package kr.pigmarketbrief

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs

private val RefPink=Color(0xFFFF376A)
private val RefBlue=Color(0xFF087BF4)
private val RefText=Color(0xFF15151A)
private val RefGray=Color(0xFF737986)
private val RefPalePink=Color(0xFFFFF0F5)
private val RefPaleBlue=Color(0xFFEEF7FF)

@Composable fun ExactReferenceHome(d:AppData,feed:JSONObject,onPrice:()->Unit,onMarket:()->Unit,onOpen:(String)->Unit,onRefresh:()->Unit){
 Column(verticalArrangement=Arrangement.spacedBy(12.dp)){
  ExactHeader()
  ExactPriceCard(d,onPrice,onRefresh)
  Row(horizontalArrangement=Arrangement.spacedBy(10.dp)){
   TodayTasks(Modifier.weight(1f)){onOpen("사료")}
   TodayWeather(Modifier.weight(1f)){onOpen("지역")}
  }
  ExactMarkets(feed,onMarket)
  ExactIssues(d){onOpen("질병")}
 }
}

@Composable private fun ExactHeader(){ DondonHero() }

@Composable private fun ExactPriceCard(d:AppData,onPrice:()->Unit,onRefresh:()->Unit){val p=d.pig;val ch=p.change?:((p.price?:0)-(p.previous?:0));Card(Modifier.fillMaxWidth().clickable(onClick=onPrice),shape=RoundedCornerShape(22.dp),colors=CardDefaults.cardColors(containerColor=Color.White),elevation=CardDefaults.cardElevation(2.dp)){Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(7.dp)){
 Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Text("전국 돈가",fontSize=23.sp,fontWeight=FontWeight.Black,color=RefText);Text(" (제주 제외)",fontSize=13.sp,fontWeight=FontWeight.Bold);Spacer(Modifier.weight(1f));Text("최종 업데이트 ${displayUpdate(p.updatedAt)}",fontSize=9.sp,color=RefGray);TextButton(onRefresh,contentPadding=PaddingValues(4.dp)){Text("↻",fontSize=23.sp,color=RefGray)}}
 Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1.15f)){Row(verticalAlignment=Alignment.Bottom){Text(p.price?.let{comma(it)}?:"발표 대기",fontSize=47.sp,fontWeight=FontWeight.Black,color=RefText);if(p.price!=null)Text(" 원/kg",Modifier.padding(bottom=8.dp),fontSize=17.sp,fontWeight=FontWeight.Black)};if(p.price!=null&&p.previous!=null){Text("${if(ch<0)"▼" else "▲"} ${comma(abs(ch))}원 (${p.changePct?.let{String.format(Locale.KOREA,"%.2f",abs(it))}?:"—"}%)",fontSize=22.sp,fontWeight=FontWeight.Black,color=if(ch<0)RefBlue else RefPink);Text("전일 ${comma(p.previous)}원",fontSize=15.sp,color=RefGray)}};Surface(Modifier.weight(.85f),color=RefPaleBlue,shape=RoundedCornerShape(15.dp)){Column(Modifier.padding(14.dp)){Text("▥  전일 대비 ${if(ch<0)"하락" else if(ch>0)"상승" else "보합"}",fontSize=16.sp,fontWeight=FontWeight.Black,color=RefBlue);Text(if(ch<0)"시장이 조정을 보이고 있습니다." else "가격 흐름을 확인하세요.",Modifier.padding(top=10.dp),fontSize=12.sp,color=RefText)}}}
 CompactChart(d.history)
 Row(Modifier.fillMaxWidth().background(Color(0xFFF7F7F9),RoundedCornerShape(22.dp)),horizontalArrangement=Arrangement.SpaceAround){listOf("일간","주간","월간","연간").forEach{Text(it,Modifier.padding(horizontal=12.dp,vertical=9.dp),fontSize=14.sp,fontWeight=if(it=="일간")FontWeight.Black else FontWeight.Medium,color=if(it=="일간")RefPink else RefGray)}}
 Text("출처 축산물품질평가원 · ${p.basis} · 기준 ${formatDay(p.date)}",fontSize=10.sp,color=RefGray)
 }}}

@Composable private fun CompactChart(rows:List<HistPoint>){val data=rows.filter{it.resolution=="day"}.sortedBy{it.date}.takeLast(8);if(data.size<2){Box(Modifier.fillMaxWidth().height(105.dp),contentAlignment=Alignment.Center){Text("확정 데이터가 쌓이면 그래프를 표시합니다",fontSize=12.sp,color=RefGray)};return};val lo=data.minOf{it.price};val hi=data.maxOf{it.price};Canvas(Modifier.fillMaxWidth().height(105.dp)){for(i in 0..3){val y=size.height*i/3;drawLine(Color(0xFFE8E8EC),Offset(0f,y),Offset(size.width,y),1f)};val path=Path();data.forEachIndexed{i,p->val x=size.width*i/data.lastIndex;val y=size.height*.86f-(p.price-lo).toFloat()/(hi-lo).coerceAtLeast(1)*size.height*.68f;if(i==0)path.moveTo(x,y)else path.lineTo(x,y);drawCircle(if(i==data.lastIndex)Color.White else RefPink,if(i==data.lastIndex)7f else 4f,Offset(x,y));if(i==data.lastIndex)drawCircle(RefPink,8f,Offset(x,y),style=Stroke(4f))};drawPath(path,RefPink,style=Stroke(3.5f))}}

@Composable private fun TodayTasks(modifier:Modifier,on:()->Unit){Card(modifier.height(205.dp).clickable(onClick=on),shape=RoundedCornerShape(20.dp),colors=CardDefaults.cardColors(containerColor=RefPalePink)){Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){Row(verticalAlignment=Alignment.CenterVertically){Surface(color=Color.White,shape=RoundedCornerShape(12.dp)){Text("▦",Modifier.padding(9.dp),fontSize=25.sp,color=RefPink)};Spacer(Modifier.width(8.dp));Text("오늘 할 일",fontSize=20.sp,fontWeight=FontWeight.Black);Spacer(Modifier.weight(1f));Surface(color=RefPink,shape=CircleShape){Text("4",Modifier.padding(horizontal=9.dp,vertical=5.dp),color=Color.White,fontWeight=FontWeight.Black)}};Text("전체 4     주간 1     3주 1",fontSize=12.sp,color=RefGray);listOf("□  사료 주문        오늘","□  2그룹 이유       오늘","□  분만사 환기 점검  오늘","☑  돈사 청소        완료").forEach{Text(it,fontSize=12.sp,color=RefText)}}}}

@Composable private fun TodayWeather(modifier:Modifier,on:()->Unit){Card(modifier.height(205.dp).clickable(onClick=on),shape=RoundedCornerShape(20.dp),colors=CardDefaults.cardColors(containerColor=RefPaleBlue)){Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){Row{Text("🌤",fontSize=31.sp);Spacer(Modifier.width(8.dp));Column{Text("오늘 날씨",fontSize=20.sp,fontWeight=FontWeight.Black);Text("22℃  맑음",fontSize=23.sp,fontWeight=FontWeight.Black)}};Text("최고 28°  |  최저 18°",fontSize=13.sp,color=RefGray);Surface(color=Color.White,shape=RoundedCornerShape(13.dp)){Text("💧 습도 65%   ☂ 10%   ≋ 2m/s",Modifier.padding(10.dp),fontSize=11.sp)};Surface(color=RefPalePink,shape=RoundedCornerShape(13.dp)){Text("낮 기온이 높습니다.\n돈사 온도 관리에 유의하세요.",Modifier.padding(10.dp),fontSize=11.sp,fontWeight=FontWeight.Bold,color=RefPink)}}}}

@Composable private fun ExactMarkets(feed:JSONObject,on:()->Unit){val rows=feed.optJSONArray("markets");Card(Modifier.fillMaxWidth().clickable(onClick=on),shape=RoundedCornerShape(20.dp),colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF3F6))){Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){Row{Text("▥",fontSize=23.sp,color=RefPink);Spacer(Modifier.width(8.dp));Text("국제정세 & 원료 동향",fontSize=20.sp,fontWeight=FontWeight.Black);Spacer(Modifier.weight(1f));Text("›",fontSize=26.sp)};Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){listOf("옥수수","대두박","WTI","원/달러").forEach{name->val x=(0 until(rows?.length()?:0)).map{rows!!.getJSONObject(it)}.firstOrNull{it.optString("name")==name};Surface(Modifier.weight(1f),color=Color.White,shape=RoundedCornerShape(13.dp)){Column(Modifier.padding(horizontal=7.dp,vertical=12.dp)){Text(name,fontSize=12.sp,fontWeight=FontWeight.Black);Text(if(x==null||x.isNull("value"))"연결 대기" else x.optString("value"),Modifier.padding(top=12.dp),fontSize=13.sp,fontWeight=FontWeight.Black);Text(x?.optString("unit")?:"",fontSize=9.sp,color=RefGray)}}}}}}}

@Composable private fun ExactIssues(d:AppData,on:()->Unit){Card(Modifier.fillMaxWidth().clickable(onClick=on),shape=RoundedCornerShape(20.dp),colors=CardDefaults.cardColors(containerColor=Color.White)){Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){Row{Text("◀",color=RefPink);Spacer(Modifier.width(8.dp));Text("양돈 이슈 & 공지",fontSize=20.sp,fontWeight=FontWeight.Black);Spacer(Modifier.weight(1f));Text("더보기 ›",fontSize=12.sp,color=RefGray)};if(d.diseases.isEmpty())Text("현재 확인된 새로운 공지가 없습니다.",fontSize=12.sp,color=RefGray);d.diseases.take(3).forEach{x->Row{Surface(color=if(x.scope=="국내")RefPaleBlue else Color(0xFFEFF8F2),shape=RoundedCornerShape(7.dp)){Text(x.scope,Modifier.padding(horizontal=7.dp,vertical=3.dp),fontSize=9.sp,color=if(x.scope=="국내")RefBlue else Color(0xFF24865A))};Text("${x.disease} · ${x.summary}",Modifier.padding(start=7.dp).weight(1f),fontSize=11.sp,maxLines=1,overflow=TextOverflow.Ellipsis)}}}}}
