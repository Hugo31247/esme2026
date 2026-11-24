import 'package:drift/drift.dart';
import 'package:esme26/data/database/app_database.dart';
import 'package:esme26/data/repositories/in_memory_repository.dart';
import 'package:esme26/data/shared_preferences/shared_preference_keys.dart';
import 'package:esme26/domain/models/adress.dart';
import 'package:esme26/domain/models/geo_point.dart';
import 'package:esme26/domain/models/user.dart';
import 'package:esme26/domain/repositories/user_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Users are persisted in Drift and the current user id in SharedPreferences.
///
/// Reads are served synchronously from a cache loaded by [open]; writes update
/// the cache immediately and are persisted in order in the background.
/// Await [flush] to wait for pending writes.
class DriftUserRepository implements UserRepository {
  final AppDatabase _database;
  final SharedPreferences _preferences;
  final Map<String, User> _users;
  User? _me;
  Future<void> _pendingWrites = Future.value();

  DriftUserRepository._(
    this._database,
    this._preferences,
    this._users,
    this._me,
  );

  static Future<DriftUserRepository> open({
    required AppDatabase database,
    required SharedPreferences preferences,
  }) async {
    final rows = await database.select(database.users).get();
    final users = {for (final row in rows) row.id: _toDomain(row)};
    final storedId = preferences.getString(myUserId);
    final me = storedId == null ? null : users[storedId];
    if (storedId != null && me == null) {
      await preferences.remove(myUserId);
    }
    return DriftUserRepository._(database, preferences, users, me);
  }

  @override
  User? me() => _me;

  @override
  void setUser(User user) {
    if (user.id == null) {
      _me = user;
      _enqueue(() => _preferences.remove(myUserId));
      return;
    }
    save(user);
    _me = user;
    _enqueue(() => _preferences.setString(myUserId, user.id!));
  }

  @override
  List<User> getAll() => List.unmodifiable(_users.values);

  @override
  User? getById(String id) => _users[id];

  @override
  void save(User entity) {
    final id = requireRepositoryId(entity.id);
    _users[id] = entity;
    if (_me?.id == id) {
      _me = entity;
    }
    _enqueue(
      () => _database
          .into(_database.users)
          .insertOnConflictUpdate(_toCompanion(entity)),
    );
  }

  @override
  void delete(String id) {
    if (_users.remove(id) == null) {
      throw StateError('No entity with key: $id');
    }
    final wasMe = _me?.id == id;
    if (wasMe) {
      _me = null;
    }
    _enqueue(() async {
      await (_database.delete(
        _database.users,
      )..where((row) => row.id.equals(id))).go();
      if (wasMe) {
        await _preferences.remove(myUserId);
      }
    });
  }

  /// Completes once every write enqueued so far has been persisted.
  Future<void> flush() => _pendingWrites;

  Future<void> close() async {
    await flush();
    await _database.close();
  }

  void _enqueue(Future<void> Function() write) {
    _pendingWrites = _pendingWrites
        .then((_) => write())
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'user repository',
              ),
            );
          },
        );
  }

  static User _toDomain(UserRow row) {
    final latitude = row.latitude;
    final longitude = row.longitude;
    final avatarUrl = row.avatarUrl;
    return User(
      id: row.id,
      firstName: row.firstName,
      lastName: row.lastName,
      email: row.email,
      birthDateInMillisFromEpoch: row.birthDateInMillisFromEpoch,
      adress: Adress(
        street: row.street,
        city: row.city,
        postalCode: row.postalCode,
        country: row.country,
        complement: row.complement,
        location: latitude != null && longitude != null
            ? GeoPoint(latitude: latitude, longitude: longitude)
            : null,
      ),
      phoneNumber: row.phoneNumber,
      avatarUrl: avatarUrl == null ? null : Uri.parse(avatarUrl),
      roles: row.roles,
      status: row.status,
      createdAt: row.createdAt,
    );
  }

  static UsersCompanion _toCompanion(User user) => UsersCompanion.insert(
    id: user.id!,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    birthDateInMillisFromEpoch: user.birthDateInMillisFromEpoch,
    street: user.adress.street,
    city: user.adress.city,
    postalCode: user.adress.postalCode,
    country: user.adress.country,
    complement: Value(user.adress.complement),
    latitude: Value(user.adress.location?.latitude),
    longitude: Value(user.adress.location?.longitude),
    phoneNumber: Value(user.phoneNumber),
    avatarUrl: Value(user.avatarUrl?.toString()),
    roles: user.roles,
    status: user.status,
    createdAt: Value(user.createdAt),
  );
}
