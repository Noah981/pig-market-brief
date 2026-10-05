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
import '../widgets/disease_dashboard_widgets.dart';
import 'section_pages.dart';

class DiseasePage extends StatefulWidget{const DiseasePage({super.key});@override State<DiseasePage> createState()=>_DiseasePageState();}
class _DiseasePageState extends State<DiseasePage> with WidgetsBindingObserver{
  final _repository=DiseaseRepository();DiseaseFeed? _feed;Timer? _liveTimer;int _tab=0,_historyDays=30;DiseaseType? _selected;double? _lat,_lng;bool _gpsVerified=false,_showRadii=false,_locating=false;String _location='현재 위치를 확인할 수 없습니다.';String? _message,_focusedId;bool _refreshing=false;DateTime? _lastOfficialCheck;final _mapController=TransformationController();
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);FarmLocationSettings.instance.addListener(_syncLocation);NotificationService.instance.selectedDiseaseEvent.addListener(_notificationSelected);_loadLocation();_load();_liveTimer=Timer.periodic(const Duration(minutes:1),(_)=>_refresh(checkOfficial:false));}
  @override void dispose(){_liveTimer?.cancel();WidgetsBinding.instance.removeObserver(this);_mapController.dispose();FarmLocationSettings.instance.removeListener(_syncLocation);NotificationService.instance.selectedDiseaseEvent.removeListener(_notificationSelected);super.dispose();}
  Future<void> _loadLocation()async{await FarmLocationSettings.instance.load();_syncLocation();if(!_gpsVerified){try{await _updateGps(silent:true);}catch(_){}}}
  void _syncLocation(){final x=FarmLocationSettings.instance.location;if(!mounted)return;setState((){_gpsVerified=x.gpsVerified;_lat=x.gpsVerified?x.latitude:null;_lng=x.gpsVerified?x.longitude:null;_location=x.gpsVerified?x.label:(x.label.isEmpty?'농장 위치를 설정해주세요.':'기준 위치 · ${x.label}');});}
  void _notificationSelected(){final id=NotificationService.instance.selectedDiseaseEvent.value;if(id==null)return;final match=(_feed?.items??const <DiseaseAlert>[]).where((x)=>x.stableKey==id).firstOrNull;if(match!=null&&mounted)setState((){_tab=0;_selected=match.type;_focusedId=id;});}
  Future<void> _load()async{try{final cached=await _repository.cached();if(mounted)setState(()=>_feed=cached);}catch(_){}await _refresh();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)_refresh();}
  Future<void> _refresh({bool checkOfficial=true})async{
    if(_refreshing)return;
    _refreshing=true;
    try{
      final official=checkOfficial||_lastOfficialCheck==null||DateTime.now().difference(_lastOfficialCheck!)>=const Duration(minutes:5);
      final value=await _repository.refresh(checkOfficial:official);
      if(official)_lastOfficialCheck=DateTime.now();
      await DiseaseNotificationCoordinator.process(value);
      if(mounted)setState((){_feed=value;_message=value.errorMessage;});
      _notificationSelected();
    }finally{_refreshing=false;}
  }
  List<DiseaseAlert> get _active=>(_feed?.active(DateTime.now())??const []).where((x)=>_tab==0?x.countryCode=='KR':x.countryCode!='KR').toList();
  List<DiseaseAlert> get _visible=>_active.where((x)=>_selected==null||x.type==_selected).toList()..sort((a,b){final d=b.occurrenceDate.compareTo(a.occurrenceDate);if(d!=0)return d;return (b.isOfficial?1:0).compareTo(a.isOfficial?1:0);});
  List<DiseaseAlert> get _historyItems{final now=DateTime.now();return (_feed?.items??const <DiseaseAlert>[]).where((x){final date=x.displayMoment;return (_tab==0?x.countryCode=='KR':x.countryCode!='KR')&&date!=null&&!date.isAfter(now)&&date.isAfter(now.subtract(Duration(days:_historyDays)));}).toList()..sort((a,b)=>b.displayDate.compareTo(a.displayDate));}
  List<DiseaseAlert> get _listed=>_historyItems.where((x)=>_selected==null||x.type==_selected).toList();
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
  @override Widget build(BuildContext context){
    final verified=_feed?.coverageVerified==true&&_feed?.fromCache==false&&_feed?.state==DiseaseDataState.live;
    final risk=DiseaseRiskEngine.summarize(_visible,latitude:verified?_lat:null,longitude:verified?_lng:null,type:_selected);
    return PageShell(compactHeader:true,title:'질병',subtitle:'내 농장 주변 질병 발생 현황을 확인하세요',help:_openHelp,onRefresh:()=>_refresh(),child:Column(children:[
      _tabs(),const SizedBox(height:10),_summary(),const SizedBox(height:10),
      if(_message!=null)Padding(padding:const EdgeInsets.only(bottom:8),child:Text(_message!,style:const TextStyle(fontSize:10,color:AppColors.secondary))),
      if(_tab==0)...[
        _locationBar(),const SizedBox(height:10),
        Container(decoration:appCard(radius:16),padding:const EdgeInsets.all(9),child:Column(children:[
          Row(children:[
            Expanded(child:_filterLabel()),const SizedBox(width:5),
            ...const [(30,'1개월'),(90,'3개월'),(180,'6개월'),(365,'1년')].map((period)=>Padding(
              padding:const EdgeInsets.only(left:2),
              child:InkWell(key:ValueKey('disease_period_${period.$1}'),onTap:()=>setState(()=>_historyDays=period.$1),borderRadius:BorderRadius.circular(24),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:8),
                  decoration:BoxDecoration(color:_historyDays==period.$1?AppColors.coral:const Color(0xFFF5F5F7),borderRadius:BorderRadius.circular(24)),
                  child:Text(period.$2,style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:_historyDays==period.$1?Colors.white:AppColors.secondary)),
                ),
              ),
            )),
            IconButton(key:const ValueKey('disease_layers'),tooltip:'방역반경 표시',onPressed:()=>setState(()=>_showRadii=!_showRadii),constraints:const BoxConstraints(minWidth:28,minHeight:36),padding:EdgeInsets.zero,icon:Icon(Icons.layers_outlined,size:21,color:_showRadii?AppColors.coral:AppColors.secondary)),
          ]),
          KoreaDiseaseMap(items:_listed.where((x)=>x.isConfirmed).toList(),onTap:_openDetail,userLatitude:_lat,userLongitude:_lng,showRadii:_showRadii,focusedEventId:_focusedId,controller:_mapController,dashboard:true),
        ])),const SizedBox(height:10),if(_selected==DiseaseType.ped)_pedNotice()else _riskCard(risk,verified),
      ]else Container(padding:const EdgeInsets.all(14),decoration:appCard(radius:16),child:const Text('WOAH 아프리카 공식 통보입니다. 세계 전체 발생 집계는 아니며, 통보일은 실제 발생일과 다를 수 있습니다.',style:TextStyle(fontSize:11))),
      const SizedBox(height:10),if(_selected==DiseaseType.ped&&_tab==0)_pedStatisticsCard()else _recentCard(),
      const SizedBox(height:8),Row(children:[Expanded(child:Text(_updated(),style:const TextStyle(fontSize:9,color:AppColors.secondary))),TextButton.icon(key:const ValueKey('disease_refresh'),onPressed:()=>_refresh(),icon:const Icon(Icons.refresh,size:16),label:const Text('새로고침',style:TextStyle(fontSize:10)))])
    ]));
  }
  Widget _tabs()=>Container(height:28,padding:const EdgeInsets.all(1),decoration:BoxDecoration(color:const Color(0xFFF0EFF3),borderRadius:BorderRadius.circular(10)),child:Row(children:List.generate(2,(i)=>Expanded(child:InkWell(key:ValueKey('disease_tab_$i'),onTap:()=>setState((){_tab=i;_focusedId=null;}),borderRadius:BorderRadius.circular(9),child:Container(alignment:Alignment.center,decoration:BoxDecoration(color:_tab==i?AppColors.coral:Colors.transparent,borderRadius:BorderRadius.circular(9)),child:Text(i==0?'국내':'해외',style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:_tab==i?Colors.white:AppColors.secondary))))))));
  Map<String,dynamic>? _pedPeriod(int days){final value=(_feed?.statistics['ped'] as Map?)?['periods'];final period=(value as Map?)?['$days'];return (period as Map?)?.cast<String,dynamic>();}
  Widget _summary()=>Row(children:DiseaseType.values.map((type){final count=(_feed?.items??const <DiseaseAlert>[]).where((x)=>x.type==type&&(_tab==0?x.countryCode=='KR':x.countryCode!='KR')&&x.displayMoment!=null&&!x.displayMoment!.isAfter(DateTime.now())&&DateTime.now().difference(x.displayMoment!).inDays<=365).length;return Expanded(child:Padding(padding:EdgeInsets.only(right:type==DiseaseType.prrs?0:6),child:DiseaseSummaryCard(type:type,count:type==DiseaseType.ped&&_tab==0?(_pedPeriod(365)?['farmCount'] as num?)?.toInt()??0:count,statistical:type==DiseaseType.ped&&_tab==0,selected:_selected==type,verified:type==DiseaseType.ped&&_tab==0?_pedPeriod(365)!=null:_feed?.coverageVerified==true,onTap:()=>setState(()=>_selected=_selected==type?null:type))));}).toList());
  Widget _locationBar()=>Row(children:[Expanded(child:Container(height:34,padding:const EdgeInsets.symmetric(horizontal:10),decoration:appCard(radius:12),child:Row(children:[const Icon(Icons.location_on_rounded,color:AppColors.secondary,size:20),const SizedBox(width:7),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_gpsVerified?'현재 위치':'기준 위치',style:const TextStyle(fontSize:8,color:AppColors.secondary)),Text(_location,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))]))]))),const SizedBox(width:9),TextButton.icon(key:const ValueKey('disease_gps'),onPressed:_locating?null:_updateGps,icon:const Icon(Icons.my_location,size:18),label:Text(_locating?'확인 중':'GPS 재설정',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),style:TextButton.styleFrom(foregroundColor:AppColors.blue,backgroundColor:const Color(0xFFEDF4FF),minimumSize:const Size(94,34),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))))]);
  Widget _filterLabel()=>PopupMenuButton<String>(key:const ValueKey('disease_filter'),tooltip:'질병 선택',onSelected:(value)=>setState(()=>_selected=value=='all'?null:DiseaseType.values.byName(value)),itemBuilder:(_)=>[const PopupMenuItem<String>(value:'all',child:Text('전체 보기')),...DiseaseType.values.map((type)=>PopupMenuItem<String>(value:type.name,child:Text('${type.label}만 보기')))],child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),decoration:BoxDecoration(color:const Color(0xFFF5F5F7),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFE8E8EC))),child:FittedBox(alignment:Alignment.centerLeft,fit:BoxFit.scaleDown,child:Text(_selected==null?'전체 보기 ▼':'${_selected!.label}만 보기 ▼',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)))));
  Widget _riskCard(DiseaseRiskSummary r,bool verified){final data=switch(r.level){DiseaseRiskLevel.level1=>('LEVEL 1','긴급',const Color(0xFFE53935),'10km 이내 공식 발생이 있습니다.'),DiseaseRiskLevel.level2=>('LEVEL 2','주의',const Color(0xFFFF8F00),'30km 이내 공식 발생이 있습니다.'),DiseaseRiskLevel.level3=>('LEVEL 3','관심',const Color(0xFFF9A825),'50km 이내 공식 발생이 있습니다.'),DiseaseRiskLevel.safe=>('경보 없음','최근 1개월',const Color(0xFF2E9D61),'50km 이내 경보 대상이 없습니다.'),_=>('확인 필요',verified?'위치 필요':'자료 확인',AppColors.secondary,verified?(_gpsVerified?'일부 발생 위치의 좌표가 미공개입니다.':'GPS 위치를 확인해주세요.'):'최신 공식 자료를 확인 중입니다.')};return InkWell(key:const ValueKey('disease_risk_help'),onTap:_openHelp,borderRadius:BorderRadius.circular(16),child:Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('내 주변 질병 위험도 (${_selected?.label??'전체'})',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900))),const Icon(Icons.chevron_right,size:20,color:AppColors.secondary)]),const SizedBox(height:8),Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),decoration:BoxDecoration(color:data.$3.withValues(alpha:.1),borderRadius:BorderRadius.circular(9)),child:Row(children:[Icon(Icons.verified_user_rounded,color:data.$3,size:28),const SizedBox(width:5),Column(children:[Text(data.$1,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:data.$3)),Text(data.$2,style:TextStyle(fontSize:8,color:data.$3))])])),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(data.$4,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),const SizedBox(height:3),Text('최근 1개월 미종식 공식 기록 기준',style:const TextStyle(fontSize:9,color:AppColors.secondary))]))]),const SizedBox(height:9),Row(children:[_count('10km',r.count10,verified&&_gpsVerified&&r.level!=DiseaseRiskLevel.unknown),Container(height:25,width:1,color:AppColors.divider),_count('30km',r.count30,verified&&_gpsVerified&&r.level!=DiseaseRiskLevel.unknown),Container(height:25,width:1,color:AppColors.divider),_count('50km',r.count50,verified&&_gpsVerified&&r.level!=DiseaseRiskLevel.unknown)])])));}
  Widget _count(String label,int value,bool known)=>Expanded(child:Column(children:[Text(label,style:const TextStyle(fontSize:10,color:AppColors.secondary)),Text(known?'$value건':'—',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900))]));
  Widget _pedNotice()=>Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:appCard(radius:16),child:const Row(children:[Icon(Icons.info_outline,color:AppColors.secondary),SizedBox(width:9),Expanded(child:Text('PED는 시도별 공식 발생통계입니다. 농장별 위치·발생일은 공개되지 않아 거리 경보를 계산하지 않습니다.',style:TextStyle(fontSize:11,height:1.4)))]));
  Widget _pedStatisticsCard(){final period=_pedPeriod(_historyDays);final source=(_feed?.statistics['ped'] as Map?);final regions=(period?['regions'] as List? ?? const []).whereType<Map>().where((x)=>(x['farmCount'] as num? ?? 0)>0).toList();return Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('PED 공식 발생통계',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(period==null?'공식 통계를 확인하지 못했습니다.':'${period['from']} ~ ${period['to']} · ${period['farmCount']}건 / ${period['animalCount']}두',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),const SizedBox(height:8),...regions.map((row)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Expanded(child:Text(row['province'].toString(),style:const TextStyle(fontSize:12))),Text('${row['farmCount']}건 · ${row['animalCount']}두',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))]))),if(period!=null&&regions.isEmpty)const Text('선택한 기간의 공식 집계는 0건입니다.',style:TextStyle(fontSize:11,color:AppColors.secondary)),const SizedBox(height:8),Text('확인 기준: ${DateTime.tryParse(source?['checkedAt']?.toString()??'')?.toIso8601String().split('T').first??'미확인'} · 발생농장수 보고 집계. 개별 농장 위치가 아닙니다.',style:TextStyle(fontSize:9,color:AppColors.secondary)),TextButton.icon(onPressed:()async{final uri=Uri.tryParse(source?['sourceUrl']?.toString()??'https://home.kahis.go.kr/home/lkntscrinfo/selectLkntsOccrrnc.do');if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);},icon:const Icon(Icons.open_in_new,size:15),label:const Text('KAHIS 공식 통계 원문',style:TextStyle(fontSize:10)))]));}
  Widget _recentCard()=>Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('최근 발생 내역 (${_selected?.label??'전체'})',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900))),TextButton(key:const ValueKey('disease_more'),onPressed:_openHistory,style:TextButton.styleFrom(minimumSize:const Size(45,28),padding:EdgeInsets.zero),child:const Text('더보기 ›',style:TextStyle(fontSize:10,color:AppColors.secondary)))]),if(_listed.isEmpty)Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:12,vertical:14),decoration:BoxDecoration(color:const Color(0xFFF7F7F9),borderRadius:BorderRadius.circular(11),border:Border.all(color:const Color(0xFFEDEDF0))),child:Row(children:[const Icon(Icons.description_outlined,size:30,color:AppColors.secondary),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_feed?.coverageVerified==true?'선택한 기간의 조회 자료가 없습니다.':'최신 공식 자료를 확인하지 못했습니다.',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:AppColors.secondary)),const SizedBox(height:3),const Text('다른 기간이나 질병을 선택해 확인해보세요.',style:TextStyle(fontSize:9,color:AppColors.secondary))]))]))else ..._listed.take(3).map(_eventRow)]));
  void _openHistory()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:Text('${_selected?.label??'전체'} 공식 발생·통보 내역')),body:ListView(padding:const EdgeInsets.all(16),children:[Text('최근 $_historyDays일 · ${_listed.length}건',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:10),if(_listed.isEmpty)const Text('선택한 기간의 조회 자료가 없습니다.')else ..._listed.map(_eventRow)]))));
  Widget _eventRow(DiseaseAlert x){final km=_eventDistance(x),status=x.isClosed?'종식':x.usesNotificationDate?'공식 통보':x.isSuspected?'의심 · 검사 중':x.isConfirmed?'양성 · 공식 발생':x.status;return InkWell(onTap:()=>_focus(x),child:Container(padding:const EdgeInsets.symmetric(vertical:11),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:AppColors.divider))),child:Row(children:[Container(width:46,padding:const EdgeInsets.symmetric(vertical:5),decoration:BoxDecoration(color:x.isOfficial?AppColors.lightCoral:const Color(0xFFFFE5EC),borderRadius:BorderRadius.circular(20)),child:Text(x.disease,textAlign:TextAlign.center,style:const TextStyle(fontSize:8,fontWeight:FontWeight.w900,color:AppColors.coral))),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.region.isEmpty?x.summary:x.region,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w800)),Text('$status · ${x.dateLabel} ${_date(x.displayDate)}${km==null?'':' · ${_distanceLabel(km)}'}',style:TextStyle(fontSize:8,fontWeight:FontWeight.w700,color:x.isSuspected?const Color(0xFFFF8F00):x.isConfirmed?AppColors.coral:AppColors.secondary))])),const Icon(Icons.chevron_right,size:18)])));}
  void _focus(DiseaseAlert x){setState((){_focusedId=x.stableKey;_selected=x.type;});_openDetail(x);}
  void _openDetail(DiseaseAlert x){Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DiseaseEventDetailPage(event:x,distanceKm:_eventDistance(x),userLatitude:_lat,userLongitude:_lng)));}
  void _openHelp()=>showModalBottomSheet(context:context,showDragHandle:true,builder:(context)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(18,0,18,18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('방역경보 LEVEL 안내',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:12),const Row(children:[Expanded(child:_LevelGuide('LEVEL 1','긴급','10km 이내',Color(0xFFE53935))),SizedBox(width:6),Expanded(child:_LevelGuide('LEVEL 2','주의','10~30km',Color(0xFFFF8F00))),SizedBox(width:6),Expanded(child:_LevelGuide('LEVEL 3','관심','30~50km',Color(0xFFF9A825))),SizedBox(width:6),Expanded(child:_LevelGuide('안전','안전','50km 초과',Color(0xFF2E9D61)))]),const SizedBox(height:14),const Text('농림축산식품 공공데이터의 공식 발생만 지도·위험도·알림에 반영합니다. 기사 게시일은 발생일로 사용하지 않으며 최근 30일의 실제 발생일을 기준으로 합니다. 구제역은 소 등 다른 우제류의 공식 발생도 포함하며, 발생 축종은 상세 화면에 표시합니다.',style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,height:1.5,color:AppColors.secondary)),const SizedBox(height:12),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:(){Navigator.pop(context);Navigator.of(this.context).push(MaterialPageRoute(builder:(_)=>const DiseaseNotificationSettingsPage()));},icon:const Icon(Icons.notifications_active_outlined),label:const Text('질병 알림 설정')))]))));
  double? _eventDistance(DiseaseAlert x)=>x.countryCode!='KR'||_lat==null||_lng==null||x.latitude==null||x.longitude==null?null:DiseaseRiskEngine.distanceKm(_lat!,_lng!,x.latitude!,x.longitude!);
  String _distanceLabel(double km)=>km<10?'${km.toStringAsFixed(1)}km':'${km.round()}km';
  String _date(String value)=>value.length>=10?value.substring(0,10):value;
  String _updated(){final value=_feed?.updatedAt??'';final date=DateTime.tryParse(value)?.toUtc().add(const Duration(hours:9));return date==null?'업데이트 확인 중':'${date.month}/${date.day} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')} 확인${_feed?.fromCache==true?' · 저장 자료':''}';}
}

