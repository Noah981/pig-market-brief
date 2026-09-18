package kr.pigmarketbrief

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.net.URLEncoder

data class AdminArea(val code:String,val district:String,val province:String,val rings:List<List<Pair<Double,Double>>>)

private const val ADMIN_SERVICE="https://portal.esrikr.com/arcgis/rest/services/Hosted/SGG_view/FeatureServer/0/query"

suspend fun loadAdministrativeAreas():List<AdminArea> = withContext(Dispatchers.IO){
 val query=listOf("where" to "1=1","outFields" to "sig_cd,sig_kor_nm,ctp_kor_nm","returnGeometry" to "true","outSR" to "4326","geometryPrecision" to "4","f" to "geojson").joinToString("&"){(k,v)->"$k="+URLEncoder.encode(v,"UTF-8")}
 val body=OkHttpClient.Builder().build().newCall(Request.Builder().url("$ADMIN_SERVICE?$query").build()).execute().use{if(!it.isSuccessful)error("행정경계 HTTP ${it.code}");it.body?.string()?:error("빈 행정경계")}
 val root=JSONObject(body);val result=mutableListOf<AdminArea>();val features=root.getJSONArray("features")
 for(i in 0 until features.length()){
  val f=features.getJSONObject(i);val p=f.getJSONObject("properties");val g=f.getJSONObject("geometry");val rings=mutableListOf<List<Pair<Double,Double>>>()
  fun ring(a:org.json.JSONArray){val points=mutableListOf<Pair<Double,Double>>();for(j in 0 until a.length()){val q=a.getJSONArray(j);points+=q.getDouble(0) to q.getDouble(1)};if(points.size>2)rings+=points}
  val c=g.getJSONArray("coordinates")
  if(g.getString("type")=="Polygon")for(j in 0 until c.length())ring(c.getJSONArray(j)) else for(j in 0 until c.length()){val poly=c.getJSONArray(j);for(k in 0 until poly.length())ring(poly.getJSONArray(k))}
  result+=AdminArea(p.optString("sig_cd"),p.optString("sig_kor_nm"),p.optString("ctp_kor_nm"),rings)
 }
 result
}

@Composable fun AdministrativeBoundaryMap(selectedProvince:String,selectedDistrict:String?,onSelect:(String,String)->Unit){
 var areas by remember{mutableStateOf<List<AdminArea>>(emptyList())};var error by remember{mutableStateOf<String?>(null)}
 LaunchedEffect(Unit){try{areas=loadAdministrativeAreas()}catch(e:Exception){error=e.message}}
 val west=124.3;val east=131.9;val south=33.0;val north=38.8
 Card(colors=CardDefaults.cardColors(containerColor=Color(0xFFF1F5F2)),shape=RoundedCornerShape(28.dp)){
  Box(Modifier.fillMaxWidth().height(430.dp).padding(12.dp)){
   if(areas.isEmpty())Column(Modifier.fillMaxSize(),verticalArrangement=Arrangement.Center){LinearProgressIndicator(Modifier.fillMaxWidth());Text(error?:"행정안전부 기반 시군구 경계를 불러오는 중",Modifier.padding(top=12.dp),style=MaterialTheme.typography.bodySmall)}
   else Canvas(Modifier.fillMaxSize().pointerInput(areas){detectTapGestures{tap->
    val lon=west+(tap.x/size.width)*(east-west);val lat=north-(tap.y/size.height)*(north-south)
    areas.lastOrNull{a->a.rings.any{pointInPolygon(lon,lat,it)}}?.let{onSelect(it.province,it.district)}
   }}){
    fun xy(p:Pair<Double,Double>)=Offset(((p.first-west)/(east-west)*size.width).toFloat(),((north-p.second)/(north-south)*size.height).toFloat())
    areas.forEach{a->a.rings.forEach{ring->if(ring.size>2){val path=Path();val first=xy(ring.first());path.moveTo(first.x,first.y);ring.drop(1).forEach{q->val v=xy(q);path.lineTo(v.x,v.y)};path.close();val selected=a.province==selectedProvince&&(selectedDistrict==null||a.district==selectedDistrict);drawPath(path,if(selected)Color(0xFF256C5A) else Color.White);drawPath(path,Color(0xFFB5C3BC),style=Stroke(if(selected)2.4f else 1f))}}}
   }
  }
 }
 Text("${selectedProvince}${selectedDistrict?.let{" · $it"}?:""}",style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=10.dp))
 Text("행정안전부 주소기반산업지원서비스 원본 · Esri Korea 2026.07 서비스",style=MaterialTheme.typography.labelSmall,color=Color.Gray)
}

private fun pointInPolygon(x:Double,y:Double,polygon:List<Pair<Double,Double>>):Boolean{var inside=false;var j=polygon.lastIndex;for(i in polygon.indices){val xi=polygon[i].first;val yi=polygon[i].second;val xj=polygon[j].first;val yj=polygon[j].second;if(((yi>y)!=(yj>y))&&(x<(xj-xi)*(y-yi)/(yj-yi+1e-12)+xi))inside=!inside;j=i};return inside}
