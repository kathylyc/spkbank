import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import 'migration.dart';

class MigrationV1 implements MigrationStep {
  @override
  int get version => 1;

  @override
  Future<void> up(Database db) async {
    await runBatch(db, [
      '''
      CREATE TABLE IF NOT EXISTS t_user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_name TEXT NOT NULL UNIQUE,
        nick_name TEXT,
        user_type TEXT NOT NULL,
        email TEXT,
        phonenumber TEXT,
        sex INTEGER,
        avatar TEXT,
        password TEXT NOT NULL,
        status TEXT,
        login_date TEXT,
        pwd_update_date TEXT,
        create_by TEXT,
        create_time TEXT,
        update_by TEXT,
        update_time TEXT
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS t_customer (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_uid TEXT NOT NULL UNIQUE,
        customer_name TEXT NOT NULL,
        customer_tag TEXT NOT NULL,
        country_code TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        manager_account TEXT NOT NULL,
        create_by TEXT,
        create_time TEXT,
        update_by TEXT,
        update_time TEXT,
        FOREIGN KEY(manager_account) REFERENCES t_user(user_name) ON DELETE RESTRICT ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS t_customer_account_file (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_file_uid TEXT NOT NULL,
        customer_uid TEXT NOT NULL,
        account_file_name TEXT NOT NULL,
        file_version TEXT,
        file_path TEXT NOT NULL,
        sign_status TEXT,
        file_src_type TEXT,
        template_name TEXT,
        create_by TEXT,
        create_time TEXT,
        update_by TEXT,
        update_time TEXT,
        FOREIGN KEY(customer_uid) REFERENCES t_customer(customer_uid) ON DELETE CASCADE ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS t_customer_attachment_file (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_uid TEXT NOT NULL,
        attachment_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        create_by TEXT,
        create_time TEXT,
        update_by TEXT,
        update_time TEXT,
        FOREIGN KEY(customer_uid) REFERENCES t_customer(customer_uid) ON DELETE CASCADE ON UPDATE CASCADE
      )
      ''',
      '''
      CREATE INDEX IF NOT EXISTS idx_customer_uid ON t_customer(customer_uid)
      ''',
      '''
      CREATE INDEX IF NOT EXISTS idx_customer_manager ON t_customer(manager_account)
      ''',
      '''
      CREATE INDEX IF NOT EXISTS idx_account_file_uid ON t_customer_account_file(customer_uid)
      ''',
      '''
      CREATE INDEX IF NOT EXISTS idx_attachment_uid ON t_customer_attachment_file(customer_uid)
      ''',
    ]);

    // 初始化默认超级管理员账号
    await db.insert(
      't_user',
      {
        'user_name': 'admin',
        'nick_name': '超级管理员',
        'user_type': '00',
        // 'password': r'$2a$10$7JB720yubVSZvUI0rEqK/.VqGOZTH.ulu33dHOiBE8ByOhJIrdAu2',// admin123
        'password': r'$2a$10$twkqepxKQwY4d/lXweZmm.UMi45sPcrv0HjTdKg1VN0es7xgmaBrW',// SaP2dDm0BiA2nNK6@ 生成方法：BCrypt.hashpw(text, BCrypt.gensalt());
        'status': '0',
        'create_time': DateTime.now().toIso8601String(),
        'create_by': 'system',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    debugPrint('MigrationV1().up()==>');
  }
}