class _LevelGuide extends StatelessWidget{const _LevelGuide(this.level,this.label,this.distance,this.color);final String level,label,distance;final Color color;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:10),decoration:BoxDecoration(color:color.withValues(alpha:.1),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withValues(alpha:.25))),child:Column(children:[Icon(Icons.notifications_active_rounded,color:color,size:20),const SizedBox(height:5),FittedBox(child:Text(level,style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:color))),Text('$label · $distance',textAlign:TextAlign.center,style:const TextStyle(fontSize:7.5))]));}

class DiseaseEventDetailPage extends StatelessWidget{
  const DiseaseEventDetailPage({super.key,required this.event,this.distanceKm,this.userLatitude,this.userLongitude});
  final DiseaseAlert event;final double? distanceKm,userLatitude,userLongitude;
  @override Widget build(BuildContext context){final level=event.countryCode!='KR'?'해외 공식 통보 · 국내 방역 LEVEL 제외':!event.isActiveAt(DateTime.now())?'과거 발생 내역 · 현재 방역 LEVEL 제외':!event.isConfirmed?'공식 확진 전 · 방역 LEVEL 미반영':distanceKm==null?'위치 확인 필요':distanceKm!<=10?'LEVEL 1 · 긴급':distanceKm!<=30?'LEVEL 2 · 주의':distanceKm!<=50?'LEVEL 3 · 관심':'50km 밖 · 근접 경보 대상 아님';return Scaffold(appBar:AppBar(title:Text('${event.disease} 발생지역 상세',style:const TextStyle(fontWeight:FontWeight.w900))),body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[if(event.countryCode=='KR') Container(padding:const EdgeInsets.all(12),decoration:appCard(radius:18),child:KoreaDiseaseMap(items:[event],onTap:(_){},userLatitude:userLatitude,userLongitude:userLongitude,showRadii:event.isConfirmed,focusedEventId:event.stableKey)),const SizedBox(height:12),Container(padding:const EdgeInsets.all(16),decoration:appCard(radius:18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Wrap(spacing:8,children:[Chip(label:Text(event.disease)),Chip(label:Text(event.isClosed?'종식':event.usesNotificationDate?'공식 통보':event.isSuspected?'의심 · 검사 중':event.isConfirmed?'양성 · 공식 발생':event.status))]),const SizedBox(height:8),Text(event.region.isEmpty?event.summary:event.region,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:10),Text('${event.dateLabel}  ${event.displayDate}${event.usesNotificationDate?' (실제 발생일 미확인)':''}\n축종  ${event.livestockType.isEmpty?'원문 확인':event.livestockType}\n상태  ${event.status}${event.countryCode=='KR'?'\n내 위치에서':''}  ${event.countryCode!='KR'?'':distanceKm==null?'좌표 확인 필요':distanceKm!<10?'${distanceKm!.toStringAsFixed(1)}km':'${distanceKm!.round()}km'}',style:const TextStyle(fontSize:11,height:1.7)),const SizedBox(height:12),Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppColors.lightCoral,borderRadius:BorderRadius.circular(12)),child:Text(level,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:AppColors.coral))),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:event.sourceUrl.isEmpty?null:()async{final uri=Uri.tryParse(event.sourceUrl);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);},icon:const Icon(Icons.route),label:const Text('출처 원문에서 확인'),style:FilledButton.styleFrom(backgroundColor:AppColors.coral)))]))])));}
}

