import 'package:esme26/domain/models/geo_point.dart';

/// Road importance, from the busiest roads to the most local ones.
enum RoadClass { motorway, trunk, primary, secondary, tertiary }

enum PlaceKind { city, town }

class MapRoad {
  final RoadClass roadClass;
  final List<GeoPoint> points;

  const MapRoad({required this.roadClass, required this.points});
}

class MapPlace {
  final String name;
  final PlaceKind kind;
  final GeoPoint position;

  const MapPlace({
    required this.name,
    required this.kind,
    required this.position,
  });
}

/// Minimal offline map of a region: main roads, rivers, outline and towns.
class RegionMap {
  final String name;

  /// Credit for the map data, to display next to the map.
  final String attribution;
  final GeoPoint southWest;
  final GeoPoint northEast;
  final List<MapRoad> roads;
  final List<List<GeoPoint>> rivers;
  final List<List<GeoPoint>> boundary;
  final List<MapPlace> places;

  const RegionMap({
    required this.name,
    required this.attribution,
    required this.southWest,
    required this.northEast,
    required this.roads,
    required this.rivers,
    required this.boundary,
    required this.places,
  });
}
