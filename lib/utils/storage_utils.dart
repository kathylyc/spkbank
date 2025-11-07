import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:json_annotation/json_annotation.dart';

// 导入其他 package 的模型类
import '../models/notice_info.dart';

// 这一行会告诉代码生成器为这个文件生成代码
// 生成的文件名为：storage_utils.g.dart
part 'storage_utils.g.dart';

/// 登录信息模型
/// 
/// 使用 @JsonSerializable() 注解后，fromJson 和 toJson 会自动生成！
/// 你只需要写字段定义，其他都不用管！
@JsonSerializable()
class LoginInfo {
  final String username;
  final String role;

  const LoginInfo({
    required this.username,
    required this.role,
  });

  /// fromJson 工厂构造函数（调用自动生成的 _$LoginInfoFromJson）
  factory LoginInfo.fromJson(Map<String, dynamic> json) => _$LoginInfoFromJson(json);

  /// toJson 方法（调用自动生成的 _$LoginInfoToJson）
  Map<String, dynamic> toJson() => _$LoginInfoToJson(this);
}

/// 存储键封装类（类似 Gson 的自动序列化）
/// 泛型 T 表示存储值的类型
/// 
/// 使用约定：
/// - 序列化：自动调用对象的 toJson() 方法
/// - 反序列化：自动从类型注册表中查找 fromJson 构造函数
/// 
/// 需要在应用启动时注册自定义类型：
/// ```dart
/// void main() {
///   StorageKey.register<LoginInfo>(LoginInfo.fromJson);
///   runApp(MyApp());
/// }
/// ```
class StorageKey<T> {
  /// key 名称
  final String key;

  /// 默认值
  final T? defaultValue;

  /// 类型注册表（类似 Gson 的 TypeAdapter）
  static final Map<Type, Function> _typeRegistry = {};

  /// 注册自定义类型的 fromJson 构造函数
  /// 
  /// 示例：
  /// ```dart
  /// StorageKey.register<LoginInfo>(LoginInfo.fromJson);
  /// StorageKey.register<UserProfile>(UserProfile.fromJson);
  /// ```
  static void register<T>(T Function(Map<String, dynamic> json) fromJson) {
    _typeRegistry[T] = fromJson;
  }

  /// 统一构造函数（基础类型和复杂对象都用这个）
  const StorageKey(this.key, {this.defaultValue});

  /// 获取 SharedPreferences 实例
  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  /// 检查是否是基础类型
  bool _isPrimitiveType() {
    return T == String || 
           T == int || 
           T == double || 
           T == bool || 
           T == List<String>;
  }

  /// 读取值
  Future<T?> get() async {
    final prefs = await _prefs;
    
    // 优先判断是否为非基础类型
    if (!_isPrimitiveType()) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          final decoded = json.decode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            // 从类型注册表中查找 fromJson 函数
            final fromJson = _typeRegistry[T];
            if (fromJson != null) {
              return fromJson(decoded) as T;
            }
          }
        } catch (e) {
          return defaultValue;
        }
      }
      return defaultValue;
    }
    
    // 基础类型处理
    if (T == String) {
      return prefs.getString(key) as T? ?? defaultValue;
    } else if (T == int) {
      return prefs.getInt(key) as T? ?? defaultValue;
    } else if (T == double) {
      return prefs.getDouble(key) as T? ?? defaultValue;
    } else if (T == bool) {
      return prefs.getBool(key) as T? ?? defaultValue;
    } else if (T == List<String>) {
      return prefs.getStringList(key) as T? ?? defaultValue;
    }
    
    return defaultValue;
  }

  /// 设置值
  Future<bool> set(T value) async {
    final prefs = await _prefs;
    
    // 优先判断是否为非基础类型
    if (!_isPrimitiveType()) {
      try {
        // 直接使用 json.encode，会自动调用对象的 toJson() 方法
        // 这就是 Gson 的工作方式！
        final jsonStr = json.encode(value);
        return await prefs.setString(key, jsonStr);
      } catch (e) {
        return false;
      }
    }
    
    // 基础类型处理
    if (value is String) {
      return await prefs.setString(key, value);
    } else if (value is int) {
      return await prefs.setInt(key, value);
    } else if (value is double) {
      return await prefs.setDouble(key, value);
    } else if (value is bool) {
      return await prefs.setBool(key, value);
    } else if (value is List<String>) {
      return await prefs.setStringList(key, value);
    }
    
    return false;
  }

  /// 删除值
  Future<bool> remove() async {
    final prefs = await _prefs;
    return await prefs.remove(key);
  }

  /// 检查是否存在
  Future<bool> exists() async {
    final prefs = await _prefs;
    return prefs.containsKey(key);
  }
}

/// 本地存储工具类
/// 用于管理应用中的本地缓存数据
class StorageUtils {
  // 私有构造函数，防止实例化
  StorageUtils._();

  /// 初始化方法 - 注册所有自定义类型
  /// 
  /// 在 main() 函数中调用：
  /// ```dart
  /// void main() {
  ///   StorageUtils.init();
  ///   runApp(MyApp());
  /// }
  /// ```
  static void init() {
    // 注册所有自定义类型
    StorageKey.register<LoginInfo>(LoginInfo.fromJson);
    
    // 注册其他 package 的类型
    StorageKey.register<NoticeInfo>(NoticeInfo.fromJson);
    
    // 后续添加更多类型注册
    // StorageKey.register<UserProfile>(UserProfile.fromJson);
  }

  // 定义所有缓存键常量（无需 Key 后缀）
  /// 登录状态
  static const isLoggedIn = StorageKey<bool>('is_logged_in', defaultValue: false);
  
  /// 用户名
  static const username = StorageKey<String>('username');
  
  /// 角色
  static const role = StorageKey<String>('role');

  /// 用户信息对象（自动序列化）
  static const userInfo = StorageKey<LoginInfo>('user_info');

  /// 通知信息对象（来自其他 package 的类型）
  static const noticeInfo = StorageKey<NoticeInfo>('notice_info');

  /// 获取 SharedPreferences 实例
  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  /// 保存登录信息（对象方式 - 推荐）
  static Future<void> saveLoginInfo(LoginInfo loginInfo) async {
    await Future.wait([
      userInfo.set(loginInfo),
      isLoggedIn.set(true),
    ]);
  }

  /// 保存登录信息（命名参数方式）
  static Future<void> saveLoginInfoWithParams({
    required String username,
    required String role,
  }) async {
    await saveLoginInfo(LoginInfo(username: username, role: role));
  }

  /// 获取登录信息
  static Future<LoginInfo?> getLoginInfo() async {
    return await userInfo.get();
  }

  /// 清除登录信息
  static Future<void> clearLoginInfo() async {
    await Future.wait([
      isLoggedIn.remove(),
      userInfo.remove(),
      // 保留单独字段的清除（如果有使用的话）
      username.remove(),
      role.remove(),
    ]);
  }

  /// 退出登录
  static Future<void> logout() async {
    await clearLoginInfo();
  }
}

