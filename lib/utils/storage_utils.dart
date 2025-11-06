import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储工具类
/// 用于管理应用中的本地缓存数据
class StorageUtils {
  // 私有构造函数，防止实例化
  StorageUtils._();

  // 登录状态键
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername = 'username';
  static const String _keyRole = 'role';

  /// 获取 SharedPreferences 实例
  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  /// 检查是否已登录
  static Future<bool> isLoggedIn() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// 设置登录状态
  static Future<void> setLoggedIn(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyIsLoggedIn, value);
  }

  /// 保存登录信息
  static Future<void> saveLoginInfo({
    required String username,
    required String role,
  }) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString(_keyUsername, username),
      prefs.setString(_keyRole, role),
      prefs.setBool(_keyIsLoggedIn, true),
    ]);
  }

  /// 获取用户名
  static Future<String?> getUsername() async {
    final prefs = await _prefs;
    return prefs.getString(_keyUsername);
  }

  /// 获取角色
  static Future<String?> getRole() async {
    final prefs = await _prefs;
    return prefs.getString(_keyRole);
  }

  /// 清除登录信息
  static Future<void> clearLoginInfo() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove(_keyIsLoggedIn),
      prefs.remove(_keyUsername),
      prefs.remove(_keyRole),
    ]);
  }

  /// 退出登录
  static Future<void> logout() async {
    await clearLoginInfo();
  }
}

