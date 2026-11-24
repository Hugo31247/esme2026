import 'package:esme26/data/repositories/region_map_repository_impl.dart';
import 'package:esme26/domain/repositories/region_map_repository.dart'
    as domain;

abstract class RegionMapRepository implements domain.RegionMapRepository {
  static final RegionMapRepository instance = RegionMapRepositoryImpl();
}
