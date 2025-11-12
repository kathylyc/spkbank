import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/user.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/storage_utils.dart';

class AccountManagerAddPage extends StatefulWidget {
  const AccountManagerAddPage({super.key, this.manager});

  final User? manager;

  @override
  State<AccountManagerAddPage> createState() => _AccountManagerAddPageState();
}

class _AccountManagerAddPageState extends State<AccountManagerAddPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _managerAccountController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _managerPhoneController = TextEditingController();
  final UserRepository _userRepository = UserRepository();
  User? _loginUser;
  User? _initialManager;

  final RegExp _chineseCharacterRegExp = RegExp(r'[\u4e00-\u9fff]');
  bool _isSaving = false;

  bool get _isEdit => _initialManager != null;

  @override
  void initState() {
    super.initState();
    _initialManager = widget.manager;
    if (_initialManager != null) {
      _managerAccountController.text = _initialManager!.userName;
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
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _managerAccountController.text.trim() != (_initialManager?.userName ?? '') ||
      _managerNameController.text.trim() != (_initialManager?.nickName ?? '') ||
      _managerPhoneController.text.trim() != (_initialManager?.phoneNumber ?? '');

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
          nickName: managerName,
          phoneNumber: managerPhone.isEmpty ? null : managerPhone,
          updateBy: _loginUser?.userName ?? existing.updateBy,
          updateTime: now,
        );
        await _userRepository.upsert(updated);
      } else {
        final defaultPwdLight = managerAccount;
        final passwordHash = BCrypt.hashpw(defaultPwdLight, BCrypt.gensalt());
        final newManager = User(
          userName: managerAccount,
          nickName: managerName,
          userType: '01',
          phoneNumber: managerPhone.isEmpty ? null : managerPhone,
          password: passwordHash,
          status: '0',
          createBy: _loginUser?.userName,
          createTime: now,
        );
        await _userRepository.upsert(newManager);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $error')),
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
          title: Text(_isEdit ? '修改客户经理' : '新增客户经理'),
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
                      child: const Text('保存'),
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
}


