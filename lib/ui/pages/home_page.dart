import 'dart:async';

import 'package:esme26/application/region_map_controller.dart';
import 'package:esme26/data/repositories/region_map_repository.dart' as data;
import 'package:esme26/domain/models/user.dart';
import 'package:esme26/domain/repositories/region_map_repository.dart';
import 'package:esme26/ui/widgets/home/region_map_view.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  final UserRole role;
  final String firstName;
  final RegionMapRepository? regionMapRepository;

  const HomePage({
    super.key,
    required this.role,
    required this.firstName,
    this.regionMapRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final RegionMapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = RegionMapController(
      repository:
          widget.regionMapRepository ?? data.RegionMapRepository.instance,
    );
    unawaited(_mapController.load());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = widget.role;
    final firstName = widget.firstName.trim();
    final welcome = firstName.isEmpty
        ? 'Bienvenue dans votre espace ${role == UserRole.artisan ? 'artisan' : 'particulier'} !'
        : 'Bienvenue $firstName !';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                role == UserRole.artisan
                    ? Icons.handyman_outlined
                    : Icons.home_outlined,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(welcome, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Votre parcours de découverte est terminé.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RegionMapView(controller: _mapController),
            ),
          ),
        ],
      ),
    );
  }
}
