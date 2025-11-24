import 'package:sqflite/sqflite.dart';

import '../db/db_provider.dart';
import '../models/user.dart';
import '../../utils/password_utils.dart';

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

  Future<List<User>> findManagers({
    int? limit,
    int? offset,
    String? accountKeyword,
    String? nameKeyword,
    String? phoneKeyword,
  }) =>
      _provider.userDao.findManagers(
        limit: limit,
        offset: offset,
        accountKeyword: accountKeyword,
        nameKeyword: nameKeyword,
        phoneKeyword: phoneKeyword,
      );

  Future<int> countManagers({
    String? accountKeyword,
    String? nameKeyword,
    String? phoneKeyword,
  }) =>
      _provider.userDao.countManagers(
        accountKeyword: accountKeyword,
        nameKeyword: nameKeyword,
        phoneKeyword: phoneKeyword,
      );

  /// 根据团队编码查找客户经理
  Future<List<User>> findManagersByGroupCode(String groupCode) =>
      _provider.userDao.findManagersByGroupCode(groupCode);

  Future<int> deleteById(int id) => _provider.userDao.deleteById(id);

  /// 增加登录失败次数
  Future<void> incrementLoginFailCount(String userName) async {
    final existing = await findByUserName(userName);
    if (existing == null) return;

    final newFailCount = (existing.loginFailCount ?? 0) + 1;
    DateTime? lockUntil;

    if (PasswordUtils.shouldLockAccount(newFailCount)) {
      lockUntil = PasswordUtils.calculateLockTime();
    }

    await _provider.userDao.update(
      existing.copyWith(
        loginFailCount: newFailCount,
        lockUntil: lockUntil,
      ),
    );
  }

  /// 重置登录失败次数
  Future<void> resetLoginFailCount(String userName) async {
    final existing = await findByUserName(userName);
    if (existing == null) return;

    await _provider.userDao.update(
      existing.copyWith(
        loginFailCount: 0,
        lockUntil: DateTime.now(),
      ),
    );
  }

  /// 检查账号是否被锁定
  Future<bool> isAccountLocked(String userName) async {
    final user = await findByUserName(userName);
    if (user == null) return false;

    return PasswordUtils.isAccountLocked(user.lockUntil);
  }

  /// 强制首次登录修改密码
  Future<void> setFirstLogin(String userName, bool isFirstLogin) async {
    final existing = await findByUserName(userName);
    if (existing == null) return;

    await _provider.userDao.update(
      existing.copyWith(isFirstLogin: isFirstLogin),
    );
  }

  /// 解锁账号（管理员功能）
  Future<void> unlockAccount(String userName) async {
    final existing = await findByUserName(userName);
    if (existing == null) return;

    await _provider.userDao.update(
      existing.copyWith(
        loginFailCount: 0,
        lockUntil: DateTime.now(),
        updateTime: DateTime.now(),
      ),
    );
  }

  /// 检查密码是否需要更新
  Future<bool> shouldUpdatePassword(String userName) async {
    final user = await findByUserName(userName);
    if (user == null) return true;

    // 首次登录需要修改密码
    if (user.isFirstLogin == true) return true;

    // 密码过期需要修改密码
    return PasswordUtils.isPasswordExpired(user.pwdUpdateDate);
  }
}

