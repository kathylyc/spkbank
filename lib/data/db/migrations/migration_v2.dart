import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import 'migration.dart';

class MigrationV2 implements MigrationStep {
  @override
  int get version => 2;

  @override
  Future<void> up(Database db) async {
    await runBatch(db, [
      '''
      ALTER TABLE t_user ADD COLUMN is_first_login INTEGER DEFAULT 1
      ''',
      '''
      ALTER TABLE t_user ADD COLUMN login_fail_count INTEGER DEFAULT 0
      ''',
      '''
      ALTER TABLE t_user ADD COLUMN lock_until TEXT
      ''',
    ]);

    // 更新现有用户数据，设置默认值
    await db.update(
      't_user',
      {
        'is_first_login': 1,
        'login_fail_count': 0,
      },
      where: 'is_first_login IS NULL',
    );

    debugPrint('MigrationV2().up()==> Added password security fields to t_user table');
  }

  @override
  Future<void> down(Database db) async {
    // SQLite 不支持 DROP COLUMN，所以这里省略了回滚操作
    // 在生产环境中，如果需要回滚，需要重新创建表
    debugPrint('MigrationV2().down()==> Cannot drop columns in SQLite, manual intervention required');
  }
}