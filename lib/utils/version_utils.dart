/// 版本号工具类
///
/// 提供 int 型和 String 型版本号的互相转换功能
/// 转换逻辑：
/// - int 型版本号：万位以上是大版本号，千位和百位是中版本号，十位和个位是小版本号
/// - 例如：10000 -> "1.0.0"
/// - 例如：12345 -> "1.23.45"
class VersionUtils {

  /// 基础版本号常量
  /// 对应 String 版本号 "1.0.0"
  static const int baseVersion = 10000;

  /// 将 int 型版本号转换为 String 型版本号
  ///
  /// [intVersion] int 型版本号，例如 10000
  ///
  /// 返回 String 型版本号，例如 "1.0.0"
  ///
  /// 示例：
  /// ```dart
  /// VersionUtils.intToString(10000) // "1.0.0"
  /// VersionUtils.intToString(12345) // "1.23.45"
  /// VersionUtils.intToString(20106) // "2.1.6"
  /// ```
  static String intToString(int intVersion) {
    if (intVersion < 0) {
      throw ArgumentError('版本号不能为负数');
    }

    // 提取各个版本号部分
    final int majorVersion = intVersion ~/ 10000;  // 万位以上：大版本号
    final int remainder = intVersion % 10000;
    final int middleVersion = remainder ~/ 100;    // 千位和百位：中版本号
    final int minorVersion = remainder % 100;     // 十位和个位：小版本号

    return '$majorVersion.$middleVersion.$minorVersion';
  }

  /// 将 String 型版本号转换为 int 型版本号
  ///
  /// [stringVersion] String 型版本号，例如 "1.0.0"
  ///
  /// 返回 int 型版本号，例如 10000
  ///
  /// 示例：
  /// ```dart
  /// VersionUtils.stringToInt("1.0.0")  // 10000
  /// VersionUtils.stringToInt("1.23.45") // 12345
  /// VersionUtils.stringToInt("2.1.6")  // 20106
  /// ```
  static int stringToInt(String stringVersion) {
    if (stringVersion.isEmpty) {
      throw ArgumentError('版本号字符串不能为空');
    }

    final parts = stringVersion.split('.');
    if (parts.length != 3) {
      throw ArgumentError('版本号格式不正确，应为 x.y.z 格式，例如 "1.0.0"');
    }

    try {
      final int majorVersion = int.parse(parts[0]);
      final int middleVersion = int.parse(parts[1]);
      final int minorVersion = int.parse(parts[2]);

      // 验证版本号范围
      if (majorVersion < 0 || middleVersion < 0 || minorVersion < 0) {
        throw ArgumentError('版本号部分不能为负数');
      }

      if (middleVersion >= 100 || minorVersion >= 100) {
        throw ArgumentError('中版本号和小版本号必须小于100');
      }

      // 组装 int 型版本号
      return majorVersion * 10000 + middleVersion * 100 + minorVersion;
    } on FormatException {
      throw ArgumentError('版本号包含非数字字符');
    }
  }

  /// 验证 int 型版本号是否有效
  ///
  /// [intVersion] 要验证的 int 型版本号
  ///
  /// 返回 true 如果版本号有效，false 否则
  static bool isValidIntVersion(int intVersion) {
    if (intVersion < 0) {
      return false;
    }

    final int remainder = intVersion % 10000;
    final int middleVersion = remainder ~/ 100;
    final int minorVersion = remainder % 100;

    return middleVersion < 100 && minorVersion < 100;
  }

