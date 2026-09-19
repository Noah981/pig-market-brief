package kr.pigmarketbrief

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.json.JSONObject

private val Pink = Color(0xFFFF376A)
@Composable fun ReferenceHome(d:AppData,feed:JSONObject,price:()->Unit,market:()->Unit,open:(String)->Unit,refresh:()->Unit){
 DondonHero()
 Card(Modifier.fillMaxWidth(),shape=RoundedCornerShape(24.dp),colors=CardDefaults.cardColors(containerColor=Color.White)){
  Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
   Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Text("전국 돈가",Modifier.weight(1f),fontSize=24.sp,fontWeight=FontWeight.Black);IconButton(refresh){Text("↻",fontSize=25.sp)}}
   Text(d.pig.basis,fontSize=12.sp,color=Color.Gray)
   Text(d.pig.price?.let{"${comma(it)} 원/kg"}?:"발표 대기",Modifier.clickable(onClick=price),fontSize=40.sp,fontWeight=FontWeight.Black)
   val previous=d.pig.previous;val current=d.pig.price
   if(previous!=null&&current!=null){val delta=current-previous;Text("${if(delta<0)"▼" else "▲"} ${comma(kotlin.math.abs(delta))}원",fontSize=23.sp,fontWeight=FontWeight.Bold,color=if(delta<0)Color(0xFF087BF4)else Pink);Text("전일 ${comma(previous)}원",color=Color.Gray)}
   val points=d.history.filter{it.resolution=="day"}.takeLast(8)
   if(points.isNotEmpty())TouchPriceChart(points)else Text("확정 가격이 수집되면 그래프를 표시합니다.",Modifier.padding(vertical=24.dp),color=Color.Gray)
   Row(Modifier.fillMaxWidth().background(Color(0xFFF7F7F9),RoundedCornerShape(24.dp)),horizontalArrangement=Arrangement.SpaceAround){listOf("일간","주간","월간","연간").forEach{TextButton(price){Text(it,color=if(it=="일간")Pink else Color.Gray)}}}
   Text("기준 ${formatDay(d.pig.date)} · ${priceStatus(d.pig)}\n축산물품질평가원 · ${displayUpdate(d.pig.updatedAt)}",fontSize=12.sp,color=Color.Gray)
  }
 }
 Row(horizontalArrangement=Arrangement.spacedBy(10.dp)){
  Card(Modifier.weight(1f).heightIn(min=190.dp).clickable{open("사료")},colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF0F5)),shape=RoundedCornerShape(20.dp)){
   Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){Text("▦ 오늘 할 일",fontSize=20.sp,fontWeight=FontWeight.Bold);Text("사료 주문",fontWeight=FontWeight.Bold);Text("주문시기 확인",fontSize=14.sp,color=Color.Gray);Text("알림 설정  ›",color=Pink)}
  }
  Card(Modifier.weight(1f).heightIn(min=190.dp).clickable{open("지역")},colors=CardDefaults.cardColors(containerColor=Color(0xFFEEF7FF)),shape=RoundedCornerShape(20.dp)){
   Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){Text("☀ 오늘 날씨",fontSize=20.sp,fontWeight=FontWeight.Bold);Text("내 위치  ›",color=Color(0xFF087BF4));Text("지역을 선택해\n기상정보 확인",fontSize=16.sp)}
  }
 }
 Card(Modifier.fillMaxWidth().clickable(onClick=market),colors=CardDefaults.cardColors(containerColor=Color(0xFFFFF3F6)),shape=RoundedCornerShape(20.dp)){
  Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
   Text("▥ 국제정세 & 원료 동향  ›",fontSize=21.sp,fontWeight=FontWeight.Bold)
   Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){
    listOf("옥수수","대두박","WTI","원/달러").forEach{name->
     Surface(Modifier.weight(1f),color=Color.White,shape=RoundedCornerShape(14.dp)){
      Column(Modifier.padding(horizontal=6.dp,vertical=14.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
       Text(name,fontSize=13.sp,fontWeight=FontWeight.Bold)
       val rows=feed.optJSONArray("markets");val row=(0 until(rows?.length()?:0)).map{rows!!.getJSONObject(it)}.firstOrNull{it.optString("name")==name}
       Text(if(row==null||row.isNull("value"))"확인 중" else row.optString("value"),fontSize=14.sp,fontWeight=FontWeight.Bold)
       Text(row?.optString("unit")?:"연결 대기",fontSize=11.sp,color=Color.Gray)
      }
     }
    }
   }
  }
 }
 Card(Modifier.fillMaxWidth().clickable{open("질병")},colors=CardDefaults.cardColors(containerColor=Color.White),shape=RoundedCornerShape(20.dp)){
  Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
   Text("◀ 양돈 이슈 & 공지  ›",fontSize=21.sp,fontWeight=FontWeight.Bold)
   if(d.diseases.isEmpty())Text("새로운 공식 소식을 확인하고 있습니다.",color=Color.Gray,fontSize=14.sp)
   d.diseases.take(3).forEach{Text("${it.scope} · ${it.disease}  ${it.summary}",fontSize=14.sp,maxLines=2);HorizontalDivider(color=Color(0xFFF1F1F3))}
  }
 }
}
