import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../services/korean_location_resolver.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/disease_repository.dart';
import '../models/disease_models.dart';
import '../services/disease_notification_coordinator.dart';
import '../services/disease_risk_engine.dart';
import '../services/notification_service.dart';
import '../settings/farm_location_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/korea_disease_map.dart';
import 'section_pages.dart';

class DiseasePage extends StatefulWidget{const DiseasePage({super.key});@override State<DiseasePage> createState()=>_DiseasePageState();}
class _DiseasePageState extends State<DiseasePage>{
  final _repository=DiseaseRepository();DiseaseFeed? _feed;Timer? _liveTimer;int _tab=0;DiseaseType? _selected;double? _lat,_lng;bool _gpsVerified=false,_showRadii=false,_locating=false;String _location='현재 위치를 확인할 수 없습니다.';String? _message,_focusedId;
  @override void initState(){super.initState();FarmLocationSettings.instance.addListener(_syncLocation);NotificationService.instance.selectedDiseaseEvent.addListener(_notificationSelected);_loadLocation();_load();_liveTimer=Timer.periodic(const Duration(minutes:5),(_)=>_refresh());}
  @override void dispose(){_liveTimer?.cancel();FarmLocationSettings.instance.removeListener(_syncLocation);NotificationService.instance.selectedDiseaseEvent.removeListener(_notificationSelected);super.dispose();}
  Future<void> _loadLocation()async{await FarmLocationSettings.instance.load();_syncLocation();if(!_gpsVerified){try{await _updateGps(silent:true);}catch(_){}}}
  void _syncLocation(){final x=FarmLocationSettings.instance.location;if(!mounted)return;setState((){_gpsVerified=x.gpsVerified;_lat=x.gpsVerified?x.latitude:null;_lng=x.gpsVerified?x.longitude:null;_location=x.gpsVerified?x.label:(x.label.isEmpty?'농장 위치를 설정해주세요.':'기준 위치 · ${x.label}');});}
  void _notificationSelected(){final id=NotificationService.instance.selectedDiseaseEvent.value;if(id==null)return;final match=(_feed?.items??const <DiseaseAlert>[]).where((x)=>x.stableKey==id).firstOrNull;if(match!=null&&mounted)setState((){_tab=0;_selected=match.type;_focusedId=id;});}
  Future<void> _load()async{try{final cached=await _repository.cached();if(mounted)setState(()=>_feed=cached);}catch(_){}await _refresh();}
  Future<void> _refresh()async{final value=await _repository.refresh();await DiseaseNotificationCoordinator.process(value);if(mounted)setState((){_feed=value;_message=value.errorMessage;});_notificationSelected();}
  List<DiseaseAlert> get _active=>(_feed?.active(DateTime.now())??const []).where((x)=>_tab==0?x.countryCode=='KR':x.countryCode!='KR').toList();
  List<DiseaseAlert> get _visible=>_active.where((x)=>_selected==null||x.type==_selected).toList()..sort((a,b){final d=b.occurrenceDate.compareTo(a.occurrenceDate);if(d!=0)return d;return (b.isOfficial?1:0).compareTo(a.isOfficial?1:0);});
  Future<void> _updateGps({bool silent=false})async{
    if(_locating)return;
    if(mounted)setState((){_locating=true;_message='정확한 GPS 위치를 확인하고 있습니다.';});
    try{
      if(!await Geolocator.isLocationServiceEnabled()){
        if(mounted)setState(()=>_message='휴대폰 위치 서비스를 켜야 GPS를 사용할 수 있습니다.');
        if(!silent)await Geolocator.openLocationSettings();
        return;
      }
      var permission=await Geolocator.checkPermission();
      if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();
      if(permission==LocationPermission.deniedForever){
        if(mounted)setState(()=>_message='위치 권한이 차단되어 있습니다. 앱 설정에서 위치를 허용해주세요.');
        if(!silent)await Geolocator.openAppSettings();
        return;
      }
      if(permission!=LocationPermission.whileInUse&&permission!=LocationPermission.always){
        if(mounted)setState(()=>_message='위치 권한이 필요합니다. GPS 버튼을 다시 눌러 허용해주세요.');
        return;
      }

      final position=await _reliablePosition();
      if(position==null)throw StateError('reliable-position-unavailable');
      await setLocaleIdentifier('ko_KR');
      final places=await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds:10));
      ResolvedKoreanLocation? address;
      for(final place in places){
        final country=(place.isoCountryCode??'').toUpperCase();
        if(country.isNotEmpty&&country!='KR')continue;
        address=KoreanLocationResolver.resolve(
        administrativeArea:place.administrativeArea,
        subAdministrativeArea:place.subAdministrativeArea,
        locality:place.locality,
        subLocality:place.subLocality,
      );
        if(address!=null)break;
      }
      if(address==null)throw StateError('korean-administrative-area-unresolved');

