import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import 'migration.dart';

class MigrationV4 implements MigrationStep {
  @override
  int get version => 4;

  @override
  Future<void> up(Database db) async {
    // 添加 company 字段到 t_customer 表
    await db.execute('''
      ALTER TABLE t_customer ADD COLUMN company TEXT NOT NULL DEFAULT ''
    ''');

    // 更新现有数据，将 company 设置为空字符串（因为字段是 NOT NULL）
    // 注意：由于使用了 DEFAULT ''，现有记录已经会有默认值
    // 但为了确保一致性，我们显式更新一次
    await db.update(
      't_customer',
      {'company': ''},
      where: 'company IS NULL',
    );

    debugPrint('MigrationV4().up()==> Added company field to t_customer table');
  }

  @override
  Future<void> down(Database db) async {
    // SQLite 不支持 DROP COLUMN，所以这里省略了回滚操作
    // 在生产环境中，如果需要回滚，需要重新创建表
    debugPrint('MigrationV4().down()==> Cannot drop columns in SQLite, manual intervention required');
  }
}

