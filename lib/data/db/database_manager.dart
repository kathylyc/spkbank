import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations/migration.dart';
import 'migrations/migration_v1.dart';
import 'migrations/migration_v2.dart';
import 'migrations/migration_v3.dart';
import 'migrations/migration_v4.dart';
import 'migrations/migration_v5.dart';

class DatabaseManager {
  DatabaseManager._internal();

  static final DatabaseManager instance = DatabaseManager._internal();

  static const String _dbName = 'spdbank.db';

  /// 如果增加新的迁移，请在这里补充，并确保按版本升序排列。
  final List<MigrationStep> _migrations = [
    MigrationV1(),
    MigrationV2(),
    MigrationV3(),
    MigrationV4(),
    MigrationV5(),
  ];

  Database? _database;

  int get schemaVersion => _migrations.fold<int>(
        0,
        (previousValue, element) => element.version > previousValue ? element.version : previousValue,
      );

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await _resolveDbPath();
    _database = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
    return _database!;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<String> _resolveDbPath() async {
    final basePath = await getDatabasesPath();
    return p.join(basePath, _dbName);
  }

  FutureOr<void> _onConfigure(Database db) async {
    // 强制开启外键约束，确保引用完整性。
    await db.execute('PRAGMA foreign_keys = ON');
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await _runMigrations(db, 0, version);
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _runMigrations(db, oldVersion, newVersion);
  }

  FutureOr<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    // 默认策略是不允许降级，直接抛异常，提醒开发者显式处理。
    throw UnsupportedError('不支持数据库降级：$oldVersion -> $newVersion');
  }

  Future<void> _runMigrations(Database db, int from, int to) async {
    final pending = _migrations.where((step) => step.version > from && step.version <= to).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    for (final migration in pending) {
      await migration.up(db);
    }
  }
}