      await FarmLocationSettings.instance.setGps(
        position.latitude,
        position.longitude,
        province:address.province,
        cityCounty:address.cityCounty,
        town:address.town,
        accuracy:position.accuracy,
      );
      if(mounted){
        setState(()=>_message=position.accuracy<=100
            ?'GPS 위치를 확인했습니다.'
            :'GPS 위치를 확인했습니다. 오차 약 ${position.accuracy.round()}m');
      }
    } on TimeoutException {
      if(mounted)setState(()=>_message='GPS 응답이 늦습니다. 실외에서 위치를 켠 뒤 다시 시도해주세요.');
    } catch (_) {
      if(mounted)setState(()=>_message='GPS 주소를 확인하지 못했습니다. 위치 권한과 휴대폰 위치 서비스를 확인한 뒤 다시 시도해주세요.');
    } finally {
      if(mounted)setState(()=>_locating=false);
    }
  }

  Future<Position?> _reliablePosition()async{
    Position? best;
    for(var attempt=0;attempt<2;attempt++){
      try{
        final candidate=await Geolocator.getCurrentPosition(
          locationSettings:AndroidSettings(
            accuracy:LocationAccuracy.best,
            distanceFilter:0,
            timeLimit:const Duration(seconds:12),
            forceLocationManager:attempt>0,
          ),
        );
        if(_validPosition(candidate)&&(best==null||candidate.accuracy<best.accuracy))best=candidate;
        if(best!=null&&best.accuracy<=100)break;
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }
    if(best!=null&&best.accuracy<=500){return best;}

    try{
      final last=await Geolocator.getLastKnownPosition();
      if(last!=null&&_validPosition(last)&&last.accuracy<=250)return last;
    } catch (_) {}
    return best!=null&&_validPosition(best)?best:null;
  }

  bool _validPosition(Position position){
    final age=DateTime.now().difference(position.timestamp).inSeconds;
    return position.latitude.isFinite&&position.longitude.isFinite&&
        position.latitude>=-90&&position.latitude<=90&&
        position.longitude>=-180&&position.longitude<=180&&
        position.accuracy.isFinite&&position.accuracy>=0&&position.accuracy<=1000&&
        age>=-30&&age<=180&&!position.isMocked;
  }
  @override Widget build(BuildContext context){final risk=DiseaseRiskEngine.summarize(_visible,latitude:_lat,longitude:_lng,type:_selected);return PageShell(title:'질병',subtitle:'내 농장 주변 질병 발생 현황을 확인하세요',help:_openHelp,child:Column(children:[
    _tabs(),const SizedBox(height:8),_summary(),const SizedBox(height:8),
    if(_message!=null)Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:AppColors.lightCoral,borderRadius:BorderRadius.circular(11)),child:Row(children:[const Icon(Icons.info_outline_rounded,size:15,color:AppColors.coral),const SizedBox(width:5),Expanded(child:Text(_message!,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,color:AppColors.coral)))])),
    if(_tab==0)...[_locationBar(),const SizedBox(height:7),Container(padding:const EdgeInsets.fromLTRB(8,6,8,8),decoration:appCard(radius:16),child:Column(children:[SizedBox(height:36,child:Row(children:[_filterLabel(),const Spacer(),TextButton.icon(style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:6),visualDensity:VisualDensity.compact),onPressed:()=>setState(()=>_showRadii=!_showRadii),icon:Icon(_showRadii?Icons.check_circle:Icons.circle_outlined,size:15),label:const Text('방역반경',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700)))])),KoreaDiseaseMap(items:_visible,onTap:_openDetail,userLatitude:_lat,userLongitude:_lng,showRadii:_showRadii,focusedEventId:_focusedId)])),const SizedBox(height:9),_riskCard(risk)]
    else Container(padding:const EdgeInsets.all(14),decoration:appCard(radius:16),child:const Text('해외 정보는 국내 지도·거리·방역 LEVEL과 완전히 분리됩니다.',style:TextStyle(fontSize:10.5))),
    const SizedBox(height:12),Row(children:[const Expanded(child:Text('최근 발생 정보',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900))),Text(_updated(),style:const TextStyle(fontSize:8,color:AppColors.secondary))]),
    if(_feed?.state==DiseaseDataState.error)const Padding(padding:EdgeInsets.all(24),child:Text('데이터 확인 실패',textAlign:TextAlign.center))
    else if(_visible.isEmpty)Padding(padding:const EdgeInsets.all(24),child:Text(_feed?.fromCache==true?'최신 발생 정보를 확인하지 못했습니다.\n마지막 저장 자료에는 최근 30일 정보가 없습니다.':'최근 30일 발생 정보 0건',textAlign:TextAlign.center,style:const TextStyle(color:AppColors.secondary)))
    else ..._visible.map(_eventRow),
  ]));}
  Widget _tabs()=>Container(height:40,padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:const Color(0xFFF4F4F6),borderRadius:BorderRadius.circular(16)),child:Row(children:List.generate(2,(i)=>Expanded(child:InkWell(onTap:()=>setState((){_tab=i;_focusedId=null;}),borderRadius:BorderRadius.circular(13),child:Container(alignment:Alignment.center,decoration:BoxDecoration(color:_tab==i?AppColors.coral:Colors.transparent,borderRadius:BorderRadius.circular(13)),child:Text(i==0?'국내':'해외',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:_tab==i?Colors.white:AppColors.secondary))))))));
  Widget _summary()=>Row(children:DiseaseType.values.map((type){final count=_active.where((x)=>x.type==type).length,active=_selected==type;return Expanded(child:InkWell(onTap:()=>setState(()=>_selected=active?null:type),borderRadius:BorderRadius.circular(12),child:Container(margin:const EdgeInsets.symmetric(horizontal:2),padding:const EdgeInsets.symmetric(vertical:7),decoration:BoxDecoration(color:active?AppColors.lightCoral:const Color(0xFFF8F8FA),border:Border.all(color:active?AppColors.coral:Colors.transparent),borderRadius:BorderRadius.circular(12)),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(type.label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),Text('${type.legalGroup} 법정질병',style:const TextStyle(fontSize:6.8,fontWeight:FontWeight.w700,color:AppColors.secondary)),const SizedBox(height:1),Text('$count건',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:count>0?AppColors.coral:AppColors.secondary)),Text(count==0?'공식 발생 없음':'최근 30일',maxLines:1,style:const TextStyle(fontSize:7.5,fontWeight:FontWeight.w700,color:AppColors.secondary))]))));}).toList());
  Widget _locationBar()=>Row(children:[Expanded(child:Container(height:44,padding:const EdgeInsets.symmetric(horizontal:12),alignment:Alignment.centerLeft,decoration:BoxDecoration(border:Border.all(color:AppColors.divider),borderRadius:BorderRadius.circular(12)),child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_gpsVerified?'현재 위치':'기준 위치',style:const TextStyle(fontSize:7,color:AppColors.secondary)),Text(_location,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w700))]))),const SizedBox(width:7),FilledButton.icon(onPressed:_locating?null:_updateGps,icon:const Icon(Icons.my_location,size:16),label:Text(_locating?'확인 중':'GPS'),style:FilledButton.styleFrom(minimumSize:const Size(94,44),backgroundColor:AppColors.blue))]);
  Widget _filterLabel()=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0xFFF4F4F6),borderRadius:BorderRadius.circular(12)),child:Text(_selected==null?'전체 보기 ▼':'${_selected!.label}만 보기 ▼',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)));
  Widget _riskCard(DiseaseRiskSummary r){final data=switch(r.level){DiseaseRiskLevel.level1=>('LEVEL 1','긴급',const Color(0xFFE53935),'10km 이내에서 발생했습니다. 즉시 농장 방역상태를 확인하세요.'),DiseaseRiskLevel.level2=>('LEVEL 2','주의',const Color(0xFFFF8F00),'30km 이내에서 발생했습니다. 농장 출입 및 방역관리를 강화하세요.'),DiseaseRiskLevel.level3=>('LEVEL 3','관심',const Color(0xFFF9A825),'50km 이내에서 발생했습니다. 주변 발생 상황을 지속 확인하세요.'),DiseaseRiskLevel.safe=>('안전','안전',const Color(0xFF2E9D61),'50km 이내 공식 발생이 없습니다.'),_=>('확인 불가','위치 필요',AppColors.secondary,'정확한 GPS 위치 확인 후 방역 LEVEL을 계산합니다.')};return Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(12,11,12,10),decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('내 주변 질병 위험도 (${_selected?.label??'전체'})',style:const TextStyle(fontSize:13.5,fontWeight:FontWeight.w900)),const SizedBox(height:7),Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:data.$3.withValues(alpha:.12),borderRadius:BorderRadius.circular(11)),child:Column(children:[Text(data.$1,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:data.$3)),Text(data.$2,style:TextStyle(fontSize:8.5,color:data.$3))])),const SizedBox(width:9),Expanded(child:Text(data.$4,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9.5,height:1.35)))]),const SizedBox(height:7),Row(children:[_count('10km',r.count10),_count('30km',r.count30),_count('50km',r.count50)])]));}
  Widget _count(String label,int value)=>Expanded(child:Column(children:[Text(label,style:const TextStyle(fontSize:8,color:AppColors.secondary)),Text('$value건',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900))]));
  Widget _eventRow(DiseaseAlert x){final km=_eventDistance(x),status=x.isSuspected?'의심 · 검사 중':x.isConfirmed?'양성 · 공식 발생':x.status;return InkWell(onTap:()=>_focus(x),child:Container(padding:const EdgeInsets.symmetric(vertical:11),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:AppColors.divider))),child:Row(children:[Container(width:46,padding:const EdgeInsets.symmetric(vertical:5),decoration:BoxDecoration(color:x.isOfficial?AppColors.lightCoral:const Color(0xFFFFE5EC),borderRadius:BorderRadius.circular(20)),child:Text(x.disease,textAlign:TextAlign.center,style:const TextStyle(fontSize:8,fontWeight:FontWeight.w900,color:AppColors.coral))),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.region.isEmpty?x.summary:x.region,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w800)),Text('$status · ${_date(x.occurrenceDate)}${km==null?'':' · ${_distanceLabel(km)}'}',style:TextStyle(fontSize:8,fontWeight:FontWeight.w700,color:x.isSuspected?const Color(0xFFFF8F00):x.isConfirmed?AppColors.coral:AppColors.secondary))])),const Icon(Icons.chevron_right,size:18)])));}
  void _focus(DiseaseAlert x){setState((){_focusedId=x.stableKey;_selected=x.type;});_openDetail(x);}
  void _openDetail(DiseaseAlert x){Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DiseaseEventDetailPage(event:x,distanceKm:_eventDistance(x),userLatitude:_lat,userLongitude:_lng)));}
  void _openHelp()=>showModalBottomSheet(context:context,showDragHandle:true,builder:(context)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(18,0,18,18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('방역경보 LEVEL 안내',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:12),const Row(children:[Expanded(child:_LevelGuide('LEVEL 1','긴급','10km 이내',Color(0xFFE53935))),SizedBox(width:6),Expanded(child:_LevelGuide('LEVEL 2','주의','10~30km',Color(0xFFFF8F00))),SizedBox(width:6),Expanded(child:_LevelGuide('LEVEL 3','관심','30~50km',Color(0xFFF9A825))),SizedBox(width:6),Expanded(child:_LevelGuide('안전','안전','50km 초과',Color(0xFF2E9D61)))]),const SizedBox(height:14),const Text('농림축산식품 공공데이터의 공식 발생만 지도·위험도·알림에 반영합니다. 기사 게시일은 발생일로 사용하지 않으며 최근 30일의 실제 발생일을 기준으로 합니다.',style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,height:1.5,color:AppColors.secondary)),const SizedBox(height:12),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:(){Navigator.pop(context);Navigator.of(this.context).push(MaterialPageRoute(builder:(_)=>const DiseaseNotificationSettingsPage()));},icon:const Icon(Icons.notifications_active_outlined),label:const Text('질병 알림 설정')))]))));
  double? _eventDistance(DiseaseAlert x)=>_lat==null||_lng==null||x.latitude==null||x.longitude==null?null:DiseaseRiskEngine.distanceKm(_lat!,_lng!,x.latitude!,x.longitude!);
  String _distanceLabel(double km)=>km<10?'${km.toStringAsFixed(1)}km':'${km.round()}km';
  String _date(String value)=>value.length>=10?value.substring(0,10):value;
  String _updated(){final value=_feed?.updatedAt??'';return value.length>=10?'마지막 업데이트 ${value.substring(0,10)}':'';}
}

