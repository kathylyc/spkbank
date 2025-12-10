import 'package:flutter/material.dart';

/// 滑入动画组件
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const SlideInAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.elasticInOut,
  });

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.2), // 从底部更远的位置开始
      end: Offset.zero, // 移动到正常位置
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.curve,
    ));

    // 启动动画
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: widget.child,
    );
  }
}

/// 自定义动画SnackBar
class AnimatedSnackBar extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onAnimationComplete;

  const AnimatedSnackBar({
    super.key,
    required this.message,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onAnimationComplete,
  });

  @override
  State<AnimatedSnackBar> createState() => _AnimatedSnackBarState();
}

class _AnimatedSnackBarState extends State<AnimatedSnackBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 位移动画：从底部滑入
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 2.0), // 从底部更远处开始
      end: Offset.zero, // 移动到正常位置
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // 淡入动画
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    // 启动进入动画
    _animationController.forward();

    // 自动隐藏
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _hideSnackbar();
      }
    });
  }

  void _hideSnackbar() {
    _animationController.reverse().then((_) {
      widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取键盘高度和屏幕安全区域
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final safeBottom = mediaQuery.padding.bottom;

    // 计算Snackbar的位置
    // 如果键盘弹出，显示在键盘上方；否则显示在底部安全区域上方
    final bottomPadding = keyboardHeight > 0
        ? keyboardHeight + 16
        : safeBottom + 16;

    // 确保Snackbar不会超出屏幕范围，给一些安全距离
    final maxBottom = screenHeight - 200; // 预留200px给Snackbar内容
    final finalBottom = bottomPadding > maxBottom ? maxBottom : bottomPadding;

    return Positioned(
      bottom: finalBottom,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: widget.textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SnackbarUtils {
  static const Duration _defaultDuration = Duration(seconds: 2);

  static void _showSnackbar(
    String message,
    BuildContext context, {
    Color backgroundColor = Colors.grey,
    Color textColor = Colors.white,
    IconData? icon,
    Duration duration = _defaultDuration,
  }) {
    // 隐藏当前的 SnackBar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // 使用自定义的 Overlay 方式创建更明显的动画效果
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            AnimatedSnackBar(
              message: message,
              icon: icon,
              backgroundColor: backgroundColor,
              textColor: textColor,
              onAnimationComplete: () {
                overlayEntry.remove();
              },
            ),
          ],
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  /// 显示成功消息（绿色）
  static void success(
    String message,
    BuildContext context, {
    Duration duration = _defaultDuration,
  }) {
    _showSnackbar(
      message,
      context,
      backgroundColor: const Color(0xFF4CAF50),
      textColor: Colors.white,
      icon: Icons.check_circle,
      duration: duration,
    );
  }

  /// 显示错误消息（红色）
  static void error(
    String message,
    BuildContext context, {
    Duration duration = _defaultDuration,
  }) {
    _showSnackbar(
      message,
      context,
      backgroundColor: const Color(0xFFF44336),
      textColor: Colors.white,
      icon: Icons.error,
      duration: duration,
    );
  }

  /// 显示警告消息（橘黄色）
  static void warning(
    String message,
    BuildContext context, {
    Duration duration = _defaultDuration,
  }) {
    _showSnackbar(
      message,
      context,
      backgroundColor: const Color(0xFFFF9800),
      textColor: Colors.white,
      icon: Icons.warning,
      duration: duration,
    );
  }

  /// 显示普通消息（深蓝色）
  static void normal(
      String message,
      BuildContext context, {
        Duration duration = _defaultDuration,
      }) {
    _showSnackbar(
      message,
      context,
      backgroundColor: const Color(0xFFF2F3FA),
      textColor: Colors.black,
      icon: Icons.info,
      duration: duration,
    );
  }
}