import 'package:bank_flutter/utils/file_manager.dart';
import 'package:bank_flutter/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../data/models/customer.dart';
import '../../data/models/customer_attachment_file.dart';
import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/common_const.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/storage_utils.dart';

class CustomerAddPage extends StatefulWidget {
  const CustomerAddPage({super.key, this.customer});

  final Customer? customer;

  @override
  State<CustomerAddPage> createState() => _CustomerAddPageState();
}

class _CustomerAddPageState extends State<CustomerAddPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _managerAccountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final CustomerRepository _customerRepository = CustomerRepository();
  final UserRepository _userRepository = UserRepository();
  bool get _isAccountManager => _loginUser?.userType == '01';

  User? _loginUser;
  Customer? _initialCustomer;

  final Set<String> _selectedTags = <String>{};
  String _selectedCountryCode = 'CN';
  bool _isSaving = false;

  // 附件相关数据
  final List<_AttachmentInfo> _attachments = <_AttachmentInfo>[];
  List<_AttachmentInfo> _initialAttachments = <_AttachmentInfo>[];

  bool get _isEdit => _initialCustomer != null;

  static const List<_TagOption> _tagOptions = [
    _TagOption(ConstCustomerTag.keyCustomer, '大客户'),
    _TagOption(ConstCustomerTag.publicOfficials, '公职人员'),
    _TagOption(ConstCustomerTag.highQualityCredit, '优质征信'),
  ];

  static const List<_CountryOption> _countryOptions = [
    _CountryOption(code: 'CN', dialCode: '+86', label: '中国 (+86)'),
    _CountryOption(code: 'HK', dialCode: '+852', label: '中国香港 (+852)'),
    _CountryOption(code: 'MO', dialCode: '+853', label: '中国澳门 (+853)'),
    _CountryOption(code: 'TW', dialCode: '+886', label: '中国台湾 (+886)'),
    _CountryOption(code: 'SG', dialCode: '+65', label: '新加坡 (+65)'),
    _CountryOption(code: 'US', dialCode: '+1', label: '美国 (+1)'),
    _CountryOption(code: 'GB', dialCode: '+44', label: '英国 (+44)'),
  ];

  @override
  void initState() {
    super.initState();
    _initialCustomer = widget.customer;
    if (_initialCustomer != null) {
      _nameController.text = _initialCustomer!.customerName;
      _managerAccountController.text = _initialCustomer!.managerAccount;
      _phoneController.text = _initialCustomer!.phone ?? '';
      _addressController.text = _initialCustomer!.address ?? '';
      _selectedCountryCode = _resolveCountryCode(_initialCustomer!.countryCode);
      _selectedTags
        ..clear()
        ..addAll(_parseTags(_initialCustomer!.customerTag));
    } else {
      _selectedCountryCode = _countryOptions.first.code;
    }
    _loadUserInfo();
    if (_isEdit) {
      _loadAttachments();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _managerAccountController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// 加载当前登录用户信息
  Future<void> _loadUserInfo() async {
    final User? loginUser = await StorageUtils.getLoginUser();
    if (mounted) {
      setState(() {
        _loginUser = loginUser;
        if (!_isEdit && _isAccountManager) {
          _managerAccountController.text = _loginUser!.userName;
        }
      });
    }
  }

  /// 加载客户的附件信息
  Future<void> _loadAttachments() async {
    if (_initialCustomer == null) return;

    try {
      final attachmentFiles = await _customerRepository.findAttachmentFiles(_initialCustomer!.customerUid);

      final List<_AttachmentInfo> loadedAttachments = [];
      for (final attachmentFile in attachmentFiles) {
        // 从文件路径中提取文件名
        final filePath = attachmentFile.filePath;
        final fileName = filePath.split('/').last;

        // 检查文件是否存在以获取文件大小
        final file = File(filePath);
        int fileSize = 0;
        if (await file.exists()) {
          fileSize = await file.length();
        }

        loadedAttachments.add(_AttachmentInfo(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSize,
        ));
      }

      if (mounted) {
        setState(() {
          _attachments.clear();
          _attachments.addAll(loadedAttachments);
          // 保存初始附件列表的副本
          _initialAttachments = List<_AttachmentInfo>.from(_attachments);
        });
      }
    } catch (e) {
      debugPrint('加载附件失败: $e');
      // 不显示错误提示，避免影响用户体验
    }
  }

  bool get _hasUnsavedChanges {
    final String initialTagString = _normalizeTags(_initialCustomer?.customerTag);
    final String currentTagString = _normalizeTags(_joinTags(_selectedTags));
    final String initialCountryCode = _resolveCountryCode(_initialCustomer?.countryCode);

    // 检查附件是否有变更
    final bool attachmentsChanged = _attachments.length != _initialAttachments.length ||
        !_attachments.every((attachment) => _initialAttachments.any((initial) =>
            initial.fileName == attachment.fileName &&
            initial.filePath == attachment.filePath));

    return _nameController.text.trim() != (_initialCustomer?.customerName ?? '') ||
        _managerAccountController.text.trim() != (_initialCustomer?.managerAccount ?? '') ||
        _selectedCountryCode != initialCountryCode ||
        _phoneController.text.trim() != (_initialCustomer?.phone ?? '') ||
        _addressController.text.trim() != (_initialCustomer?.address ?? '') ||
        currentTagString != initialTagString ||
        attachmentsChanged;
  }

  Future<bool> _handleWillPop() async {
    // WillPopScope 总是允许返回，主要逻辑在 _handleLeadingPressed 中处理
    return true;
  }

  Future<bool?> _showUnsavedConfirmDialog() async {
    bool? result = await DialogUtils.confirm(
      context: context,
      title: '提示',
      content: '您还未保存，确定退出吗？',
    );
    return result;
  }

  Future<void> _handleLeadingPressed() async {
    if (!_hasUnsavedChanges) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final shouldExit = await _showUnsavedConfirmDialog();

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final String customerName = _nameController.text.trim();
    final String managerAccount = _managerAccountController.text.trim();
    final String countryCode = _selectedCountryCode;
    final String phone = _phoneController.text.trim();
    final String address = _addressController.text.trim();
    final String company = ''; // 20251210 UPDATE：客户名称就是公司，所以公司字段至为空
    final String? customerTag = _selectedTags.isEmpty ? '' : _joinTags(_selectedTags);

    setState(() {
      _isSaving = true;
    });

    try {
      // 检查客户经理关联
      final User? manager = await _userRepository.findByUserName(managerAccount);
      if (manager == null) {
        if (!mounted) return;
        SnackbarUtils.error('客户经理不存在，请检查编号', context);
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // 检查客户名称是否已存在
      final nameExists = await _customerRepository.isCustomerNameExists(
        customerName,
        managerAccount,
        excludeCustomerUid: _isEdit ? _initialCustomer!.customerUid : null
      );
      if (nameExists) {
        if (!mounted) return;
        SnackbarUtils.error('客户名称已存在，请使用其他名称', context);
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // 检查客户联系电话是否已存在
      if (phone.isNotEmpty) {
        final phoneExists = await _customerRepository.isPhoneExists(
          phone,
          excludeCustomerUid: _isEdit ? _initialCustomer!.customerUid : null
        );
        if (phoneExists) {
          if (!mounted) return;
          SnackbarUtils.error('联系电话已存在，请使用其他电话号码', context);
          setState(() {
            _isSaving = false;
          });
          return;
        }
      }

      final DateTime now = DateTime.now();

      Customer customer;
      if (_isEdit) {
        final Customer existing = _initialCustomer!;
        customer = existing.copyWith(
          customerName: customerName,
          managerAccount: managerAccount,
          countryCode: countryCode,
          phone: phone.isEmpty ? null : phone,
          address: address.isEmpty ? null : address,
          company: company,
          customerTag: customerTag,
          updateBy: _loginUser?.userName ?? existing.updateBy,
          updateTime: now,
        );
        await _customerRepository.upsert(customer);
      } else {
        customer = await _customerRepository.create(
          customerName: customerName,
          countryCode: countryCode,
          managerAccount: managerAccount,
          phone: phone.isEmpty ? null : phone,
          address: address.isEmpty ? null : address,
          company: company,
          customerTag: customerTag,
          createBy: _loginUser?.userName,
          createTime: now,
        );
      }

      // 处理附件信息
      if (_isEdit) {
        // 编辑模式：比较附件变更
        final existingAttachments = await _customerRepository.findAttachmentFiles(customer.customerUid);

        // 找出需要删除的附件（在初始列表中但不在当前列表中）
        for (final existing in existingAttachments) {
          final bool isDeleted = !_attachments.any((current) =>
            current.filePath == existing.filePath && current.fileName == existing.filePath.split('/').last);

          if (isDeleted) {
            await _customerRepository.deleteAttachmentFile(existing.id!);
            // 删除附件文件
            await FileManager.deleteCustomerAttachment(existing.filePath);
          }
        }

        // 找出需要新增的附件（在当前列表中但不在初始列表中）
        for (final attachment in _attachments) {
          final bool isNew = !_initialAttachments.any((initial) =>
            initial.fileName == attachment.fileName && initial.filePath == attachment.filePath);

          if (isNew) {
            final attachmentFile = CustomerAttachmentFile(
              customerUid: customer.customerUid,
              filePath: await FileManager.saveCustomerAttachment(sourcePath: attachment.filePath, customerUid: customer.customerUid),
              createBy: _loginUser?.userName,
              createTime: now,
            );
            await _customerRepository.addAttachmentFile(attachmentFile);
          }
        }
      } else {
        // 新增模式：保存所有附件
        for (final attachment in _attachments) {
          final attachmentFile = CustomerAttachmentFile(
            customerUid: customer.customerUid,
            filePath: await FileManager.saveCustomerAttachment(sourcePath: attachment.filePath, customerUid: customer.customerUid),
            createBy: _loginUser?.userName,
            createTime: now,
          );
          await _customerRepository.addAttachmentFile(attachmentFile);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      SnackbarUtils.error('保存失败: $error', context);
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
          title: Text(_isEdit ? '修改客户' : '新增客户'),
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
                          _buildField(
                            label: '客户经理编号',
                            hint: '请输入客户经理编号',
                            controller: _managerAccountController,
                            requiredField: true,
                            enabled: !_isAccountManager && !_isEdit,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            ],
                          ),
                          if (_isEdit)
                            _buildReadOnlyField(
                              label: '客户编号',
                              value: _initialCustomer!.customerUid,
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Text(
                                '客户编号将在保存后自动生成',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ),
                          // _buildField(
                          //   label: '客户姓名',
                          //   hint: '请输入客户姓名',
                          //   controller: _nameController,
                          //   requiredField: true,
                          // ),
                          _buildField(
                            label: '公司名称（中文/英文）',
                            hint: '请输入公司名称（中文/英文）',
                            controller: _nameController,
                            requiredField: true,
                          ),
                          _buildPhoneField(),
                          _buildField(
                            label: '联系地址',
                            hint: '请输入联系地址',
                            controller: _addressController,
                            maxLines: 3,
                          ),
                          _buildTagSelector(),
                          _buildAttachmentUpload(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
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

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool requiredField = false,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
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
              if (requiredField) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
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
              final String value = rawValue?.trim() ?? '';
              if (requiredField && value.isEmpty) {
                return '请输入$label';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    final List<_CountryOption> options = List<_CountryOption>.from(_countryOptions);
    _CountryOption selectedOption;
    final String normalizedCode = _selectedCountryCode.toUpperCase();
    final maybeOption = options.where((option) => option.code == normalizedCode);
    if (maybeOption.isNotEmpty) {
      selectedOption = maybeOption.first;
    } else {
      final _CountryOption customOption = _CountryOption(
        code: normalizedCode,
        dialCode: normalizedCode,
        label: normalizedCode,
      );
      options.add(customOption);
      selectedOption = customOption;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '联系电话',
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SizedBox(
              //   width: 120,
              //   child: DropdownButtonFormField<String>(
              //     initialValue: selectedOption.code,
              //     decoration: InputDecoration(
              //       border: OutlineInputBorder(
              //         borderRadius: BorderRadius.circular(4),
              //         borderSide: BorderSide(color: Colors.grey.shade300),
              //       ),
              //       enabledBorder: OutlineInputBorder(
              //         borderRadius: BorderRadius.circular(4),
              //         borderSide: BorderSide(color: Colors.grey.shade300),
              //       ),
              //       focusedBorder: OutlineInputBorder(
              //         borderRadius: BorderRadius.circular(4),
              //         borderSide: const BorderSide(color: Colors.blue),
              //       ),
              //       contentPadding: const EdgeInsets.symmetric(
              //         horizontal: 12,
              //         vertical: 12,
              //       ),
              //     ),
              //     items: options
              //         .map(
              //           (option) => DropdownMenuItem<String>(
              //             value: option.code,
              //             child: Text(option.dialCode),
              //           ),
              //         )
              //         .toList(),
              //     onChanged: (value) {
              //       if (value == null) return;
              //       setState(() {
              //         _selectedCountryCode = value;
              //       });
              //     },
              //   ),
              // ),
              // const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\s-]')),
                  ],
                  maxLength: 20,
                  decoration: InputDecoration(
                    hintText: '请输入客户电话',
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
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    final String phone = value?.trim() ?? '';
                    if (phone.isEmpty) {
                      return '请输入联系电话';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade100,
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '客户标签',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(可多选)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tagOptions.map((option) {
              final bool isSelected = _selectedTags.contains(option.value);
              return FilterChip(
                label: Text(option.label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(option.value);
                    } else {
                      _selectedTags.remove(option.value);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentUpload() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '客户信息附件',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(仅支持jpg，png，pdf格式，最多上传3个附件，每个大小不超过5MB。)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 显示已上传的附件列表
          ..._attachments.asMap().entries.map((entry) {
            final index = entry.key;
            final attachment = entry.value;
            return _buildAttachmentItem(attachment, index);
          }),
          // 上传按钮（当附件数量小于3个时显示）
          if (_attachments.length < 3)
            _buildUploadButton(),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(_AttachmentInfo attachment, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                attachment.fileName,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteAttachmentDialog(attachment, index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示删除附件确认对话框
  Future<void> _showDeleteAttachmentDialog(_AttachmentInfo attachment, int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除附件 "${attachment.fileName}" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      setState(() {
        _attachments.removeAt(index);
      });
    }
  }

  Widget _buildUploadButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file, color: Colors.blue),
          label: const Text(
            '上传附件',
            style: TextStyle(color: Colors.blue),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  /// 选择文件
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;

        // 检查文件大小（5MB = 5 * 1024 * 1024 bytes）
        const maxSize = 5 * 1024 * 1024;
        if (fileSize > maxSize) {
          if (!mounted) return;
          SnackbarUtils.error('文件大小不能超过5MB', context);
          return;
        }

        // 检查是否已达到最大数量
        if (_attachments.length >= 3) {
          if (!mounted) return;
          SnackbarUtils.error('最多只能上传3个附件', context);
          return;
        }

        setState(() {
          _attachments.add(_AttachmentInfo(
            fileName: fileName,
            filePath: file.path,
            fileSize: fileSize,
          ));
        });
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error('选择文件失败: $e', context);
    }
  }

  String _resolveCountryCode(String? rawCode) {
    if (rawCode == null || rawCode.trim().isEmpty) {
      return _countryOptions.first.code;
    }
    final String normalized = rawCode.trim().toUpperCase();
    final bool exists = _countryOptions.any((option) => option.code == normalized);
    if (exists) {
      return normalized;
    }
    return normalized;
  }

  Set<String> _parseTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet();
  }

  String _joinTags(Set<String> tags) {
    final List<String> sorted = tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList()
      ..sort();
    return sorted.join(',');
  }

  String _normalizeTags(String? raw) {
    return _joinTags(_parseTags(raw));
  }
}

class _TagOption {
  const _TagOption(this.value, this.label);

  final String value;
  final String label;
}

class _CountryOption {
  const _CountryOption({
    required this.code,
    required this.dialCode,
    required this.label,
  });

  final String code;
  final String dialCode;
  final String label;
}

class _AttachmentInfo {
  const _AttachmentInfo({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
  });

  final String fileName;
  final String filePath;
  final int fileSize;
}