class _LevelGuide extends StatelessWidget{const _LevelGuide(this.level,this.label,this.distance,this.color);final String level,label,distance;final Color color;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:10),decoration:BoxDecoration(color:color.withValues(alpha:.1),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withValues(alpha:.25))),child:Column(children:[Icon(Icons.notifications_active_rounded,color:color,size:20),const SizedBox(height:5),FittedBox(child:Text(level,style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:color))),Text('$label · $distance',textAlign:TextAlign.center,style:const TextStyle(fontSize:7.5))]));}

class DiseaseEventDetailPage extends StatelessWidget{
  const DiseaseEventDetailPage({super.key,required this.event,this.distanceKm,this.userLatitude,this.userLongitude});
  final DiseaseAlert event;final double? distanceKm,userLatitude,userLongitude;
  @override Widget build(BuildContext context){final level=!event.isConfirmed?'공식 확진 전 · 방역 LEVEL 미반영':distanceKm==null?'위치 확인 필요':distanceKm!<=10?'LEVEL 1 · 긴급':distanceKm!<=30?'LEVEL 2 · 주의':distanceKm!<=50?'LEVEL 3 · 관심':'안전';return Scaffold(appBar:AppBar(title:Text('${event.disease} 발생지역 상세',style:const TextStyle(fontWeight:FontWeight.w900))),body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[Container(padding:const EdgeInsets.all(12),decoration:appCard(radius:18),child:KoreaDiseaseMap(items:[event],onTap:(_){},userLatitude:userLatitude,userLongitude:userLongitude,showRadii:event.isConfirmed,focusedEventId:event.stableKey)),const SizedBox(height:12),Container(padding:const EdgeInsets.all(16),decoration:appCard(radius:18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Wrap(spacing:8,children:[Chip(label:Text(event.disease)),Chip(label:Text(event.isSuspected?'의심 · 검사 중':event.isConfirmed?'양성 · 공식 발생':event.status))]),const SizedBox(height:8),Text(event.region.isEmpty?event.summary:event.region,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:10),Text('발생일  ${event.occurrenceDate}\n상태  ${event.status}\n내 위치에서  ${distanceKm==null?'좌표 확인 필요':distanceKm!<10?'${distanceKm!.toStringAsFixed(1)}km':'${distanceKm!.round()}km'}',style:const TextStyle(fontSize:11,height:1.7)),const SizedBox(height:12),Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppColors.lightCoral,borderRadius:BorderRadius.circular(12)),child:Text(level,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:AppColors.coral))),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:event.sourceUrl.isEmpty?null:()async{final uri=Uri.tryParse(event.sourceUrl);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);},icon:const Icon(Icons.route),label:const Text('출처 원문에서 확인'),style:FilledButton.styleFrom(backgroundColor:AppColors.coral)))]))])));}
}

