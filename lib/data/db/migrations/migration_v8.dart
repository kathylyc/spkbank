import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import 'migration.dart';

class MigrationV8 implements MigrationStep {
  @override
  int get version => 8;

  @override
  Future<void> up(Database db) async {
    // SQLite 不支持直接修改列类型，需要重建表
    // 将 file_version 字段从 TEXT 改为 INTEGER

    // 1. 创建新表，file_version 字段改为 INTEGER 类型
    await db.execute('''
      CREATE TABLE IF NOT EXISTS t_customer_account_file_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_file_uid TEXT NOT NULL,
        customer_uid TEXT NOT NULL,
        account_file_name TEXT NOT NULL,
        file_version INTEGER,
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

    // 2. 复制数据，将 file_version 从 TEXT 转换为 INTEGER
    // 转换规则：
    // - 如果是纯数字字符串，直接转换为整数
    // - 如果是空值或null，保持为null
    // - 如果是无法转换的字符串，保持为null
    // - 使用 VersionUtils 来处理版本号转换（例如 "1.0.0" -> 10000）
    await db.execute('''
      INSERT INTO t_customer_account_file_new (
        id, account_file_uid, customer_uid, account_file_name, file_version,
        file_path, sign_status, file_src_type, template_name, template_sign_code,
        enable_status, create_by, create_time, update_by, update_time
      )
      SELECT
        id, account_file_uid, customer_uid, account_file_name,
        CASE
          WHEN file_version IS NULL OR file_version = '' THEN NULL
          WHEN file_version GLOB '*[0-9]*' AND file_version NOT GLOB '*[a-zA-Z]*' THEN CAST(file_version AS INTEGER)
          WHEN file_version LIKE '%.%.%' THEN
            CASE
              -- 尝试将 x.y.z 格式转换为整数: major*10000 + middle*100 + minor
              WHEN length(file_version) - length(replace(file_version, '.', '')) = 2 THEN
                CASE
                  WHEN substr(file_version, 1, instr(file_version, '.') - 1) GLOB '[0-9]*' AND
                       substr(file_version, instr(file_version, '.') + 1, instr(substr(file_version, instr(file_version, '.') + 1), '.') - 1) GLOB '[0-9]*' AND
                       substr(file_version, instr(substr(file_version, instr(file_version, '.') + 1), '.') + 1) GLOB '[0-9]*' THEN
                    CAST(substr(file_version, 1, instr(file_version, '.') - 1) AS INTEGER) * 10000 +
                    CAST(substr(file_version, instr(file_version, '.') + 1, instr(substr(file_version, instr(file_version, '.') + 1), '.') - 1) AS INTEGER) * 100 +
                    CAST(substr(file_version, instr(substr(file_version, instr(file_version, '.') + 1), '.') + 1) AS INTEGER)
                  ELSE NULL
                END
              ELSE NULL
            END
          ELSE NULL
        END AS file_version,
        file_path, sign_status, file_src_type, template_name, template_sign_code,
        enable_status, create_by, create_time, update_by, update_time
      FROM t_customer_account_file
    ''');

    // 3. 删除旧表
    await db.execute('DROP TABLE t_customer_account_file');

    // 4. 重命名新表
    await db.execute('ALTER TABLE t_customer_account_file_new RENAME TO t_customer_account_file');

    // 5. 重新创建索引
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_account_file_uid ON t_customer_account_file(customer_uid)
    ''');

    debugPrint('MigrationV8().up()=> Changed file_version from TEXT to INTEGER in t_customer_account_file table');
  }
}