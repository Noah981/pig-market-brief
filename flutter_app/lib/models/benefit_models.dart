class BenefitNotice{
 const BenefitNotice({required this.id,required this.title,required this.region,required this.agency,required this.url,required this.target,required this.support,this.deadline});
 final String id,title,region,agency,url,target,support;final DateTime? deadline;
 factory BenefitNotice.fromJson(Map<String,dynamic> x)=>BenefitNotice(id:x['id']?.toString()??'',title:x['title']?.toString()??'',region:x['region']?.toString()??'',agency:x['agency']?.toString()??'',url:x['url']?.toString()??'',target:x['target']?.toString()??'공식 공고에서 확인',support:x['support']?.toString()??'공식 공고에서 확인',deadline:DateTime.tryParse(x['deadline']?.toString()??''));
}
class BenefitFeed{const BenefitFeed({required this.items,required this.status,required this.fromCache});final List<BenefitNotice> items;final String status;final bool fromCache;}
