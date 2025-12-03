import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 对话框工具类，自动处理iOS和Android平台的对话框适配
class DialogUtils {
  // 私有构造函数，防止实例化
  DialogUtils._();

  /// 显示确认对话框
  ///
  /// [context] 必需的BuildContext
  /// [title] 对话框标题
  /// [content] 对话框内容
  /// [confirmText] 确认按钮文字，默认为'确定'
  /// [cancelText] 取消按钮文字，默认为'取消'
  /// [confirmColor] 确认按钮颜色
  /// [barrierDismissible] 是否可以通过点击外部关闭对话框
  ///
  /// 返回用户的选择：true表示确认，false表示取消，null表示发生异常
  static Future<bool?> confirm({
    required BuildContext context,
    String? title,
    String? content,
    String confirmText = '确定',
    String cancelText = '取消',
    Color? confirmColor,
    bool barrierDismissible = true,
  }) async {
    try {
      // 确保context处于稳定状态
      if (!context.mounted) return null;

      // 对于确认对话框，强制禁止点击外部关闭
      final confirmDialogBarrierDismissible = false;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        bool? result = await showCupertinoDialog<bool>(
          context: context,
          barrierDismissible: confirmDialogBarrierDismissible,
          builder: (dialogContext) {
            return CupertinoAlertDialog(
              title: title != null ? Text(title) : null,
              content: content != null ? Text(content) : null,
              actions: [
                CupertinoDialogAction(
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(false);
                    }
                  },
                  child: Text(cancelText),
                ),
                CupertinoDialogAction(
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  isDefaultAction: true,
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
        return result;
      } else {
        bool? result = await showDialog<bool>(
          context: context,
          barrierDismissible: confirmDialogBarrierDismissible,
          builder: (dialogContext) {
            return AlertDialog(
              title: title != null ? Text(title) : null,
              content: content != null ? Text(content) : null,
              actions: [
                TextButton(
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(false);
                    }
                  },
                  child: Text(cancelText),
                ),
                TextButton(
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  style: confirmColor != null
                      ? TextButton.styleFrom(foregroundColor: confirmColor)
                      : null,
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
        return result;
      }
    } catch (e, s) {
      // 发生异常时返回null，让调用者处理
      debugPrintStack(stackTrace: s);
      return null;
    }
  }

  /// 显示提示对话框（只有确认按钮）
  ///
  /// [context] 必需的BuildContext
  /// [title] 对话框标题
  /// [content] 对话框内容
  /// [confirmText] 确认按钮文字，默认为'确定'
  /// [onConfirm] 确认按钮回调
  /// [barrierDismissible] 是否可以通过点击外部关闭对话框
  static Future<void> alert({
    required BuildContext context,
    String? title,
    String? content,
    String confirmText = '确定',
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
  }) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await showCupertinoDialog<void>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (dialogContext) {
            return CupertinoAlertDialog(
              title: title != null ? Text(title) : null,
              content: content != null ? Text(content) : null,
              actions: [
                CupertinoDialogAction(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onConfirm?.call();
                  },
                  isDefaultAction: true,
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (dialogContext) {
            return AlertDialog(
              title: title != null ? Text(title) : null,
              content: content != null ? Text(content) : null,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onConfirm?.call();
                  },
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // 静默处理异常
    }
  }

  /// 显示加载对话框
  ///
  /// [context] 必需的BuildContext
  /// [message] 加载提示信息
  /// [barrierDismissible] 是否可以通过点击外部关闭对话框
  static void showLoading({
    required BuildContext context,
    String message = '处理中...',
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => WillPopScope(
        onWillPop: () => Future.value(!barrierDismissible),
        child: defaultTargetPlatform == TargetPlatform.iOS
            ? CupertinoAlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 16),
                    const SizedBox(height: 16),
                    Text(message),
                  ],
                ),
              )
            : AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(message),
                  ],
                ),
              ),
      ),
    );
  }

  /// 关闭加载对话框
  ///
  /// [context] BuildContext，用于关闭对话框
  static void hideLoading(BuildContext? context) {
    if (context != null) {
      try {
        Navigator.of(context).pop();
      } catch (e) {
        // 忽略导航错误
      }
    }
  }

  /// 显示自定义对话框
  ///
  /// [context] 必需的BuildContext
  /// [builder] 对话框构建器
  /// [barrierDismissible] 是否可以通过点击外部关闭对话框
  /// [barrierColor] 遮罩层颜色
  ///
  /// 返回对话框的结果
  static Future<T?> showCustomDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return showCupertinoDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        builder: builder,
      );
    } else {
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        builder: builder,
      );
    }
  }
}