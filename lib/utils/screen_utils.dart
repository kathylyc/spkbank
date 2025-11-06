import 'package:flutter/material.dart';

/// 屏幕工具类
/// 提供屏幕相关的工具方法
class ScreenUtils {
  /// 判断是否为手机竖屏
  /// 
  /// [context] BuildContext 用于获取屏幕信息
  /// [breakpoint] 断点宽度，默认 600，小于此宽度且为竖屏时认为是手机竖屏
  /// 
  /// 返回 true 表示是手机竖屏，false 表示其他情况（手机横屏、pad横屏、pad竖屏）
  static bool isPhonePortrait(BuildContext context, {double breakpoint = 600}) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final orientation = mediaQuery.orientation;
    
    return screenWidth < breakpoint && orientation == Orientation.portrait;
  }

  /// 判断是否为手机横屏
  /// 
  /// [context] BuildContext 用于获取屏幕信息
  /// [breakpoint] 断点宽度，默认 600
  /// 
  /// 返回 true 表示是手机横屏
  static bool isPhoneLandscape(BuildContext context, {double breakpoint = 600}) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final orientation = mediaQuery.orientation;
    
    return screenWidth < breakpoint && orientation == Orientation.landscape;
  }

  /// 判断是否为平板设备
  /// 
  /// [context] BuildContext 用于获取屏幕信息
  /// [breakpoint] 断点宽度，默认 600，大于等于此宽度时认为是平板
  /// 
  /// 返回 true 表示是平板设备
  static bool isTablet(BuildContext context, {double breakpoint = 600}) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    return screenWidth >= breakpoint;
  }

  /// 获取屏幕宽度
  /// 
  /// [context] BuildContext 用于获取屏幕信息
  /// 
  /// 返回屏幕宽度
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// 获取屏幕高度
  /// 
  /// [context] BuildContext 用于获取屏幕信息
  /// 
  /// 返回屏幕高度
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// 获取屏幕方向
  /// 
  /// [context] BuildContext 用于获取屏幕信息
  /// 
  /// 返回屏幕方向
  static Orientation getOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation;
  }
}

