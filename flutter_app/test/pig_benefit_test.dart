import 'package:flutter_test/flutter_test.dart';
import '../lib/models/benefit_models.dart';
BenefitNotice notice(String title,{String target='',String support=''})=>BenefitNotice(id:'x',title:title,region:'전국',agency:'공식기관',url:'https://www.mafra.go.kr/',target:target,support:support);
void main(){
 test('Pig and shared livestock programmes remain eligible',(){
  for(final title in ['양돈농가 시설 지원 신청','돼지 방역 지원','축산농가 사료구매 융자 지원','가축 사육 농가 분뇨 처리 지원']){expect(notice(title).relevantToPigFarming,true,reason:title);}
 });
 test('Other species, non-livestock and exclusions are rejected',(){
  for(final title in ['한우농가 사료 지원','낙농 시설 지원','양계 방역 지원','반려동물 지원','저탄소 벼 농가 지원','양돈사육원 채용 모집']){expect(notice(title,support:'축산농가 돼지 참고').relevantToPigFarming,false,reason:title);}
  expect(notice('축산농가 사료 지원',target:'양돈 제외').relevantToPigFarming,false);
  expect(notice('양돈농가 지원',target:'돼지 농가 미지원').relevantToPigFarming,false);
 });
 test('Province aliases and specific county scope are respected',(){
  const local=BenefitNotice(id:'a',title:'양돈 지원',region:'경북·상주시',agency:'상주시',url:'https://www.sangju.go.kr/',target:'양돈농가',support:'지원');
  expect(local.matchesRegion('경상북도','상주시'),true);
  expect(local.matchesRegion('경상북도','김천시'),false);
  const province=BenefitNotice(id:'b',title:'양돈 지원',region:'경북',agency:'경상북도',url:'https://www.gb.go.kr/',target:'양돈농가',support:'지원');
  expect(province.matchesRegion('경상북도','김천시'),true);
 });

}
