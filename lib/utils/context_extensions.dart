import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// BuildContext 扩展方法
/// 提供便捷的本地化访问方法
extension AppLocalizationsExtension on BuildContext {
  /// 获取本地化字符串
  /// 如果本地化不可用，会抛出异常
  /// 使用示例: context.S.systemName
  AppLocalizations get S => AppLocalizations.of(this)!;
}

