import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/file_manager.dart';
import '../../utils/storage_utils.dart';
import '../../widgets/common_data_table_page.dart';
import 'account_manager_add_page.dart';

/// 客户经理管理页面
class AccountManagerPage extends StatefulWidget {
  const AccountManagerPage({super.key});

  @override
  State<AccountManagerPage> createState() => _AccountManagerPageState();
}

class _AccountManagerPageState extends State<AccountManagerPage> {
  // 查询条件
  final TextEditingController _managerCodeController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _managerPhoneController = TextEditingController();
  final CustomerRepository _customerRepository = CustomerRepository();
  final UserRepository _userRepository = UserRepository();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  
  static const int _itemsPerPage = 20;
  
  // 分页
  int _currentPage = 1;
  int _totalItems = 0;
  
  // 表格数据
  List<Map<String, dynamic>> _tableData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _managerCodeController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  /// 加载数据
  Future<void> _loadData() async {
    final managerCodeKeyword = _managerCodeController.text.trim();
    final managerNameKeyword = _managerNameController.text.trim();
    final managerPhoneKeyword = _managerPhoneController.text.trim();

    try {
      final totalItems = await _userRepository.countManagers(
        accountKeyword: managerCodeKeyword,
        nameKeyword: managerNameKeyword,
        phoneKeyword: managerPhoneKeyword,
      );
      final totalPages = (totalItems / _itemsPerPage).ceil();
      int currentPage = _currentPage;
      if (totalPages == 0) {
        currentPage = 1;
      } else if (currentPage > totalPages) {
        currentPage = totalPages;
      }

      final offset = totalItems == 0 ? 0 : (currentPage - 1) * _itemsPerPage;
      final managers = totalItems == 0
          ? <User>[]
          : await _userRepository.findManagers(
              limit: _itemsPerPage,
              offset: offset,
              accountKeyword: managerCodeKeyword,
              nameKeyword: managerNameKeyword,
              phoneKeyword: managerPhoneKeyword,
            );

      final managerAccounts = managers.map((user) => user.userName).toList();
      final statsList = await _customerRepository.findManagerStats(managerAccounts);
      final statsByAccount = {
        for (final stat in statsList) stat.managerAccount: stat,
      };

      final tableData = <Map<String, dynamic>>[];
      for (int index = 0; index < managers.length; index++) {
        final manager = managers[index];
        final stats = statsByAccount[manager.userName];
        final displayIndex = offset + index + 1;
        final displayName = manager.nickName.isNotEmpty ? manager.nickName : manager.userName;
        final phone = manager.phoneNumber;
        final latestEntry = stats?.latestEntryTime;

        tableData.add({
          'id': displayIndex,
          'managerAccount': manager.userName,
          'managerCode': manager.userName,
          'managerName': displayName,
          'managerPhone': (phone != null && phone.isNotEmpty) ? phone : '-',
          'customerCount': stats?.customerCount ?? 0,
          'entryTime': latestEntry != null
              ? _dateFormatter.format(latestEntry)
              : '-',
        });
      }

      if (!mounted) return;
      setState(() {
        _currentPage = currentPage;
        _totalItems = totalItems;
        _tableData = tableData;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载客户经理数据失败: $error')),
      );
      setState(() {
        _currentPage = 1;
        _totalItems = 0;
        _tableData = [];
      });
    }
  }

  /// 查询
  void _handleQuery() {
    _currentPage = 1;
    _loadData();
  }

  /// 重置
  void _handleReset() {
    _managerCodeController.clear();
    _managerNameController.clear();
    _managerPhoneController.clear();
    _currentPage = 1;
    _loadData();
  }

  /// 页码变化
  void _handlePageChanged(int page) {
    _currentPage = page;
    _loadData();
  }

  /// 删除客户经理
  Future<void> _handleDeleteManager(Map<String, dynamic> row) async {
    final managerAccount = row['managerAccount'] as String?;
    final managerName = row['managerName'] as String?;
    
    if (managerAccount == null || managerAccount.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取客户经理编号')),
        );
      }
      return;
    }

