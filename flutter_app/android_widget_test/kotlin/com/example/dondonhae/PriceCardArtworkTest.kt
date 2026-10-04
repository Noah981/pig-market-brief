package com.example.dondonhae

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.widget.RemoteViews
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class PriceCardArtworkTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val fixture = PriceData(6057.0, 6027.0, 30.0, .5, "20261002", "", emptyList())
    private fun save(bitmap: Bitmap, name: String) {
        val file = File("build/widget-screenshots/$name.png"); file.parentFile!!.mkdirs()
        file.outputStream().use { assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
    }
    @Test fun nativeCardUsesLiveFieldsWithoutChangingIllustration() {
        val reference = PriceCardArtwork.render(context, 1332, 765, fixture, "10월 3일 (토)")
        val updated = PriceCardArtwork.render(context, 1332, 765, fixture.copy(price=7123.0,change=-70.0,percent=-1.0,date="20261005"), "10월 6일 (화)")
        assertEquals(0, Color.alpha(reference.getPixel(0, 0)))
        // The pig/heart/flower region remains identical when all live text changes.
        for (x in 740 until 1280 step 7) for (y in 170 until 740 step 7) assertEquals(reference.getPixel(x,y),updated.getPixel(x,y))
        var changed=0
        for (x in 70 until 690 step 3) for (y in 410 until 570 step 3) if (reference.getPixel(x,y)!=updated.getPixel(x,y)) changed++
        assertTrue("Live price must repaint the number",changed>100)
        save(reference,"price_card_reference_size"); save(updated,"price_card_down")
        save(PriceCardArtwork.render(context,720,414,fixture,"10월 3일 (토)"),"price_card_360")
        save(PriceCardArtwork.render(context,320,320,fixture,"10월 3일 (토)"),"price_card_square_host")
        save(PriceCardArtwork.render(context,720,414,fixture.copy(price=null,change=null,percent=null,date=""),"10월 3일 (토)"),"price_card_missing")
    }
    @Test fun remoteViewsActuallyInflatesAndDisplaysRenderedCard() {
        val bitmap=PriceCardArtwork.render(context,720,414,fixture,"10월 3일 (토)")
        val views=RemoteViews(context.packageName,R.layout.widget_price_small)
        views.setImageViewBitmap(R.id.price_artwork,bitmap)
        val view=views.apply(context,null)
        view.measure(android.view.View.MeasureSpec.makeMeasureSpec(720,android.view.View.MeasureSpec.EXACTLY),android.view.View.MeasureSpec.makeMeasureSpec(414,android.view.View.MeasureSpec.EXACTLY))
        view.layout(0,0,720,414)
        val captured=Bitmap.createBitmap(720,414,Bitmap.Config.ARGB_8888)
        view.draw(android.graphics.Canvas(captured))
        assertEquals(bitmap.getPixel(300,200),captured.getPixel(300,200))
        save(captured,"price_card_remote_views")
    }
}