class DiseaseNotificationSettingsPage extends StatefulWidget{const DiseaseNotificationSettingsPage({super.key});@override State<DiseaseNotificationSettingsPage> createState()=>_DiseaseNotificationSettingsPageState();}
class _DiseaseNotificationSettingsPageState extends State<DiseaseNotificationSettingsPage>{bool enabled=true;final levels=<bool>[true,true,true];final diseases=<bool>[true,true,true,true];@override void initState(){super.initState();_load();}Future<void> _load()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){enabled=p.getBool('disease_notifications_enabled')??true;for(var i=0;i<3;i++){levels[i]=p.getBool('disease_level_$i')??true;}for(var i=0;i<4;i++){diseases[i]=p.getBool('disease_type_$i')??true;}});}Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setBool('disease_notifications_enabled',enabled);for(var i=0;i<3;i++){await p.setBool('disease_level_$i',levels[i]);}for(var i=0;i<4;i++){await p.setBool('disease_type_$i',diseases[i]);}} @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('질병 알림 설정',style:TextStyle(fontWeight:FontWeight.w900))),body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,16),children:[Container(decoration:appCard(radius:16),child:SwitchListTile(contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:3),title:const Text('질병 알림',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)),subtitle:const Text('의심·검사 결과·신규 공식 발생 알림',style:TextStyle(fontSize:10)),value:enabled,onChanged:(v){setState(()=>enabled=v);_save();})),const SizedBox(height:12),_settingGroup('공식 발생 알림 기준 (거리)',List.generate(3,(i)=>CheckboxListTile(dense:true,visualDensity:VisualDensity.compact,contentPadding:const EdgeInsets.symmetric(horizontal:10),title:Text(const ['LEVEL 1 · 긴급 (10km 이내)','LEVEL 2 · 주의 (10~30km)','LEVEL 3 · 관심 (30~50km)'][i],style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),value:levels[i],onChanged:enabled?(v){setState(()=>levels[i]=v??false);_save();}:null))),const SizedBox(height:12),_settingGroup('알림 받을 질병',List.generate(4,(i)=>CheckboxListTile(dense:true,visualDensity:VisualDensity.compact,contentPadding:const EdgeInsets.symmetric(horizontal:10),title:Text(const ['구제역 (FMD)','ASF (아프리카돼지열병)','PED (돼지유행성설사)','PRRS (돼지생식기호흡기증후군)'][i],style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),value:diseases[i],onChanged:enabled?(v){setState(()=>diseases[i]=v??false);_save();}:null)))])));
  Widget _settingGroup(String title,List<Widget> rows)=>Container(decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.fromLTRB(13,12,13,5),child:Text(title,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900))),...rows]));
}
