import 'dart:async';

import 'package:esme26/application/region_map_controller.dart';
import 'package:esme26/domain/models/geo_point.dart';
import 'package:esme26/domain/models/region_map.dart';
import 'package:esme26/domain/repositories/region_map_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledRegionMapRepository implements RegionMapRepository {
  final requests = <Completer<RegionMap>>[];

  @override
  Future<RegionMap> load() {
    final request = Completer<RegionMap>();
    requests.add(request);
    return request.future;
  }
}

final _map = RegionMap(
  name: 'Test',
  attribution: 'OpenStreetMap contributors',
  southWest: GeoPoint(latitude: 48.1, longitude: 1.4),
  northEast: GeoPoint(latitude: 49.3, longitude: 3.6),
  roads: const [],
  rivers: const [],
  boundary: const [],
  places: const [],
);

void main() {
  late _ControlledRegionMapRepository repository;
  late RegionMapController controller;

  setUp(() {
    repository = _ControlledRegionMapRepository();
    controller = RegionMapController(repository: repository);
  });

  tearDown(() => controller.dispose());

  test('starts loading and exposes the map once ready', () async {
    expect(controller.status, RegionMapStatus.loading);
    final loading = controller.load();
    repository.requests.single.complete(_map);
    await loading;

    expect(controller.status, RegionMapStatus.ready);
    expect(controller.map, same(_map));
  });

  test('reports a failure and can retry', () async {
    final failing = controller.load();
    repository.requests.single.completeError(const FormatException('bad'));
    await failing;
    expect(controller.status, RegionMapStatus.failed);
    expect(controller.map, isNull);

    final retry = controller.load();
    expect(controller.status, RegionMapStatus.loading);
    repository.requests.last.complete(_map);
    await retry;
    expect(controller.status, RegionMapStatus.ready);
  });

  test('ignores a stale request and results after dispose', () async {
    final stale = controller.load();
    final latest = controller.load();
    repository.requests.last.complete(_map);
    await latest;
    repository.requests.first.completeError(StateError('stale'));
    await stale;
    expect(controller.status, RegionMapStatus.ready);

    final disposed = RegionMapController(repository: repository);
    final pending = disposed.load();
    disposed.dispose();
    repository.requests.last.complete(_map);
    await expectLater(pending, completes);
  });
}
