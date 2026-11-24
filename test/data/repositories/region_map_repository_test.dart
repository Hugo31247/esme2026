import 'dart:convert';

import 'package:esme26/data/maps/region_map_codec.dart';
import 'package:esme26/data/repositories/region_map_repository.dart';
import 'package:esme26/data/repositories/region_map_repository_impl.dart';
import 'package:esme26/domain/models/region_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBundle extends AssetBundle {
  String source;
  bool fail = false;
  int loads = 0;

  _FakeBundle(this.source);

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads++;
    if (fail) throw FlutterError('Unable to load asset: "$key".');
    return source;
  }
}

String _encode(Map<String, Object?> overrides) => jsonEncode({
  'version': 1,
  'name': 'Test',
  'attribution': 'OpenStreetMap contributors',
  'precision': 5,
  'bounds': [1.4, 48.1, 3.6, 49.3],
  'roads': {
    'motorway': [
      [235220, 4885660, 100, -50, 20, 30],
    ],
    'footway': [
      [235220, 4885660, 1, 1],
    ],
  },
  'rivers': [
    [230000, 4884000, 500, 500],
  ],
  'boundary': [],
  'places': [
    ['Paris', 'city', 235220, 4885660],
    ['Hameau', 'hamlet', 235220, 4885660],
  ],
  ...overrides,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegionMapCodec', () {
    test('decodes delta-encoded lines, places and bounds', () {
      final map = RegionMapCodec.decode(_encode({}));

      expect(map.name, 'Test');
      expect(map.attribution, 'OpenStreetMap contributors');
      expect(map.southWest.latitude, 48.1);
      expect(map.northEast.longitude, 3.6);

      final road = map.roads.single;
      expect(road.roadClass, RoadClass.motorway);
      expect(road.points.map((p) => (p.longitude, p.latitude)), [
        (2.3522, 48.8566),
        (2.3532, 48.8561),
        (2.3534, 48.8564),
      ]);
      expect(map.rivers.single, hasLength(2));
      expect(map.boundary, isEmpty);

      final place = map.places.single;
      expect(place.name, 'Paris');
      expect(place.kind, PlaceKind.city);
      expect(place.position.latitude, 48.8566);
    });

    test('rejects an unknown format version', () {
      expect(
        () => RegionMapCodec.decode(_encode({'version': 2})),
        throwsFormatException,
      );
      expect(() => RegionMapCodec.decode('[]'), throwsFormatException);
    });
  });

  group('RegionMapRepositoryImpl', () {
    test('loads the asset once and retries after a failure', () async {
      final bundle = _FakeBundle(_encode({}))..fail = true;
      final repository = RegionMapRepositoryImpl(bundle: bundle);

      await expectLater(repository.load(), throwsA(isA<FlutterError>()));
      bundle.fail = false;
      final first = await repository.load();
      final second = await repository.load();

      expect(second, same(first));
      expect(bundle.loads, 2);
    });

    test('the facade exposes a singleton', () {
      expect(RegionMapRepository.instance, same(RegionMapRepository.instance));
      expect(RegionMapRepository.instance, isA<RegionMapRepositoryImpl>());
    });

    test('the bundled Ile-de-France map has roads around Paris', () async {
      final map = await RegionMapRepositoryImpl().load();

      for (final roadClass in RoadClass.values) {
        expect(
          map.roads.where((road) => road.roadClass == roadClass),
          isNotEmpty,
          reason: '$roadClass roads',
        );
      }
      expect(map.rivers, isNotEmpty);
      expect(map.boundary, isNotEmpty);
      final paris = map.places.firstWhere((place) => place.name == 'Paris');
      expect(paris.kind, PlaceKind.city);
      expect(paris.position.latitude, closeTo(48.86, 0.05));
      expect(paris.position.longitude, closeTo(2.35, 0.05));
      expect(map.southWest.latitude, lessThan(paris.position.latitude));
      expect(map.northEast.latitude, greaterThan(paris.position.latitude));
      expect(map.attribution, contains('OpenStreetMap'));
    });
  });
}
