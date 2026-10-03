import 'package:flutter_test/flutter_test.dart';
import 'package:dondonhae/services/korean_location_resolver.dart';

void main() {
  group('KoreanLocationResolver', () {
    test('explicit province wins over romanized Gwangju city name', () {
      final result = KoreanLocationResolver.resolve(
        administrativeArea: 'Gyeonggi-do',
        subAdministrativeArea: '광주시',
        locality: 'Gwangju',
        subLocality: '경안동',
      );
      expect(result?.province, '경기도');
      expect(result?.cityCounty, '광주시');
    });
    test('resolves Korean province and municipality names', () {
      final result = KoreanLocationResolver.resolve(
        administrativeArea: '충청남도',
        subAdministrativeArea: '천안시 동남구',
        locality: '천안시',
        subLocality: '신방동',
      );

      expect(result?.province, '충청남도');
      expect(result?.cityCounty, '천안시');
      expect(result?.town, '신방동');
    });

    test('normalizes romanized province names when city name is Korean', () {
      final result = KoreanLocationResolver.resolve(
        administrativeArea: 'Gyeongsangbuk-do',
        subAdministrativeArea: '문경시',
        locality: '문경시',
        subLocality: '점촌동',
      );

      expect(result?.province, '경상북도');
      expect(result?.cityCounty, '문경시');
    });

    test('distinguishes Gwangju city in Gyeonggi from Gwangju metro', () {
      final result = KoreanLocationResolver.resolve(
        administrativeArea: '경기도',
        subAdministrativeArea: '광주시',
        locality: '광주시',
        subLocality: '경안동',
      );

      expect(result?.province, '경기도');
      expect(result?.cityCounty, '광주시');
    });

    test('does not invent a region when reverse geocoding is ambiguous', () {
      final result = KoreanLocationResolver.resolve(
        administrativeArea: '충청남도',
        subAdministrativeArea: 'Unknown locality',
        locality: 'Unknown locality',
        subLocality: null,
      );

      expect(result, isNull);
    });

    test('does not guess a municipality from a saved region', () {
      final result = KoreanLocationResolver.resolve(
        administrativeArea: null,
        subAdministrativeArea: null,
        locality: null,
        subLocality: null,
      );

      expect(result, isNull);
    });
  });
}
