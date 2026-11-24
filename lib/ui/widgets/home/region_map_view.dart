import 'package:esme26/application/region_map_controller.dart';
import 'package:esme26/ui/widgets/home/region_map_canvas.dart';
import 'package:flutter/material.dart';

class RegionMapView extends StatelessWidget {
  final RegionMapController controller;

  const RegionMapView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => switch ((controller.status, controller.map)) {
          (RegionMapStatus.ready, final map?) => RegionMapCanvas(map: map),
          (RegionMapStatus.failed, _) => RegionMapLoadFailure(
            onRetry: controller.load,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class RegionMapLoadFailure extends StatelessWidget {
  final VoidCallback onRetry;

  const RegionMapLoadFailure({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 40),
            const SizedBox(height: 8),
            Text(
              'La carte n’a pas pu être chargée.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
