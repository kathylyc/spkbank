import 'dart:ui';
import 'package:bank_flutter/utils/context_extensions.dart';
import 'package:bank_flutter/utils/storage_utils.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/db/database_manager.dart';
import 'data/models/user.dart';
import 'data/repositories/user_repository.dart';
import 'features/admin_user/login_page.dart';
import 'features/router/router_page.dart';
import 'l10n/app_localizations.dart';
import '../utils/page_transition_animations.dart';
import 'data/db/db_provider.dart';

Future<void> main() async {
  // 设置全局错误处理，确保所有错误都被打印到终端
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('========== FlutterError 捕获 ==========');
    debugPrint('错误: ${details.exception}');
    debugPrint('堆栈: ${details.stack}');
    debugPrint('上下文: ${details.context}');
    debugPrint('================================');
  };
  
  // 捕获异步错误
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('========== PlatformDispatcher 错误捕获 ==========');
    debugPrint('错误: $error');
    debugPrint('堆栈: $stack');
    debugPrint('================================');
    return true;
  };
  
  // 设置全屏模式
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
  
  // 设置首选屏幕方向（可选，根据需求调整）
  // SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.landscapeLeft,
  //   DeviceOrientation.landscapeRight,
  // ]);


  await _initSdk();
  
  runApp(const MyApp());
}
/// 检查登录状态
Future<void> _initSdk() async {
  // 可在应用启动（如 main 函数中）提前触发数据库初始化

  try {
    final users = await DbProvider.instance.userDao.findAll(limit: 1);
    debugPrint('读取users = ${users.length}');
  } catch (e, s) {
    debugPrint('findAll failed: $e');
    debugPrint('$s');
  }


  final db = await DatabaseManager.instance.database;
  debugPrint('db path = ${db.path}');
  final rows = await db.rawQuery('SELECT * FROM t_user');
  debugPrint('raw t_user = $rows');

  // final pwd1 = BCrypt.hashpw('SiPoDsBANK2026@', BCrypt.gensalt());// storeuser1
  // final pwd2 = BCrypt.hashpw('SaP2dDm0BiA2nNK6#', BCrypt.gensalt());// admin
  // debugPrint('storeuser1 密码哈希: $pwd1');
  // debugPrint('admin 密码哈希: $pwd2');

  // 创建iOS审核专用账号
  await UserRepository().createReviewAccountIfNeeded();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bank Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // 配置本地化支持（使用生成的代码）
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // 支持的语言列表（使用生成的列表，确保一致性）
      supportedLocales: AppLocalizations.supportedLocales,
      // 不设置 locale，让系统自动根据设备语言选择
      // 如果系统语言是英文，会显示英文；否则显示中文
      home: const AuthWrapper(),
    );
  }
}

/// 认证包装器
/// 根据登录状态显示不同的页面
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    final User? loginUser = await StorageUtils.getLoginUser();
    if (mounted) {
      setState(() {
        _isLoggedIn = loginUser != null;
        _isLoading = false;
      });
    }
  }

  /// 处理登录成功
  void _onLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  /// 处理退出登录
  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 加载中显示加载指示器
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 使用 AnimatedSwitcher 实现页面切换动画
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500), // 动画持续时间
      transitionBuilder: PageTransitionAnimations.fadeScale,
      child: _isLoggedIn
          ? RouterPage(
              key: const ValueKey('router'), // 关键：不同的 key 才会触发动画
              onLogout: _onLogout,
            )
          : LoginPage(
              key: const ValueKey('login'), // 关键：不同的 key 才会触发动画
              onLoginSuccess: _onLoginSuccess,
            ),
    );
  }
}