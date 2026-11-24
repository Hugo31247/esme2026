import 'package:esme26/domain/models/region_map.dart';
import 'package:esme26/domain/repositories/region_map_repository.dart';
import 'package:flutter/foundation.dart';

enum RegionMapStatus { loading, ready, failed }

class RegionMapController extends ChangeNotifier {
  final RegionMapRepository repository;
  RegionMapStatus _status = RegionMapStatus.loading;
  RegionMap? _map;
  int _request = 0;
  bool _disposed = false;

  RegionMapController({required this.repository});

  RegionMapStatus get status => _status;
  RegionMap? get map => _map;

  Future<void> load() async {
    final request = ++_request;
    _status = RegionMapStatus.loading;
    notifyListeners();
    try {
      final map = await repository.load();
      if (_disposed || request != _request) return;
      _map = map;
      _status = RegionMapStatus.ready;
    } catch (error) {
      if (_disposed || request != _request) return;
      debugPrint('Region map failed to load: $error');
      _status = RegionMapStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
