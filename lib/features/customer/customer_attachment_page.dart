import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/models/customer.dart';
import '../../data/models/customer_attachment_file.dart';
import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';
import '../../utils/storage_utils.dart';

class CustomerAttachmentPage extends StatefulWidget {
  const CustomerAttachmentPage({
    super.key,
    required this.customer,
  });

  final Customer customer;

  @override
  State<CustomerAttachmentPage> createState() => _CustomerAttachmentPageState();
}

class _CustomerAttachmentPageState extends State<CustomerAttachmentPage> {
  final CustomerRepository _customerRepository = CustomerRepository();

  User? _loginUser;
  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, _AttachmentState> _attachmentStates = {};

  static const List<_AttachmentConfig> _attachmentConfigs = [
    _AttachmentConfig(
      type: 'id_front',
      title: '身份证正面',
    ),
    _AttachmentConfig(
      type: 'id_back',
      title: '身份证背面',
    ),
    _AttachmentConfig(
      type: 'business_license',
      title: '营业执照',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final String customerUid = widget.customer.customerUid;
      final results = await Future.wait([
        StorageUtils.getLoginUser(),
        _customerRepository.findAttachmentFiles(customerUid),
      ]);

      final User? loginUser = results[0] as User?;
      final List<CustomerAttachmentFile> attachmentFiles =
          results[1] as List<CustomerAttachmentFile>;
      final Map<String, _AttachmentState> states = {
        for (final config in _attachmentConfigs)
          config.type: _AttachmentState(
            existingPath: attachmentFiles
                .where((file) => file.attachmentType == config.type)
                .map((file) => file.filePath)
                .lastOrNull,
          ),
      };

      if (!mounted) {
        return;
      }
      setState(() {
        _loginUser = loginUser;
        _attachmentStates
          ..clear()
          ..addAll(states);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载附件信息失败: $error')),
      );
    }
  }

  Future<void> _pickFile(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final selected = result.files.single;
      final String? path = selected.path;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取文件路径，请重试')),
        );
        return;
      }
      if (!await File(path).exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在，请重新选择')),
        );
        return;
      }
      setState(() {
        _attachmentStates[type] = _attachmentStates[type]?.copyWith(
              selectedPath: path,
              selectedName: selected.name,
            ) ??
            _AttachmentState(
              selectedPath: path,
              selectedName: selected.name,
            );
      });
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败: $error')),
      );
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) {
      return;
    }
    final selectedEntries = _attachmentStates.entries
        .where((entry) => entry.value.selectedPath != null)
        .toList();
    if (selectedEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要上传的附件')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DateTime now = DateTime.now();
      for (final entry in selectedEntries) {
        final String type = entry.key;
        final String filePath = entry.value.selectedPath!;
        final CustomerAttachmentFile entity = CustomerAttachmentFile(
          customerUid: widget.customer.customerUid,
          attachmentType: type,
          filePath: filePath,
          createBy: _loginUser?.userName,
          createTime: now,
          updateBy: _loginUser?.userName,
          updateTime: now,
        );
        await _customerRepository.addAttachmentFile(entity);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('上传客户附件'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerInfoCard(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _attachmentConfigs
                              .map((config) => _buildAttachmentTile(config))
                              .toList(),
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
                        child: Text(_isSaving ? '保存中...' : '保存'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    final Customer customer = widget.customer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '客户姓名: ${customer.customerName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '客户手机号: ${customer.phone?.isNotEmpty == true ? customer.phone : '-'}',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            '客户地址: ${customer.address?.isNotEmpty == true ? customer.address : '-'}',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(_AttachmentConfig config) {
    final _AttachmentState state = _attachmentStates[config.type] ?? const _AttachmentState();
    final String? selectedName = state.selectedName;
    final String? selectedPath = state.selectedPath;
    final String? existingPath = state.existingPath;
    final String? existingName =
        existingPath == null ? null : p.basename(existingPath);

    String displayText;
    if (selectedName != null) {
      displayText = selectedName;
    } else if (existingName != null) {
      displayText = '已上传: $existingName';
    } else {
      displayText = '暂未选择文件';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: selectedName != null || existingName != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _pickFile(config.type),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(selectedPath != null ? '重新上传' : '上传'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentConfig {
  const _AttachmentConfig({
    required this.type,
    required this.title,
  });

  final String type;
  final String title;
}

class _AttachmentState {
  const _AttachmentState({
    this.selectedPath,
    this.selectedName,
    this.existingPath,
  });

  final String? selectedPath;
  final String? selectedName;
  final String? existingPath;

  _AttachmentState copyWith({
    String? selectedPath,
    String? selectedName,
    String? existingPath,
  }) {
    return _AttachmentState(
      selectedPath: selectedPath ?? this.selectedPath,
      selectedName: selectedName ?? this.selectedName,
      existingPath: existingPath ?? this.existingPath,
    );
  }
}

extension<T> on Iterable<T> {
  T? get lastOrNull {
    if (isEmpty) return null;
    return last;
  }
}

