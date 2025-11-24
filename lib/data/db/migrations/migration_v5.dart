import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import 'migration.dart';

class MigrationV5 implements MigrationStep {
  @override
  int get version => 5;

  @override
  Future<void> up(Database db) async {
    // 添加 group_code 字段到 t_user 表
    await db.execute('''
      ALTER TABLE t_user ADD COLUMN group_code TEXT NOT NULL DEFAULT ''
    ''');

    // 更新现有数据，将 group_code 设置为空字符串（因为字段是 NOT NULL）
    // 注意：由于使用了 DEFAULT ''，现有记录已经会有默认值
    // 但为了确保一致性，我们显式更新一次
    await db.update(
      't_user',
      {'group_code': ''},
      where: 'group_code IS NULL',
    );

    debugPrint('MigrationV5().up()==> Added group_code field to t_user table');
  }

  @override
  Future<void> down(Database db) async {
    // SQLite 不支持 DROP COLUMN，所以这里省略了回滚操作
    // 在生产环境中，如果需要回滚，需要重新创建表
    debugPrint('MigrationV5().down()==> Cannot drop columns in SQLite, manual intervention required');
  }
}

