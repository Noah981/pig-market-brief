package com.example.dondonhae

import android.content.Context
import android.graphics.*
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.min
import kotlin.math.roundToInt

/** Source coordinates follow the supplied 1536 × 1024 card, with live data. */
object PriceCardArtwork {
    private const val WIDTH = 1332f
    private const val HEIGHT = 765f
    private val crop = Rect(102, 130, 1434, 895)
    private val number = NumberFormat.getIntegerInstance(Locale.KOREA)
    fun render(context: Context, width: Int, height: Int, data: PriceData, today: String): Bitmap {
        val bitmap = Bitmap.createBitmap(width.coerceAtLeast(1), height.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val scale = min(width / WIDTH, height / HEIGHT)
        canvas.translate((width - WIDTH * scale) / 2, (height - HEIGHT * scale) / 2)
        canvas.scale(scale, scale)
        canvas.clipPath(Path().apply { addRoundRect(RectF(0f, 0f, WIDTH, HEIGHT), 92f, 92f, Path.Direction.CW) })
        val art = context.assets.open("widget/price_card_art.png").use { BitmapFactory.decodeStream(it) }
        canvas.drawBitmap(art, crop, RectF(0f, 0f, WIDTH, HEIGHT), Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        art.recycle()
        val korean = Typeface.createFromAsset(context.assets, "widget/NotoSansKR.ttf")
        val heavy = Typeface.create("sans-serif-black", Typeface.NORMAL)
        fun text(value: String, x: Float, baseline: Float, size: Float, color: Int, face: Typeface, maxWidth: Float) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color; typeface = face; textSize = size }
            if (paint.measureText(value) > maxWidth) paint.textSize *= maxWidth / paint.measureText(value)
            canvas.drawText(value, x - 102, baseline - 130, paint)
        }
        text(today, 1016f, 260f, 60f, 0xFF706B6D.toInt(), korean, 340f)
        val basis = if (data.date.length == 8) "${data.date.substring(4, 6)}/${data.date.substring(6, 8)} 기준" else "기준일 확인 중"
        text(basis, 173f, 512f, 56f, 0xFF999598.toInt(), korean, 430f)
        val price = data.price?.let { number.format(it.roundToInt()) }
        if (price != null) {
            text(price, 166f, 679f, 176f, 0xFF191A1C.toInt(), heavy, 465f)
            text("원/kg", 636f, 668f, 65f, 0xFF191A1C.toInt(), korean, 169f)
        } else text("확인 중", 173f, 665f, 110f, 0xFF777B85.toInt(), korean, 600f)
        val change = data.change
        val color = when { change == null || change == 0.0 -> 0xFF777B85.toInt(); change > 0 -> 0xFFFA456D.toInt(); else -> 0xFF2087D4.toInt() }
        if (change == null) text("변동 확인 중", 173f, 803f, 65f, color, korean, 585f)
        else {
            val up = change > 0
            if (change != 0.0) {
                val path = Path().apply {
                    if (up) { moveTo(174f - 102, 803f - 130); lineTo(211f - 102, 735f - 130); lineTo(249f - 102, 803f - 130) }
                    else { moveTo(174f - 102, 737f - 130); lineTo(211f - 102, 805f - 130); lineTo(249f - 102, 737f - 130) }
                    close()
                }
                canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color })
            }
            val delta = (if (up) "+" else "") + number.format(change.roundToInt())
            val pct = data.percent?.takeIf { it.isFinite() }?.let { " (${if (it > 0) "+" else ""}${String.format(Locale.US, "%.1f", it)}%)" } ?: ""
            text(delta + pct, if (change == 0.0) 173f else 267f, 803f, 93f, color, heavy, if (change == 0.0) 580f else 492f)
        }
        return bitmap
    }
}