    try {
      // 检查客户的开户文件数量
      final accountFileCount = await _customerRepository.countAccountFiles(
        managerAccount: managerAccount,
      );

      if (accountFileCount > 0) {
        // 存在关联信息，不可删除
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('存在关联信息，不可删除'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 开户文件数量为0，提示确认删除
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认删除'),
          content: const Text('该操作不可逆，是否确认删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('确认'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      // 获取该客户经理的所有客户
      final customers = await _customerRepository.findByManager(managerAccount);

      // 删除所有客户的附件文件
      for (final customer in customers) {
        final attachmentFiles = await _customerRepository.findAttachmentFiles(customer.customerUid);
        for (final attachmentFile in attachmentFiles) {
          try {
            // 删除本机附件文件
            await FileManager.deleteCustomerAttachment(attachmentFile.filePath);
            // 删除数据库记录
            await _customerRepository.deleteAttachmentFile(attachmentFile.id!);
          } catch (e) {
            debugPrint('删除客户附件文件失败: ${attachmentFile.filePath}, 错误: $e');
            // 继续删除其他文件，不中断流程
          }
        }
      }

      // 删除客户经理
      final manager = await _userRepository.findByUserName(managerAccount);
      if (manager != null && manager.id != null) {
        await _userRepository.deleteById(manager.id!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除: ${managerName ?? managerAccount}'),
            backgroundColor: Colors.green,
          ),
        );
        // 重新加载数据
        _loadData();
      }
    } catch (error) {
      debugPrint('删除客户经理失败: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 新增客户经理
  Future<void> _handleAddManager() async {
    final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => const AccountManagerAddPage(),
          ),
        ) ??
        false;

    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      _loadData();
    }
  }

  /// 获取Downloads目录
  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final rootPath = externalDir.path.split('/Android')[0];
          final downloadsDir = Directory(p.join(rootPath, 'Download'));
          if (!await downloadsDir.exists()) {
            final downloadsDirAlt = Directory(p.join(rootPath, 'Downloads'));
            if (await downloadsDirAlt.exists()) {
              return downloadsDirAlt;
            }
            await downloadsDir.create(recursive: true);
          }
          return downloadsDir;
        }
      } catch (e) {
        debugPrint('获取Android Downloads目录失败: $e');
      }
    } else if (Platform.isIOS) {
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory(p.join(documentsDir.path, 'Downloads'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      } catch (e) {
        debugPrint('获取iOS Downloads目录失败: $e');
      }
    }
    return null;
  }

  /// 下载导入模板 - 将assets中的Excel文件复制到Downloads目录
  void _handleDownloadTemplate() async {
    const assetPath = 'assets/excel/customer_manager_info.xlsx';
    const fileName = 'customer_manager_info.xlsx';

    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在下载导入模板...'),
          duration: Duration(seconds: 2),
        ),
    );
    }

    try {
      final downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('无法获取Downloads目录，请检查存储权限');
      }

      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      final targetPath = p.join(downloadsDir.path, fileName);
      final targetFile = File(targetPath);

      String finalPath = targetPath;
      if (await targetFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        finalPath = p.join(downloadsDir.path, '${nameWithoutExt}_$timestamp$ext');
      }

      await File(finalPath).writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('导入模板下载成功'),
                const SizedBox(height: 4),
                Text(
                  '保存为: ${p.basename(finalPath)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('下载导入模板失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载导入模板失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 提示输入解压密码
  Future<String?> _promptUnzipPassword() async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('输入解压密码'),
              content: TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '解压密码',
                  hintText: '请输入密码',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final password = controller.text.trim();
                    if (password.isEmpty) {
                      setState(() {
                        errorText = '密码不能为空';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(password);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    // 延迟 dispose，确保 dialog 完全关闭后再清理 controller
    Future.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });
    return result;
  }

  /// 导入客户经理
  Future<void> _handleImportManager() async {
    try {
      // 获取下载目录作为初始目录
      final downloadsDir = await _getDownloadsDirectory();
      String? initialDirectory;
      if (downloadsDir != null) {
        initialDirectory = downloadsDir.path;
      }

      // 弹出文件浏览器，仅可选择 zip 包
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        initialDirectory: initialDirectory,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selectedFile = result.files.single;
      final String? zipFilePath = selectedFile.path;
      if (zipFilePath == null) {
        if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法获取文件路径，请重试'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文件不存在，请重新选择'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 弹出密码输入对话框
      final password = await _promptUnzipPassword();
      if (password == null) {
        return;
      }

      // 显示加载对话框
      if (mounted) {
        _showLoadingDialog(message: '正在导入客户经理数据...');
      }

      // 获取 cache/import 目录
      final cacheDir = await getTemporaryDirectory();
      final importDir = Directory(p.join(cacheDir.path, 'import'));
      if (!await importDir.exists()) {
        await importDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final importCurrentDir = Directory(p.join(importDir.path, '$timestamp'));
      if (!await importCurrentDir.exists()) {
        await importCurrentDir.create(recursive: true);
      }

      // 复制 zip 文件到 cache/import 目录
      final targetZipName = 'import_$timestamp.zip';
      final targetZipPath = p.join(importCurrentDir.path, targetZipName);
      final targetZipFile = File(targetZipPath);
      await zipFile.copy(targetZipPath);

      // 解压 zip 文件
      try {
        final zipBytes = await targetZipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(zipBytes, password: password);

        // 解压到 cache/import 目录
        for (final file in archive) {
          final filePath = p.join(importCurrentDir.path, file.name);
          if (file.isFile) {
            final outFile = File(filePath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            await Directory(filePath).create(recursive: true);
          }
        }

        // TODO:
        // 检查是否包含名字以customer_manager_info开头的xlsx文件
        File? excelFile;
        final importFiles = importCurrentDir.listSync();
        for (final file in importFiles) {
          if (file is File) {
            final fileName = p.basename(file.path);
            if (fileName.toLowerCase().startsWith('customer_manager_info') && 
                fileName.toLowerCase().endsWith('.xlsx')) {
              excelFile = file;
              break;
            }
          }
        }

        if (excelFile == null || !await excelFile.exists()) {
          // 删除临时文件
          try {
            if (await targetZipFile.exists()) {
              await targetZipFile.delete();
            }
            if (await importCurrentDir.exists()) {
              await importCurrentDir.delete(recursive: true);
            }
          } catch (deleteError) {
            debugPrint('删除临时文件失败: $deleteError');
          }

          _hideLoadingDialog();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('非标准压缩包，不支持导入1'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // 读取 Excel 文件并检查表头
        final excelBytes = await excelFile.readAsBytes();
        final excelBook = excel.Excel.decodeBytes(excelBytes);
        final sheetName = excelBook.tables.isNotEmpty
            ? excelBook.tables.keys.first
            : (excelBook.sheets.isNotEmpty ? excelBook.sheets.keys.first : null);
        if (sheetName == null) {
          // 删除临时文件
          try {
            if (await targetZipFile.exists()) {
              await targetZipFile.delete();
            }
            if (await importCurrentDir.exists()) {
              await importCurrentDir.delete(recursive: true);
            }
          } catch (deleteError) {
            debugPrint('删除临时文件失败: $deleteError');
          }

          _hideLoadingDialog();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('非标准压缩包，不支持导入2'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        final sheet = excelBook[sheetName];
        if (sheet == null) {
          // 删除临时文件
          try {
            if (await targetZipFile.exists()) {
              await targetZipFile.delete();
            }
            if (await importCurrentDir.exists()) {
              await importCurrentDir.delete(recursive: true);
            }
          } catch (deleteError) {
            debugPrint('删除临时文件失败: $deleteError');
          }

          _hideLoadingDialog();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('非标准压缩包，不支持导入2'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // 检查前三列表头
        const expectedHeaders = ['客户经理编号', '客户经理姓名', '客户经理手机号码'];
        final headerRow = sheet.rows[0];
        if (headerRow.length < 3) {
          // 删除临时文件
          try {
            if (await targetZipFile.exists()) {
              await targetZipFile.delete();
            }
            if (await importCurrentDir.exists()) {
              await importCurrentDir.delete(recursive: true);
            }
          } catch (deleteError) {
            debugPrint('删除临时文件失败: $deleteError');
          }

          _hideLoadingDialog();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('非标准压缩包，不支持导入2'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // 检查表头是否匹配
        bool headersMatch = true;
        for (int i = 0; i < 3; i++) {
          final cellValue = headerRow[i]?.value?.toString() ?? '';
          if (cellValue != expectedHeaders[i]) {
            headersMatch = false;
            break;
          }
        }

        if (!headersMatch) {
          // 删除临时文件
          try {
            if (await targetZipFile.exists()) {
              await targetZipFile.delete();
            }
            if (await importCurrentDir.exists()) {
              await importCurrentDir.delete(recursive: true);
            }
          } catch (deleteError) {
            debugPrint('删除临时文件失败: $deleteError');
          }

          _hideLoadingDialog();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('非标准压缩包，不支持导入2'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // 读取 Excel 数据并导入数据库
        final loginUser = await StorageUtils.getLoginUser();
        final now = DateTime.now();
        int insertCount = 0;
        int updateCount = 0;

        // 获取数据库中所有 user_type='01' 的用户
        final existingManagers = await _userRepository.findManagers();
        final existingManagersMap = {
          for (final manager in existingManagers) manager.userName: manager,
        };

        // 从第二行开始读取数据（第一行是表头）
        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty || row[0]?.value == null) {
            continue; // 跳过空行
          }

          final managerCode = row[0]?.value?.toString() ?? '';
          final managerName = row[1]?.value?.toString() ?? '';
          final managerPhone = row[2]?.value?.toString() ?? '';

          if (managerCode.isEmpty) {
            continue; // 跳过客户经理编号为空的行
          }

          final existingManager = existingManagersMap[managerCode];
          if (existingManager != null) {
            // 更新现有用户
            final updatedManager = existingManager.copyWith(
              nickName: managerName.isNotEmpty ? managerName : existingManager.nickName,
              phoneNumber: managerPhone.isNotEmpty ? managerPhone : existingManager.phoneNumber,
              updateBy: loginUser?.userName,
              updateTime: now,
            );
            await _userRepository.upsert(updatedManager);
            updateCount++;
          } else {
            // 插入新用户
            // 默认密码为客户经理编号
            final defaultPassword = BCrypt.hashpw(managerCode, BCrypt.gensalt());
            final newManager = User(
              userName: managerCode,
              nickName: managerName.isNotEmpty ? managerName : managerCode,
              userType: '01',
              phoneNumber: managerPhone.isNotEmpty ? managerPhone : null,
              password: defaultPassword,
              status: '0',
              createBy: loginUser?.userName,
              createTime: now,
              updateBy: loginUser?.userName,
              updateTime: now,
            );
            await _userRepository.upsert(newManager);
            insertCount++;
          }
        }

        // 删除临时文件
        try {
          if (await targetZipFile.exists()) {
            await targetZipFile.delete();
          }
          if (await importDir.exists()) {
            await importDir.delete(recursive: true);
          }
        } catch (deleteError) {
          debugPrint('删除临时文件失败: $deleteError');
        }

        // 关闭加载对话框
        _hideLoadingDialog();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('导入成功：新增 $insertCount 条，更新 $updateCount 条'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // 重新加载数据
        _loadData();
      } catch (e) {
        // 解压失败（可能是密码错误）
        debugPrint('解压失败: $e');

        // 关闭加载对话框
        _hideLoadingDialog();

        // 删除临时文件
        try {
          if (await targetZipFile.exists()) {
            await targetZipFile.delete();
          }
        } catch (deleteError) {
          debugPrint('删除临时文件失败: $deleteError');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('解压失败: ${e.toString().contains('password') || e.toString().contains('密码') ? '密码错误' : e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, s) {
      debugPrint('导入客户经理失败: $e');
      debugPrintStack(stackTrace: s);

      // 关闭加载对话框（如果还在显示）
      _hideLoadingDialog();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示加载对话框
  void _showLoadingDialog({String message = '正在处理...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// 关闭加载对话框
  void _hideLoadingDialog() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// 导出客户经理
  Future<void> _handleExportManager() async {
    if (_tableData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前没有可导出的数据'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final zipPassword = await _promptZipPassword();
    if (zipPassword == null) {
      return;
    }

    // 显示加载对话框
    if (mounted) {
      _showLoadingDialog(message: '正在导出客户经理数据...');
    }

    // 临时文件变量，用于在 finally 块中清理
    File? excelFile;
    File? zipFile;

    try {
      const templateAsset = 'assets/excel/customer_manager_info.xlsx';
      final templateData = await rootBundle.load(templateAsset);
      final templateBytes = templateData.buffer.asUint8List();
      final excelBook = excel.Excel.decodeBytes(templateBytes);
      final sheetName = excelBook.tables.isNotEmpty
          ? excelBook.tables.keys.first
          : (excelBook.sheets.isNotEmpty ? excelBook.sheets.keys.first : null);
      if (sheetName == null) {
        throw Exception('模板中未找到可用的工作表');
      }
      final sheet = excelBook[sheetName];
      if (sheet == null) {
        throw Exception('无法访问模板工作表: $sheetName');
      }

      const startRow = 2; // 模板第一行是表头，从第二行开始写数据
      for (int i = 0; i < _tableData.length; i++) {
        final data = _tableData[i];
        final rowIndex = startRow - 1 + i; // excel包的行索引从0开始
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = excel.TextCellValue('${data['managerCode'] ?? ''}');
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = excel.TextCellValue('${data['managerName'] ?? ''}');
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = excel.TextCellValue('${data['managerPhone'] ?? ''}');
      }

      final excelBytes = excelBook.encode();
      if (excelBytes == null) {
        throw Exception('生成Excel数据失败');
      }

      final cacheDir = await getTemporaryDirectory();
      final exportDir = Directory(p.join(cacheDir.path, 'export'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportCurrentDir = Directory(p.join(exportDir.path, '$timestamp'));
      if (!await exportCurrentDir.exists()) {
        await exportCurrentDir.create(recursive: true);
      }
      final excelName = 'customer_manager_info_export_$timestamp.xlsx';
      final excelPath = p.join(exportCurrentDir.path, excelName);
      excelFile = File(excelPath);
      await excelFile.writeAsBytes(excelBytes, flush: true);

      final zipName = 'customer_manager_info_export_$timestamp.zip';
      final zipPath = p.join(exportCurrentDir.path, zipName);
      zipFile = File(zipPath);
      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      // 使用 archive 包创建密码保护的 ZIP 文件
      final archive = Archive();
      final excelFileBytes = await excelFile.readAsBytes();
      final excelArchiveFile = ArchiveFile(
        excelName,
        excelFileBytes.length,
        excelFileBytes,
      );
      archive.addFile(excelArchiveFile);

      // 编码 ZIP 文件（带密码保护）
      final zipEncoder = ZipEncoder(password: zipPassword);
      final zipBytes = zipEncoder.encode(
        archive,
        level: Deflate.BEST_COMPRESSION,
      );
      
      if (zipBytes == null) {
        throw Exception('生成 ZIP 文件失败');
      }
      
      await zipFile.writeAsBytes(zipBytes, flush: true);

      final downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('无法获取Downloads目录，请检查存储权限');
      }

      final targetZipPath = p.join(downloadsDir.path, zipName);
      final targetZipFile = File(targetZipPath);
      if (await targetZipFile.exists()) {
        await targetZipFile.delete();
      }
      await zipFile.copy(targetZipPath);

      // 关闭加载对话框
      _hideLoadingDialog();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('客户经理数据导出成功'),
                const SizedBox(height: 4),
                Text(
                  'ZIP 文件: ${p.basename(targetZipPath)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, s) {
      debugPrint('导出客户经理数据失败: $e');
      debugPrintStack(stackTrace: s);
      
      // 关闭加载对话框
      _hideLoadingDialog();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 无论成功还是失败，都清理临时文件
      try {
        if (excelFile != null && await excelFile.exists()) {
          await excelFile.delete();
        }
        if (zipFile != null && await zipFile.exists()) {
          await zipFile.delete();
        }
      } catch (e) {
        debugPrint('删除临时文件失败: $e');
        // 删除临时文件失败不影响主流程，只记录日志
      }
    }
  }

  Future<String?> _promptZipPassword() async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('设置压缩包密码'),
              content: TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '压缩包密码',
                  hintText: '请输入密码',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final password = controller.text.trim();
                    if (password.isEmpty) {
                      setState(() {
                        errorText = '密码不能为空';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(password);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    // 延迟 dispose，确保 dialog 完全关闭后再清理 controller
    // 这样可以避免在 dialog 关闭动画期间 controller 被 dispose 导致的错误
    Future.delayed(const Duration(milliseconds: 300), () {
    controller.dispose();
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return CommonDataTablePage(
      // 查询条件区域
      querySection: _buildQuerySection(),
      
      // 表格标题
      tableTitle: '维护客户经理基础信息',
      
      // 功能按钮
      actionButtons: [
        ActionButton(
          label: '新增客户经理',
          onPressed: _handleAddManager,
        ),
        ActionButton(
          label: '下载导入模板',
          onPressed: _handleDownloadTemplate,
        ),
        ActionButton(
          label: '导入客户经理',
          onPressed: _handleImportManager,
        ),
        ActionButton(
          label: '导出客户经理',
          onPressed: _handleExportManager,
        ),
      ],
      
      // 表格列定义
      columns: [
        // DataTableColumn(
        //   label: 'id',
        //   builder: (row, context) => Text(row['id'].toString()),
        // ),
        DataTableColumn(
          label: '客户经理编码',
          builder: (row, context) => Text(row['managerCode']),
        ),
        DataTableColumn(
          label: '客户经理姓名',
          builder: (row, context) => Text(row['managerName']),
        ),
        DataTableColumn(
          label: '客户经理手机号码',
          builder: (row, context) => Text(row['managerPhone']),
        ),
        DataTableColumn(
          label: '客户数量',
          builder: (row, context) => Text(row['customerCount'].toString()),
        ),
        DataTableColumn(
          label: '录入时间',
          builder: (row, context) => Text(row['entryTime']),
        ),
        DataTableColumn(
          label: '操作',
          builder: (row, context) => _buildActions(row),
        ),
      ],
      
      // 数据
      data: _tableData,
      
      // 分页配置
      currentPage: _currentPage,
      totalItems: _totalItems,
      itemsPerPage: _itemsPerPage,
      onPageChanged: _handlePageChanged,
    );
  }

  /// 构建查询条件区域
  Widget _buildQuerySection() {
    return Row(
      children: [
        // 客户经理编号
        Expanded(
          child: _buildTextField(
            controller: _managerCodeController,
            label: '客户经理编号',
            hint: '请输入',
          ),
        ),
        const SizedBox(width: 16),
        
        // 客户经理姓名
        Expanded(
          child: _buildTextField(
            controller: _managerNameController,
            label: '客户经理姓名',
            hint: '请输入',
          ),
        ),
        const SizedBox(width: 16),
        
        // 客户经理手机
        Expanded(
          child: _buildTextField(
            controller: _managerPhoneController,
            label: '客户经理手机',
            hint: '请输入',
          ),
        ),
        const SizedBox(width: 24),
        
        // 重置按钮
        ElevatedButton(
          onPressed: _handleReset,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text('重置'),
        ),
        const SizedBox(width: 12),
        
        // 查询按钮
        ElevatedButton(
          onPressed: _handleQuery,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text('查询'),
        ),
      ],
    );
  }

  /// 构建输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
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
        TextField(
          controller: controller,
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
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActions(Map<String, dynamic> row) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 修改按钮（蓝色）
        ElevatedButton(
          onPressed: () async {
            final managerAccount = row['managerAccount'] as String?;
            if (managerAccount == null || managerAccount.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('无法获取客户经理编号')),
              );
              return;
            }
            try {
              final manager = await _userRepository.findByUserName(managerAccount);
              if (!mounted) return;
              if (manager == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未找到该客户经理')),
                );
                return;
              }
              final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (context) => AccountManagerAddPage(manager: manager),
                    ),
                  ) ??
                  false;
              if (saved) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('保存成功')),
                );
                _loadData();
              }
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('加载客户经理信息失败: $error')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('修改', style: TextStyle(fontSize: 13)),
        ),
        
        const SizedBox(width: 8),
        
        // 重置密码按钮（蓝色）
        ElevatedButton(
          onPressed: () {
            final managerAccount = row['managerAccount'] as String?;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认重置密码'),
                content: Text('确定要重置"${row['managerName']}"的密码吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (managerAccount == null || managerAccount.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('无法获取客户经理编号')),
                        );
                        return;
                      }
                      try {
                        final defaultPwdLight = managerAccount;
                        final passwordHash = BCrypt.hashpw(defaultPwdLight, BCrypt.gensalt());
                        await _userRepository.updatePassword(
                          managerAccount,
                          passwordHash,
                          DateTime.now(),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已重置密码: ${row['managerName']}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('重置密码失败: $error')),
                        );
                      }
                    },
                    child: const Text('确认'),
                  ),
                ],
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('重置密码', style: TextStyle(fontSize: 13)),
        ),
        
        const SizedBox(width: 8),
        
        // 删除按钮（红色）
        ElevatedButton(
          onPressed: () => _handleDeleteManager(row),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('删除', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

