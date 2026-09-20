enum SourceAvailability { connected, readyForKey, approvalPending, unavailable }

class SourceDescriptor {
  const SourceDescriptor({required this.id,required this.name,required this.availability,required this.secretName,required this.official});
  final String id,name,secretName;final SourceAvailability availability;final bool official;
}

abstract interface class ApiClient<Dto> {Future<Dto> fetch();}
abstract interface class DataAdapter<Dto,Domain> {Domain normalize(Dto value);}
abstract interface class DataRepository<Domain> {Future<Domain?> cached();Future<Domain> refresh();}

abstract final class SourceRegistry {
  static const sources=[
    SourceDescriptor(id:'kape',name:'축산물품질평가원',availability:SourceAvailability.readyForKey,secretName:'KAPE_SERVICE_KEY',official:true),
    SourceDescriptor(id:'kma',name:'기상청',availability:SourceAvailability.readyForKey,secretName:'KMA_SERVICE_KEY',official:true),
    SourceDescriptor(id:'mois_disease',name:'행정안전부 가축전염병',availability:SourceAvailability.approvalPending,secretName:'MOIS_DISEASE_API_KEY',official:true),
    SourceDescriptor(id:'ecos',name:'한국은행 ECOS',availability:SourceAvailability.readyForKey,secretName:'ECOS_API_KEY',official:true),
    SourceDescriptor(id:'kamis',name:'KAMIS',availability:SourceAvailability.approvalPending,secretName:'KAMIS_API_KEY',official:true),
    SourceDescriptor(id:'international_feed',name:'국제 원료 공개데이터',availability:SourceAvailability.connected,secretName:'',official:true),
    SourceDescriptor(id:'benefits',name:'정부·지자체 공식 공고',availability:SourceAvailability.connected,secretName:'',official:true),
  ];
}
