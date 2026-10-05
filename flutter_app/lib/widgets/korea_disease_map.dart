import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/disease_models.dart';
import '../theme/app_theme.dart';

class KoreaDiseaseMap extends StatefulWidget {
  const KoreaDiseaseMap({super.key,required this.items,required this.onTap,this.userLatitude,this.userLongitude,this.showRadii=false,this.focusedEventId,this.controller,this.dashboard=false});
  final List<DiseaseAlert> items;
  final ValueChanged<DiseaseAlert> onTap;
  final double? userLatitude,userLongitude;
  final bool showRadii;final String? focusedEventId;final TransformationController? controller;final bool dashboard;

  @override State<KoreaDiseaseMap> createState()=>_KoreaDiseaseMapState();
}

class _KoreaDiseaseMapState extends State<KoreaDiseaseMap>{
  late final Future<List<_Shape>> _shapes=_load();

  Future<List<_Shape>> _load()async{
    final bytes=await rootBundle.load('assets/data/korea_provinces.geojson.gz');
    final raw=utf8.decode(gzip.decode(bytes.buffer.asUint8List()));
    final root=jsonDecode(raw) as Map<String,dynamic>;
    return (root['features'] as List? ?? const []).whereType<Map<String,dynamic>>().map(_Shape.fromGeoJson).toList();
  }

  final _ownController=TransformationController();
  TransformationController get _controller=>widget.controller??_ownController;
  @override void dispose(){_ownController.dispose();super.dispose();}
  void _zoom(double factor,Size size){
    final current=_controller.value.getMaxScaleOnAxis();
    final next=(current*factor).clamp(1.0,4.0);
    final center=Offset(size.width/2,size.height/2);
    final scene=_controller.toScene(center);
    _controller.value=Matrix4.identity()..translate(center.dx-scene.dx*next,center.dy-scene.dy*next)..scale(next);
  }
  void _center(Size size){
    if(widget.userLatitude==null||widget.userLongitude==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('GPS 위치를 먼저 확인해주세요.')));return;}
    final p=_Projection(size).point(widget.userLongitude!,widget.userLatitude!);
    const scale=2.0;
    _controller.value=Matrix4.identity()..translate(size.width/2-p.dx*scale,size.height/2-p.dy*scale)..scale(scale);
  }
  @override Widget build(BuildContext context)=>AspectRatio(
    aspectRatio:widget.dashboard?1.55:1.30,
    child:ClipRRect(borderRadius:BorderRadius.circular(12),child:FutureBuilder<List<_Shape>>(
      future:_shapes,builder:(context,snapshot){
        if(snapshot.hasError)return const Center(child:Text('행정경계 지도를 불러오지 못했습니다.'));
        if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
        return LayoutBuilder(builder:(context,box){final projection=_Projection(box.biggest);
          return Stack(children:[
            InteractiveViewer(key:const ValueKey('disease_map_view'),transformationController:_controller,minScale:1,maxScale:4,boundaryMargin:const EdgeInsets.all(160),child:GestureDetector(behavior:HitTestBehavior.opaque,onTapUp:(detail)=>_tap(detail.localPosition,projection),child:CustomPaint(size:box.biggest,painter:_MapPainter(shapes:snapshot.data!,items:widget.items,userLatitude:widget.userLatitude,userLongitude:widget.userLongitude,projection:projection,showRadii:widget.showRadii,focusedEventId:widget.focusedEventId,dashboard:widget.dashboard)))),
            if(widget.dashboard)...[
              const Positioned(left:0,top:8,child:_MapLegend()),
              Positioned(right:0,bottom:4,child:Column(children:[Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFEDEDF0)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.04),blurRadius:6)]),child:Column(children:[_control('disease_map_zoom_in','지도 확대',Icons.add,()=>_zoom(1.5,box.biggest)),Container(width:28,height:1,color:const Color(0xFFEDEDF0)),_control('disease_map_zoom_out','지도 축소',Icons.remove,()=>_zoom(1/1.5,box.biggest))])),const SizedBox(height:8),Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFEDEDF0))),child:_control('disease_map_center','내 위치로 이동',Icons.gps_fixed,()=>_center(box.biggest)))])),
            ],
          ]);
        });
      })),
  );
  Widget _control(String key,String tooltip,IconData icon,VoidCallback action)=>IconButton(key:ValueKey(key),tooltip:tooltip,onPressed:action,icon:Icon(icon,size:20,color:const Color(0xFF636B77)),style:IconButton.styleFrom(tapTargetSize:MaterialTapTargetSize.shrinkWrap),padding:const EdgeInsets.all(6),constraints:const BoxConstraints.tightFor(height:29,width:30));

  void _tap(Offset point,_Projection projection){
    DiseaseAlert? target;var shortest=double.infinity;
    for(final item in widget.items.where((x)=>x.hasMapPoint)){
      final marker=projection.point(item.longitude!,item.latitude!);
      final distance=(marker-point).distance;
      if(distance<24&&distance<shortest){target=item;shortest=distance;}
    }
    if(target!=null)widget.onTap(target);
  }
}

