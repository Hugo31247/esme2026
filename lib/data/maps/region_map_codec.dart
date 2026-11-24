import 'dart:convert';
import 'dart:math' as math;

import 'package:esme26/domain/models/geo_point.dart';
import 'package:esme26/domain/models/region_map.dart';

/// Decodes the compact map format written by `tool/build_region_map.py`.
///
/// Coordinates are integers scaled by `10^precision`. Each line stores its
/// first point as an absolute `x, y` pair, then deltas from the previous one.
abstract final class RegionMapCodec {
  static const supportedVersion = 1;

  static RegionMap decode(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> || json['version'] != supportedVersion) {
      throw const FormatException('Unsupported region map format.');
    }
    final scale = math.pow(10, json['precision'] as int).toDouble();

    GeoPoint point(int x, int y) =>
        GeoPoint(latitude: y / scale, longitude: x / scale);

    List<GeoPoint> line(dynamic encoded) {
      final values = encoded as List<dynamic>;
      final points = <GeoPoint>[];
      var x = 0;
      var y = 0;
      for (var i = 0; i + 1 < values.length; i += 2) {
        x += values[i] as int;
        y += values[i + 1] as int;
        points.add(point(x, y));
      }
      return points;
    }

    List<List<GeoPoint>> lines(dynamic encoded) => [
      for (final value in (encoded as List<dynamic>? ?? const [])) line(value),
    ];

    final roadClasses = RoadClass.values.asNameMap();
    final placeKinds = PlaceKind.values.asNameMap();
    final bounds = (json['bounds'] as List<dynamic>).cast<num>();

    return RegionMap(
      name: json['name'] as String,
      attribution: json['attribution'] as String,
      southWest: GeoPoint(
        latitude: bounds[1].toDouble(),
        longitude: bounds[0].toDouble(),
      ),
      northEast: GeoPoint(
        latitude: bounds[3].toDouble(),
        longitude: bounds[2].toDouble(),
      ),
      roads: [
        for (final MapEntry(:key, :value)
            in (json['roads'] as Map<String, dynamic>).entries)
          if (roadClasses[key] case final roadClass?)
            for (final points in lines(value))
              MapRoad(roadClass: roadClass, points: points),
      ],
      rivers: lines(json['rivers']),
      boundary: lines(json['boundary']),
      places: [
        for (final place in (json['places'] as List<dynamic>? ?? const []))
          if (placeKinds[(place as List<dynamic>)[1]] case final kind?)
            MapPlace(
              name: place[0] as String,
              kind: kind,
              position: point(place[2] as int, place[3] as int),
            ),
      ],
    );
  }
}
