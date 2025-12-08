import 'package:sqflite/sqflite.dart';

import '../../models/customer_attachment_file.dart';
import '../database_manager.dart';

class CustomerAttachmentFileDao {
  CustomerAttachmentFileDao(this._manager);

  final DatabaseManager _manager;

  Future<int> insert(CustomerAttachmentFile entity,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final db = await _manager.database;
    return db.insert(
      CustomerAttachmentFile.tableName,
      entity.toMap(),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> update(CustomerAttachmentFile entity) async {
    final db = await _manager.database;
    return db.update(
      CustomerAttachmentFile.tableName,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  Future<int> deleteById(int id) async {
    final db = await _manager.database;
    return db.delete(
      CustomerAttachmentFile.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CustomerAttachmentFile>> findByCustomerUid(String customerUid) async {
    final db = await _manager.database;
    final rows = await db.query(
      CustomerAttachmentFile.tableName,
      where: 'customer_uid = ?',
      whereArgs: [customerUid],
      orderBy: 'create_time DESC',
    );
    return rows.map(CustomerAttachmentFile.fromMap).toList();
  }
}

