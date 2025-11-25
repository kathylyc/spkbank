import 'package:sqflite/sqflite.dart';

import '../../models/customer.dart';
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
      whereArgs: [accountFileUid, fileVersion],
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

  /// 根据客户UID和模板名称查找最新的账户文件
  /// 返回使用相同模板的最新文件（按版本号降序排列）
  Future<CustomerAccountFile?> findLatestByCustomerUidAndTemplate(
    String customerUid,
    String templateName,
  ) async {
    final db = await _manager.database;
    final rows = await db.query(
      CustomerAccountFile.tableName,
      where: 'customer_uid = ? AND template_name = ?',
      whereArgs: [customerUid, templateName],
      orderBy: 'CAST(file_version AS INTEGER) DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CustomerAccountFile.fromMap(rows.first);
  }

  /// 根据账户文件UID查找所有记录
  Future<List<CustomerAccountFile>> findByAccountFileUid(String accountFileUid) async {
    final db = await _manager.database;
    final rows = await db.query(
      CustomerAccountFile.tableName,
      where: 'account_file_uid = ?',
      whereArgs: [accountFileUid],
      orderBy: 'CAST(file_version AS INTEGER) DESC',
    );
    return rows.map(CustomerAccountFile.fromMap).toList();
  }

  /// 根据账户文件UID查找最大版本号
  /// 返回最大版本号，如果没有记录则返回 null
  Future<String?> findMaxVersionByAccountFileUid(String accountFileUid) async {
    final db = await _manager.database;
    final rows = await db.query(
      CustomerAccountFile.tableName,
      columns: ['file_version'],
      where: 'account_file_uid = ?',
      whereArgs: [accountFileUid],
      orderBy: 'CAST(file_version AS INTEGER) DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['file_version'] as String?;
  }

  /// 查询开户文件列表，关联客户信息和客户经理信息
  /// 返回包含所有关联数据的 Map 列表
  Future<List<Map<String, Object?>>> findWithCustomerAndManager({
    int? limit,
    int? offset,
    String? customerNameKeyword,
    String? phoneKeyword,
    String? fileNameKeyword,
    String? managerAccount,
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
    if (managerAccount != null && managerAccount.isNotEmpty) {
      whereClauses.add('c.manager_account = ?');
      whereArgs.add(managerAccount);
    }

    final whereClause = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';

    final rows = await db.rawQuery(
      '''
      SELECT 
        f.id,
        f.account_file_uid,
        f.customer_uid,
        f.account_file_name,
        f.file_version,
        f.file_path,
        f.sign_status,
        f.file_src_type,
        f.template_name,
        f.template_sign_code,
        f.create_by,
        f.create_time,
        f.update_by,
        f.update_time,
        c.customer_name,
        c.company,
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
    String? managerAccount,
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
    if (managerAccount != null && managerAccount.isNotEmpty) {
      whereClauses.add('c.manager_account = ?');
      whereArgs.add(managerAccount);
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

  /// 统计不同模板数量
  Future<int> countDistinctTemplates({String? managerAccount}) async {
    final db = await _manager.database;
    final whereClauses = <String>["template_name IS NOT NULL AND template_name != ''"];
    final whereArgs = <Object?>[];
    
    if (managerAccount != null && managerAccount.isNotEmpty) {
      whereClauses.add('customer_uid IN (SELECT customer_uid FROM ${Customer.tableName} WHERE manager_account = ?)');
      whereArgs.add(managerAccount);
    }
    
    final whereClause = whereClauses.join(' AND ');
    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT template_name) AS count
      FROM ${CustomerAccountFile.tableName}
      WHERE $whereClause
      ''',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 统计已签署文档数量
  Future<int> countSignedDocuments({String? managerAccount}) async {
    final db = await _manager.database;
    final whereClauses = <String>["sign_status = '1' OR sign_status = '已签署'"];
    final whereArgs = <Object?>[];
    
    if (managerAccount != null && managerAccount.isNotEmpty) {
      whereClauses.add('customer_uid IN (SELECT customer_uid FROM ${Customer.tableName} WHERE manager_account = ?)');
      whereArgs.add(managerAccount);
    }
    
    final whereClause = whereClauses.join(' AND ');
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${CustomerAccountFile.tableName}
      WHERE $whereClause
      ''',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 统计待签署文档数量
  Future<int> countPendingDocuments({String? managerAccount}) async {
    final db = await _manager.database;
    final whereClauses = <String>["sign_status IS NULL OR sign_status = '' OR sign_status = '2' OR sign_status = '未签署'"];
    final whereArgs = <Object?>[];
    
    if (managerAccount != null && managerAccount.isNotEmpty) {
      whereClauses.add('customer_uid IN (SELECT customer_uid FROM ${Customer.tableName} WHERE manager_account = ?)');
      whereArgs.add(managerAccount);
    }
    
    final whereClause = whereClauses.join(' AND ');
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${CustomerAccountFile.tableName}
      WHERE $whereClause
      ''',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 按客户统计账户文件数量（用于饼图）
  /// 返回前N个客户的文件数量统计
  Future<List<Map<String, Object?>>> countFilesByCustomer({
    int limit = 10,
    String? managerAccount,
  }) async {
    final db = await _manager.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];
    
    if (managerAccount != null && managerAccount.isNotEmpty) {
      whereClauses.add('c.manager_account = ?');
      whereArgs.add(managerAccount);
    }
    
    final whereClause = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final rows = await db.rawQuery(
      '''
      SELECT 
        c.customer_uid,
        c.customer_name,
        COUNT(f.id) AS file_count
      FROM ${Customer.tableName} c
      LEFT JOIN ${CustomerAccountFile.tableName} f ON c.customer_uid = f.customer_uid
      $whereClause
      GROUP BY c.customer_uid, c.customer_name
      ORDER BY file_count DESC
      LIMIT ?
      ''',
      [...whereArgs, limit],
    );
    return rows;
  }

  /// 每月新客户和新账户文件统计（用于柱状图）
  /// 返回最近N个月的数据
  Future<List<Map<String, Object?>>> getMonthlyStats({
    int months = 5,
    String? managerAccount,
  }) async {
    final db = await _manager.database;
    final now = DateTime.now();
    
    // 计算起始日期，处理跨年情况
    int startYear = now.year;
    int startMonth = now.month - months + 1;
    while (startMonth <= 0) {
      startMonth += 12;
      startYear -= 1;
    }
    final startDate = DateTime(startYear, startMonth, 1);
    final startDateStr = startDate.toIso8601String();

    // 构建客户查询条件
    final customerWhereClauses = <String>['create_time >= ?'];
    final customerWhereArgs = <Object?>[startDateStr];
    if (managerAccount != null && managerAccount.isNotEmpty) {
      customerWhereClauses.add('manager_account = ?');
      customerWhereArgs.add(managerAccount);
    }
    final customerWhereClause = customerWhereClauses.join(' AND ');

    // 获取每月新客户数量
    final customerRows = await db.rawQuery(
      '''
      SELECT 
        strftime('%Y-%m', create_time) AS month,
        COUNT(*) AS customer_count
      FROM ${Customer.tableName}
      WHERE $customerWhereClause
      GROUP BY strftime('%Y-%m', create_time)
      ORDER BY month ASC
      ''',
      customerWhereArgs,
    );

    // 构建文件查询条件
    final fileWhereClauses = <String>['create_time >= ?'];
    final fileWhereArgs = <Object?>[startDateStr];
    if (managerAccount != null && managerAccount.isNotEmpty) {
      fileWhereClauses.add('customer_uid IN (SELECT customer_uid FROM ${Customer.tableName} WHERE manager_account = ?)');
      fileWhereArgs.add(managerAccount);
    }
    final fileWhereClause = fileWhereClauses.join(' AND ');

    // 获取每月新账户文件数量
    final fileRows = await db.rawQuery(
      '''
      SELECT 
        strftime('%Y-%m', create_time) AS month,
        COUNT(*) AS file_count
      FROM ${CustomerAccountFile.tableName}
      WHERE $fileWhereClause
      GROUP BY strftime('%Y-%m', create_time)
      ORDER BY month ASC
      ''',
      fileWhereArgs,
    );

    // 合并数据
    final Map<String, Map<String, Object?>> resultMap = {};
    
    // 初始化所有月份
    for (int i = 0; i < months; i++) {
      int year = startYear;
      int month = startMonth + i;
      while (month > 12) {
        month -= 12;
        year += 1;
      }
      final monthDateTime = DateTime(year, month, 1);
      final monthStr = '${monthDateTime.year}-${monthDateTime.month.toString().padLeft(2, '0')}';
      resultMap[monthStr] = {
        'month': monthStr,
        'customer_count': 0,
        'file_count': 0,
      };
    }

    // 填充客户数据
    for (final row in customerRows) {
      final month = row['month'] as String;
      if (resultMap.containsKey(month)) {
        resultMap[month]!['customer_count'] = row['customer_count'];
      }
    }

    // 填充文件数据
    for (final row in fileRows) {
      final month = row['month'] as String;
      if (resultMap.containsKey(month)) {
        resultMap[month]!['file_count'] = row['file_count'];
      }
    }

    return resultMap.values.toList();
  }
}

