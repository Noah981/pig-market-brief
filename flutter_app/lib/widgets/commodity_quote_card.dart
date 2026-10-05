import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class CommodityQuoteCard extends StatelessWidget {
  const CommodityQuoteCard({super.key,required this.item,this.onTap,this.detail=false,this.compact=false});
  final Commodity item;
  final VoidCallback? onTap;
  final bool detail,compact;
  Color get accent=>switch(item.id){'corn'||'wheat'=>const Color(0xFFB78312),'wti'=>const Color(0xFF3576A5),'usd_krw'=>const Color(0xFF6B62AE),_=>const Color(0xFF568D63)};
  Color get movement=>item.change==null||item.change==0?AppColors.secondary:item.change!>0?AppColors.coral:AppColors.blue;
  String get source=>item.source.contains('World Bank')?'세계은행 Pink Sheet':item.source.contains('IMF')?'IMF · FRED':item.source.contains('ECOS')?'한국은행 ECOS':item.source.contains('EIA')?(item.source.contains('FRED')?'EIA · FRED':'미국 EIA'):item.source.contains('연방준비')?'Federal Reserve · FRED':item.source;
  @override Widget build(BuildContext context)=>Material(color:Colors.white,borderRadius:BorderRadius.circular(20),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(20),child:Container(padding:EdgeInsets.all(detail?20:14),decoration:BoxDecoration(border:Border.all(color:accent.withValues(alpha:.15)),borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
    Row(children:[Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:accent.withValues(alpha:.09),borderRadius:BorderRadius.circular(11)),child:Icon(item.icon,size:20,color:accent)),const SizedBox(width:8),Expanded(child:Text(item.shortName,maxLines:2,style:TextStyle(fontSize:detail?18:13,fontWeight:FontWeight.w800,letterSpacing:-.3))),if(onTap!=null)const Icon(Icons.chevron_right,size:17,color:AppColors.secondary)]),
    const SizedBox(height:12),
    FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(item.hasQuote?item.value:'자료 확인 필요',style:TextStyle(fontSize:detail?36:25,fontWeight:FontWeight.w900,letterSpacing:-1,color:item.hasQuote?AppColors.text:AppColors.secondary))),
    Text(item.hasQuote?item.unit:'검증된 가격만 표시합니다',style:TextStyle(fontSize:detail?13:10,color:AppColors.secondary)),
    const SizedBox(height:9),
    Wrap(spacing:5,runSpacing:4,children:[Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:movement.withValues(alpha:.08),borderRadius:BorderRadius.circular(7)),child:Text(item.comparisonLabel,style:TextStyle(fontSize:detail?13:11,fontWeight:FontWeight.w800,color:movement))),if(item.hasQuote)Text(item.frequency=='monthly'?'전월 대비':'직전 공표 대비',style:const TextStyle(fontSize:9,height:2.1,color:AppColors.secondary))]),
    if(detail&&item.history.length>=2)...[const SizedBox(height:15),SizedBox(height:45,width:double.infinity,child:CustomPaint(painter:_QuoteSparkline(item.history,accent)))],
    if(!detail&&!compact)const Spacer(),
    const SizedBox(height:10),
    Text(item.basisLabel,style:TextStyle(fontSize:detail?13:10,fontWeight:FontWeight.w700,color:accent)),
    const SizedBox(height:4),
    Row(children:[Expanded(child:Text(source.isEmpty?'출처 조회 대기':source,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,color:AppColors.secondary))),if(item.status=='STALE')const Text('저장값',style:TextStyle(fontSize:9,color:AppColors.secondary))]),
    if(detail)...[const SizedBox(height:12),Text(item.basis,style:const TextStyle(fontSize:12,height:1.5,color:AppColors.secondary)),if(item.id=='wti')const Text('국제 원유 현물가격이며 국내 주유소 판매가격과 다릅니다.',style:TextStyle(fontSize:11,height:1.5,color:AppColors.secondary)),if(item.frequency=='monthly')const Text('월평균 국제 벤치마크입니다. 농장의 실제 사료 구매단가와 다릅니다.',style:TextStyle(fontSize:11,height:1.5,color:AppColors.secondary))],
  ]))));
}
class _QuoteSparkline extends CustomPainter{
  _QuoteSparkline(this.points,this.color);final List<CommodityPoint> points;final Color color;
  @override void paint(Canvas canvas,Size size){final values=points.takeLast(12).map((x)=>x.value).toList();if(values.length<2)return;final low=values.reduce((a,b)=>a<b?a:b),high=values.reduce((a,b)=>a>b?a:b),range=high-low;final path=Path();for(var i=0;i<values.length;i++){final x=i*size.width/(values.length-1),y=range==0?size.height/2:size.height-4-(values[i]-low)/(range)*(size.height-8);if(i==0){path.moveTo(x,y);}else{path.lineTo(x,y);}}canvas.drawPath(path,Paint()..color=color..strokeWidth=2..style=PaintingStyle.stroke..strokeCap=StrokeCap.round);}
  @override bool shouldRepaint(covariant _QuoteSparkline old)=>old.points!=points||old.color!=color;
}
extension _LastPoints<T> on List<T>{Iterable<T> takeLast(int count)=>skip(length>count?length-count:0);}
