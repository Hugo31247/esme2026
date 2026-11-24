import 'package:esme26/data/maps/region_map_codec.dart';
import 'package:esme26/data/repositories/region_map_repository.dart';
import 'package:esme26/domain/models/region_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Offline map of Ile-de-France bundled as an asset.
///
/// Temporary free solution until the app uses a real map provider. The asset
/// is generated from OpenStreetMap by `tool/build_region_map.py`.
class RegionMapRepositoryImpl implements RegionMapRepository {
  static const assetPath = 'assets/maps/ile_de_france.json';

  final AssetBundle _bundle;
  Future<RegionMap>? _cached;

  RegionMapRepositoryImpl({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  @override
  Future<RegionMap> load() async {
    final future = _cached ??= _read();
    try {
      return await future;
    } catch (_) {
      if (identical(_cached, future)) _cached = null;
      rethrow;
    }
  }

  Future<RegionMap> _read() async {
    final source = await _bundle.loadString(assetPath, cache: false);
    return compute(RegionMapCodec.decode, source);
  }
}
