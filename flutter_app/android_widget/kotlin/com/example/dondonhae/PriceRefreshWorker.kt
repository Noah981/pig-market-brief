package com.example.dondonhae

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/** Refreshes without a foreground Flutter engine or its activity-only channel. */
class PriceRefreshWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result {
        try {
            val connection = URL("https://noah981.github.io/pig-market-brief/data/pig-price.json?v=${System.currentTimeMillis()}").openConnection() as HttpURLConnection
            connection.connectTimeout = 12000; connection.readTimeout = 12000
            connection.setRequestProperty("Cache-Control", "no-cache")
            val text = try {
                if (connection.responseCode != 200) return Result.retry()
                connection.inputStream.bufferedReader().use { it.readText() }
            } finally { connection.disconnect() }
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val key = "flutter.official_dabom_producer_pig_price_v4"
            val stored = prefs.getString(key, null)
            val merged = mergeVerifiedPrice(stored, text)
            if (merged == null) return Result.retry()
            if (!prefs.edit().putString(key, merged).commit()) return Result.retry()
            return Result.success()
        } catch (_: Exception) { return Result.retry() }
        finally { WidgetRenderer.updateAll(applicationContext) }
    }
    companion object {
        fun schedule(context: Context) {
            val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val manager = WorkManager.getInstance(context)
            manager.enqueueUniquePeriodicWork("native-official-price-v1", ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<PriceRefreshWorker>(30, TimeUnit.MINUTES).setConstraints(constraints).build())
            manager.enqueueUniqueWork("native-official-price-now-v1", ExistingWorkPolicy.KEEP,
                OneTimeWorkRequestBuilder<PriceRefreshWorker>().setConstraints(constraints).build())
        }
        internal fun mergeVerifiedPrice(stored: String?, incoming: String, now: Date = Date()): String? {
            val row = try { JSONObject(incoming) } catch (_: Exception) { return null }
            val value = row.optDouble("price", Double.NaN)
            val date = row.optString("date")
            val parser = SimpleDateFormat("yyyyMMdd", Locale.US).apply { isLenient = false; timeZone = TimeZone.getTimeZone("Asia/Seoul") }
            val validDate = try { date.length == 8 && parser.format(parser.parse(date)!!) == date && date <= parser.format(now) } catch (_: Exception) { false }
            val scope = row.optString("scope").replace(" ", "")
            if (!value.isFinite() || value <= 0 || !validDate || !scope.contains("제주제외") || row.optString("status") != "ok") return null
            val old = try { JSONObject(stored ?: "{}") } catch (_: Exception) { JSONObject() }
            val prior = old.optJSONObject("price") ?: old
            if (prior.optString("date") > date) return old.toString()
            // Retain full historical rows and the official price basis on holidays.
            old.put("price", row)
            return old.toString()
        }
    }
}

class WidgetClockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetRenderer.updateAll(context)
        PriceRefreshWorker.schedule(context)
    }
}