class _Shape{
  const _Shape(this.rings,this.name);
  final List<List<Offset>> rings;final String name;
  factory _Shape.fromGeoJson(Map<String,dynamic> feature){
    final geometry=feature['geometry'] as Map<String,dynamic>? ?? const {};
    final coordinates=geometry['coordinates'] as List? ?? const [];
    final rings=<List<Offset>>[];
    void polygon(List polygon){
      for(final raw in polygon.whereType<List>()){
        final ring=raw.whereType<List>().where((p)=>p.length>=2).map((p)=>Offset((p[0] as num).toDouble(),(p[1] as num).toDouble())).toList();
        if(ring.length>=3)rings.add(ring);
      }
    }
    if(geometry['type']=='Polygon')polygon(coordinates);
    if(geometry['type']=='MultiPolygon'){
      for(final item in coordinates.whereType<List>()){polygon(item);}
    }
    return _Shape(rings,(feature['properties'] as Map?)?['name']?.toString()??'');
  }
}

class _Projection{
  const _Projection(this.size);
  final Size size;
  static const minLon=124.45,maxLon=132.05,minLat=32.9,maxLat=38.75,padding=8.0;
  Offset point(double lon,double lat){
    // A single geographical scale preserves the reference map proportions.
    // Equirectangular geographic projection matches the reference viewport.
    // Every boundary and marker still comes from longitude/latitude.
    const cosine=1.0;
    final width=math.max(1.0,size.width-padding*2),height=math.max(1.0,size.height-padding*2);
    final scale=math.min(width/((maxLon-minLon)*cosine),height/(maxLat-minLat));
    return Offset((size.width-(maxLon-minLon)*cosine*scale)/2+(lon-minLon)*cosine*scale,(size.height-(maxLat-minLat)*scale)/2+(maxLat-lat)*scale);
  }
}

