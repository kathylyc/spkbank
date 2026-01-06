import 'package:bcrypt/bcrypt.dart';
import 'package:bank_flutter/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import '../../data/models/user.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/context_extensions.dart';
import '../../utils/storage_utils.dart';
import '../dashboard/dashboard_page.dart';
import '../pdf_template/pdf_template_page.dart';
import '../customer/customer_page.dart';
import '../customer_file/customer_file_page.dart';
import '../account_manager/account_manager_page.dart';
import '../usage/usage_page.dart';
import '../admin_user/force_reset_pwd.dart';

/// 功能类型枚举
enum FunctionType {
  dashboard,
  pdfTemplate,
  customer,
  customerFile,
  accountManager,
  usage,
}

class RouterPage extends StatefulWidget {
  final VoidCallback onLogout;

  const RouterPage({
    super.key,
    required this.onLogout,
  });

  @override
  State<RouterPage> createState() => _RouterPageState();
}

class _RouterPageState extends State<RouterPage> {
  User? _loginUser;
  FunctionType _selectedFunction = FunctionType.dashboard;
  final List<String> _openTabs = ['首页']; // 打开的标签页列表

  bool get _isAccountManager => _loginUser?.userType == '01';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// 加载用户信息
  Future<void> _loadUserInfo() async {
    final User? loginUser = await StorageUtils.getLoginUser();
    if (mounted) {
      setState(() {
        _loginUser = loginUser;
        if (_isAccountManager) {
          _openTabs.remove(context.S.templateManagement);
          _openTabs.remove('客户经理管理');
          if (_selectedFunction == FunctionType.pdfTemplate ||
              _selectedFunction == FunctionType.accountManager) {
            _selectedFunction = FunctionType.dashboard;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 切换功能
  void _switchFunction(FunctionType functionType) {
    if (_isAccountManager && functionType == FunctionType.accountManager) {
      return;
    }
    setState(() {
      _selectedFunction = functionType;
      // 根据功能类型添加标签页
      String tabName = _getFunctionName(functionType);
      if (!_openTabs.contains(tabName)) {
        _openTabs.add(tabName);
      }
    });
  }

  /// 获取功能名称
  String _getFunctionName(FunctionType functionType) {
    switch (functionType) {
      case FunctionType.dashboard:
        return context.S.home;
      case FunctionType.pdfTemplate:
        return context.S.templateManagement;
      case FunctionType.customer:
        return context.S.customerManagement;
      case FunctionType.customerFile:
        return '开户文件管理';
      case FunctionType.accountManager:
        return '客户经理管理';
      case FunctionType.usage:
        return '使用说明';
    }
  }

  /// 关闭标签页
  void _closeTab(String tabName) {
    // 首页标签不可关闭
    if (tabName == context.S.home) {
      return;
    }
    
    if (_openTabs.length > 1) {
      setState(() {
        _openTabs.remove(tabName);
        // 如果关闭的是当前选中的标签，切换到首页
        if (_getFunctionName(_selectedFunction) == tabName) {
          _selectedFunction = FunctionType.dashboard;
        }
      });
    }
  }

  /// 处理修改密码
  Future<void> _handleChangePassword() async {
    if (_loginUser == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ForceResetPwdPage(
          user: _loginUser!,
          trigger: PasswordChangeTrigger.routerPage,
          onPasswordChanged: () {
            // 密码修改成功后返回 true
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );

    // 如果密码修改成功，则退出登录
    if (result == true && mounted) {
      _doLogout();
    }
  }

  /// 处理注销账号
  Future<void> _handleDeleteAccount() async {
    if (_loginUser == null) return;

    // 检查是否为超级管理员
    if (_loginUser!.userType == '00') {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认注销账户？'),
            content: const Text('超级管理员账号如需注销，请联系：baiyuekeji@beyoit.com'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 开始注销流程
    await _showDeleteAccountFlow();
  }

  /// 注销账号流程（两次弹窗）
  Future<void> _showDeleteAccountFlow() async {
    // 第一步：显示第一次确认弹窗
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认注销账户？'),
          content: const Text(
            '您确定要注销账户吗？注销后所有数据将被永久删除，且无法恢复。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                '取消',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '确定',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // 第二步：显示密码输入弹窗
    await _showPasswordInputDialog();
  }

  /// 显示密码输入弹窗
  Future<void> _showPasswordInputDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('注销账户'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        '* ',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '输入登录密码',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    validator: (value) {
                      final password = value?.trim() ?? '';
                      if (password.isEmpty) {
                        return '请输入密码';
                      }
                      if (_loginUser != null &&
                          !BCrypt.checkpw(password, _loginUser!.password)) {
                        return '密码不正确';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: '请输入',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                '取消',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text(
                '确认注销',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    // 确保弹窗完全关闭后再释放 controller
    Future.delayed(Duration.zero, () {
      passwordController.dispose();
    });

    if (result == true && mounted) {
      await _performAccountDeletion();
    } else if (mounted && result == false) {
      // 如果取消，返回第一个弹窗
      _showDeleteAccountFlow();
    }
  }

  /// 执行账户删除
  Future<void> _performAccountDeletion() async {
    if (_loginUser == null) return;

    try {
      final userRepo = UserRepository();
      await userRepo.deleteAccountWithCascade(
        userName: _loginUser!.userName,
        password: '', // 密码已在弹窗中验证过
      );

      // 删除成功，显示成功弹窗
      if (mounted) {
        await _showSuccessDialog();
        // 成功后退出登录
        await _doLogout();
      }
    } catch (e) {
      if (mounted) {
        // 删除失败，显示错误提示并返回密码输入页
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _showPasswordInputDialog();
      }
    }
  }

  /// 显示成功弹窗
  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('注销账户'),
        content: const Text(
          '注销成功！若后续需要使用，可重新注册账户。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '确定',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 处理退出登录
  Future<void> _handleLogout() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.S.logout),
          content: Text(context.S.logoutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                context.S.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                context.S.confirm,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _doLogout();
    }
  }
  Future<void> _doLogout() async {
    try {
      // 清除登录信息
      await StorageUtils.logout();

      if (mounted) {
        SnackbarUtils.success(context.S.logoutSuccess, context);

        // 通知父组件退出登录
        widget.onLogout();
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.error('退出登录失败: $e', context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 防止软键盘弹起时调整布局
      body: SafeArea(
        // 确保 SafeArea 正确处理 iPad 的底部安全区域
        top: false,
        bottom: false,
        left: true,
        right: true,
        child: Row(
          children: [
            // 左侧边栏
            _buildSidebar(),
            // 右侧内容区域
            Expanded(
              child: _buildContentArea(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建左侧边栏
  Widget _buildSidebar() {
    return Container(
      width: 80, // 固定宽度
      color: const Color(0xFF1A202C), // 深蓝色背景
      child: Column(
        children: [
          // 上方：功能切换图标
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // 首页图标
                  _buildFunctionIcon(
                    icon: Icons.home_outlined,
                    isSelected: _selectedFunction == FunctionType.dashboard,
                    onTap: () => _switchFunction(FunctionType.dashboard),
                  ),
                  const SizedBox(height: 8),
                  // 模板管理图标
                  _buildFunctionIcon(
                    icon: Icons.description_outlined,
                    isSelected: _selectedFunction == FunctionType.pdfTemplate,
                    onTap: () => _switchFunction(FunctionType.pdfTemplate),
                  ),
                  const SizedBox(height: 8),
                  // 客户管理图标
                  _buildFunctionIcon(
                    icon: Icons.people_outline,
                    isSelected: _selectedFunction == FunctionType.customer,
                    onTap: () => _switchFunction(FunctionType.customer),
                  ),
                  const SizedBox(height: 8),
                  // 开户文件管理图标
                  _buildFunctionIcon(
                    icon: Icons.folder_outlined,
                    isSelected: _selectedFunction == FunctionType.customerFile,
                    onTap: () => _switchFunction(FunctionType.customerFile),
                  ),
                  if (!_isAccountManager) ...[
                    const SizedBox(height: 8),
                    // 客户经理管理图标
                    _buildFunctionIcon(
                      icon: Icons.person_outline,
                      isSelected: _selectedFunction == FunctionType.accountManager,
                      onTap: () => _switchFunction(FunctionType.accountManager),
                    ),
                  ],
                  // 可以添加更多功能图标
                  const SizedBox(height: 8),
                  // 使用说明图标
                  _buildFunctionIcon(
                    icon: Icons.help_outline,
                    isSelected: _selectedFunction == FunctionType.usage,
                    onTap: () => _switchFunction(FunctionType.usage),
                  ),
                ],
              ),
            ),
          ),
          // 下方：操作图标（修改密码、注销账号、退出登录）
          Column(
            children: [
              // 修改密码图标
              _buildActionIcon(
                icon: Icons.lock_outline,
                tooltip: context.S.changePassword,
                onTap: _handleChangePassword,
              ),
              const SizedBox(height: 8),
              // 注销账号图标
              _buildActionIcon(
                icon: Icons.person_remove,
                tooltip: '注销账号',
                onTap: _handleDeleteAccount,
              ),
              const SizedBox(height: 8),
              // 退出登录图标
              _buildActionIcon(
                icon: Icons.logout,
                tooltip: context.S.logout,
                onTap: _handleLogout,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建功能图标
  Widget _buildFunctionIcon({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4299E1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// 构建操作图标
  Widget _buildActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  /// 构建右侧内容区域
  Widget _buildContentArea() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 标签页栏
          _buildTabBar(),
          // 内容区域
          Expanded(
            child: _buildFunctionContent(),
          ),
        ],
      ),
    );
  }

  /// 构建标签页栏
  Widget _buildTabBar() {
    final visibleTabs = _openTabs.where((tabName) {
      if (_isAccountManager) {
        return tabName != '客户经理管理';
      }
      return true;
    }).toList();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: visibleTabs.length,
              itemBuilder: (context, index) {
                final tabName = visibleTabs[index];
                final isActive = tabName == _getFunctionName(_selectedFunction);
                
                return GestureDetector(
                  onTap: () {
                    // 根据标签名称切换功能
                    if (tabName == context.S.home) {
                      _switchFunction(FunctionType.dashboard);
                    } else if (tabName == context.S.templateManagement) {
                      _switchFunction(FunctionType.pdfTemplate);
                    } else if (tabName == context.S.customerManagement) {
                      _switchFunction(FunctionType.customer);
                    } else if (tabName == '开户文件管理') {
                      _switchFunction(FunctionType.customerFile);
                    } else if (tabName == '使用说明') {
                      _switchFunction(FunctionType.usage);
                    } else if (tabName == '客户经理管理') {
                      _switchFunction(FunctionType.accountManager);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? const Color(0xFF4299E1) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tabName,
                          style: TextStyle(
                            color: isActive ? const Color(0xFF4299E1) : Colors.grey.shade700,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        // 首页标签不显示关闭按钮，其他标签在多个标签时显示关闭按钮
                        if (tabName != context.S.home && visibleTabs.length > 1) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _closeTab(tabName),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text.rich(
              TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                children: [
                  TextSpan(text: _getSayHello(),
                    style: const TextStyle(
                      color: Color(0xFF222222),
                    ),),
                  TextSpan(
                    text: _loginUser?.nickName ?? '',
                    style: const TextStyle(
                      color: Color(0xFF4299E1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSayHello() {
    if (_isAccountManager) {
      return '${context.S.helloRightTop}${context.S.accountManager}';
    } else {
      return context.S.helloRightTop;
    }
  }

  /// 构建功能内容
  Widget _buildFunctionContent() {
    switch (_selectedFunction) {
      case FunctionType.dashboard:
        return DashboardPage(
          onNavigateToCustomerFile: () => _switchFunction(FunctionType.customerFile),
        );
      case FunctionType.pdfTemplate:
        return const PdfTemplatePage();
      case FunctionType.customer:
        return const CustomerPage();
      case FunctionType.customerFile:
        return const CustomerFilePage();
      case FunctionType.usage:
        return const UsagePage();
      case FunctionType.accountManager:
        return const AccountManagerPage();
    }
  }
}
