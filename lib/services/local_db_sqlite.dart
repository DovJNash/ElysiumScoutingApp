import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config/supabase_config.dart';
import 'local_db_service.dart';

/// SQLite offline store (Android, iOS, macOS).
class SqliteLocalDb extends LocalDbService {
  Database? _db;

  static String _name(LocalTable t) =>
      t == LocalTable.scouting ? 'scouting_local' : 'super_scouting_local';

  @override
  Future<void> initialize() async {
    if (_db != null) return;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'frc_scouting_${SupabaseConfig.projectRef}.db');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scouting_local (
            ID TEXT PRIMARY KEY,
            uniqueKey TEXT UNIQUE NOT NULL,
            competition TEXT NOT NULL,
            scouterId TEXT NOT NULL,
            scouterName TEXT NOT NULL,
            teamNum INTEGER NOT NULL,
            matchNum INTEGER NOT NULL,
            matchLevel TEXT NOT NULL DEFAULT 'qm',
            matchSet INTEGER NOT NULL DEFAULT 1,
            startPos TEXT NOT NULL,
            exitPos TEXT NOT NULL,
            autoShoot INTEGER NOT NULL,
            autoIntake INTEGER NOT NULL,
            allianceCount INTEGER NOT NULL,
            neutralCount INTEGER NOT NULL,
            opponentCount INTEGER NOT NULL,
            teleopShoot INTEGER NOT NULL,
            teleopIntake INTEGER NOT NULL,
            robotShowed INTEGER NOT NULL DEFAULT 1,
            fuelCountsAreRanges INTEGER NOT NULL DEFAULT 0,
            autoCycles INTEGER NOT NULL DEFAULT 0,
            autoFuelsDelivered INTEGER NOT NULL DEFAULT 0,
            autoIntakeSpeed INTEGER NOT NULL DEFAULT 0,
            autoPerformance INTEGER NOT NULL DEFAULT 0,
            teleopCanShootMoving INTEGER NOT NULL DEFAULT 0,
            teleopCycles INTEGER NOT NULL DEFAULT 0,
            teleopFuelsDelivered INTEGER NOT NULL DEFAULT 0,
            teleopIntakeSpeed INTEGER NOT NULL DEFAULT 0,
            teleopAccuracy INTEGER NOT NULL DEFAULT 0,
            teleopPerformance INTEGER NOT NULL DEFAULT 0,
            playedDefense INTEGER NOT NULL DEFAULT 0,
            defenseRating INTEGER NOT NULL DEFAULT 0,
            dealtWithDefense INTEGER NOT NULL DEFAULT 0,
            defenseResilience INTEGER NOT NULL DEFAULT 0,
            climbed INTEGER NOT NULL DEFAULT 0,
            climbLevel TEXT NOT NULL DEFAULT '',
            climbTimeSeconds INTEGER NOT NULL DEFAULT 0,
            doingDefence INTEGER NOT NULL,
            standDefence INTEGER NOT NULL,
            driverSkill INTEGER NOT NULL,
            notes TEXT NOT NULL,
            durationSeconds INTEGER NOT NULL,
            createdAt TEXT NOT NULL,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE super_scouting_local (
            ID TEXT PRIMARY KEY,
            uniqueKey TEXT UNIQUE NOT NULL,
            competition TEXT NOT NULL,
            scouterId TEXT NOT NULL,
            scouterName TEXT NOT NULL,
            teamNum INTEGER NOT NULL,
            auto TEXT NOT NULL,
            autoExitPath TEXT NOT NULL DEFAULT '',
            bps TEXT NOT NULL,
            shootingLimits TEXT NOT NULL,
            missPercent TEXT NOT NULL,
            intakeSpeed TEXT NOT NULL,
            RobotCap TEXT NOT NULL,
            robotLimits TEXT NOT NULL,
            driverSkills TEXT NOT NULL,
            penalties TEXT NOT NULL,
            bumpSpeed TEXT NOT NULL,
            DriverTechnique TEXT NOT NULL,
            defenceStyle TEXT NOT NULL,
            shootingWhileMoving TEXT NOT NULL DEFAULT '',
            climbCapability TEXT NOT NULL DEFAULT '',
            durationSeconds INTEGER NOT NULL,
            createdAt TEXT NOT NULL,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_deletions (
            recordId TEXT PRIMARY KEY,
            tableName TEXT NOT NULL,
            requesterId TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          const scoutingColumns = {
            'matchLevel': "TEXT NOT NULL DEFAULT 'qm'",
            'matchSet': 'INTEGER NOT NULL DEFAULT 1',
            'robotShowed': 'INTEGER NOT NULL DEFAULT 1',
            'autoCycles': 'INTEGER NOT NULL DEFAULT 0',
            'autoFuelsDelivered': 'INTEGER NOT NULL DEFAULT 0',
            'autoIntakeSpeed': 'INTEGER NOT NULL DEFAULT 0',
            'autoPerformance': 'INTEGER NOT NULL DEFAULT 0',
            'teleopCanShootMoving': 'INTEGER NOT NULL DEFAULT 0',
            'teleopCycles': 'INTEGER NOT NULL DEFAULT 0',
            'teleopFuelsDelivered': 'INTEGER NOT NULL DEFAULT 0',
            'teleopIntakeSpeed': 'INTEGER NOT NULL DEFAULT 0',
            'teleopAccuracy': 'INTEGER NOT NULL DEFAULT 0',
            'teleopPerformance': 'INTEGER NOT NULL DEFAULT 0',
            'playedDefense': 'INTEGER NOT NULL DEFAULT 0',
            'defenseRating': 'INTEGER NOT NULL DEFAULT 0',
            'dealtWithDefense': 'INTEGER NOT NULL DEFAULT 0',
            'defenseResilience': 'INTEGER NOT NULL DEFAULT 0',
            'climbed': 'INTEGER NOT NULL DEFAULT 0',
            'climbLevel': "TEXT NOT NULL DEFAULT ''",
            'climbTimeSeconds': 'INTEGER NOT NULL DEFAULT 0',
          };
          for (final entry in scoutingColumns.entries) {
            await db.execute(
              'ALTER TABLE scouting_local ADD COLUMN ${entry.key} ${entry.value}',
            );
          }
          const superColumns = {
            'autoExitPath': "TEXT NOT NULL DEFAULT ''",
            'shootingWhileMoving': "TEXT NOT NULL DEFAULT ''",
            'climbCapability': "TEXT NOT NULL DEFAULT ''",
          };
          for (final entry in superColumns.entries) {
            await db.execute(
              'ALTER TABLE super_scouting_local ADD COLUMN ${entry.key} ${entry.value}',
            );
          }
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE scouting_local ADD COLUMN '
            'fuelCountsAreRanges INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  Database get _d {
    final d = _db;
    if (d == null) {
      throw StateError('LocalDbService.initialize() was not called.');
    }
    return d;
  }

  @override
  Future<void> putRow(LocalTable table, Map<String, dynamic> row) async {
    await _d.insert(
      _name(table),
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getRows(
    LocalTable table, {
    bool unsyncedOnly = false,
  }) async {
    final rows = await _d.query(
      _name(table),
      where: unsyncedOnly ? 'isSynced = 0' : null,
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<void> setSynced(LocalTable table, String id) async {
    await _d.update(
      _name(table),
      {'isSynced': 1},
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> removeRow(LocalTable table, String id) async {
    await _d.delete(_name(table), where: 'ID = ?', whereArgs: [id]);
  }

  @override
  Future<void> removeUserRecords(String userId) async {
    recordLocalWrite();
    await _d.transaction((txn) async {
      await txn.delete(
        'scouting_local',
        where: 'scouterId = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'super_scouting_local',
        where: 'scouterId = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'pending_deletions',
        where: 'requesterId = ?',
        whereArgs: [userId],
      );
    });
  }

  @override
  Future<bool> replaceSyncedRows(
    LocalTable table,
    List<Map<String, dynamic>> serverRows,
    int expectedVersion,
  ) {
    final name = _name(table);
    return _d.transaction<bool>((txn) async {
      if (writeVersion != expectedVersion) return false;

      final pending = (await txn.query(
        'pending_deletions',
        columns: ['recordId'],
      ))
          .map((e) => e['recordId'] as String)
          .toSet();
      final unsyncedKeys = (await txn.query(
        name,
        columns: ['uniqueKey'],
        where: 'isSynced = 0',
      ))
          .map((e) => e['uniqueKey'] as String)
          .toSet();
      final remoteIds = serverRows.map((r) => r['ID'].toString()).toSet();

      final synced = await txn.query(
        name,
        columns: ['ID'],
        where: 'isSynced = 1',
      );
      for (final s in synced) {
        final id = s['ID'] as String;
        if (!remoteIds.contains(id)) {
          await txn.delete(name, where: 'ID = ?', whereArgs: [id]);
        }
      }

      for (final r in serverRows) {
        final id = r['ID'].toString();
        if (id.isEmpty || pending.contains(id)) continue;
        if (unsyncedKeys.contains(r['uniqueKey'].toString())) continue;
        await txn.insert(name, r, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return true;
    });
  }

  @override
  Future<void> putDeletion({
    required String recordId,
    required String tableName,
    required String requesterId,
  }) async {
    await _d.insert(
        'pending_deletions',
        {
          'recordId': recordId,
          'tableName': tableName,
          'requesterId': requesterId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> getDeletions() async {
    final rows = await _d.query('pending_deletions');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<void> dropDeletion(String recordId) async {
    await _d.delete(
      'pending_deletions',
      where: 'recordId = ?',
      whereArgs: [recordId],
    );
  }
}
