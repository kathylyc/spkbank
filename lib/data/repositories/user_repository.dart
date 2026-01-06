import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../db/db_provider.dart';
import '../models/user.dart';
import '../../utils/password_utils.dart';
import '../../utils/file_manager.dart';

/// 账户删除统计信息
class AccountDeletionStats {
  const AccountDeletionStats({
    required this.customerCount,
    required this.accountFileCount,
    required this.attachmentFileCount,
  });

  final int customerCount;
  final int accountFileCount;
  final int attachmentFileCount;
}

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
    if (user.isFirstLogin == null || user.isFirstLogin == true) return true;

    // 客户经理（userType == '01'）需要检查90天密码过期
    if (user.userType == '01') {
      return PasswordUtils.isPasswordExpired(user.pwdUpdateDate);
    }

    // 其他用户类型不需要检查密码过期
    return false;
  }

  /// 检查手机号是否重复（排除指定用户ID）
  Future<bool> isPhoneNumberExists(String phoneNumber, {int? excludeId}) =>
      _provider.userDao.existsByPhoneNumber(phoneNumber, excludeId: excludeId);

  /// 统计用户关联数据量
  ///
  /// [userName] 用户名
  ///
  /// 返回统计信息（客户数量、开户文件数量、附件文件数量）
  Future<Map<String, int>> countUserData(String userName) async {
    final db = await _provider.database;

    // 统计客户数量
    final customerResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM t_customer WHERE manager_account = ?',
      [userName],
    );
    final customerCount = Sqflite.firstIntValue(customerResult) ?? 0;

    // 统计开户文件数量
    final accountFileResult = await db.rawQuery(
      '''SELECT COUNT(*) AS count FROM t_customer_account_file
         WHERE customer_uid IN (
           SELECT customer_uid FROM t_customer WHERE manager_account = ?
         )''',
      [userName],
    );
    final accountFileCount = Sqflite.firstIntValue(accountFileResult) ?? 0;

    // 统计附件文件数量
    final attachmentFileResult = await db.rawQuery(
      '''SELECT COUNT(*) AS count FROM t_customer_attachment_file
         WHERE customer_uid IN (
           SELECT customer_uid FROM t_customer WHERE manager_account = ?
         )''',
      [userName],
    );
    final attachmentFileCount = Sqflite.firstIntValue(attachmentFileResult) ?? 0;

    return {
      'customerCount': customerCount,
      'accountFileCount': accountFileCount,
      'attachmentFileCount': attachmentFileCount,
    };
  }

  /// 删除用户账户及其所有关联数据
  ///
  /// [userName] 用户名
  /// [password] 密码（用于验证身份，如果为空则跳过验证）
  ///
  /// 返回删除统计信息
  ///
  /// 抛出异常的情况：
  /// - [ArgumentError] 密码验证失败
  /// - [StateError] 管理员账号不允许删除
  /// - [Exception] 删除过程中发生错误
  Future<AccountDeletionStats> deleteAccountWithCascade({
    required String userName,
    required String password,
  }) async {
    // 1. 验证用户存在
    final user = await findByUserName(userName);
    if (user == null) {
      throw Exception('用户不存在');
    }

    // 2. 如果提供了密码，则验证密码
    if (password.isNotEmpty) {
      if (!BCrypt.checkpw(password, user.password)) {
        throw ArgumentError('密码不正确');
      }
    }

    // 3. 检查是否为管理员
    if (user.userType == '00') {
      throw StateError('管理员账号不允许删除');
    }

    final db = await _provider.database;

    return await db.transaction<AccountDeletionStats>((txn) async {
      // 在事务上下文中直接执行删除操作
      int customerCount = 0;
      int accountFileCount = 0;
      int attachmentFileCount = 0;

      // 4.1 查询所有客户
      final customers = await txn.query(
        't_customer',
        where: 'manager_account = ?',
        whereArgs: [userName],
      );

      customerCount = customers.length;

      // 4.2 删除每个客户的文件和数据
      for (final customerRow in customers) {
        final customerUid = customerRow['customer_uid'] as String;

        // 删除开户文件（物理文件）
        final accountFiles = await txn.query(
          't_customer_account_file',
          where: 'customer_uid = ?',
          whereArgs: [customerUid],
        );

        accountFileCount += accountFiles.length.toInt();

        for (final accountFile in accountFiles) {
          final filePath = accountFile['file_path'] as String;
          try {
            debugPrint('准备删除开户文件: $filePath');
            await FileManager.deleteAccountFile(filePath);
          } catch (e) {
            debugPrint('删除开户文件失败: $filePath, 错误: $e');
          }
        }

        // 删除附件文件（物理文件）
        final attachmentFiles = await txn.query(
          't_customer_attachment_file',
          where: 'customer_uid = ?',
          whereArgs: [customerUid],
        );

        attachmentFileCount += attachmentFiles.length.toInt();

        for (final attachmentFile in attachmentFiles) {
          final filePath = attachmentFile['file_path'] as String;
          try {
            debugPrint('准备删除附件文件: $filePath');
            await FileManager.deleteCustomerAttachment(filePath);
          } catch (e) {
            debugPrint('删除附件文件失败: $filePath, 错误: $e');
          }
        }

        // 删除客户记录（会自动级联删除开户文件和附件记录）
        await txn.delete(
          't_customer',
          where: 'customer_uid = ?',
          whereArgs: [customerUid],
        );
      }

      // 5. 删除用户记录
      await txn.delete(
        User.tableName,
        where: 'user_name = ?',
        whereArgs: [userName],
      );

      return AccountDeletionStats(
        customerCount: customerCount,
        accountFileCount: accountFileCount,
        attachmentFileCount: attachmentFileCount,
      );
    });
  }
}

