import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import '../../utils/password_utils.dart';
import '../../data/models/user.dart';
import '../../data/repositories/user_repository.dart';

class ForceResetPwdPage extends StatefulWidget {
  final User user;
  final VoidCallback onPasswordChanged;

  const ForceResetPwdPage({
    super.key,
    required this.user,
    required this.onPasswordChanged,
  });

  @override
  State<ForceResetPwdPage> createState() => _ForceResetPwdPageState();
}

class _ForceResetPwdPageState extends State<ForceResetPwdPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _oldObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePasswordFormat(String password) {
    return PasswordUtils.validatePasswordFormat(password);
  }

  String? _validateOldPassword(String? value) {
    final String password = value?.trim() ?? '';
    if (password.isEmpty) {
      return '请输入原密码';
    }
    if (!BCrypt.checkpw(password, widget.user.password)) {
      return '原密码不正确';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final String password = value?.trim() ?? '';
    if (password.isEmpty) {
      return '请输入新密码';
    }

    // 检查新密码是否与原密码相同
    if (password == _oldPasswordController.text.trim()) {
      return '新密码不能与原密码相同';
    }

    // 验证新密码格式
    final formatError = _validatePasswordFormat(password);
    if (formatError != null) {
      return formatError;
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final String password = value?.trim() ?? '';
    if (password.isEmpty) {
      return '请确认新密码';
    }

    // 验证两次输入的新密码是否一致
    if (password != _newPasswordController.text.trim()) {
      return '两次输入的新密码不一致';
    }

    return null;
  }

  Future<void> _handleChangePassword() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userRepo = UserRepository();
      final newPwdEncrypt = BCrypt.hashpw(_newPasswordController.text.trim(), BCrypt.gensalt());

      await userRepo.updatePassword(
        widget.user.userName,
        newPwdEncrypt,
        DateTime.now(),
      );

      // 标记非首次登录
      await userRepo.setFirstLogin(widget.user.userName, false);

      // 修改密码成功后自动解锁账号
      await userRepo.unlockAccount(widget.user.userName);

      if (mounted) {
        widget.onPasswordChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '密码修改失败: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改密码'),
        automaticallyImplyLeading: false, // 禁用返回按钮，强制用户修改密码
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
                        // 说明信息
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            widget.user.isFirstLogin == true
                                ? '您是首次登录，请修改密码'
                                : '您的密码已超过3个月未修改，请更新密码',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        // 错误信息显示区域
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        _buildPasswordField(
                          label: '原密码',
                          hint: '请输入原密码',
                          controller: _oldPasswordController,
                          obscure: _oldObscure,
                          validator: _validateOldPassword,
                          onObscureChanged: () {
                            setState(() {
                              _oldObscure = !_oldObscure;
                            });
                          },
                        ),

                        _buildPasswordField(
                          label: '新密码',
                          hint: '请输入新密码',
                          controller: _newPasswordController,
                          obscure: _newObscure,
                          validator: _validateNewPassword,
                          helperText: '8位+大小写字母+数字+特殊字符',
                          onObscureChanged: () {
                            setState(() {
                              _newObscure = !_newObscure;
                            });
                          },
                        ),

                        _buildPasswordField(
                          label: '确认新密码',
                          hint: '请再次输入新密码',
                          controller: _confirmPasswordController,
                          obscure: _confirmObscure,
                          validator: _validateConfirmPassword,
                          onObscureChanged: () {
                            setState(() {
                              _confirmObscure = !_confirmObscure;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('确认修改'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    required String? Function(String?) validator,
    String? helperText,
    required VoidCallback onObscureChanged,
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
            obscureText: obscure,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              helperText: helperText,
              helperStyle: const TextStyle(fontSize: 12),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.red),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onObscureChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}