class _MapPainter extends CustomPainter{
  const _MapPainter({required this.shapes,required this.items,required this.userLatitude,required this.userLongitude,required this.projection,required this.showRadii,this.focusedEventId,this.dashboard=false});
  final List<_Shape> shapes;final List<DiseaseAlert> items;final double? userLatitude,userLongitude;final _Projection projection;final bool showRadii;final String? focusedEventId;final bool dashboard;
  @override void paint(Canvas canvas,Size size){
    canvas.drawColor(Colors.white,BlendMode.srcOver);
    final fill=Paint()..color=const Color(0xFFE5E7EB);
    final border=Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.1;
    for(final shape in shapes){fill.color=dashboard?_provinceColor(shape.name):const Color(0xFFE5E7EB);for(final ring in shape.rings){final first=projection.point(ring.first.dx,ring.first.dy);final path=Path()..moveTo(first.dx,first.dy);for(final coordinate in ring.skip(1)){final p=projection.point(coordinate.dx,coordinate.dy);path.lineTo(p.dx,p.dy);}path.close();canvas.drawPath(path,fill);canvas.drawPath(path,border);}}
    if(showRadii&&userLatitude!=null&&userLongitude!=null){final c=projection.point(userLongitude!,userLatitude!);for(final ring in const [(50.0,Color(0xFFFFD54F)),(30.0,Color(0xFFFF9800)),(10.0,Color(0xFFE53935))]){final edge=projection.point(userLongitude!,userLatitude!+ring.$1/111.0),radius=(edge-c).distance;canvas.drawCircle(c,radius,Paint()..color=ring.$2.withValues(alpha:.10));canvas.drawCircle(c,radius,Paint()..color=ring.$2.withValues(alpha:.65)..style=PaintingStyle.stroke..strokeWidth=.8);}}
    for(final item in items.where((x)=>x.hasMapPoint)){
      final p=projection.point(item.longitude!,item.latitude!);
      final color=dashboard?_ageColor(item):_diseaseColor(item.type),selected=item.stableKey==focusedEventId,radius=selected?8.0:dashboard?4.0:9.0;
      canvas.drawCircle(p,radius+4,Paint()..color=color.withValues(alpha:item.isOfficial ? 0.24 : 0.13));
      canvas.drawCircle(p,radius,Paint()..color=item.isOfficial?color:Colors.white);
      canvas.drawCircle(p,radius,Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=item.isOfficial?1.5:2.2);
      if(!dashboard){final glyph=TextPainter(text:TextSpan(text:_diseaseGlyph(item.type),style:TextStyle(color:item.isOfficial?Colors.white:color,fontSize:selected?10:8.5,fontWeight:FontWeight.w900,height:1)),textDirection:TextDirection.ltr)..layout();
      glyph.paint(canvas,p-Offset(glyph.width/2,glyph.height/2));}
    }
    if(userLatitude!=null&&userLongitude!=null){final p=projection.point(userLongitude!,userLatitude!);canvas.drawCircle(p,8,Paint()..color=AppColors.blue.withValues(alpha:.2));canvas.drawCircle(p,4.5,Paint()..color=AppColors.blue);canvas.drawCircle(p,4.5,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.5);}
    if(dashboard){
      for(final label in const [('강원',128.3,37.8),('경기',127.1,37.4),('충북',127.7,36.65),('충남',126.8,36.5),('경북',128.8,36.4),('전북',127.1,35.75),('전남',126.8,34.65),('경남',128.2,35.25),('제주',126.55,33.4),('울릉',130.9,37.5),('독도',131.87,37.25)]){
        final p=projection.point(label.$2,label.$3);final text=TextPainter(text:TextSpan(text:label.$1,style:TextStyle(fontFamily:'NotoSansKR',fontSize:label.$1=='울릉'||label.$1=='독도'?6:8,color:const Color(0xFF606873),fontWeight:FontWeight.w600)),textDirection:TextDirection.ltr)..layout();text.paint(canvas,p-Offset(text.width/2,text.height/2));
      }
      return;
    }
    const label=TextSpan(text:'A ASF  F 구제역  P PED  R PRRS  ● 내 위치',style:TextStyle(fontSize:7.0,color:AppColors.secondary,fontWeight:FontWeight.w700));final painter=TextPainter(text:label,textDirection:TextDirection.ltr)..layout();painter.paint(canvas,Offset(size.width-painter.width-8,size.height-painter.height-5));
  }
  Color _ageColor(DiseaseAlert event){final age=DateTime.now().difference(event.eventDate??DateTime.fromMillisecondsSinceEpoch(0)).inDays;return age<=30?const Color(0xFFE94B51):age<=90?const Color(0xFFF49B43):age<=180?const Color(0xFFF6CF4E):const Color(0xFFAEB4BE);}
  Color _provinceColor(String name){
    String short(String text)=>text.replaceAll(RegExp(r'특별자치|특별|광역'),'').replaceAll('전라','전').replaceAll('경상','경').replaceAll('충청','충');
    final matches=items.where((x)=>x.province.isNotEmpty&&short(x.province)==short(name)&&x.isConfirmed).toList()..sort((a,b)=>b.occurrenceDate.compareTo(a.occurrenceDate));
    return matches.isEmpty?const Color(0xFFE5E7EB):Color.alphaBlend(_ageColor(matches.first).withValues(alpha:.20),Colors.white);
  }
  Color _diseaseColor(DiseaseType type)=>switch(type){DiseaseType.asf=>const Color(0xFFE91E63),DiseaseType.fmd=>const Color(0xFFF57C00),DiseaseType.ped=>const Color(0xFFF9A825),DiseaseType.prrs=>const Color(0xFF9C4DCC)};
  String _diseaseGlyph(DiseaseType type)=>switch(type){DiseaseType.asf=>'A',DiseaseType.fmd=>'F',DiseaseType.ped=>'P',DiseaseType.prrs=>'R'};
  @override bool shouldRepaint(covariant _MapPainter old)=>old.items!=items||old.userLatitude!=userLatitude||old.userLongitude!=userLongitude||old.shapes!=shapes||old.showRadii!=showRadii||old.focusedEventId!=focusedEventId||old.dashboard!=dashboard;
}

class _MapLegend extends StatelessWidget{
  const _MapLegend();
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.95),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFF0F0F3)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.025),blurRadius:8)]),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:const [(Color(0xFFE94B51),'발생 (최근 1개월)'),(Color(0xFFF49B43),'발생 (1~3개월)'),(Color(0xFFF6CF4E),'발생 (3~6개월)'),(Color(0xFFAEB4BE),'이전·조회 자료 없음')].map((x)=>Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(mainAxisSize:MainAxisSize.min,children:[Container(width:8,height:8,decoration:BoxDecoration(color:x.$1,shape:BoxShape.circle)),const SizedBox(width:6),Text(x.$2,style:const TextStyle(fontSize:7.5,color:AppColors.secondary,fontWeight:FontWeight.w600))]))).toList()));
}
