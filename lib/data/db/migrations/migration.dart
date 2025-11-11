import 'package:sqflite/sqflite.dart';

/// 单个数据库迁移步骤的抽象。
/// [version] 表示迁移要到达的目标版本（含）。
/// 所有迁移按版本升序执行。
abstract interface class MigrationStep {
  int get version;

  Future<void> up(Database db);
}

/// 辅助工具：批量执行 SQL 语句，便于保持迁移代码整洁。
Future<void> runBatch(Database db, List<String> statements) async {
  final batch = db.batch();
  for (final statement in statements) {
    batch.execute(statement);
  }
  await batch.commit(noResult: true);
}

