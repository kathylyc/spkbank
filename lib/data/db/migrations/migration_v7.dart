import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import 'migration.dart';

class MigrationV7 implements MigrationStep {
  @override
  int get version => 7;

  @override
  Future<void> up(Database db) async {
    // SQLite 不支持直接修改列类型，需要重建表
    // 同时添加 enable_status 字段并修改 sign_status 字段类型
    // 1. 创建新表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS t_customer_account_file_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_file_uid TEXT NOT NULL,
        customer_uid TEXT NOT NULL,
        account_file_name TEXT NOT NULL,
        file_version TEXT,
        file_path TEXT NOT NULL,
        sign_status INTEGER DEFAULT 0,
        file_src_type TEXT,
        template_name TEXT,
        template_sign_code TEXT,
        enable_status INTEGER DEFAULT 0,
        create_by TEXT,
        create_time TEXT,
        update_by TEXT,
        update_time TEXT,
        FOREIGN KEY(customer_uid) REFERENCES t_customer(customer_uid) ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    // 2. 复制数据，将 sign_status 从 TEXT 转换为 INTEGER
    // 转换规则：'已签署' 或 '1' -> 1, '未签署' 或 '2' -> 2, 其他或空 -> 0
    await db.execute('''
      INSERT INTO t_customer_account_file_new (
        id, account_file_uid, customer_uid, account_file_name, file_version,
        file_path, sign_status, file_src_type, template_name, template_sign_code,
        enable_status, create_by, create_time, update_by, update_time
      )
      SELECT 
        id, account_file_uid, customer_uid, account_file_name, file_version,
        file_path,
        CASE 
          WHEN sign_status = '已签署' OR sign_status = '1' THEN 1
          WHEN sign_status = '未签署' OR sign_status = '2' THEN 2
          ELSE 0
        END AS sign_status,
        file_src_type, template_name, template_sign_code,
        0 AS enable_status,
        create_by, create_time, update_by, update_time
      FROM t_customer_account_file
    ''');

    // 3. 删除旧表
    await db.execute('DROP TABLE t_customer_account_file');

    // 4. 重命名新表
    await db.execute('ALTER TABLE t_customer_account_file_new RENAME TO t_customer_account_file');

    // 5. 重新创建索引（如果有）
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_account_file_uid ON t_customer_account_file(customer_uid)
    ''');

    debugPrint('MigrationV7().up()==> Added enable_status field and changed sign_status to INTEGER in t_customer_account_file table');
  }
}

