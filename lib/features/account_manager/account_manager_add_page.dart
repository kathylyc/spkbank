import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/user.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/storage_utils.dart';

class AccountManagerAddPage extends StatefulWidget {
  const AccountManagerAddPage({
    super.key,
    this.manager,
    this.isRegisterMode = false,
  });

  final User? manager;
  final bool isRegisterMode;

  @override
  State<AccountManagerAddPage> createState() => _AccountManagerAddPageState();
}

class _AccountManagerAddPageState extends State<AccountManagerAddPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _managerAccountController = TextEditingController();
  final TextEditingController _groupCodeController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _managerPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final UserRepository _userRepository = UserRepository();
  User? _loginUser;
  User? _initialManager;

  final RegExp _chineseCharacterRegExp = RegExp(r'[\u4e00-\u9fff]');
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _isEdit => _initialManager != null;
  bool get _isRegisterMode => widget.isRegisterMode;

  @override
  void initState() {
    super.initState();
    _initialManager = widget.manager;
    if (_initialManager != null) {
      _managerAccountController.text = _initialManager!.userName;
      _groupCodeController.text = _initialManager!.groupCode;
      _managerNameController.text = _initialManager!.nickName;
      _managerPhoneController.text = _initialManager!.phoneNumber ?? '';
    }
    _loadUserInfo();
  }

  /// 加载用户信息
  Future<void> _loadUserInfo() async {
    final User? loginUser = await StorageUtils.getLoginUser();
    if (mounted) {
      setState(() {
        _loginUser = loginUser;
      });
    }
  }

  @override
  void dispose() {
    _managerAccountController.dispose();
    _groupCodeController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    if (_isRegisterMode) {
      return _managerAccountController.text.trim().isNotEmpty ||
          _managerNameController.text.trim().isNotEmpty ||
          _managerPhoneController.text.trim().isNotEmpty ||
          _passwordController.text.isNotEmpty ||
          _confirmPasswordController.text.isNotEmpty;
    }
    return _managerAccountController.text.trim() != (_initialManager?.userName ?? '') ||
        _groupCodeController.text.trim() != (_initialManager?.groupCode ?? '') ||
        _managerNameController.text.trim() != (_initialManager?.nickName ?? '') ||
        _managerPhoneController.text.trim() != (_initialManager?.phoneNumber ?? '');
  }

  Future<bool> _handleWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }
    final shouldExit = await _showUnsavedConfirmDialog();
    return shouldExit ?? false;
  }

  Future<bool?> _showUnsavedConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('您还未保存，确定退出吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLeadingPressed() async {
    final canExit = await _handleWillPop();
    if (canExit && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final managerAccount = _managerAccountController.text.trim();
    final groupCode = _groupCodeController.text.trim();
    final managerName = _managerNameController.text.trim();
    final managerPhone = _managerPhoneController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      if (!_isEdit) {
        final existing = await _userRepository.findByUserName(managerAccount);
        if (existing != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('客户经理编号已存在')),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }
      }

      final now = DateTime.now();
      if (_isEdit) {
        final existing = _initialManager!;
        final updated = existing.copyWith(
          groupCode: groupCode,
          nickName: managerName,
          phoneNumber: managerPhone.isEmpty ? null : managerPhone,
          updateBy: _loginUser?.userName ?? existing.updateBy,
          updateTime: now,
        );
        await _userRepository.upsert(updated);
      } else {
        // 注册模式下使用用户输入的密码，否则使用默认密码（客户经理编号）
        final passwordToUse = _isRegisterMode
            ? _passwordController.text
            : managerAccount;
        final passwordHash = BCrypt.hashpw(passwordToUse, BCrypt.gensalt());
        final newManager = User(
          userName: managerAccount,
          nickName: managerName,
          userType: '01',
          phoneNumber: managerPhone.isEmpty ? null : managerPhone,
          password: passwordHash,
          status: '0',
          groupCode: groupCode,
          lockUntil: DateTime.now(),
          createBy: _loginUser?.userName,
          createTime: now,
        );
        await _userRepository.upsert(newManager);
      }

      if (!mounted) return;
      if (_isRegisterMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功')),
        );
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isRegisterMode ? '注册失败: $error' : '保存失败: $error')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isRegisterMode
              ? '注册客户经理'
              : (_isEdit ? '修改客户经理' : '新增客户经理')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleLeadingPressed,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRequiredField(
                            label: '客户经理编号',
                            hint: '请输入客户经理编号',
                            controller: _managerAccountController,
                            extraValidator: (value) {
                              if (_chineseCharacterRegExp.hasMatch(value)) {
                                return '客户经理编号不能包含中文';
                              }
                              return null;
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(_chineseCharacterRegExp),
                            ],
                          ),
                          _buildRequiredField(
                            label: '团队编码',
                            hint: '请输入团队编码',
                            controller: _groupCodeController,
                          ),
                          _buildRequiredField(
                            label: '客户经理姓名',
                            hint: '请输入客户经理姓名',
                            controller: _managerNameController,
                          ),
                          _buildRequiredField(
                            label: '客户经理手机号',
                            hint: '请输入客户经理手机号',
                            controller: _managerPhoneController,
                            keyboardType: TextInputType.phone,
                            extraValidator: (value) {
                              if (value.length > 15) {
                                return '手机号长度不能超过15位';
                              }
                              return null;
                            },
                            maxLength: 15,
                          ),
                          if (_isRegisterMode) ...[
                            _buildPasswordField(
                              label: '登录密码',
                              hint: '请输入登录密码',
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onToggleObscure: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onChanged: (value) {
                                // 当密码改变时，重新验证确认密码字段
                                if (_confirmPasswordController.text.isNotEmpty) {
                                  _formKey.currentState?.validate();
                                }
                              },
                              extraValidator: (value) {
                                if (value.length < 6) {
                                  return '密码长度不能少于6位';
                                }
                                return null;
                              },
                            ),
                            _buildPasswordField(
                              label: '确认密码',
                              hint: '请再次输入登录密码',
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              onToggleObscure: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                              extraValidator: (value) {
                                if (value != _passwordController.text) {
                                  return '两次输入的密码不一致';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _handleSave(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isRegisterMode ? '注册' : '保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequiredField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String value)? extraValidator,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            readOnly: _isEdit && controller == _managerAccountController,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            validator: (rawValue) {
              final value = rawValue?.trim() ?? '';
              if (value.isEmpty) {
                return '请输入$label';
              }
              if (extraValidator != null) {
                return extraValidator(value);
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    String? Function(String value)? extraValidator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleObscure,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            validator: (rawValue) {
              final value = rawValue?.trim() ?? '';
              if (value.isEmpty) {
                return '请输入$label';
              }
              if (extraValidator != null) {
                return extraValidator(value);
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}


