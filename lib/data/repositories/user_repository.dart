import 'package:sqflite/sqflite.dart';

import '../db/db_provider.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository({DbProvider? provider}) : _provider = provider ?? DbProvider.instance;

  final DbProvider _provider;

  Future<User> upsert(User user, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    if (user.id == null) {
      final id = await _provider.userDao.insert(user, conflictAlgorithm: conflictAlgorithm);
      return user.copyWith(id: id);
    } else {
      await _provider.userDao.update(user);
      return user;
    }
  }

  Future<User?> findByUserName(String userName) => _provider.userDao.findByUserName(userName);

  Future<List<User>> findAll({int? limit, int? offset}) => _provider.userDao.findAll(limit: limit, offset: offset);

  Future<void> updateLoginDate(String userName, DateTime loginDate) async {
    final existing = await findByUserName(userName);
    if (existing == null) return;
    await _provider.userDao.update(
      existing.copyWith(loginDate: loginDate),
    );
  }

  Future<void> updatePassword(String userName, String password, DateTime updateTime) async {
    final existing = await findByUserName(userName);
    if (existing == null) return;
    await _provider.userDao.update(
      existing.copyWith(password: password, pwdUpdateDate: updateTime, updateTime: updateTime),
    );
  }
}

