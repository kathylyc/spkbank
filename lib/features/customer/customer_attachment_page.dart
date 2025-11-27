import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/models/customer.dart';
import '../../data/models/customer_attachment_file.dart';
import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';
import '../../utils/common_const.dart';
import '../../utils/file_manager.dart';
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
      type: ConstCustomerAttachmentType.idCardFront,
      title: '身份证正面',
    ),
    _AttachmentConfig(
      type: ConstCustomerAttachmentType.idCardBack,
      title: '身份证背面',
    ),
    _AttachmentConfig(
      type: ConstCustomerAttachmentType.businessLicense,
      title: '营业执照',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    // 清理 file_picker 生成的临时文件
    FilePicker.platform.clearTemporaryFiles().catchError((error) {
      debugPrint('清理 file_picker 临时文件失败: $error');
    });
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final String customerUid = widget.customer.customerUid;
      final results = await Future.wait([
        StorageUtils.getLoginUser(),
        _customerRepository.findAttachmentFiles(customerUid),
      ]);

      final User? loginUser = results[0] as User?;
      List<CustomerAttachmentFile> attachmentFiles =
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

  void _clearFile(String type) {
    setState(() {
      final currentState = _attachmentStates[type];
      if (currentState != null) {
        _attachmentStates[type] = currentState.copyWith(
          clearSelectedPath: true,
          clearSelectedName: true,
          clearExistingPath: true,
        );
      }
    });
  }

  bool _isImageFile(String? filePath) {
    if (filePath == null) return false;
    final extension = p.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension);
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
      final String customerUid = widget.customer.customerUid;
      
      for (final entry in selectedEntries) {
        final String attachmentType = entry.key; // 已经是常量值
        final String sourcePath = entry.value.selectedPath!;
        
        // 先复制文件到沙盒目录
        final String sandboxPath = await FileManager.saveCustomerAttachment(
          sourcePath: sourcePath,
          customerUid: customerUid,
          attachmentType: attachmentType,
        );
        
        // 检查是否已存在该类型的附件
        final existingFiles = await _customerRepository.findAttachmentFilesByType(
          customerUid,
          attachmentType,
        );
        
        if (existingFiles.isNotEmpty) {
          // 如果存在，执行 update
          final existingFile = existingFiles.first;
          
          // 删除旧文件（如果存在且与新文件路径不同）
          if (existingFile.filePath != sandboxPath) {
            try {
              await FileManager.deleteCustomerAttachment(existingFile.filePath);
            } catch (e) {
              // 忽略删除旧文件失败的错误
              debugPrint('删除旧文件失败: $e');
            }
          }
          
          final updatedEntity = existingFile.copyWith(
            filePath: sandboxPath,
            updateBy: _loginUser?.userName,
            updateTime: now,
          );
          await _customerRepository.updateAttachmentFile(updatedEntity);
        } else {
          // 如果不存在，执行 insert
          final newEntity = CustomerAttachmentFile(
            customerUid: customerUid,
            attachmentType: attachmentType,
            filePath: sandboxPath,
            createBy: _loginUser?.userName,
            createTime: now,
            updateBy: _loginUser?.userName,
            updateTime: now,
          );
          await _customerRepository.addAttachmentFile(newEntity);
        }
      }

      // 保存成功后，清理 file_picker 生成的临时文件
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (e) {
        debugPrint('清理 file_picker 临时文件失败: $e');
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
      
      // 保存失败时，也清理 file_picker 生成的临时文件
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (e) {
        debugPrint('清理 file_picker 临时文件失败: $e');
      }
      
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
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.7,
                          mainAxisExtent: 310,
                        ),
                        itemCount: _attachmentConfigs.length,
                        itemBuilder: (context, index) {
                          return _buildAttachmentTile(_attachmentConfigs[index]);
                        },
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

    String? previewPath = selectedPath ?? existingPath;
    final bool hasFile = previewPath != null;

    return FutureBuilder<String?>(
      future: hasFile ? FileManager.getFullPath(previewPath) : Future.value(null),
      builder: (context, snapshot) {
        String? fullPath = snapshot.data;
        final bool isImage = _isImageFile(fullPath);

        String displayText;
        if (selectedName != null) {
          displayText = selectedName;
        } else if (existingName != null) {
          displayText = '已上传: $existingName';
        } else {
          displayText = '点击选择文件';
        }

        return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            config.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // 预览区域（始终显示）
          InkWell(
            onTap: () => _pickFile(config.type),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade100,
              ),
              child: hasFile
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isImage && fullPath != null
                          ? Image.file(
                              File(fullPath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
                            ),
                    )
                  : const Center(
                      child: Icon(Icons.add, size: 48, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 13,
              color: selectedName != null || existingName != null
                  ? Colors.black87
                  : Colors.grey.shade500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: ElevatedButton(
                  onPressed: () => _pickFile(config.type),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    selectedPath != null ? '重新上传' : '上传',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (hasFile) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () => _clearFile(config.type),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('清除', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
        );
      },
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
    bool clearSelectedPath = false,
    bool clearSelectedName = false,
    bool clearExistingPath = false,
  }) {
    return _AttachmentState(
      selectedPath: clearSelectedPath ? null : (selectedPath ?? this.selectedPath),
      selectedName: clearSelectedName ? null : (selectedName ?? this.selectedName),
      existingPath: clearExistingPath ? null : (existingPath ?? this.existingPath),
    );
  }
}

extension<T> on Iterable<T> {
  T? get lastOrNull {
    if (isEmpty) return null;
    return last;
  }
}

