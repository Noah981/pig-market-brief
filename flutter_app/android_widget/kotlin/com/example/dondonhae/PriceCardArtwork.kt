package com.example.dondonhae

import android.content.Context
import android.graphics.*
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.*

/** Four live cards, using measured source coordinates from the supplied reference.
 * Brand/pig artwork is retained; numbers and every chart pixel are rendered data. */
object PriceCardArtwork {
    enum class Kind(val crop: Rect, val w: Float, val h: Float) {
        SMALL(Rect(90,80,470,448),380f,368f),
        MEDIUM(Rect(519,79,1459,448),940f,369f),
        LARGE(Rect(90,518,1137,945),1047f,427f),
        TODAY(Rect(1170,521,1460,935),290f,414f)
    }
    private val white=Color.WHITE
    private val muted=0xFFB1B8C6.toInt()
    private val green=0xFF48D4A0.toInt()
    private val red=0xFFFF6C83.toInt()
    private val fmt=NumberFormat.getIntegerInstance(Locale.KOREA)
    private fun money(v:Double?)=v?.let { fmt.format(it.roundToInt()) } ?: "—"
    internal fun weekAverage(data:PriceData):Double? {
        // Average published daily prices in the current Korean calendar week;
        // no nearest-date substitute, no monthly rows, no made-up holiday values.
        val cal=Calendar.getInstance(TimeZone.getTimeZone("Asia/Seoul"))
        cal.set(Calendar.HOUR_OF_DAY,0);cal.set(Calendar.MINUTE,0);cal.set(Calendar.SECOND,0);cal.set(Calendar.MILLISECOND,0)
        cal.add(Calendar.DAY_OF_MONTH,-((cal.get(Calendar.DAY_OF_WEEK)+5)%7))
        val parser=SimpleDateFormat("yyyyMMdd",Locale.US).apply{timeZone=cal.timeZone}
        val from=parser.format(cal.time);val to=parser.format(Date())
        val points=data.history.filter{it.date>=from&&it.date<=to}.distinctBy{it.date}
        return if(points.isEmpty()) null else points.map{it.price}.average()
    }
    fun render(context:Context,width:Int,height:Int,data:PriceData,today:String):Bitmap =
        render(context,width,height,data,GradeData("",emptyMap(),emptyMap()),Kind.SMALL,today)
    fun render(context:Context,width:Int,height:Int,data:PriceData,grades:GradeData,kind:Kind,today:String):Bitmap {
        val b=Bitmap.createBitmap(width.coerceAtLeast(1),height.coerceAtLeast(1),Bitmap.Config.ARGB_8888)
        val c=Canvas(b);val scale=min(width/kind.w,height/kind.h)
        c.translate((width-kind.w*scale)/2,(height-kind.h*scale)/2);c.scale(scale,scale)
        val radius=if(kind==Kind.TODAY)34f else 55f
        c.clipPath(Path().apply{addRoundRect(RectF(0f,0f,kind.w,kind.h),radius,radius,Path.Direction.CW)})
        val source=context.assets.open("widget/four_price_reference.png").use{BitmapFactory.decodeStream(it)}
        c.drawBitmap(source,kind.crop,RectF(0f,0f,kind.w,kind.h),Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        val font=Typeface.createFromAsset(context.assets,"widget/NotoSansKR.ttf")
        val heavy=Typeface.create("sans-serif",Typeface.BOLD)
        fun sample(x:Int,y:Int):Int {
            val candidates=mutableListOf<Int>()
            for(dx in -3..3)for(dy in -2..2){
                val col=source.getPixel((kind.crop.left+x+dx).coerceIn(0,source.width-1),(kind.crop.top+y+dy).coerceIn(0,source.height-1))
                if(maxOf(Color.red(col),Color.green(col),Color.blue(col))<90)candidates.add(col)
            }
            return candidates.sortedBy{Color.red(it)+Color.green(it)+Color.blue(it)}.let{if(it.isEmpty())0xFF151C22.toInt() else it[it.size/2]}
        }
        fun clear(l:Float,t:Float,r:Float,bt:Float){
            // Reconstruct the smooth dark field from its untouched row edges.
            // This keeps the source's per-card and per-grade lighting instead
            // of painting a visibly different flat rectangle behind new text.
            val w=(r-l).roundToInt().coerceAtLeast(1);val h=(bt-t).roundToInt().coerceAtLeast(1)
            val pixels=IntArray(w*h)
            for(y in 0 until h){
                val a=sample(l.toInt()-2,t.toInt()+y);val deltaField=(kind==Kind.SMALL && t==259f)||(kind==Kind.MEDIUM && t==216f)||(kind==Kind.LARGE && (t==258f||t==339f))||(kind==Kind.TODAY && t==148f)
                val z=if(deltaField)a else sample(r.toInt()+2,t.toInt()+y)
                for(x in 0 until w){val f=x.toFloat()/max(1,w-1);pixels[y*w+x]=Color.rgb(
                    (Color.red(a)*(1-f)+Color.red(z)*f).roundToInt(),
                    (Color.green(a)*(1-f)+Color.green(z)*f).roundToInt(),
                    (Color.blue(a)*(1-f)+Color.blue(z)*f).roundToInt())}
            }
            val patch=Bitmap.createBitmap(pixels,w,h,Bitmap.Config.ARGB_8888)
            c.drawBitmap(patch,null,RectF(l,t,r,bt),Paint(Paint.FILTER_BITMAP_FLAG));patch.recycle()
        }
        fun text(s:String,x:Float,y:Float,size:Float,color:Int=white,maxWidth:Float=kind.w-x-20,bold:Boolean=false){
            val p=Paint(Paint.ANTI_ALIAS_FLAG).apply{this.color=color;typeface=if(bold)heavy else font;textSize=size}
            if(p.measureText(s)>maxWidth)p.textSize*=maxWidth/p.measureText(s)
            c.drawText(s,x,y,p)
        }
        fun price(x:Float,y:Float,size:Float,available:Float){
            val value=money(data.price);val p=Paint(Paint.ANTI_ALIAS_FLAG).apply{typeface=heavy;textSize=size;color=white}
            val unitWidth=size*.9f
            if(p.measureText(value)>available-unitWidth)p.textSize*=(available-unitWidth)/p.measureText(value)
            c.drawText(value,x,y,p);text("원/kg",x+p.measureText(value)+8,y-4,size*.34f,muted,unitWidth)
        }
        val change=data.change
        val color=when{change==null||change==0.0->muted;change>0->red;else->green}
        fun delta(x:Float,y:Float,size:Float,width:Float){
            val arrow=when{change==null->"";change>0->"▲ ";change<0->"▼ ";else->"— "}
            val pct=data.percent?.let{" (${if(it>0)"+" else ""}${String.format(Locale.US,"%.1f",it)}%)"}?:""
            text(if(change==null)"전일 비교 미확인" else arrow+money(abs(change))+pct,x,y,size,color,width,true)
        }
        val basis=if(data.date.length==8)"${data.date.substring(4,6).toInt()}.${data.date.substring(6,8).toInt()} 기준" else "기준일 미확인"
        when(kind){
            Kind.SMALL->{
                clear(242f,42f,355f,88f);text(today,245f,72f,23f,muted,100f)
                clear(31f,155f,354f,253f);price(37f,236f,92f,311f)
                clear(35f,259f,265f,306f);delta(44f,295f,34f,221f)
                // The source has a missing parenthesis; all comparison text is live.
            }
            Kind.MEDIUM->{
                clear(603f,37f,720f,86f);text(today,612f,70f,24f,muted,110f)
                clear(35f,111f,370f,215f)
                clear(37f,216f,310f,275f)
                clear(307f,102f,909f,341f);chart(c,data,RectF(310f,116f,830f,291f),font,true)
                price(40f,192f,94f,315f);delta(46f,253f,34f,265f)
            }
            Kind.LARGE->{
                clear(650f,32f,986f,89f);text(basis+" | 전국",666f,69f,25f,muted,310f)
                clear(34f,163f,410f,257f);price(39f,239f,91f,405f)
                clear(38f,258f,344f,307f);delta(44f,294f,33f,300f)
                clear(90f,339f,318f,381f)
                val insight=if(change==null)"전일 비교 미확인" else "전일 대비 ${money(abs(change))}원 ${if(change>0)"상승" else if(change<0)"하락" else "보합"}"
                text(insight,95f,371f,23f,white,235f)
                val keys=listOf("1+","1","2","등외")
                keys.forEachIndexed{i,g->
                    val y=114f+i*71f
                    clear(640f,y+5,978f,y+58)
                    val gp=grades.current[g];val prev=grades.previous[g];val d=if(gp!=null&&prev!=null)gp-prev else null
                    text(if(g=="등외")g else g+"등급",655f,y+43,25f,white,109f)
                    text(money(gp),794f,y+43,25f,white,103f)
                    text(if(d==null)"—" else (if(d>0)"▲ " else if(d<0)"▼ " else "— ")+money(abs(d)),913f,y+43,22f,if(d!=null&&d>0)red else green,80f)
                }
                // Never attach today's price date to older grade records.
                if(grades.date!=data.date)text(if(grades.date.isEmpty())"등급 자료 미확인" else "등급 ${grades.date.takeLast(4).chunked(2).joinToString("/")} 기준",655f,414f,14f,muted,300f)
            }
            Kind.TODAY->{
                clear(167f,24f,268f,72f);text(today,175f,56f,20f,muted,85f)
                clear(22f,82f,268f,143f);price(28f,134f,56f,243f)
                clear(24f,148f,266f,190f);delta(29f,176f,25f,232f)
                clear(23f,201f,280f,298f);chart(c,data,RectF(26f,214f,249f,292f),font,false)
                clear(22f,311f,273f,393f)
                text("전 거래일",29f,340f,19f,muted,112f);text("이번 주 평균",167f,340f,19f,muted,105f)
                text(money(data.previous),29f,377f,27f,white,111f,true);text(money(weekAverage(data)),167f,377f,27f,white,105f,true)
            }
        }
        source.recycle()
        return b
    }
    internal fun dailyPlot(data:PriceData):List<PricePoint>{
        val byDate=data.history.filter{it.price.isFinite()&&it.price>0&&it.date<=data.date}.associateBy{it.date}.toMutableMap()
        if(data.date.length==8 && data.price!=null)byDate[data.date]=PricePoint(data.date,data.price)
        return byDate.values.sortedBy{it.date}.takeLast(30)
    }
    private fun chart(c:Canvas,data:PriceData,r:RectF,font:Typeface,axes:Boolean){
        val rows=dailyPlot(data)
        val p=Paint(Paint.ANTI_ALIAS_FLAG)
        if(rows.size<2){p.color=muted;p.typeface=font;p.textSize=if(axes)22f else 15f;c.drawText("일별 이력 확인 중",r.left,r.centerY(),p);return}
        val low=rows.minOf{it.price};val high=rows.maxOf{it.price};val range=max(high-low,1.0)
        val path=Path();var ex=0f;var ey=0f
        rows.forEachIndexed{i,row->ex=r.left+i*r.width()/(rows.size-1);ey=r.bottom-10-(row.price-low).toFloat()/range.toFloat()*(r.height()-24);if(i==0)path.moveTo(ex,ey)else path.lineTo(ex,ey)}
        val area=Path(path);area.lineTo(ex,r.bottom);area.lineTo(r.left,r.bottom);area.close()
        p.shader=LinearGradient(0f,r.top,0f,r.bottom,0x5548D4A0,0x0548D4A0,Shader.TileMode.CLAMP);c.drawPath(area,p);p.shader=null
        p.color=0xFF39444B.toInt();p.strokeWidth=1f;p.pathEffect=DashPathEffect(floatArrayOf(3f,5f),0f)
        for(i in 0..2){val y=r.top+i*r.height()/2;c.drawLine(r.left,y,r.right,y,p)};p.pathEffect=null
        p.color=green;p.style=Paint.Style.STROKE;p.strokeWidth=if(axes)3f else 2f;p.strokeJoin=Paint.Join.ROUND;c.drawPath(path,p);p.style=Paint.Style.FILL
        for((size,alpha) in listOf(19f to 20,13f to 50,8f to 150)){p.color=green;p.alpha=alpha;c.drawCircle(ex,ey,size,p)};p.alpha=255;p.color=white;c.drawCircle(ex,ey,4f,p)
        if(axes){
            p.color=muted;p.typeface=font;p.textSize=19f
            c.drawText(money(high),r.right+18,r.top+8,p);c.drawText(money(low),r.right+18,r.bottom,p)
            for(i in 0..5){val index=i*(rows.size-1)/5;val d=rows[index].date;val label=d.substring(4,6).toInt().toString()+"."+d.substring(6,8).toInt();c.drawText(label,r.left+i*r.width()/5-9,r.bottom+31,p)}
            val bubbleTop=(if(ey-r.top<65f)ey+14f else ey-81f).coerceIn(r.top,r.bottom-42f)
            p.color=0xFF20272D.toInt();c.drawRoundRect(RectF(ex-45,bubbleTop,ex+45,bubbleTop+42),14f,14f,p);p.color=white;p.textSize=23f;c.drawText(money(rows.last().price),ex-35,bubbleTop+29,p)
        }
    }
}
