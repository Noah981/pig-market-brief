import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/disease_models.dart';
import '../theme/app_theme.dart';

class KoreaDiseaseMap extends StatefulWidget {
  const KoreaDiseaseMap({super.key,required this.items,required this.onTap,this.userLatitude,this.userLongitude});
  final List<DiseaseAlert> items;
  final ValueChanged<DiseaseAlert> onTap;
  final double? userLatitude,userLongitude;

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

  @override Widget build(BuildContext context)=>AspectRatio(
    aspectRatio:1235/1536,
    child:ClipRRect(
      borderRadius:BorderRadius.circular(12),
      child:FutureBuilder<List<_Shape>>(
        future:_shapes,
        builder:(context,snapshot){
          if(snapshot.hasError)return const Center(child:Text('행정경계 지도를 불러오지 못했습니다.'));
          if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
          return LayoutBuilder(builder:(context,box){
            final projection=_Projection(box.biggest);
            return GestureDetector(
              behavior:HitTestBehavior.opaque,
              onTapUp:(detail)=>_tap(detail.localPosition,projection),
              child:CustomPaint(
                size:box.biggest,
                painter:_MapPainter(shapes:snapshot.data!,items:widget.items,userLatitude:widget.userLatitude,userLongitude:widget.userLongitude,projection:projection),
              ),
            );
          });
        },
      ),
    ),
  );

  void _tap(Offset point,_Projection projection){
    DiseaseAlert? target;var shortest=double.infinity;
    for(final item in widget.items.where((x)=>x.hasMapPoint&&x.isOfficial)){
      final marker=projection.point(item.longitude!,item.latitude!);
      final distance=(marker-point).distance;
      if(distance<24&&distance<shortest){target=item;shortest=distance;}
    }
    if(target!=null)widget.onTap(target);
  }
}

class _Shape{
  const _Shape(this.rings);
  final List<List<Offset>> rings;
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
    return _Shape(rings);
  }
}

class _Projection{
  const _Projection(this.size);
  final Size size;
  static const minLon=124.45,maxLon=132.05,minLat=32.9,maxLat=38.75,padding=8.0;
  Offset point(double lon,double lat){
    final width=math.max(1.0,size.width-padding*2),height=math.max(1.0,size.height-padding*2);
    return Offset(padding+(lon-minLon)/(maxLon-minLon)*width,padding+(maxLat-lat)/(maxLat-minLat)*height);
  }
}

class _MapPainter extends CustomPainter{
  const _MapPainter({required this.shapes,required this.items,required this.userLatitude,required this.userLongitude,required this.projection});
  final List<_Shape> shapes;final List<DiseaseAlert> items;final double? userLatitude,userLongitude;final _Projection projection;
  @override void paint(Canvas canvas,Size size){
    canvas.drawColor(Colors.white,BlendMode.srcOver);
    final fill=Paint()..color=const Color(0xFFE5E7EB);
    final border=Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.1;
    for(final shape in shapes){for(final ring in shape.rings){final first=projection.point(ring.first.dx,ring.first.dy);final path=Path()..moveTo(first.dx,first.dy);for(final coordinate in ring.skip(1)){final p=projection.point(coordinate.dx,coordinate.dy);path.lineTo(p.dx,p.dy);}path.close();canvas.drawPath(path,fill);canvas.drawPath(path,border);}}
    for(final item in items.where((x)=>x.hasMapPoint&&x.isOfficial)){
      final p=projection.point(item.longitude!,item.latitude!);
      canvas.drawCircle(p,8,Paint()..color=AppColors.coral.withValues(alpha:.2));
      canvas.drawCircle(p,4.5,Paint()..color=AppColors.coral);
      canvas.drawCircle(p,4.5,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.5);
    }
    if(userLatitude!=null&&userLongitude!=null){final p=projection.point(userLongitude!,userLatitude!);canvas.drawCircle(p,8,Paint()..color=AppColors.blue.withValues(alpha:.2));canvas.drawCircle(p,4.5,Paint()..color=AppColors.blue);canvas.drawCircle(p,4.5,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.5);}
    const label=TextSpan(text:'● 공식 확인   ● 내 위치',style:TextStyle(fontSize:7.5,color:AppColors.secondary));final painter=TextPainter(text:label,textDirection:TextDirection.ltr)..layout();painter.paint(canvas,Offset(size.width-painter.width-8,size.height-painter.height-5));
  }
  @override bool shouldRepaint(covariant _MapPainter old)=>old.items!=items||old.userLatitude!=userLatitude||old.userLongitude!=userLongitude||old.shapes!=shapes;
}