  /// 验证 String 型版本号是否有效
  ///
  /// [stringVersion] 要验证的 String 型版本号
  ///
  /// 返回 true 如果版本号有效，false 否则
  static bool isValidStringVersion(String stringVersion) {
    try {
      stringToInt(stringVersion);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 比较两个版本号
  ///
  /// [version1] 第一个版本号（可以是 int 或 String）
  /// [version2] 第二个版本号（可以是 int 或 String）
  ///
  /// 返回：
  /// - 1 如果 version1 > version2
  /// - 0 如果 version1 == version2
  /// - -1 如果 version1 < version2
  static int compareVersions(dynamic version1, dynamic version2) {
    final int v1 = version1 is int ? version1 : stringToInt(version1);
    final int v2 = version2 is int ? version2 : stringToInt(version2);

    if (v1 > v2) return 1;
    if (v1 < v2) return -1;
    return 0;
  }

  /// 检查版本1是否大于版本2
  static bool isGreaterThan(dynamic version1, dynamic version2) {
    return compareVersions(version1, version2) > 0;
  }

  /// 检查版本1是否小于版本2
  static bool isLessThan(dynamic version1, dynamic version2) {
    return compareVersions(version1, version2) < 0;
  }

  /// 检查版本1是否等于版本2
  static bool isEqual(dynamic version1, dynamic version2) {
    return compareVersions(version1, version2) == 0;
  }

  /// 检查版本1是否大于等于版本2
  static bool isGreaterThanOrEqual(dynamic version1, dynamic version2) {
    return compareVersions(version1, version2) >= 0;
  }

  /// 检查版本1是否小于等于版本2
  static bool isLessThanOrEqual(dynamic version1, dynamic version2) {
    return compareVersions(version1, version2) <= 0;
  }

  /// 计算版本号递增
  ///
  /// [version] 起始版本号（String 类型），例如 "1.0.0"
  /// [majorIncrement] 大版本号递增量，默认为 0
  /// [middleIncrement] 中版本号递增量，默认为 0
  /// [minorIncrement] 小版本号递增量，默认为 0
  ///
  /// 返回递增后的版本号字符串
  ///
  /// 示例：
  /// ```dart
  /// VersionUtils.incrementVersion("1.0.0", majorIncrement: 1)        // "2.0.0"
  /// VersionUtils.incrementVersion("1.2.3", middleIncrement: 1)      // "1.3.3"
  /// VersionUtils.incrementVersion("1.2.3", minorIncrement: 1)      // "1.2.4"
  /// VersionUtils.incrementVersion("1.9.99", minorIncrement: 1)     // "2.0.0"
  /// VersionUtils.incrementVersion("1.0.0", middleIncrement: 1, minorIncrement: -1) // "1.0.99"
  /// ```
  static String incrementVersion(
    String version, {
    int majorIncrement = 0,
    int middleIncrement = 0,
    int minorIncrement = 0,
  }) {
    // 转换为 int 版本号
    final int intVersion = stringToInt(version);

    // 提取各个版本号部分
    final int majorVersion = intVersion ~/ 10000;  // 大版本号
    final int remainder = intVersion % 10000;
    final int middleVersion = remainder ~/ 100;    // 中版本号
    final int minorVersion = remainder % 100;     // 小版本号

    // 计算递增后的版本号
    int newMajor = majorVersion + majorIncrement;
    int newMiddle = middleVersion + middleIncrement;
    int newMinor = minorVersion + minorIncrement;

    // 处理小版本号溢出（超过99或小于0）
    if (newMinor > 99) {
      final int middleOverflow = newMinor ~/ 100;
      newMiddle += middleOverflow;
      newMinor = newMinor % 100;
    } else if (newMinor < 0) {
      // 小版本号下溢，需要借位
      newMiddle--;
      newMinor += 100;
    }

    // 处理中版本号溢出（超过99或小于0）
    if (newMiddle > 99) {
      final int majorOverflow = newMiddle ~/ 100;
      newMajor += majorOverflow;
      newMiddle = newMiddle % 100;
    } else if (newMiddle < 0) {
      // 中版本号下溢，需要借位
      newMajor--;
      newMiddle += 100;
    }

    // 如果小版本号借位后，中版本号也下溢了，继续借位
    if (newMinor >= 100) {
      newMiddle++;
      newMinor -= 100;
    }

    // 确保版本号不为负数
    if (newMajor < 0) {
      throw ArgumentError('递增后的大版本号不能为负数');
    }

    // 重新组装为 int 版本号
    final int newIntVersion = newMajor * 10000 + newMiddle * 100 + newMinor;

    return intToString(newIntVersion);
  }

  /// 方便的方法：递增大版本号
  static String incrementMajorVersion(String version, {int increment = 1}) {
    return incrementVersion(version, majorIncrement: increment);
  }

  /// 方便的方法：递增中版本号
  static String incrementMiddleVersion(String version, {int increment = 1}) {
    return incrementVersion(version, middleIncrement: increment);
  }

  /// 方便的方法：递增小版本号
  static String incrementMinorVersion(String version, {int increment = 1}) {
    return incrementVersion(version, minorIncrement: increment);
  }

  /// 方便的方法：递减大版本号
  static String decrementMajorVersion(String version, {int decrement = 1}) {
    return incrementVersion(version, majorIncrement: -decrement);
  }

  /// 方便的方法：递减中版本号
  static String decrementMiddleVersion(String version, {int decrement = 1}) {
    return incrementVersion(version, middleIncrement: -decrement);
  }

  /// 方便的方法：递减小版本号
  static String decrementMinorVersion(String version, {int decrement = 1}) {
    return incrementVersion(version, minorIncrement: -decrement);
  }

  /// 计算 int 型版本号递增
  ///
  /// [intVersion] 起始版本号（int 类型），例如 10000
  /// [majorIncrement] 大版本号递增量，默认为 0
  /// [middleIncrement] 中版本号递增量，默认为 0
  /// [minorIncrement] 小版本号递增量，默认为 0
  ///
  /// 返回递增后的 int 型版本号
  ///
  /// 示例：
  /// ```dart
  /// VersionUtils.incrementIntVersion(10000, majorIncrement: 1)        // 20000 ("2.0.0")
  /// VersionUtils.incrementIntVersion(10203, middleIncrement: 1)      // 10303 ("1.3.3")
  /// VersionUtils.incrementIntVersion(10203, minorIncrement: 1)      // 10204 ("1.2.4")
  /// VersionUtils.incrementIntVersion(10999, minorIncrement: 1)     // 11000 ("1.10.0")
  /// VersionUtils.incrementIntVersion(19999, middleIncrement: 1)     // 20099 ("2.0.99")
  /// VersionUtils.incrementIntVersion(10000, majorIncrement: 1, middleIncrement: 2, minorIncrement: 3) // 22203 ("2.2.3")
  /// ```
  static int incrementIntVersion(
    int intVersion, {
    int majorIncrement = 0,
    int middleIncrement = 0,
    int minorIncrement = 0,
  }) {
    if (intVersion < 0) {
      throw ArgumentError('版本号不能为负数');
    }

    // 提取各个版本号部分
    final int majorVersion = intVersion ~/ 10000;  // 大版本号
    final int remainder = intVersion % 10000;
    final int middleVersion = remainder ~/ 100;    // 中版本号
    final int minorVersion = remainder % 100;     // 小版本号

    // 计算递增后的版本号
    int newMajor = majorVersion + majorIncrement;
    int newMiddle = middleVersion + middleIncrement;
    int newMinor = minorVersion + minorIncrement;

    // 处理小版本号溢出（超过99或小于0）
    if (newMinor > 99) {
      final int middleOverflow = newMinor ~/ 100;
      newMiddle += middleOverflow;
      newMinor = newMinor % 100;
    } else if (newMinor < 0) {
      // 小版本号下溢，需要借位
      newMiddle--;
      newMinor += 100;
    }

    // 处理中版本号溢出（超过99或小于0）
    if (newMiddle > 99) {
      final int majorOverflow = newMiddle ~/ 100;
      newMajor += majorOverflow;
      newMiddle = newMiddle % 100;
    } else if (newMiddle < 0) {
      // 中版本号下溢，需要借位
      newMajor--;
      newMiddle += 100;
    }

    // 确保版本号不为负数
    if (newMajor < 0) {
      throw ArgumentError('递增后的大版本号不能为负数');
    }

    // 重新组装为 int 版本号
    return newMajor * 10000 + newMiddle * 100 + newMinor;
  }

  /// 方便的方法：递增 int 型大版本号
  static int incrementMajorIntVersion(int intVersion, {int increment = 1}) {
    return incrementIntVersion(intVersion, majorIncrement: increment);
  }

  /// 方便的方法：递增 int 型中版本号
  static int incrementMiddleIntVersion(int intVersion, {int increment = 1}) {
    return incrementIntVersion(intVersion, middleIncrement: increment);
  }

  /// 方便的方法：递增 int 型小版本号
  static int incrementMinorIntVersion(int intVersion, {int increment = 1}) {
    return incrementIntVersion(intVersion, minorIncrement: increment);
  }

  /// 方便的方法：递减 int 型大版本号
  static int decrementMajorIntVersion(int intVersion, {int decrement = 1}) {
    return incrementIntVersion(intVersion, majorIncrement: -decrement);
  }

  /// 方便的方法：递减 int 型中版本号
  static int decrementMiddleIntVersion(int intVersion, {int decrement = 1}) {
    return incrementIntVersion(intVersion, middleIncrement: -decrement);
  }

  /// 方便的方法：递减 int 型小版本号
  static int decrementMinorIntVersion(int intVersion, {int decrement = 1}) {
    return incrementIntVersion(intVersion, minorIncrement: -decrement);
  }
}