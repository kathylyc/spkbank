import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import 'migration.dart';

class MigrationV6 implements MigrationStep {
  @override
  int get version => 6;

  @override
  Future<void> up(Database db) async {
    // 添加 template_sign_code 字段到 t_customer_account_file 表
    await db.execute('''
      ALTER TABLE t_customer_account_file ADD COLUMN template_sign_code TEXT
    ''');

    debugPrint('MigrationV6().up()==> Added template_sign_code field to t_customer_account_file table');
  }
}

