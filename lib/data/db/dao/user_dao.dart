import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/user.dart';
import '../database_manager.dart';

class UserDao {
  UserDao(this._manager);

  final DatabaseManager _manager;

  Future<int> insert(User entity, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final db = await _manager.database;
    return db.insert(
      User.tableName,
      entity.toMap(),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> update(User entity) async {
    final db = await _manager.database;
    return db.update(
      User.tableName,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  Future<int> deleteById(int id) async {
    final db = await _manager.database;
    return db.delete(
      User.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<User?> findByUserName(String userName) async {
    final db = await _manager.database;
    final rows = await db.query(
      User.tableName,
      where: 'user_name = ?',
      whereArgs: [userName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<List<User>> findAll({int? limit, int? offset}) async {
    final db = await _manager.database;
    final rows = await db.query(
      User.tableName,
      limit: limit,
      offset: offset,
      orderBy: 'create_time DESC',
    );
    debugPrint('findAll rows: $rows');        // 观察这里
    return rows.map(User.fromMap).toList();
  }

  Future<List<User>> findManagers({
    int? limit,
    int? offset,
    String? accountKeyword,
    String? nameKeyword,
    String? phoneKeyword,
  }) async {
    final db = await _manager.database;
    final whereClauses = <String>['user_type = ?'];
    final whereArgs = <Object?>['01'];

    if (accountKeyword != null && accountKeyword.isNotEmpty) {
      whereClauses.add('user_name LIKE ?');
      whereArgs.add('%$accountKeyword%');
    }
    if (nameKeyword != null && nameKeyword.isNotEmpty) {
      whereClauses.add('(nick_name LIKE ? OR user_name LIKE ?)');
      whereArgs.add('%$nameKeyword%');
      whereArgs.add('%$nameKeyword%');
    }
    if (phoneKeyword != null && phoneKeyword.isNotEmpty) {
      whereClauses.add('phonenumber LIKE ?');
      whereArgs.add('%$phoneKeyword%');
    }

    final rows = await db.query(
      User.tableName,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'create_time DESC',
    );
    return rows.map(User.fromMap).toList();
  }

  Future<int> countManagers({
    String? accountKeyword,
    String? nameKeyword,
    String? phoneKeyword,
  }) async {
    final db = await _manager.database;
    final whereClauses = <String>['user_type = ?'];
    final whereArgs = <Object?>['01'];

    if (accountKeyword != null && accountKeyword.isNotEmpty) {
      whereClauses.add('user_name LIKE ?');
      whereArgs.add('%$accountKeyword%');
    }
    if (nameKeyword != null && nameKeyword.isNotEmpty) {
      whereClauses.add('(nick_name LIKE ? OR user_name LIKE ?)');
      whereArgs.add('%$nameKeyword%');
      whereArgs.add('%$nameKeyword%');
    }
    if (phoneKeyword != null && phoneKeyword.isNotEmpty) {
      whereClauses.add('phonenumber LIKE ?');
      whereArgs.add('%$phoneKeyword%');
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${User.tableName} WHERE ${whereClauses.join(' AND ')}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

