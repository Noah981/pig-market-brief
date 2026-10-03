package com.example.dondonhae

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

data class PricePoint(val date: String, val price: Double)
data class PriceData(val price: Double?, val previous: Double?, val change: Double?, val percent: Double?, val date: String, val updatedAt: String, val history: List<PricePoint>)
data class GradeData(val date: String, val current: Map<String, Double>, val previous: Map<String, Double>)
data class WeatherData(val region: String, val temperature: Double?, val rain: Double?, val humidity: Double?, val updatedAt: String)

object WidgetStore {
    private const val PREFS = "FlutterSharedPreferences"
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun raw(context: Context, key: String): String? = prefs(context).getString("flutter.$key", null)
    private fun objectOrNull(text: String?): JSONObject? = try { if (text == null) null else JSONObject(text) } catch (_: Exception) { null }

    fun price(context: Context): PriceData {
        val root = objectOrNull(raw(context, "official_dabom_producer_pig_price_v4"))
        val price = root?.optJSONObject("price") ?: root
        val rows = root?.optJSONObject("history")?.optJSONArray("rows") ?: JSONArray()
        val history = buildList {
            for (i in 0 until rows.length()) {
                val row = rows.optJSONObject(i) ?: continue
                val date = row.optString("date")
                val value = row.optDouble("price", Double.NaN)
                if (date.length == 8 && value.isFinite()) add(PricePoint(date, value))
            }
        }.sortedBy { it.date }
        return PriceData(
            price?.number("price"), price?.number("previousPrice"), price?.number("change"),
            price?.number("changePct"), price?.optString("date") ?: "", price?.optString("updatedAt") ?: "", history
        )
    }

    fun grades(context: Context): GradeData {
        val root = objectOrNull(raw(context, "official_kape_pig_grades_v1")) ?: return GradeData("", emptyMap(), emptyMap())
        val date = root.optString("date")
        val rows = root.optJSONArray("history") ?: JSONArray()
        val dates = mutableSetOf<String>()
        val all = mutableListOf<Triple<String, String, Double>>()
        for (i in 0 until rows.length()) {
            val row = rows.optJSONObject(i) ?: continue
            val d = row.optString("date"); val g = normalizeGrade(row.optString("grade")); val p = row.optDouble("price", Double.NaN)
            if (d.isNotBlank() && g.isNotBlank() && p.isFinite()) { dates.add(d); all.add(Triple(d, g, p)) }
        }
        val previousDate = dates.filter { it < date }.maxOrNull()
        return GradeData(date, all.filter { it.first == date }.associate { it.second to it.third }, all.filter { it.first == previousDate }.associate { it.second to it.third })
    }

    private fun normalizeGrade(value: String): String = when (value.trim().replace("등급", "")) { "1+", "1＋" -> "1+"; "1" -> "1"; "2" -> "2"; "등외", "E" -> "등외"; else -> value.trim() }

    fun weather(context: Context): WeatherData {
        val p = prefs(context)
        val province = p.getString("flutter.farm_location_province", "") ?: ""
        val city = p.getString("flutter.farm_location_city_county", "") ?: ""
        val town = p.getString("flutter.farm_location_town", "") ?: ""
        val configured = listOf(city, town).filter { it.isNotBlank() }.joinToString(" ").ifBlank { province }
        val root = objectOrNull(raw(context, "weather_farm_guide_v1"))
        val rows = root?.optJSONArray("regions")
        val label = listOf(province, city, town).filter { it.isNotBlank() }.joinToString(" ")
        // A saved forecast from the previous region must not acquire the new label.
        val row = (0 until (rows?.length() ?: 0)).mapNotNull { rows?.optJSONObject(it) }
            .firstOrNull { it.optString("region") == label || it.optString("region") == configured || it.optString("region") == province }
        val region = row?.optString("region") ?: configured.ifBlank { "지역 미설정" }
        return WeatherData(region, row?.number("tempMax"), row?.number("rainProbabilityMax"), row?.number("humidityMax"), root?.optString("updatedAt") ?: "")
    }

    fun todos(context: Context): List<String> {
        val root = try { JSONArray(raw(context, "widget_tasks_v1") ?: "[]") } catch (_: Exception) { JSONArray() }
        val today = SimpleDateFormat("yyyyMMdd", Locale.KOREA).format(Date())
        return buildList {
            for (i in 0 until root.length()) {
                val row = root.optJSONObject(i) ?: continue
                if (!row.optBoolean("done", false) && (row.optString("date").isBlank() || row.optString("date") == today)) {
                    val title = row.optString("title").trim(); if (title.isNotEmpty()) add(title)
                }
            }
        }.take(30)
    }

    private fun JSONObject.number(key: String): Double? = if (!has(key) || isNull(key)) null else optDouble(key, Double.NaN).takeIf { it.isFinite() }
}

