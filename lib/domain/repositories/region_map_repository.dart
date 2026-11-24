import 'package:esme26/domain/models/region_map.dart';

abstract interface class RegionMapRepository {
  /// Loads the map of the region covered by the app.
  Future<RegionMap> load();
}
