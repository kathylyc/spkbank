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
  String _selectedRole = 'manager'; // 默认选择管理员，使用 key 而不是文本
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

    try {
      // 保存登录信息到本地存储
      await StorageUtils.userInfo.set(LoginInfo(
        username: username,
        role: _selectedRole,
      ));

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
                  child: _buildHorizontalLayout(), // 其他情况：左右布局
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
        Expanded(child: _buildBrandingPanel()),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildFormFields(topSpacing: 0),
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
            children: _buildFormFields(),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandingPanel() {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogo(size: 80, iconSize: 48),
                const SizedBox(height: 32),
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
    );
  }

  Widget _buildLogo({required double size, required double iconSize}) {
    return Container(
      width: size,
      height: size,
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
      child: Icon(
        Icons.account_balance,
        size: iconSize,
        color: const Color(0xFF667EEA),
      ),
    );
  }

  List<Widget> _buildFormFields({double topSpacing = 0}) {
    return [
      if (topSpacing > 0) SizedBox(height: topSpacing),
      _buildRoleSwitcher(),
      const SizedBox(height: 32),
      _buildUsernameField(),
      const SizedBox(height: 24),
      _buildPasswordField(),
      const SizedBox(height: 32),
      _buildLoginButton(),
      const SizedBox(height: 16),
      _buildRegisterButton(),
    ];
  }

  Widget _buildRoleSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleOption(
              label: context.S.roleAdmin,
              isSelected: _selectedRole == 'admin',
              onTap: () => setState(() => _selectedRole = 'admin'),
            ),
          ),
          Expanded(
            child: _buildRoleOption(
              label: context.S.roleManager,
              isSelected: _selectedRole == 'manager',
              onTap: () => setState(() => _selectedRole = 'manager'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
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
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? const Color(0xFF667EEA)
                : const Color(0xFF718096),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return TextField(
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
    );
  }

  Widget _buildPasswordField() {
    return TextField(
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
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
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
    );
  }

  Widget _buildRegisterButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '还没有账号，',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF4A5568),
          ),
        ),
        TextButton(
          onPressed: _handleRegister,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            '立即注册',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF3182CE),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

