package com.example.dondonhae
import android.content.Context
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.text.SimpleDateFormat
import java.util.*
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WeatherCacheTest {
  private fun save(offsetDays:Int,region:String="경상북도 김천시"):Context {
    val context=RuntimeEnvironment.getApplication()
    val date=SimpleDateFormat("yyyyMMdd",Locale.KOREA).apply {timeZone=TimeZone.getTimeZone("Asia/Seoul")}.format(Date(System.currentTimeMillis()+offsetDays*86400000L))
    val row=JSONObject().put("region",region).put("forecastDate",date).put("tempMax",27).put("humidityMax",85).put("rainProbabilityMax",40)
    val root=JSONObject().put("regions",org.json.JSONArray().put(row)).put("updatedAt",date)
    context.getSharedPreferences("FlutterSharedPreferences",Context.MODE_PRIVATE).edit().clear().putString("flutter.farm_location_province","경상북도").putString("flutter.farm_location_city_county","김천시").putString("flutter.weather_farm_guide_v2",root.toString()).commit()
    return context
  }
  @Test fun todayForecastUsesTheSameVerifiedCacheAsTheApp(){
    val value=WidgetStore.weather(save(0));assertEquals(27.0,value.temperature!!,0.0);assertEquals(85.0,value.humidity!!,0.0)
  }
  @Test fun previousDayAndOtherRegionsAreNeverShownAsToday(){
    assertNull(WidgetStore.weather(save(-1)).temperature)
    assertNull(WidgetStore.weather(save(0,"대구광역시")).temperature)
  }
}
