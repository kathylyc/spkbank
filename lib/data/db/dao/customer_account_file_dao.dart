import 'package:sqflite/sqflite.dart';

import '../../models/customer_account_file.dart';
import '../database_manager.dart';

class CustomerAccountFileDao {
  CustomerAccountFileDao(this._manager);

  final DatabaseManager _manager;

  Future<int> insert(CustomerAccountFile entity,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final db = await _manager.database;
    return db.insert(
      CustomerAccountFile.tableName,
      entity.toMap(),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> updateWithVersion(CustomerAccountFile entity) async {
    final db = await _manager.database;
    return db.update(
      CustomerAccountFile.tableName,
      entity.toMap(),
      where: 'account_file_uid = ? AND file_version = ?',
      whereArgs: [entity.accountFileUid, entity.fileVersion],
    );
  }

  Future<int> deleteByAccountFileUidAndVersion(String accountFileUid, String fileVersion) async {
    final db = await _manager.database;
    return db.delete(
      CustomerAccountFile.tableName,
      where: 'account_file_uid = ? AND file_version = ?',
      whereArgs: [accountFileUid],
    );
  }

  Future<List<CustomerAccountFile>> findByCustomerUid(String customerUid) async {
    final db = await _manager.database;
    final rows = await db.query(
      CustomerAccountFile.tableName,
      where: 'customer_uid = ?',
      whereArgs: [customerUid],
      orderBy: 'create_time DESC',
    );
    return rows.map(CustomerAccountFile.fromMap).toList();
  }

  /// 查询开户文件列表，关联客户信息和客户经理信息
  /// 返回包含所有关联数据的 Map 列表
  Future<List<Map<String, Object?>>> findWithCustomerAndManager({
    int? limit,
    int? offset,
    String? customerNameKeyword,
    String? phoneKeyword,
    String? fileNameKeyword,
  }) async {
    final db = await _manager.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (customerNameKeyword != null && customerNameKeyword.isNotEmpty) {
      whereClauses.add('c.customer_name LIKE ?');
      whereArgs.add('%$customerNameKeyword%');
    }
    if (phoneKeyword != null && phoneKeyword.isNotEmpty) {
      whereClauses.add('c.phone LIKE ?');
      whereArgs.add('%$phoneKeyword%');
    }
    if (fileNameKeyword != null && fileNameKeyword.isNotEmpty) {
      whereClauses.add('f.account_file_name LIKE ?');
      whereArgs.add('%$fileNameKeyword%');
    }

    final whereClause = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';

    final rows = await db.rawQuery(
      '''
      SELECT 
        f.id,
        f.customer_uid,
        f.account_file_name,
        f.file_version,
        f.file_path,
        f.sign_status,
        f.file_src_type,
        f.template_name,
        f.create_by,
        f.create_time,
        f.update_by,
        f.update_time,
        c.customer_name,
        c.phone,
        c.manager_account,
        u.user_name AS manager_code,
        u.nick_name AS manager_name
      FROM ${CustomerAccountFile.tableName} f
      LEFT JOIN t_customer c ON f.customer_uid = c.customer_uid
      LEFT JOIN t_user u ON c.manager_account = u.user_name
      $whereClause
      ORDER BY f.create_time DESC
      $limitClause
      $offsetClause
      ''',
      whereArgs,
    );
    return rows;
  }

  /// 统计开户文件总数（带查询条件）
  Future<int> countWithCustomerAndManager({
    String? customerNameKeyword,
    String? phoneKeyword,
    String? fileNameKeyword,
  }) async {
    final db = await _manager.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (customerNameKeyword != null && customerNameKeyword.isNotEmpty) {
      whereClauses.add('c.customer_name LIKE ?');
      whereArgs.add('%$customerNameKeyword%');
    }
    if (phoneKeyword != null && phoneKeyword.isNotEmpty) {
      whereClauses.add('c.phone LIKE ?');
      whereArgs.add('%$phoneKeyword%');
    }
    if (fileNameKeyword != null && fileNameKeyword.isNotEmpty) {
      whereClauses.add('f.account_file_name LIKE ?');
      whereArgs.add('%$fileNameKeyword%');
    }

    final whereClause = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${CustomerAccountFile.tableName} f
      LEFT JOIN t_customer c ON f.customer_uid = c.customer_uid
      LEFT JOIN t_user u ON c.manager_account = u.user_name
      $whereClause
      ''',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

