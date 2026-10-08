class BenefitNotice{
 const BenefitNotice({required this.id,required this.title,required this.region,required this.agency,required this.url,required this.target,required this.support,this.startDate,this.deadline,this.publishedAt,this.applicationPeriod=''});
 final String id,title,region,agency,url,target,support,applicationPeriod;
 bool get isContinuousApplication=>RegExp(r'예산\s*소진|상시|연중|수시').hasMatch(applicationPeriod);final DateTime? startDate,deadline,publishedAt;
 bool get relevantToPigFarming{
  final text='$title $target $support';
  final pig=RegExp(r'양돈|돼지|돈사|아프리카돼지열병|\bASF\b|\bPED\b|\bPRRS\b',caseSensitive:false);
  final other=RegExp(r'한우|육우|젖소|낙농|양계|육계|산란계|오리|양봉|벌꿀|양잠|염소|말산업|승마|반려동물|반려견|반려묘|벼|쌀|과수|원예|수산|어업|음식점|식당');
  if(RegExp(r'(?:양돈|돼지|돈사)\s*(?:농가|농장|업)?\s*(?:는|은|를|을)?\s*(?:제외|미지원|지원대상\s*아님)|제외\s*(?:대상)?\s*[:：]?\s*(?:양돈|돼지)').hasMatch(text)||RegExp(r'채용|입찰|낙찰').hasMatch(title))return false;
  if(!RegExp(r'지원|보조금|융자|인센티브|모집|신청|참여|사업|공모|대상자').hasMatch(text))return false;
  if(pig.hasMatch(title))return true;
  if(!pig.hasMatch('$target $support')&&RegExp(r'온실|토마토|원예|재배|과수|수경|수산').hasMatch(support))return false;
  if(other.hasMatch(title))return false;
  if(pig.hasMatch('$target $support'))return true;
  return RegExp(r'축산농가|축산농업인|가축\s*사육\s*농가|축산업|축산시설|축산환경|축산악취|축산분뇨|축산방역|축사시설현대화|축산분야\s*ICT|사료구매자금|가축재해보험|축산악취개선').hasMatch(text)&&
   RegExp(r'시설|장비|사료|축사|분뇨|방역|퇴비|액비|악취|환경|저탄소|HACCP|무항생제|동물복지|재해|ICT|스마트|백신|예방접종|컨설팅|교육',caseSensitive:false).hasMatch(text)&&!other.hasMatch(target);
 }
 bool matchesRegion(String province,String cityCounty,{String town=''}){
  if(region.contains('전국'))return true;
  String normalized(String value){
   const aliases={'서울특별시':'서울','서울시':'서울','부산광역시':'부산','대구광역시':'대구','인천광역시':'인천','광주광역시':'광주','대전광역시':'대전','울산광역시':'울산','세종특별자치시':'세종','경기도':'경기','강원특별자치도':'강원','강원도':'강원','충청북도':'충북','충청남도':'충남','전북특별자치도':'전북','전라북도':'전북','전라남도':'전남','경상북도':'경북','경상남도':'경남','제주특별자치도':'제주','제주도':'제주'};
   for(final entry in aliases.entries){value=value.replaceAll(entry.key,entry.value);}return value;
  }
  final area=normalized(region),selected=normalized(province);
  if(selected.isEmpty||!area.contains(selected))return false;
  final counties=area.split(RegExp(r'[\s·,/]+')).where((x)=>RegExp(r'[가-힣]{2,6}(시|군|구)$').hasMatch(x)).toList();
  return counties.isEmpty||counties.contains(cityCounty)||(town.isNotEmpty&&area.contains(town));
 }
 factory BenefitNotice.fromJson(Map<String,dynamic> x)=>BenefitNotice(id:x['id']?.toString()??'',title:x['title']?.toString()??'',region:x['region']?.toString()??'',agency:x['agency']?.toString()??'',url:x['url']?.toString()??'',target:x['target']?.toString()??'공식 공고에서 확인',support:x['support']?.toString()??'공식 공고에서 확인',startDate:DateTime.tryParse(x['startDate']?.toString()??''),deadline:DateTime.tryParse(x['deadline']?.toString()??''),publishedAt:DateTime.tryParse(x['publishedAt']?.toString()??''),applicationPeriod:x['applicationPeriod']?.toString()??'');
}
class BenefitFeed{const BenefitFeed({required this.items,required this.status,required this.fromCache});final List<BenefitNotice> items;final String status;final bool fromCache;}
