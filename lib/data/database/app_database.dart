import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:esme26/domain/models/user.dart';

part 'app_database.g.dart';

class UserRolesConverter extends TypeConverter<Set<UserRole>, String> {
  const UserRolesConverter();

  @override
  Set<UserRole> fromSql(String fromDb) => {
    for (final name in fromDb.split(',')) UserRole.values.byName(name),
  };

  @override
  String toSql(Set<UserRole> value) => value.map((role) => role.name).join(',');
}

// Avoids clashing with the domain `User` model.
@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get email => text()();
  IntColumn get birthDateInMillisFromEpoch => integer()();
  TextColumn get street => text()();
  TextColumn get city => text()();
  TextColumn get postalCode => text()();
  TextColumn get country => text()();
  TextColumn get complement => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get roles => text().map(const UserRolesConverter())();
  TextColumn get status => textEnum<AccountStatus>()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.open()
    : super(
        driftDatabase(
          name: 'esme26',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 1;
}