object WidgetRenderer {
    private val formatter = NumberFormat.getIntegerInstance(Locale.KOREA)
    private const val UP = 0xFFF52D68.toInt()
    private const val DOWN = 0xFF2087D4.toInt()
    private const val FLAT = 0xFF6B7280.toInt()

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        listOf(
            PigPriceSmallWidget::class.java, PigPriceDetailWidget::class.java, PigGradeWidget::class.java,
            WeatherTodoWidget::class.java, TodayOverviewWidget::class.java
        ).forEach { cls -> manager.getAppWidgetIds(ComponentName(context, cls)).forEach { update(context, manager, it, cls) } }
    }

    fun update(context: Context, manager: AppWidgetManager, id: Int, cls: Class<*>) {
        when (cls) {
            PigPriceSmallWidget::class.java -> priceSmall(context, manager, id)
            PigPriceDetailWidget::class.java -> priceDetail(context, manager, id)
            PigGradeWidget::class.java -> grade(context, manager, id)
            WeatherTodoWidget::class.java -> weatherTodo(context, manager, id)
            TodayOverviewWidget::class.java -> today(context, manager, id)
        }
    }

    private fun priceSmall(context: Context, manager: AppWidgetManager, id: Int) {
        val data = WidgetStore.price(context); val views = RemoteViews(context.packageName, R.layout.widget_price_small)
        bindPrice(views, data); views.setTextViewText(R.id.widget_date, todayLabel()); views.setOnClickPendingIntent(R.id.widget_root, deepLink(context, "dondonhae://market/pig-price", 101 + id))
        val width = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
        views.setViewVisibility(R.id.pig_mascot, View.GONE); manager.updateAppWidget(id, views)
    }

    private fun priceDetail(context: Context, manager: AppWidgetManager, id: Int) {
        val data = WidgetStore.price(context); val views = RemoteViews(context.packageName, R.layout.widget_price_detail)
        bindPrice(views, data); views.setTextViewText(R.id.widget_date, todayLabel())
        views.setTextViewText(R.id.price_yesterday, money(data.previous))
        views.setTextViewText(R.id.price_week, money(nearest(data.history, 7)?.price))
        views.setTextViewText(R.id.price_year, money(nearest(data.history, 365)?.price))
        if (data.history.size >= 2) { views.setImageViewBitmap(R.id.sparkline, sparkline(data.history.takeLast(12))); views.setViewVisibility(R.id.sparkline, View.VISIBLE) } else views.setViewVisibility(R.id.sparkline, View.GONE)
        views.setOnClickPendingIntent(R.id.widget_root, deepLink(context, "dondonhae://market/pig-price", 201 + id)); manager.updateAppWidget(id, views)
    }

    private fun grade(context: Context, manager: AppWidgetManager, id: Int) {
        val data = WidgetStore.grades(context); val views = RemoteViews(context.packageName, R.layout.widget_grade)
        views.setTextViewText(R.id.widget_data_date, dateBasis(data.date))
        listOf("1+" to Pair(R.id.grade_1p_price, R.id.grade_1p_change), "1" to Pair(R.id.grade_1_price, R.id.grade_1_change), "2" to Pair(R.id.grade_2_price, R.id.grade_2_change), "등외" to Pair(R.id.grade_out_price, R.id.grade_out_change)).forEach { (g, ids) ->
            val value = data.current[g]; val change = if (value != null && data.previous[g] != null) value - data.previous[g]!! else null
            views.setTextViewText(ids.first, money(value)); views.setTextViewText(ids.second, changeText(change, null)); views.setTextColor(ids.second, changeColor(change))
        }
        views.setOnClickPendingIntent(R.id.widget_root, deepLink(context, "dondonhae://market/pig-price/grade", 301 + id)); manager.updateAppWidget(id, views)
    }

    private fun weatherTodo(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_weather_todo); bindWeather(views, WidgetStore.weather(context)); bindTodos(views, WidgetStore.todos(context))
        views.setOnClickPendingIntent(R.id.weather_section, deepLink(context, "dondonhae://weather", 401 + id)); views.setOnClickPendingIntent(R.id.todo_section, deepLink(context, "dondonhae://tasks", 402 + id)); manager.updateAppWidget(id, views)
    }

    private fun today(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_today); bindPrice(views, WidgetStore.price(context)); bindWeather(views, WidgetStore.weather(context)); bindTodos(views, WidgetStore.todos(context))
        views.setOnClickPendingIntent(R.id.price_section, deepLink(context, "dondonhae://market/pig-price", 501 + id)); views.setOnClickPendingIntent(R.id.weather_section, deepLink(context, "dondonhae://weather", 502 + id)); views.setOnClickPendingIntent(R.id.todo_section, deepLink(context, "dondonhae://tasks", 503 + id)); manager.updateAppWidget(id, views)
    }

    private fun bindPrice(views: RemoteViews, data: PriceData) {
        views.setTextViewText(R.id.price_value, money(data.price)); views.setTextViewText(R.id.price_change, changeText(data.change, data.percent)); views.setTextColor(R.id.price_change, changeColor(data.change)); views.setTextViewText(R.id.widget_data_date, dateBasis(data.date))
    }
    private fun bindWeather(views: RemoteViews, data: WeatherData) {
        views.setTextViewText(R.id.weather_region, data.region); views.setTextViewText(R.id.weather_temp, data.temperature?.let { "${it.roundToInt()}°" } ?: "-")
        val condition = when { data.rain == null -> "기상청 데이터 확인 중"; data.rain >= 60 -> "비 가능성 높음"; data.rain >= 30 -> "구름 많음"; else -> "맑음" }
        views.setTextViewText(R.id.weather_condition, condition); views.setTextViewText(R.id.weather_icon, when { data.rain == null -> "·"; data.rain >= 60 -> "☂"; data.rain >= 30 -> "☁"; else -> "☀" }); views.setTextViewText(R.id.weather_rain, data.rain?.let { "강수확률 ${it.roundToInt()}%" } ?: "강수확률 -")
    }
    private fun bindTodos(views: RemoteViews, todos: List<String>) {
        views.setTextViewText(R.id.todo_count, "오늘 할 일 ${todos.size}"); val ids = listOf(R.id.todo_1, R.id.todo_2, R.id.todo_3)
        ids.forEachIndexed { index, viewId -> views.setTextViewText(viewId, todos.getOrNull(index)?.let { "○ $it" } ?: if (index == 0) "등록된 할 일이 없습니다" else "") }
    }

    private fun nearest(points: List<PricePoint>, days: Int): PricePoint? {
        val target = System.currentTimeMillis() - days * 86_400_000L
        val parser = SimpleDateFormat("yyyyMMdd", Locale.KOREA)
        return points.minByOrNull { kotlin.math.abs((try { parser.parse(it.date)?.time ?: 0L } catch (_: Exception) { 0L }) - target) }
    }
    private fun money(value: Double?): String = value?.let { formatter.format(it.roundToInt()) } ?: "-"
    private fun changeText(change: Double?, percent: Double?): String {
        if (change == null) return "-"; val arrow = when { change > 0 -> "▲ +"; change < 0 -> "▼ "; else -> "- " }
        return arrow + formatter.format(change.roundToInt()) + (percent?.takeIf { it.isFinite() }?.let { " (${if (it > 0) "+" else ""}${String.format(Locale.US, "%.1f", it)}%)" } ?: "")
    }
    private fun changeColor(change: Double?): Int = when { change == null || change == 0.0 -> FLAT; change > 0 -> UP; else -> DOWN }
    private fun dateBasis(date: String): String = if (date.length == 8) "${date.substring(4, 6).toIntOrNull() ?: date.substring(4,6)}/${date.substring(6,8)} 기준" else "데이터 확인 중"
    private fun todayLabel(): String = SimpleDateFormat("M월 d일 (E)", Locale.KOREA).format(Date())
    private fun deepLink(context: Context, uri: String, requestCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri), context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    private fun sparkline(points: List<PricePoint>): Bitmap {
        val width = 420; val height = 150; val pad = 12f; val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888); val canvas = Canvas(bitmap)
        val min = points.minOf { it.price }; val max = points.maxOf { it.price }; val range = (max - min).takeIf { it > 0 } ?: 1.0
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x22F52D68; style = Paint.Style.FILL }; val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = UP; style = Paint.Style.STROKE; strokeWidth = 7f; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND }
        val path = android.graphics.Path(); points.forEachIndexed { i, p -> val x = pad + i * (width - pad * 2) / (points.size - 1); val y = pad + (max - p.price).toFloat() / range.toFloat() * (height - pad * 2); if (i == 0) path.moveTo(x, y) else path.lineTo(x, y) }
        val area = android.graphics.Path(path); area.lineTo(width - pad, height - pad); area.lineTo(pad, height - pad); area.close(); canvas.drawPath(area, fill); canvas.drawPath(path, line); return bitmap
    }
}

abstract class BaseDondonWidget : AppWidgetProvider() {
    abstract val providerClass: Class<*>
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = ids.forEach { WidgetRenderer.update(context, manager, it, providerClass) }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = WidgetRenderer.update(context, manager, id, providerClass)
}
class PigPriceSmallWidget : BaseDondonWidget() { override val providerClass = PigPriceSmallWidget::class.java }
class PigPriceDetailWidget : BaseDondonWidget() { override val providerClass = PigPriceDetailWidget::class.java }
class PigGradeWidget : BaseDondonWidget() { override val providerClass = PigGradeWidget::class.java }
class WeatherTodoWidget : BaseDondonWidget() { override val providerClass = WeatherTodoWidget::class.java }
class TodayOverviewWidget : BaseDondonWidget() { override val providerClass = TodayOverviewWidget::class.java }