class DiseaseNotificationSettingsPage extends StatefulWidget{const DiseaseNotificationSettingsPage({super.key});@override State<DiseaseNotificationSettingsPage> createState()=>_DiseaseNotificationSettingsPageState();}
class _DiseaseNotificationSettingsPageState extends State<DiseaseNotificationSettingsPage>{bool enabled=true;final levels=<bool>[true,true,true];final diseases=<bool>[true,true,true,true];@override void initState(){super.initState();_load();}Future<void> _load()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){enabled=p.getBool('disease_notifications_enabled')??true;for(var i=0;i<3;i++){levels[i]=p.getBool('disease_level_$i')??true;}for(var i=0;i<4;i++){diseases[i]=p.getBool('disease_type_$i')??true;}});}Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setBool('disease_notifications_enabled',enabled);for(var i=0;i<3;i++){await p.setBool('disease_level_$i',levels[i]);}for(var i=0;i<4;i++){await p.setBool('disease_type_$i',diseases[i]);}} @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('질병 알림 설정',style:TextStyle(fontWeight:FontWeight.w900))),body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,16),children:[Container(decoration:appCard(radius:16),child:SwitchListTile(contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:3),title:const Text('질병 알림',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)),subtitle:const Text('의심·검사 결과·신규 공식 발생 알림',style:TextStyle(fontSize:10)),value:enabled,onChanged:(v){setState(()=>enabled=v);_save();})),const SizedBox(height:12),_settingGroup('공식 발생 알림 기준 (거리)',List.generate(3,(i)=>CheckboxListTile(dense:true,visualDensity:VisualDensity.compact,contentPadding:const EdgeInsets.symmetric(horizontal:10),title:Text(const ['LEVEL 1 · 긴급 (10km 이내)','LEVEL 2 · 주의 (10~30km)','LEVEL 3 · 관심 (30~50km)'][i],style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),value:levels[i],onChanged:enabled?(v){setState(()=>levels[i]=v??false);_save();}:null))),const SizedBox(height:12),_settingGroup('알림 받을 질병',List.generate(4,(i)=>CheckboxListTile(dense:true,visualDensity:VisualDensity.compact,contentPadding:const EdgeInsets.symmetric(horizontal:10),title:Text(const ['구제역 (FMD)','ASF (아프리카돼지열병)','PED (돼지유행성설사)','PRRS (돼지생식기호흡기증후군)'][i],style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),value:diseases[i],onChanged:enabled?(v){setState(()=>diseases[i]=v??false);_save();}:null)))])));
  Widget _settingGroup(String title,List<Widget> rows)=>Container(decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.fromLTRB(13,12,13,5),child:Text(title,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900))),...rows]));
}
