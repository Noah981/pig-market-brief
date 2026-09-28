import '../settings/farm_location_settings.dart';

class ResolvedKoreanLocation {
  const ResolvedKoreanLocation(this.province, this.cityCounty, this.town);

  final String province;
  final String cityCounty;
  final String town;
}

abstract final class KoreanLocationResolver {
  static const Map<String, List<String>> _provinceAliases = {
    '서울특별시': ['서울', '서울시', 'Seoul'],
    '부산광역시': ['부산', '부산시', 'Busan'],
    '대구광역시': ['대구', '대구시', 'Daegu'],
    '인천광역시': ['인천', '인천시', 'Incheon'],
    '광주광역시': ['광주', '광주시', 'Gwangju'],
    '대전광역시': ['대전', '대전시', 'Daejeon'],
    '울산광역시': ['울산', '울산시', 'Ulsan'],
    '세종특별자치시': ['세종', '세종시', 'Sejong'],
    '경기도': ['경기', 'Gyeonggi-do', 'Gyeonggi'],
    '강원특별자치도': ['강원', '강원도', 'Gangwon-do', 'Gangwon'],
    '충청북도': ['충북', 'Chungcheongbuk-do', 'Chungbuk'],
    '충청남도': ['충남', 'Chungcheongnam-do', 'Chungnam'],
    '전북특별자치도': ['전북', '전라북도', 'Jeollabuk-do', 'Jeonbuk'],
    '전라남도': ['전남', 'Jeollanam-do', 'Jeonnam'],
    '경상북도': ['경북', 'Gyeongsangbuk-do', 'Gyeongbuk'],
    '경상남도': ['경남', 'Gyeongsangnam-do', 'Gyeongnam'],
    '제주특별자치도': ['제주', '제주도', 'Jeju-do', 'Jeju'],
  };

  static ResolvedKoreanLocation? resolve({
    required String? administrativeArea,
    required String? subAdministrativeArea,
    required String? locality,
    required String? subLocality,
  }) {
    final fields = [
      administrativeArea,
      subAdministrativeArea,
      locality,
      subLocality,
    ].whereType<String>().map(_normalize).where((x) => x.isNotEmpty).toList();
    if (fields.isEmpty) return null;

    String? province;
    for (final entry in _provinceAliases.entries) {
      final names = [entry.key, ...entry.value].map(_normalize);
      if (fields.any((field) => names.any((name) => field.contains(name)))) {
        province = entry.key;
        break;
      }
    }
    if (province == null) return null;

    final regions = FarmLocationSettings.locations[province];
    if (regions == null) return null;
    FarmLocation? match;
    for (final region in regions) {
      final name = _normalize(region.cityCounty);
      if (fields.any((field) => field.contains(name))) {
        if (match != null) return null;
        match = region;
      }
    }
    if (match == null) return null;

    final town = (subLocality ?? '').trim();
    return ResolvedKoreanLocation(province, match.cityCounty, town);
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\\s._-]'), '');
}
