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

  Future<int> update(CustomerAccountFile entity) async {
    final db = await _manager.database;
    return db.update(
      CustomerAccountFile.tableName,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  Future<int> deleteById(int id) async {
    final db = await _manager.database;
    return db.delete(
      CustomerAccountFile.tableName,
      where: 'id = ?',
      whereArgs: [id],
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
}

