import 'package:sqflite/sqflite.dart';

import '../../models/customer.dart';
import '../database_manager.dart';

class CustomerDao {
  CustomerDao(this._manager);

  final DatabaseManager _manager;

  Future<int> insert(Customer entity, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final db = await _manager.database;
    return db.insert(
      Customer.tableName,
      entity.toMap(),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> update(Customer entity) async {
    final db = await _manager.database;
    return db.update(
      Customer.tableName,
      entity.toMap(),
      where: 'customer_uid = ?',
      whereArgs: [entity.customerUid],
    );
  }

  Future<int> deleteByUid(String customerUid) async {
    final db = await _manager.database;
    return db.delete(
      Customer.tableName,
      where: 'customer_uid = ?',
      whereArgs: [customerUid],
    );
  }

  Future<Customer?> findByUid(String customerUid) async {
    final db = await _manager.database;
    final rows = await db.query(
      Customer.tableName,
      where: 'customer_uid = ?',
      whereArgs: [customerUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<List<Customer>> findByManager(String managerAccount) async {
    final db = await _manager.database;
    final rows = await db.query(
      Customer.tableName,
      where: 'manager_account = ?',
      whereArgs: [managerAccount],
      orderBy: 'create_time DESC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<List<Customer>> searchByName(String keyword) async {
    final db = await _manager.database;
    final rows = await db.query(
      Customer.tableName,
      where: 'customer_name LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'customer_name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }
}

