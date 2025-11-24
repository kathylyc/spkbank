import 'dart:io';

/// 密码验证工具类
class PasswordUtils {
  /// 密码有效期（3个月）
  static const Duration passwordValidityPeriod = Duration(days: 90);

  /// 密码错误最大次数
  static const int maxLoginFailCount = 3;

  /// 账号锁定时间（30分钟）
  static const Duration lockDuration = Duration(minutes: 30);

  /// 验证密码格式
  /// 要求：8位+大小写字母+数字+特殊字符
  static String? validatePasswordFormat(String password) {
    if (password.length < 8) {
      return '密码长度不能少于8位';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return '密码必须包含小写字母';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return '密码必须包含大写字母';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return '密码必须包含数字';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return '密码必须包含特殊字符';
    }

    return null;
  }

  /// 检查密码是否过期
  static bool isPasswordExpired(DateTime? lastUpdateDate) {
    if (lastUpdateDate == null) return true;

    final now = DateTime.now();
    final expiryDate = lastUpdateDate.add(passwordValidityPeriod);

    return now.isAfter(expiryDate);
  }

  /// 获取密码过期天数
  static int getPasswordExpiryDays(DateTime? lastUpdateDate) {
    if (lastUpdateDate == null) return 0;

    final now = DateTime.now();
    final expiryDate = lastUpdateDate.add(passwordValidityPeriod);

    if (now.isAfter(expiryDate)) return 0;

    return expiryDate.difference(now).inDays;
  }

  /// 检查账号是否被锁定
  static bool isAccountLocked(DateTime? lockUntil) {
    if (lockUntil == null) return false;

    return DateTime.now().isBefore(lockUntil);
  }

  /// 获取账号解锁时间（分钟）
  static int getLockMinutesRemaining(DateTime? lockUntil) {
    if (lockUntil == null) return 0;

    final now = DateTime.now();
    if (now.isAfter(lockUntil)) return 0;

    return lockUntil.difference(now).inMinutes;
  }

  /// 检查是否需要锁定账号
  static bool shouldLockAccount(int failCount) {
    return failCount >= maxLoginFailCount;
  }

  /// 计算账号锁定时间
  static DateTime calculateLockTime() {
    return DateTime.now().add(lockDuration);
  }
}