import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:esme26/data/database/app_database.dart';
import 'package:esme26/data/repositories/drift_user_repository.dart';
import 'package:esme26/data/shared_preferences/shared_preference_keys.dart';
import 'package:esme26/domain/models/adress.dart';
import 'package:esme26/domain/models/geo_point.dart';
import 'package:esme26/domain/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase database;
  late SharedPreferences preferences;

  final user = User(
    id: 'user-42',
    firstName: 'Camille',
    lastName: 'Martin',
    email: 'camille@example.test',
    birthDateInMillisFromEpoch: DateTime.utc(
      1990,
      4,
      12,
    ).millisecondsSinceEpoch,
    adress: Adress(
      street: '1 rue de Rivoli',
      city: 'Paris',
      postalCode: '75001',
      country: 'France',
      complement: 'Bâtiment B',
      location: GeoPoint(latitude: 48.86, longitude: 2.34),
    ),
    phoneNumber: '+33600000000',
    avatarUrl: Uri.parse('https://example.test/avatar.png'),
    roles: {UserRole.customer, UserRole.artisan},
    status: AccountStatus.suspended,
    createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
  );

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<DriftUserRepository> reopen() =>
      DriftUserRepository.open(database: database, preferences: preferences);

  test('starts empty without a current user', () async {
    final repository = await reopen();

    expect(repository.getAll(), isEmpty);
    expect(repository.me(), isNull);
  });

  test(
    'setUser persists the user in Drift and its id in SharedPreferences',
    () async {
      final repository = await reopen();

      repository.setUser(user);
      expect(repository.me(), same(user));
      await repository.flush();

      expect(preferences.getString(myUserId), 'user-42');
      final restored = (await reopen()).me()!;
      expect(restored.id, 'user-42');
      expect(restored.firstName, 'Camille');
      expect(restored.lastName, 'Martin');
      expect(restored.email, 'camille@example.test');
      expect(
        restored.birthDateInMillisFromEpoch,
        user.birthDateInMillisFromEpoch,
      );
      expect(restored.adress.street, '1 rue de Rivoli');
      expect(restored.adress.city, 'Paris');
      expect(restored.adress.postalCode, '75001');
      expect(restored.adress.country, 'France');
      expect(restored.adress.complement, 'Bâtiment B');
      expect(restored.adress.location?.latitude, 48.86);
      expect(restored.adress.location?.longitude, 2.34);
      expect(restored.phoneNumber, '+33600000000');
      expect(restored.avatarUrl, Uri.parse('https://example.test/avatar.png'));
      expect(restored.roles, {UserRole.customer, UserRole.artisan});
      expect(restored.status, AccountStatus.suspended);
      expect(restored.createdAt!.isAtSameMomentAs(user.createdAt!), isTrue);
    },
  );

  test('save upserts without changing the current user', () async {
    final repository = await reopen();
    repository.save(user);
    await repository.flush();

    expect(preferences.getString(myUserId), isNull);
    final reopened = await reopen();
    expect(reopened.me(), isNull);
    expect(reopened.getById('user-42')?.firstName, 'Camille');
  });

  test('saving the current user refreshes me()', () async {
    final repository = await reopen();
    repository.setUser(user);
    final renamed = User(
      id: user.id,
      firstName: 'Camila',
      lastName: user.lastName,
      email: user.email,
      birthDateInMillisFromEpoch: user.birthDateInMillisFromEpoch,
      adress: user.adress,
    );

    repository.save(renamed);
    expect(repository.me(), same(renamed));
    await repository.flush();

    expect((await reopen()).me()?.firstName, 'Camila');
  });

  test(
    'deleting the current user clears Drift and SharedPreferences',
    () async {
      final repository = await reopen();
      repository.setUser(user);
      repository.delete('user-42');

      expect(repository.me(), isNull);
      expect(() => repository.delete('user-42'), throwsStateError);
      await repository.flush();

      expect(preferences.getString(myUserId), isNull);
      expect((await reopen()).getAll(), isEmpty);
    },
  );

  test('a draft current user is not stored and clears the stored id', () async {
    final repository = await reopen();
    repository.setUser(user);
    final draft = User(
      firstName: 'Draft',
      lastName: 'User',
      email: 'draft@example.test',
      birthDateInMillisFromEpoch: 0,
      adress: user.adress,
    );

    repository.setUser(draft);
    expect(repository.me(), same(draft));
    await repository.flush();

    expect(preferences.getString(myUserId), isNull);
    expect((await reopen()).getAll().map((u) => u.id), ['user-42']);
  });

  test('rejects blank ids', () async {
    final repository = await reopen();
    final invalid = User(
      id: ' ',
      firstName: 'Invalid',
      lastName: 'User',
      email: 'invalid@example.test',
      birthDateInMillisFromEpoch: 0,
      adress: user.adress,
    );

    expect(() => repository.setUser(invalid), throwsArgumentError);
    expect(repository.me(), isNull);
  });

  test('a stale stored id is removed on open', () async {
    await preferences.setString(myUserId, 'missing');

    final repository = await reopen();

    expect(repository.me(), isNull);
    expect(preferences.getString(myUserId), isNull);
  });
}
