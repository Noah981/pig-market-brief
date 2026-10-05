package com.example.dondonhae

import android.content.Context
import android.graphics.*
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
@Config(sdk=[28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class PriceCardArtworkTest {
    private val context:Context get()=RuntimeEnvironment.getApplication()
    // Explicit synthetic scenarios verify repainting; no sample number is shipped as live data.
    private val fixture=PriceData(6420.0,6452.0,-32.0,-.5,"20261006","",(1..6).map{PricePoint("2026100$it",6500.0-it*13)})
    private val grades=GradeData("20261006",mapOf("1+" to 6812.0,"1" to 6681.0,"2" to 6402.0,"등외" to 5970.0),mapOf("1+" to 6840.0,"1" to 6711.0,"2" to 6434.0,"등외" to 6011.0))
    private fun save(b:Bitmap,name:String){val f=File("build/widget-screenshots/$name.png");f.parentFile!!.mkdirs();f.outputStream().use{assertTrue(b.compress(Bitmap.CompressFormat.PNG,100,it))}}
    @Test fun fourSizesPreserveSourceArtworkAndRepaintActualFields(){
        val source=context.assets.open("widget/four_price_reference.png").use{BitmapFactory.decodeStream(it)}
        for(kind in PriceCardArtwork.Kind.values()){
            val b=PriceCardArtwork.render(context,kind.w.toInt(),kind.h.toInt(),fixture,grades,kind,"10. 6 (화)")
            assertEquals(0,Color.alpha(b.getPixel(0,0)))
            // Brand pixels use the supplied image's actual coordinate system.
            assertEquals(source.getPixel(kind.crop.left+55,kind.crop.top+45),b.getPixel(55,45))
            val changed=PriceCardArtwork.render(context,kind.w.toInt(),kind.h.toInt(),fixture.copy(price=7123.0,change=89.0,percent=1.2,history=fixture.history.map{it.copy(price=8000-it.price)}),grades,kind,"10. 7 (수)")
            var differences=0
            for(x in 20 until kind.w.toInt()-20 step 4)for(y in 80 until kind.h.toInt()-20 step 4)if(b.getPixel(x,y)!=changed.getPixel(x,y))differences++
            assertTrue("Price/chart fields must repaint for $kind",differences>50)
            save(b,"four_${kind.name.lowercase()}_fixture")
            save(PriceCardArtwork.render(context,kind.w.toInt()/2,kind.h.toInt()/2,fixture.copy(price=null,change=null,percent=null,history=emptyList()),GradeData("",emptyMap(),emptyMap()),kind,"10. 6 (화)"),"four_${kind.name.lowercase()}_missing")
        };source.recycle()
    }
    @Test fun remoteViewsInflatesAllFourSizes(){
        for(kind in PriceCardArtwork.Kind.values()){
            val size=when(kind){PriceCardArtwork.Kind.SMALL->180 to 174;PriceCardArtwork.Kind.MEDIUM->360 to 142;PriceCardArtwork.Kind.LARGE->360 to 147;PriceCardArtwork.Kind.TODAY->150 to 214}
            val w=size.first;val h=size.second
            val bitmap=PriceCardArtwork.render(context,w,h,fixture,grades,kind,"10. 6 (화)")
            val views=RemoteViews(context.packageName,R.layout.widget_price_small);views.setImageViewBitmap(R.id.price_artwork,bitmap)
            val view=views.apply(context,null)
            view.measure(android.view.View.MeasureSpec.makeMeasureSpec(w,android.view.View.MeasureSpec.EXACTLY),android.view.View.MeasureSpec.makeMeasureSpec(h,android.view.View.MeasureSpec.EXACTLY));view.layout(0,0,w,h)
            val captured=Bitmap.createBitmap(w,h,Bitmap.Config.ARGB_8888);view.draw(Canvas(captured))
            assertEquals(bitmap.getPixel(w/2,h/2),captured.getPixel(w/2,h/2));save(captured,"four_${kind.name.lowercase()}_remote_views")
        }
    }
    @Test fun weekAverageUsesOnlyThisWeeksPublishedRows(){
        // The current Korean date varies; an ancient week must never substitute.
        assertNull(PriceCardArtwork.weekAverage(fixture.copy(history=listOf(PricePoint("20000101",5000.0)))))
    }
    @Test fun officialQuotesAndGradeTablesRenderAllFourCards(){
        fun input(name:String)=javaClass.getResourceAsStream("/widget/$name")!!.bufferedReader().use{it.readText()}
        val row=org.json.JSONObject(input("official-price.json"))
        val history=org.json.JSONObject(input("official-history.json"))
        val current=NativeGradeRefresh.parse(input("official-current-grade.html"),row.getString("date"))
        val previous=NativeGradeRefresh.parse(input("official-previous-grade.html"),row.getString("previousDate"))
        assertNotNull("Actual official grade response must parse",current);assertNotNull(previous)
        val prefs=context.getSharedPreferences("FlutterSharedPreferences",Context.MODE_PRIVATE)
        prefs.edit().putString("flutter.official_dabom_producer_pig_price_v4",org.json.JSONObject().put("price",row).put("history",history).toString())
            .putString("flutter.official_kape_pig_grades_v1",NativeGradeRefresh.merge(null,current!!,previous)).commit()
        val price=WidgetStore.price(context);val g=WidgetStore.grades(context)
        assertEquals(row.getDouble("price"),price.price!!,0.0);assertEquals(4,g.current.size)
        assertEquals(price.price!!,PriceCardArtwork.dailyPlot(price).last().price,0.0)
        for(kind in PriceCardArtwork.Kind.values()) save(PriceCardArtwork.render(context,kind.w.toInt(),kind.h.toInt(),price,g,kind,"${price.date.substring(4,6).toInt()}. ${price.date.substring(6,8).toInt()} 기준"),"four_${kind.name.lowercase()}_live")
    }
    @Test fun correctedQuoteAlsoCorrectsGraphEndpoint(){
        val points=PriceCardArtwork.dailyPlot(fixture.copy(price=7000.0))
        assertEquals(7000.0,points.last().price,0.0)
    }

}
