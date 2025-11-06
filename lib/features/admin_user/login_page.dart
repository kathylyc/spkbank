import 'package:flutter/material.dart';
import '../../utils/screen_utils.dart';
import '../../utils/context_extensions.dart';
import '../../utils/storage_utils.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginPage({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'admin'; // 默认选择管理员，使用 key 而不是文本
  bool _obscurePassword = true; // 密码是否隐藏
  bool _isPhonePortrait = false;// 是否是手机并且竖屏

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text;
    final password = _passwordController.text;
    
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.S.pleaseEnterUsernameAndPassword),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: 实现实际的登录逻辑（调用API验证账号密码）
    // 这里暂时模拟登录成功

    try {
      // 保存登录信息到本地存储
      await StorageUtils.saveLoginInfo(
        username: username,
        role: _selectedRole,
      );

      final roleName = _selectedRole == 'admin' ? context.S.roleAdmin : context.S.roleManager;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.S.loginSuccess(roleName, username)),
            backgroundColor: Colors.green,
          ),
        );

        // 通知父组件登录成功
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleRegister() {
    // TODO: 实现注册逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.S.navigateToRegister),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否为手机竖屏
    setState(() {
      _isPhonePortrait = ScreenUtils.isPhonePortrait(context);
    });
    
    return Scaffold(
      body: Container(
        // 纯色背景
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA), // 浅灰色背景
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                // 圆角卡片
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 1000,
                    minHeight: _isPhonePortrait ? 640 : 480,
                    maxHeight: _isPhonePortrait ? 640 : 480,
                  ),
                  child: _isPhonePortrait
                      ? _buildVerticalLayout() // 手机竖屏：上下布局
                      : _buildHorizontalLayout(), // 其他情况：左右布局
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 构建左右布局（手机横屏、pad横屏、pad竖屏）
  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        // 左侧区域：背景图 + logo + 系统名称
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF667EEA),
                  Color(0xFF764BA2),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
            ),
            child: Stack(
              children: [
                // 背景装饰图案（可选）
                // 如果不需要背景图案，可以注释掉这部分
                // Positioned.fill(
                //   child: Opacity(
                //     opacity: 0.1,
                //     child: Container(
                //       decoration: const BoxDecoration(
                //         image: DecorationImage(
                //           image: AssetImage('assets/images/pattern.png'),
                //           repeat: ImageRepeat.repeat,
                //           fit: BoxFit.none,
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
                // 内容区域
                Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          size: 48,
                          color: Color(0xFF667EEA),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 系统名称（根据系统语言自动显示）
                      Text(
                        context.S.appName,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 右侧区域：账号密码输入框 + 角色切换 + 登录按钮 + 注册按钮
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                // 角色切换
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRole = 'admin';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'admin'
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedRole == 'admin'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              context.S.roleAdmin,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _selectedRole == 'admin'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedRole == 'admin'
                                    ? const Color(0xFF667EEA)
                                    : const Color(0xFF718096),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRole = 'manager';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'manager'
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedRole == 'manager'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              context.S.roleManager,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _selectedRole == 'manager'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedRole == 'manager'
                                    ? const Color(0xFF667EEA)
                                    : const Color(0xFF718096),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // 账号输入框
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: context.S.username,
                    hintText: context.S.usernameHint,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                  ),
                ),
                const SizedBox(height: 24),
                // 密码输入框
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: context.S.password,
                    hintText: context.S.passwordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                  ),
                ),
                const SizedBox(height: 32),
                // 登录按钮
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    context.S.login,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 注册按钮
                OutlinedButton(
                  onPressed: _handleRegister,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF667EEA),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                      color: Color(0xFF667EEA),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.S.register,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 构建上下布局（手机竖屏）
  Widget _buildVerticalLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上方区域：背景图 + logo + 系统名称
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667EEA),
                Color(0xFF764BA2),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Stack(
            children: [
              // 内容区域
              SizedBox(
                width: double.infinity,
                child:
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          size: 40,
                          color: Color(0xFF667EEA),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 系统名称（根据系统语言自动显示）
                      Text(
                        context.S.appName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // 下方区域：账号密码输入框 + 角色切换 + 登录按钮 + 注册按钮
        Container(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // 角色切换
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRole = 'admin';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'admin'
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedRole == 'admin'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              context.S.roleAdmin,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _selectedRole == 'admin'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedRole == 'admin'
                                    ? const Color(0xFF667EEA)
                                    : const Color(0xFF718096),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRole = 'manager';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'manager'
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedRole == 'manager'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              context.S.roleManager,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _selectedRole == 'manager'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedRole == 'manager'
                                    ? const Color(0xFF667EEA)
                                    : const Color(0xFF718096),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // 账号输入框
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: context.S.username,
                    hintText: context.S.usernameHint,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                  ),
                ),
                const SizedBox(height: 24),
                // 密码输入框
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: context.S.password,
                    hintText: context.S.passwordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                  ),
                ),
                const SizedBox(height: 32),
                // 登录按钮
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    context.S.login,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 注册按钮
                OutlinedButton(
                  onPressed: _handleRegister,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF667EEA),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                      color: Color(0xFF667EEA),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.S.register,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

