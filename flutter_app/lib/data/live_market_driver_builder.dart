import '../models/dashboard_models.dart';
import 'market_repository.dart';
import 'pig_grade_repository.dart';

class LiveMarketDriverBuilder {
  const LiveMarketDriverBuilder._();

  static MarketAnalysis build({required MarketSnapshot? market,required PigGradeSnapshot? grades,MarketAnalysis? fallback}) {
    final factors=<MarketFactor>[];
    if(market!=null){
      final up=market.change>0,flat=market.change==0;
      factors.add(MarketFactor(flat?'전일 대비 보합':up?'전일 대비 돈가 상승':'전일 대비 돈가 하락','실제 가격',flat?'${_won(market.price)}원/kg으로 직전 거래일과 같습니다.':'${_won(market.previousPrice)}원 → ${_won(market.price)}원 (${market.changePct>=0?'+':''}${market.changePct.toStringAsFixed(2)}%)',source:'축산유통정보 다봄',sourceDate:market.date,direction:flat?'neutral':up?'up':'down'));
    }
    final current=grades?.auctionStatus,previous=grades?.previousAuction;
    if(current!=null&&previous!=null){
      _addChange(factors,title:'경락두수',current:current.totalCount.toDouble(),previous:previous.totalCount.toDouble(),unit:'두',sourceDate:current.date,pressureWhenUp:'공급 부담 신호',pressureWhenDown:'공급 완화 신호');
      if(current.averageCarcassWeight!=null&&previous.averageCarcassWeight!=null){
        _addChange(factors,title:'평균 도체중',current:current.averageCarcassWeight!,previous:previous.averageCarcassWeight!,unit:'kg',sourceDate:current.date,decimals:1,pressureWhenUp:'출하중량 증가 신호',pressureWhenDown:'출하중량 감소 신호');
        final currentWeight=current.totalCount*current.averageCarcassWeight!,previousWeight=previous.totalCount*previous.averageCarcassWeight!;
        _addChange(factors,title:'경락 총중량',current:currentWeight,previous:previousWeight,unit:'kg',sourceDate:current.date,pressureWhenUp:'시장 공급량 증가 신호',pressureWhenDown:'시장 공급량 감소 신호');
      }
    }
    if(factors.length<4){for(final item in fallback?.factors??const <MarketFactor>[]){if(item.source.isNotEmpty&&!factors.any((x)=>x.title==item.title))factors.add(item);if(factors.length==4)break;}}
    return MarketAnalysis(summary:market==null?(fallback?.summary??'확인 가능한 공식 지표를 불러오는 중입니다.'):market.change<0?'돈가가 하락했습니다. 아래 공급 관련 실측 지표를 함께 확인하세요.':market.change>0?'돈가가 상승했습니다. 아래 공급 관련 실측 지표를 함께 확인하세요.':'돈가는 보합입니다. 아래 공급 관련 실측 지표를 함께 확인하세요.',factors:factors.take(4).toList(),updatedAt:market?.updatedAt??fallback?.updatedAt??'',sources:fallback?.sources??const []);
  }

  static void _addChange(List<MarketFactor> out,{required String title,required double current,required double previous,required String unit,required String sourceDate,required String pressureWhenUp,required String pressureWhenDown,int decimals=0}){
    if(previous<=0)return;final diff=current-previous,pct=diff/previous*100,flat=diff.abs()<0.0001,up=diff>0;
    String value(double x)=>decimals==0?_number(x.round()):x.toStringAsFixed(decimals);
    out.add(MarketFactor('$title ${flat?'보합':up?'증가':'감소'}','실측 비교','${value(previous)}$unit → ${value(current)}$unit (${pct>=0?'+':''}${pct.toStringAsFixed(1)}%) · ${flat?'변화 제한':up?pressureWhenUp:pressureWhenDown}',source:'축산유통정보 다봄',sourceDate:sourceDate,direction:flat?'neutral':up?'up':'down'));
  }
  static String _won(int x)=>_number(x);
  static String _number(int x)=>x.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>',');
}
