import 'package:esme26/domain/models/geo_point.dart';
import 'package:esme26/domain/models/region_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Draws an offline [RegionMap] (roads, rivers, outline, towns) with
/// flutter_map, without any tile server.
///
/// Layer widgets are only recreated when this widget rebuilds (theme change),
/// not on camera moves: flutter_map re-projects every polyline whenever a
/// PolylineLayer widget is replaced.
class RegionMapCanvas extends StatefulWidget {
  static const initialCenter = LatLng(48.8566, 2.3522);
  static const initialZoom = 11.0;
  static const minZoom = 8.0;
  static const maxZoom = 16.0;

  final RegionMap map;

  const RegionMapCanvas({super.key, required this.map});

  @override
  State<RegionMapCanvas> createState() => _RegionMapCanvasState();
}

class _RegionMapCanvasState extends State<RegionMapCanvas> {
  late _MapGeometry _geometry;

  @override
  void initState() {
    super.initState();
    _geometry = _MapGeometry(widget.map);
  }

  @override
  void didUpdateWidget(RegionMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.map, widget.map)) {
      _geometry = _MapGeometry(widget.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? RegionMapPalette.dark
        : RegionMapPalette.light;
    final roads = _geometry.roads;

    return FlutterMap(
      options: MapOptions(
        initialCenter: RegionMapCanvas.initialCenter,
        initialZoom: RegionMapCanvas.initialZoom,
        minZoom: RegionMapCanvas.minZoom,
        maxZoom: RegionMapCanvas.maxZoom,
        backgroundColor: palette.background,
        cameraConstraint: CameraConstraint.containCenter(
          bounds: _geometry.bounds,
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        RegionMapLines(
          lines: _geometry.boundary,
          color: palette.boundary,
          width: 1.5,
        ),
        RegionMapLines(
          lines: _geometry.rivers,
          color: palette.water,
          width: 2.5,
        ),
        RegionMapZoomGate(
          minZoom: 12.5,
          child: RegionMapLines(
            lines: roads[RoadClass.tertiary] ?? const [],
            color: palette.tertiary,
            width: 1.2,
          ),
        ),
        RegionMapZoomGate(
          minZoom: 11,
          child: RegionMapLines(
            lines: roads[RoadClass.secondary] ?? const [],
            color: palette.secondary,
            width: 1.6,
          ),
        ),
        RegionMapZoomGate(
          minZoom: 9,
          child: RegionMapLines(
            lines: roads[RoadClass.primary] ?? const [],
            color: palette.primary,
            width: 2.2,
          ),
        ),
        RegionMapLines(
          lines: roads[RoadClass.trunk] ?? const [],
          color: palette.trunk,
          width: 2.8,
        ),
        RegionMapLines(
          lines: roads[RoadClass.motorway] ?? const [],
          color: palette.motorway,
          width: 3.4,
        ),
        RegionMapZoomGate(
          minZoom: 12,
          child: RegionMapPlaces(
            places: widget.map.places,
            kind: PlaceKind.town,
            palette: palette,
          ),
        ),
        RegionMapPlaces(
          places: widget.map.places,
          kind: PlaceKind.city,
          palette: palette,
        ),
        RegionMapAttribution(
          attribution: widget.map.attribution,
          palette: palette,
        ),
      ],
    );
  }
}

class RegionMapLines extends StatelessWidget {
  final List<List<LatLng>> lines;
  final Color color;
  final double width;

  const RegionMapLines({
    super.key,
    required this.lines,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return PolylineLayer(
      polylines: [
        for (final points in lines)
          Polyline(points: points, color: color, strokeWidth: width),
      ],
    );
  }
}

/// Data credit required by the OpenStreetMap licence (ODbL).
class RegionMapAttribution extends StatelessWidget {
  final String attribution;
  final RegionMapPalette palette;

  const RegionMapAttribution({
    super.key,
    required this.attribution,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: ColoredBox(
        color: palette.background.withValues(alpha: 0.85),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            '© $attribution',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.label),
          ),
        ),
      ),
    );
  }
}

/// Shows [child] only from [minZoom], to keep the map readable and fast.
class RegionMapZoomGate extends StatelessWidget {
  final double minZoom;
  final Widget child;

  const RegionMapZoomGate({
    super.key,
    required this.minZoom,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      MapCamera.of(context).zoom >= minZoom ? child : const SizedBox.shrink();
}

class RegionMapPlaces extends StatelessWidget {
  final List<MapPlace> places;
  final PlaceKind kind;
  final RegionMapPalette palette;

  const RegionMapPlaces({
    super.key,
    required this.places,
    required this.kind,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        for (final place in places)
          if (place.kind == kind)
            Marker(
              point: _latLng(place.position),
              width: 160,
              height: 24,
              child: RegionMapPlaceLabel(
                name: place.name,
                isCity: kind == PlaceKind.city,
                palette: palette,
              ),
            ),
      ],
    );
  }
}

class RegionMapPlaceLabel extends StatelessWidget {
  final String name;
  final bool isCity;
  final RegionMapPalette palette;

  const RegionMapPlaceLabel({
    super.key,
    required this.name,
    required this.isCity,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = isCity ? textTheme.titleSmall : textTheme.labelSmall;
    return Center(
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        textAlign: TextAlign.center,
        style: style?.copyWith(
          color: palette.label,
          fontWeight: isCity ? FontWeight.w700 : FontWeight.w500,
          shadows: [
            for (final blur in const [2.0, 4.0])
              Shadow(color: palette.background, blurRadius: blur),
          ],
        ),
      ),
    );
  }
}

class RegionMapPalette {
  final Color background;
  final Color water;
  final Color boundary;
  final Color motorway;
  final Color trunk;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color label;

  const RegionMapPalette({
    required this.background,
    required this.water,
    required this.boundary,
    required this.motorway,
    required this.trunk,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.label,
  });

  static const light = RegionMapPalette(
    background: Color(0xFFF2EFE9),
    water: Color(0xFF8EC3DE),
    boundary: Color(0xFFA48FC9),
    motorway: Color(0xFFE0654A),
    trunk: Color(0xFFEE8A57),
    primary: Color(0xFFEBAA3A),
    secondary: Color(0xFFB3AA98),
    tertiary: Color(0xFFCBC3B3),
    label: Color(0xFF333333),
  );

  static const dark = RegionMapPalette(
    background: Color(0xFF1C1F22),
    water: Color(0xFF2D5670),
    boundary: Color(0xFF7D6AA6),
    motorway: Color(0xFFD9694A),
    trunk: Color(0xFFC77B4C),
    primary: Color(0xFFB38B3C),
    secondary: Color(0xFF746D5F),
    tertiary: Color(0xFF514D45),
    label: Color(0xFFE6E1D8),
  );
}

LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);

/// [RegionMap] converted once to flutter_map coordinates.
class _MapGeometry {
  final LatLngBounds bounds;
  final Map<RoadClass, List<List<LatLng>>> roads = {};
  final List<List<LatLng>> rivers;
  final List<List<LatLng>> boundary;

  _MapGeometry(RegionMap map)
    : bounds = LatLngBounds(_latLng(map.southWest), _latLng(map.northEast)),
      rivers = [for (final line in map.rivers) _toLatLngs(line)],
      boundary = [for (final line in map.boundary) _toLatLngs(line)] {
    for (final road in map.roads) {
      (roads[road.roadClass] ??= []).add(_toLatLngs(road.points));
    }
  }

  static List<LatLng> _toLatLngs(List<GeoPoint> points) => [
    for (final point in points) _latLng(point),
  ];
}
