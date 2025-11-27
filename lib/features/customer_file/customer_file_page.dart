import 'dart:io';

import 'package:bank_flutter/utils/version_utils.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../widgets/common_data_table_page.dart';
import '../../utils/page_transition_animations.dart';
import '../../utils/storage_utils.dart';
import '../../utils/import_export_utils.dart';
import '../../data/models/user.dart';
import '../../data/models/customer.dart';
import '../../data/models/customer_account_file.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'customer_file_add_page.dart';
import 'customer_file_add_picture_page.dart';
import 'customer_file_preview_page.dart';

/// 验证结果类（类似Python元组）
class ValidationResult {
  final bool success;
  final String reasonCode;
  final String message;

  const ValidationResult({
    required this.success,
    required this.reasonCode,
    required this.message,
  });

  @override
  String toString() => 'ValidationResult(success: $success, reasonCode: $reasonCode, message: $message)';
}

/// 开户文件管理页面
class CustomerFilePage extends StatefulWidget {
  const CustomerFilePage({super.key});

  @override
  State<CustomerFilePage> createState() => _CustomerFilePageState();
}

class _CustomerFilePageState extends State<CustomerFilePage> {
  // 查询条件
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  
  // 分页
  int _currentPage = 1;
  int _totalItems = 0;
  
  // 数据
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;

  // 选中的行ID集合
  Set<String> _selectedIds = {};
  
  // Repository
  final CustomerRepository _repository = CustomerRepository();
  final UserRepository _userRepository = UserRepository();
  
  User? _loginUser;
  
  bool get _isAccountManager => _loginUser?.userType == '01';
  bool get _isSuperAdmin => _loginUser?.userType == '00';
  String? get _managerAccount => _isAccountManager ? _loginUser?.userName : null;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// 加载用户信息
  Future<void> _loadUserInfo() async {
    final loginUser = await StorageUtils.getLoginUser();
    if (mounted) {
      setState(() {
        _loginUser = loginUser;
      });
      _loadData();
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  /// 加载数据
  Future<void> _loadData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final itemsPerPage = 20;
      final offset = (_currentPage - 1) * itemsPerPage;
      
      // 获取查询条件
      final customerNameKeyword = _customerNameController.text.trim().isEmpty 
          ? null 
          : _customerNameController.text.trim();
      final phoneKeyword = _phoneController.text.trim().isEmpty 
          ? null 
          : _phoneController.text.trim();
      final fileNameKeyword = _fileNameController.text.trim().isEmpty 
          ? null 
          : _fileNameController.text.trim();
      
      // 如果是客户经理（userType=01），获取同一团队的所有客户经理账号列表
      // 超级管理员（userType=00）可以查询所有
      List<String>? teamManagerAccounts;
      String? singleManagerAccount;
      
      if (_loginUser != null) {
        if (_loginUser!.userType == '01' && _loginUser!.groupCode.isNotEmpty) {
          // 客户经理：获取团队下所有客户经理的账号
          final teamManagers = await _userRepository.findManagersByGroupCode(_loginUser!.groupCode);
          teamManagerAccounts = teamManagers.map((manager) => manager.userName).toList();
        } else if (_loginUser!.userType == '00') {
          // 超级管理员：不传managerAccount，查询所有
          singleManagerAccount = null;
        } else {
          // 其他情况：保持原有逻辑
          singleManagerAccount = _managerAccount;
        }
      } else {
        singleManagerAccount = _managerAccount;
      }
      
      // 查询数据和总数
      final results = await Future.wait([
        _repository.findAccountFilesWithDetails(
          limit: itemsPerPage,
          offset: offset,
          customerNameKeyword: customerNameKeyword,
          phoneKeyword: phoneKeyword,
          fileNameKeyword: fileNameKeyword,
          managerAccount: teamManagerAccounts == null ? singleManagerAccount : null,
          managerAccounts: teamManagerAccounts,
        ),
        _repository.countAccountFiles(
          customerNameKeyword: customerNameKeyword,
          phoneKeyword: phoneKeyword,
          fileNameKeyword: fileNameKeyword,
          managerAccount: teamManagerAccounts == null ? singleManagerAccount : null,
          managerAccounts: teamManagerAccounts,
        ),
      ]);
      
      final rawData = results[0] as List<Map<String, Object?>>;
      final total = results[1] as int;
      
      // 转换数据格式以匹配表格显示
      _data = rawData.map((row) {
        return {
          'id': row['id'],
          'account_file_uid': row['account_file_uid'] ?? '-',
          'company': row['company'] ?? '-',
          'customerName': row['customer_name'] ?? '',
          'phone': row['phone'] ?? '',
          'fileName': row['account_file_name'] ?? '',
          'fileVersion': row['file_version'],
          'status': _formatSignStatus(row['sign_status']),
          'enableStatus': row['enable_status'],
          'file_src_type': row['file_src_type'] ?? '',
          'template': row['template_name'] ?? '-',
          'templateSignCode': row['template_sign_code'],
          'managerCode': row['manager_code'] ?? '',
          'managerName': row['manager_name'] ?? '',
          'filePath': row['file_path'],
          'customerUid': row['customer_uid'],
        };
      }).toList();
      
      setState(() {
        _totalItems = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败: $e')),
        );
      }
    }
  }

  /// 查询
  void _handleQuery() {
    _currentPage = 1;
    _loadData();
  }

  /// 重置
  void _handleReset() {
    _customerNameController.clear();
    _phoneController.clear();
    _fileNameController.clear();
    _currentPage = 1;
    _selectedIds.clear(); // 清空选择状态
    _loadData();
  }

  /// 页码变化
  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
      _selectedIds.clear(); // 页码变化时清空选择状态
    });
    _loadData();
  }

  /// 选择状态变化处理
  void _handleSelectionChanged(List<int> selectedIds) {
    // 根据行索引获取对应的account_file_uid + file_version组合
    final selectedRowIds = <String>{};
    for (final id in selectedIds) {
      for (int i = 0; i < _data.length; i++) {
        dynamic row = _data[i];
        if (id == row['id']) {
          final accountFileUid = row['account_file_uid'] as String;
          final fileVersion = row['fileVersion'];
          // 使用 account_file_uid 和 file_version 组合成唯一标识
          final uniqueId = '${accountFileUid}_$fileVersion';
          selectedRowIds.add(uniqueId);
          break;
        }
      }
    }
    setState(() {
      _selectedIds = selectedRowIds;
    });
  }

  /// 扫描生成PDF
  Future<void> _handleScanToPdf() async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const CustomerFileAddPicturePage();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return PageTransitionAnimations.slideFromRight(child, animation);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    // 返回后刷新数据
    if (mounted) {
      _loadData();
    }
  }

  /// 新增开户文件
  void _handleAddFile() {
    _navigateToAddPage(0); // 0 表示模板生成 Tab
    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: const Text(
    //       '新增开户文件',
    //       style: TextStyle(
    //         fontSize: 18,
    //         fontWeight: FontWeight.w600,
    //       ),
    //     ),
    //     content: const Text(
    //       '请选择新增方式：',
    //       style: TextStyle(fontSize: 14),
    //     ),
    //     actions: [
    //       // 取消按钮
    //       // TextButton(
    //       //   onPressed: () => Navigator.pop(context),
    //       //   style: TextButton.styleFrom(
    //       //     foregroundColor: Colors.grey.shade700,
    //       //   ),
    //       //   child: const Text('取消'),
    //       // ),
    //       // 从模板新增按钮
    //       ElevatedButton(
    //         onPressed: () {
    //           Navigator.pop(context);
    //           _navigateToAddPage(0); // 0 表示模板生成 Tab
    //         },
    //         style: ElevatedButton.styleFrom(
    //           backgroundColor: Colors.blue,
    //           foregroundColor: Colors.white,
    //         ),
    //         child: const Text('从模板新增'),
    //       ),
    //       // 上传PDF新增按钮
    //       ElevatedButton(
    //         onPressed: () {
    //           Navigator.pop(context);
    //           _navigateToAddPage(1); // 1 表示上传PDF Tab
    //         },
    //         style: ElevatedButton.styleFrom(
    //           backgroundColor: Colors.blue,
    //           foregroundColor: Colors.white,
    //         ),
    //         child: const Text('上传PDF新增'),
    //       ),
    //     ],
    //   ),
    // );
  }

  /// 导航到新增页面
  Future<void> _navigateToAddPage(int initialTabIndex) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return CustomerFileAddPage(initialTabIndex: initialTabIndex);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return PageTransitionAnimations.slideFromRight(child, animation);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    // 返回后刷新数据
    if (mounted) {
      _loadData();
    }
  }

  /// 导航到预览页面
  Future<void> _navigateToPreviewPage(Map<String, dynamic> row, {required bool isEditMode}) async {
    final customerName = row['customerName']?.toString() ?? '';
    final fileName = row['fileName']?.toString() ?? '';
    final templateName = row['template']?.toString() ?? '-';
    final filePath = row['filePath']?.toString();
    final accountFileUid = row['account_file_uid']?.toString();
    final customerUid = row['customerUid']?.toString();
    final fileVersion = row['fileVersion'];
    final fileSrcType = row['file_src_type']?.toString();
    final templateSignCode = row['templateSignCode']?.toString();

    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return CustomerFilePreviewPage(
            customerName: customerName,
            fileName: fileName,
            templateName: templateName,
            filePath: filePath,
            isEditMode: isEditMode,
            accountFileUid: accountFileUid,
            customerUid: customerUid,
            fileVersion: fileVersion,
            fileSrcType: fileSrcType,
            templateSignCode: templateSignCode,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return PageTransitionAnimations.slideFromRight(child, animation);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    // 如果保存成功，刷新数据
    if (result == true && mounted) {
      _loadData();
    }
  }

  /// 下载导入模板
  void _handleDownloadTemplate() async {
    await ImportExportUtils.downloadTemplate(
      context,
      assetPath: 'assets/excel/account_file_info.xlsx',
      fileName: 'account_file_info.xlsx',
    );
  }

  /// 验证开户文件Excel文件
  Future<String?> _validateAccountFileExcelFile(File excelFile) async {
    try {
      final excelBytes = await excelFile.readAsBytes();
      final excelBook = excel.Excel.decodeBytes(excelBytes);
      final sheetName = excelBook.tables.isNotEmpty
          ? excelBook.tables.keys.first
          : (excelBook.sheets.isNotEmpty ? excelBook.sheets.keys.first : null);
      if (sheetName == null) {
        return '非标准压缩包，不支持导入2';
      }

      final sheet = excelBook[sheetName];

      const expectedHeaders = [
        '开户文件编号',
        '客户编码',
        '开户文件名',
        '文件版本',
        '文件路径',
        '签署状态',
        '开户方式',
        '使用模板',
        '模板编码',
        '客户经理编号'
      ];
      final headerRow = sheet.rows[0];
      if (headerRow.length < expectedHeaders.length) {
        return '非标准压缩包，不支持导入1';
      }

      // 检查表头是否匹配
      for (int i = 0; i < expectedHeaders.length; i++) {
        final cellValue = headerRow[i]?.value?.toString() ?? '';
        if (cellValue != expectedHeaders[i]) {
          return '非标准压缩包，不支持导入2';
        }
      }

      return null; // 验证通过
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      return '验证Excel文件失败: $e';
    }
  }

  /// 备份现有开户文件版本
  ///
  /// [existingFile] 现有的开户文件记录
  /// [newFileVersion] 新的版本号（用于备份）
  /// [updateBy] 更新人
  /// [updateTime] 更新时间
  /// [accountDir] 账户文件目录
  ///
  /// 返回备份后的文件记录
  Future<CustomerAccountFile?> _backupExistingVersion(
    CustomerAccountFile existingFile,
    int newFileVersion,
    String? updateBy,
    DateTime updateTime,
    Directory accountDir,
  ) async {
    try {
      CustomerAccountFile? backupFile;

      // 1. 复制PDF文件（如果存在）
      final originalFilePath = existingFile.filePath;
      if (originalFilePath.isNotEmpty) {
        final originalFile = File(originalFilePath);
        if (await originalFile.exists()) {
          // 生成备份文件名：使用新的版本号
          final backupFileName = '${existingFile.accountFileUid}_$newFileVersion.pdf';
          final backupFilePath = p.join(accountDir.path, backupFileName);
          final backupFileObj = File(backupFilePath);

          // 如果备份文件已存在，先删除
          if (await backupFileObj.exists()) {
            await backupFileObj.delete();
          }

          // 复制文件
          await originalFile.copy(backupFilePath);
          debugPrint('备份文件成功: $originalFilePath -> $backupFilePath');

          // 更新备份记录的文件路径
          // 2. 创建备份记录，版本号使用新的版本号
          backupFile = existingFile.copyNewWith(
            fileVersion: newFileVersion,
            filePath: backupFilePath,
            updateBy: updateBy,
            updateTime: updateTime,
          );
        } else {
          debugPrint('原始文件不存在，跳过文件备份: $originalFilePath');
          return null;
        }
      }

      // 3. 保存备份记录到数据库
      await _repository.addAccountFile(
        backupFile!,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('备份开户文件成功: accountFileUid=${existingFile.accountFileUid}, 原版本=${existingFile.fileVersion}, 备份版本=$newFileVersion');
      return backupFile;

    } catch (e) {
      debugPrint('备份开户文件失败: $e');
      return null;
    }
  }

  /// 处理开户文件Excel数据
  Future<String?> _processAccountFileExcelData(File excelFile, String importDirPath) async {
    final excelBytes = await excelFile.readAsBytes();
    final excelBook = excel.Excel.decodeBytes(excelBytes);
    final sheetName = excelBook.tables.isNotEmpty
        ? excelBook.tables.keys.first
        : (excelBook.sheets.isNotEmpty ? excelBook.sheets.keys.first : null);
    if (sheetName == null) {
      throw Exception('无法读取Excel工作表');
    }

    final sheet = excelBook[sheetName];

    // 获取APP缓存账户目录
    final cacheDir = await getApplicationCacheDirectory();
    final accountDir = Directory(p.join(cacheDir.path, 'account'));
    if (!await accountDir.exists()) {
      await accountDir.create(recursive: true);
    }

    // 检查是否有files目录
    final filesDir = Directory(p.join(importDirPath, 'files'));
    final hasFilesDir = await filesDir.exists();

    // 读取 Excel 数据并导入数据库
    final loginUser = await StorageUtils.getLoginUser();
    final now = DateTime.now();
    int insertCount = 0;
    int updateCount = 0;

    // 获取所有现有客户（用于匹配和验证）
    final allCustomers = await _repository.search(limit: 10000);
    final customersByUidMap = <String, Customer>{}; // key: customerUid, value: Customer
    final customersByNameMap = <String, String>{}; // key: customerName, value: customerUid
    final customersByPhoneMap = <String, String>{}; // key: phone, value: customerUid
    for (final customer in allCustomers) {
      customersByUidMap[customer.customerUid] = customer;
      customersByNameMap[customer.customerName] = customer.customerUid;
      if (customer.phone != null && customer.phone!.isNotEmpty) {
        customersByPhoneMap[customer.phone!] = customer.customerUid;
      }
    }

    // 获取所有现有开户文件（用于匹配）
    // 先获取所有唯一的accountFileUid
    final allAccountFiles = await _repository.findAccountFilesWithDetails(limit: 10000);
    final accountFileUids = <String>{};
    for (final fileData in allAccountFiles) {
      final accountFileUid = fileData['account_file_uid']?.toString() ?? '';
      if (accountFileUid.isNotEmpty) {
        accountFileUids.add(accountFileUid);
      }
    }
    
    // 批量获取所有开户文件
    final accountFilesMap = <String, CustomerAccountFile>{}; // key: accountFileUid_fileVersion
    for (final accountFileUid in accountFileUids) {
      final files = await _repository.findAccountFilesByAccountFileUid(accountFileUid);
      for (final file in files) {
        final key = '${file.accountFileUid}_${file.fileVersion ?? ''}';
        accountFilesMap[key] = file;
      }
    }

    // 从第二行开始读取数据（第一行是表头）
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty || row[0]?.value == null) {
        continue; // 跳过空行
      }

      final accountFileUid = (row[0]?.value?.toString() ?? '').trim();
      final customerUid = (row[1]?.value?.toString() ?? '').trim();
      final accountFileName = (row[2]?.value?.toString() ?? '').trim();
      final fileVersion = VersionUtils.stringToInt(row[3]?.value?.toString() ?? '');
      final relativeFilePath = (row[4]?.value?.toString() ?? '').trim(); // 第5列：文件路径（相对路径）
      final signStatusStr = row[5]?.value?.toString().trim();
      // 将 Excel 中的 signStatus 字符串转换为 int
      int? signStatus;
      if (signStatusStr != null && signStatusStr.isNotEmpty) {
        if (signStatusStr == '已签署' || signStatusStr == '1') {
          signStatus = 1;
        } else {
          signStatus = int.tryParse(signStatusStr) ?? 0;
        }
      }
      final fileSrcType = row[6]?.value?.toString().trim();
      final templateName = row[7]?.value?.toString().trim();
      final templateSignCode = row[8]?.value?.toString().trim();
      final managerAccount = (row[9]?.value?.toString() ?? '').trim();

      if (accountFileName.isEmpty) {
        continue; // 跳过开户文件名为空的行
      }

      // 验证客户UID是否存在
      if (customerUid.isEmpty) {
        continue; // 跳过客户编码为空的行
      }

      // 验证客户是否存在（外键约束检查）
      final customer = customersByUidMap[customerUid];
      if (customer == null) {
        debugPrint('客户不存在，跳过: customerUid=$customerUid, accountFileName=$accountFileName');
        continue; // 跳过客户不存在的行
      }

      // 验证客户经理是否存在
      if (managerAccount.isNotEmpty) {
        final manager = await _userRepository.findByUserName(managerAccount);
        if (manager == null) {
          debugPrint('客户经理不存在，跳过: managerAccount=$managerAccount, accountFileName=$accountFileName');
          continue; // 跳过客户经理不存在的行
        }
      }

      // 处理文件路径：如果Excel中有相对路径，且files目录存在，则复制文件到APP缓存目录
      Future<String?> copyOrReplaceToAppCacheFile() async {
        String? appCacheFilePath = null;
        if (relativeFilePath.isNotEmpty &&
            relativeFilePath != '-' &&
            hasFilesDir &&
            relativeFilePath.startsWith('files/')) {
          try {
            // 获取源文件路径（在解压目录中）
            final sourceFilePath = p.join(importDirPath, relativeFilePath);
            final sourceFile = File(sourceFilePath);

            if (await sourceFile.exists()) {
              // 生成目标文件名：使用accountFileUid和fileVersion，如果不存在则使用UUID
              final finalAccountFileUid = accountFileUid.isNotEmpty
              ? accountFileUid
                  : '${customerUid}_${DateTime.now().millisecondsSinceEpoch}';
              final finalFileVersion = fileVersion;
              final targetFileName = '${finalAccountFileUid}_$finalFileVersion.pdf';
              final targetFilePath = p.join(accountDir.path, targetFileName);
              final targetFile = File(targetFilePath);

              // 如果目标文件已存在，先删除（替换）
              if (await targetFile.exists()) {
                await targetFile.delete();
              }

              // 复制文件到APP缓存目录
              await sourceFile.copy(targetFilePath);
              appCacheFilePath = targetFilePath;
            } else {
              debugPrint('文件不存在，跳过: $sourceFilePath');
            }
          } catch (e) {
            debugPrint('复制文件失败: $relativeFilePath, 错误: $e');
            // 继续处理，不中断导入流程
          }
        }
        return appCacheFilePath;
      }

      // 尝试匹配现有开户文件
      final key = accountFileUid.isNotEmpty
          ? '${accountFileUid}_$fileVersion'
          : '${customerUid}_${accountFileName}_$fileVersion';
      final existingFile = accountFilesMap[key];

      if (existingFile != null) {
        // 新需求：备份现有版本，然后更新原版本
        try {
          // 1. 生成备份版本号（查找当前大版本下最大小版本号，然后+1）
          final currentFileVersion = existingFile.fileVersion ?? fileVersion;

          // 获取当前大版本号
          final currentVersionStr = VersionUtils.intToString(currentFileVersion);
          final currentVersionParts = currentVersionStr.split('.');
          final currentMajorVersion = currentVersionParts[0]; // 大版本号

          // 获取该accountFileUid下所有同大版本的文件
          final allAccountFiles = await _repository.findAccountFilesByAccountFileUid(existingFile.accountFileUid);
          final sameMajorVersionFiles = allAccountFiles.where((file) {
            if (file.fileVersion == null) return false;
            final fileVersionStr = VersionUtils.intToString(file.fileVersion!);
            final fileVersionParts = fileVersionStr.split('.');
            return fileVersionParts[0] == currentMajorVersion; // 同大版本
          }).toList();

          // 找到最大小版本号
          int maxMinorVersion = -1;
          final List<String> existingVersions = [];
          for (final file in sameMajorVersionFiles) {
            if (file.fileVersion != null) {
              final fileVersionStr = VersionUtils.intToString(file.fileVersion!);
              final fileVersionParts = fileVersionStr.split('.');
              final minorVersion = int.parse(fileVersionParts[2]); // 小版本号
              existingVersions.add(fileVersionStr);
              if (minorVersion > maxMinorVersion) {
                maxMinorVersion = minorVersion;
              }
            }
          }

          // 生成新的备份版本号：大版本不变，中版本保持当前，小版本号 = maxMinorVersion + 1
          final currentMiddleVersion = int.parse(currentVersionParts[1]); // 中版本号
          final newMinorVersion = maxMinorVersion + 1;
          final backupFileVersion = VersionUtils.stringToInt('$currentMajorVersion.$currentMiddleVersion.$newMinorVersion');

          debugPrint('版本分析结果: 当前版本=$currentVersionStr, 同大版本存在版本=${existingVersions.join(', ')}, 最大小版本=$maxMinorVersion, 新备份版本=${VersionUtils.intToString(backupFileVersion)}');

          debugPrint('检测到现有文件，准备备份: accountFileUid=${existingFile.accountFileUid}, 当前版本=$currentFileVersion, 备份版本=$backupFileVersion');

          // 2. 备份现有版本
          final backupResult = await _backupExistingVersion(
            existingFile,
            backupFileVersion,
            loginUser?.userName,
            now,
            accountDir,
          );

          if (backupResult != null) {
            debugPrint('备份成功，继续更新原版本');
          } else {
            debugPrint('备份失败，但仍继续更新原版本');
          }

          // 3. 更新原版本数据（保持原版本号不变）
          String? appCacheFilePath = await copyOrReplaceToAppCacheFile();
          // final updatedFile = existingFile.copyWith(
          //   accountFileName: accountFileName.isNotEmpty ? accountFileName : existingFile.accountFileName,
          //   fileVersion: currentFileVersion, // 保持原版本号
          //   filePath: appCacheFilePath ?? existingFile.filePath, // 如果有新文件路径则更新，否则保持原路径
          //   signStatus: signStatus ?? existingFile.signStatus,
          //   fileSrcType: fileSrcType?.isNotEmpty == true ? fileSrcType : existingFile.fileSrcType,
          //   templateName: templateName?.isNotEmpty == true ? templateName : existingFile.templateName,
          //   templateSignCode: templateSignCode?.isNotEmpty == true ? templateSignCode : existingFile.templateSignCode,
          //   updateBy: loginUser?.userName,
          //   updateTime: now,
          // );
          // 其实数据并没有变化，所以不需要更新DB
          // await _repository.addAccountFile(
          //   updatedFile,
          //   conflictAlgorithm: ConflictAlgorithm.replace,
          // );
          // updateCount++;
          // debugPrint('更新原版本成功: accountFileUid=${existingFile.accountFileUid}, 版本=$currentFileVersion');

        } catch (e) {
          debugPrint('处理现有文件时出错: $e');
          // 即使备份失败，也尝试更新原文件
          String? appCacheFilePath = await copyOrReplaceToAppCacheFile();
          final updatedFile = existingFile.copyWith(
            accountFileName: accountFileName.isNotEmpty ? accountFileName : existingFile.accountFileName,
            filePath: appCacheFilePath ?? existingFile.filePath,
            signStatus: signStatus ?? existingFile.signStatus,
            fileSrcType: fileSrcType?.isNotEmpty == true ? fileSrcType : existingFile.fileSrcType,
            templateName: templateName?.isNotEmpty == true ? templateName : existingFile.templateName,
            templateSignCode: templateSignCode?.isNotEmpty == true ? templateSignCode : existingFile.templateSignCode,
            updateBy: loginUser?.userName,
            updateTime: now,
          );
          await _repository.addAccountFile(
            updatedFile,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          updateCount++;
        }
      } else {
        // 插入新开户文件
        String? appCacheFilePath = await copyOrReplaceToAppCacheFile();
        final finalAccountFileUid = accountFileUid.isNotEmpty
            ? accountFileUid
            : '${customerUid}_${DateTime.now().millisecondsSinceEpoch}';
        final newFile = CustomerAccountFile(
          accountFileUid: finalAccountFileUid,
          customerUid: customerUid,
          accountFileName: accountFileName,
          fileVersion: fileVersion,
          filePath: appCacheFilePath ?? '', // 使用复制后的APP缓存路径
          signStatus: signStatus,
          fileSrcType: fileSrcType,
          templateName: templateName,
          templateSignCode: templateSignCode?.isNotEmpty == true ? templateSignCode : null,
          createBy: loginUser?.userName,
          createTime: now,
          updateBy: loginUser?.userName,
          updateTime: now,
        );
        await _repository.addAccountFile(newFile);
        insertCount++;
      }
    }

    // 重新加载数据
    _loadData();

    return '导入成功：新增 $insertCount 条，更新 $updateCount 条';
  }

  /// 导入开户文件
  Future<void> _handleImportAccountFile() async {
    await ImportExportUtils.importFromZip(
      context,
      excelFileNamePrefix: 'account_file_info',
      validateExcelFile: _validateAccountFileExcelFile,
      processExcelData: _processAccountFileExcelData,
      loadingMessage: '正在导入开户文件数据...',
      onSuccess: (_) {
        // 数据已在 processExcelData 中重新加载
      },
      onError: (error) {
        debugPrint('导入开户文件失败: $error');
      },
    );
  }

  /// 验证选中的开户文件是否符合导出条件
  ValidationResult _validateSelectedFiles(List<Map<String, dynamic>> selectedData) {
    if (selectedData.isEmpty) {
      return const ValidationResult(
        success: false,
        reasonCode: 'NO_SELECTION',
        message: '没有勾选数据，无法导出',
      );
    }

    // (1) 检查是否选择了同一客户的开户文件
    final customerUids = selectedData.map((row) => row['customerUid'] as String).toSet();
    if (customerUids.length > 1) {
      return const ValidationResult(
        success: false,
        reasonCode: 'MULTIPLE_CUSTOMERS',
        message: '仅支持对【相同客户】的开户文件导出。',
      );
    }

    // (2) 检查是否只选择了生效的开户文件
    final allEnabled = selectedData.every((row) => _isEnabled(row));
    if (!allEnabled) {
      return const ValidationResult(
        success: false,
        reasonCode: 'CONTAINS_DISABLED',
        message: '仅支持对【生效】的开户文件导出。',
      );
    }

    // (3) 检查是否只选择了正式版本的开户文件（中版本和小版本都为0）
    for (final row in selectedData) {
      final fileVersion = row['fileVersion'] as int?;
      if (fileVersion == null) {
        return const ValidationResult(
          success: false,
          reasonCode: 'NO_VERSION',
          message: '开户文件版本信息不完整，无法导出。',
        );
      }

      // 检查中版本号和小版本号是否都为0
      final remainder = fileVersion % 10000;
      final middleVersion = remainder ~/ 100;    // 中版本号
      final minorVersion = remainder % 100;     // 小版本号

      if (middleVersion != 0 || minorVersion != 0) {
        return const ValidationResult(
          success: false,
          reasonCode: 'NOT_FORMAL_VERSION',
          message: '当前为备份版本，不可直接导出。如需导出，请先编辑内容并保存为新版本，再执行导出操作。',
        );
      }
    }

    return const ValidationResult(
      success: true,
      reasonCode: 'SUCCESS',
      message: '验证通过',
    );
  }

  /// 显示提示对话框
  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止外部点击关闭，避免重复触发
      builder: (context) => AlertDialog(
        key: ValueKey('alert_${DateTime.now().millisecondsSinceEpoch}'), // 使用唯一Key
        title: const Text('提示'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 导出开户文件
  Future<void> _handleExportAccountFile() async {
    // 检查是否有选中的数据
    if (_selectedIds.isEmpty) {
      _showAlertDialog('没有勾选数据，无法导出');
      return;
    }

    // 过滤选中的数据（开户文件使用account_file_uid + file_version组合作为唯一标识）
    final selectedData = _data.where((row) {
      final accountFileUid = row['account_file_uid'] as String;
      final fileVersion = row['fileVersion'];
      final uniqueId = '${accountFileUid}_$fileVersion';
      return _selectedIds.contains(uniqueId);
    }).toList();

    // 验证选中的文件是否符合导出条件
    final validationResult = _validateSelectedFiles(selectedData);
    if (!validationResult.success) {
      _showAlertDialog(validationResult.message);
      return;
    }

    // 生成时间戳
    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());

    await ImportExportUtils.exportToZip(
      context,
      templateAssetPath: 'assets/excel/account_file_info.xlsx',
      zipFileName: '${selectedData[0]['customerName']}_$timestamp', // 客户姓名+时间戳：客户姓名_20251117122330
      excelFileName: 'account_file_info_export',
      data: selectedData,
      headers: const [
        '开户文件编号',
        '客户编码',
        '开户文件名',
        '文件版本',
        '文件路径',
        '签署状态',
        '开户方式',
        '使用模板',
        '模板编码',
        '客户经理编号'
      ],
      beforeDataToExcelRows: (exportDirPath) async {
        // 复制文件到files文件夹，并返回相对路径映射
        final filesDir = Directory(p.join(exportDirPath, 'files'));
        if (!await filesDir.exists()) {
          await filesDir.create(recursive: true);
        }

        final filePathMap = <String, String>{}; // key: 原始路径, value: 相对路径

        for (final rowData in selectedData) {
          final originalFilePath = rowData['filePath']?.toString();
          if (originalFilePath == null || originalFilePath.isEmpty || originalFilePath == '-') {
            continue;
          }

          try {
            final sourceFile = File(originalFilePath);
            if (!await sourceFile.exists()) {
              debugPrint('文件不存在，跳过: $originalFilePath');
              continue;
            }

            // 获取文件名
            final fileName = p.basename(originalFilePath);
            // 如果文件名已存在，添加时间戳前缀
            // final targetFileName = fileName;
            final targetFileName = '${rowData['fileName']}V${VersionUtils.intToString(rowData['fileVersion'])}.pdf'; // 打包的文件名使用数据库里保存的文件名+版本号
            final targetFilePath = p.join(filesDir.path, targetFileName);
            final targetFile = File(targetFilePath);

            // 如果目标文件已存在，添加时间戳
            if (await targetFile.exists()) {
              final nameWithoutExt = p.basenameWithoutExtension(targetFileName);
              final ext = p.extension(targetFileName);
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final uniqueFileName = '${nameWithoutExt}_$timestamp$ext';
              final uniqueTargetPath = p.join(filesDir.path, uniqueFileName);
              await sourceFile.copy(uniqueTargetPath);
              // 相对路径：files/文件名
              filePathMap[originalFilePath] = 'files/$uniqueFileName';
            } else {
              await sourceFile.copy(targetFilePath);
              // 相对路径：files/文件名
              filePathMap[originalFilePath] = 'files/$targetFileName';
            }
          } catch (e) {
            debugPrint('复制文件失败: $originalFilePath, 错误: $e');
            // 继续处理其他文件
          }
        }

        return filePathMap;
      },
      loadingMessage: '正在导出开户文件数据...',
      successMessage: '开户文件数据导出成功',
      dataToExcelRows: (sheet, rowData, rowIndex, filePathMap) {
        // 开户文件uid
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['account_file_uid']?.toString() ?? '');
        // 客户编码
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['customerUid']?.toString() ?? '');
        // 开户文件名
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['fileName']?.toString() ?? '');
        // 文件版本
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = excel.TextCellValue(VersionUtils.intToString(rowData['fileVersion']));
        // 文件路径（相对路径，如 files/xxx.pdf）
        String localPath = rowData['filePath']?.toString() ?? '-';
        String? relativePath = localPath;
        if (filePathMap != null && filePathMap.containsKey(localPath)) {
          relativePath = filePathMap[localPath];
        }
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = excel.TextCellValue(relativePath!);
        // 签署状态（将 int 转换为显示文本）
        final statusValue = rowData['status'];
        String statusText = '未签署';
        if (statusValue != null) {
          if (statusValue is int) {
            statusText = statusValue == 1 ? '已签署' : '未签署';
          } else if (statusValue is String) {
            statusText = statusValue;
          }
        }
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = excel.TextCellValue(statusText);
        // 开户方式
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['file_src_type']?.toString() ?? '');
        // 使用模板
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['template']?.toString() ?? '-');
        // 模板编码
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['templateSignCode']?.toString() ?? '-');
        // 客户经理编号
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['managerCode']?.toString() ?? '');
      },
      onSuccess: () {
        // 导出成功，无需额外操作
      },
      onError: (error) {
        debugPrint('导出开户文件数据失败: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonDataTablePage(
      // 查询条件区域
      querySection: _buildQuerySection(),

      // 选择状态变化回调
      onSelectionChanged: _handleSelectionChanged,
      
      // 表格标题
      tableTitle: '维护客户开户文件',
      
      // 功能按钮
      actionButtons: [
        ActionButton(
          label: '扫描生成PDF',
          onPressed: _handleScanToPdf,
        ),
        ActionButton(
          label: '新增开户文件',
          onPressed: _handleAddFile,
        ),
        // ActionButton(
        //   label: '下载导入模板',
        //   onPressed: _handleDownloadTemplate,
        // ),
        ActionButton(
          label: '导入开户文件',
          onPressed: _handleImportAccountFile,
        ),
        ActionButton(
          label: '导出开户文件',
          onPressed: _handleExportAccountFile,
        ),
      ],
      
      // 表格列定义
      columns: [
        DataTableColumn(
          label: '开户文件uid',
          builder: (row, context) => Text(row['account_file_uid'].toString()),
        ),
        DataTableColumn(
          label: '公司名称',
          builder: (row, context) => Text(row['company']?.toString() ?? '-'),
        ),
        DataTableColumn(
          label: '客户姓名',
          builder: (row, context) => Text(row['customerName']?.toString() ?? ''),
        ),
        DataTableColumn(
          label: '电话号码',
          builder: (row, context) => Text(row['phone']?.toString() ?? ''),
        ),
        DataTableColumn(
          label: '开户文件名',
          builder: (row, context) => Text(row['fileName']?.toString() ?? ''),
        ),
        DataTableColumn(
          label: '文件版本',
          builder: (row, context) => Text(VersionUtils.intToString(row['fileVersion'])),
        ),
        DataTableColumn(
          label: '签署状态',
          builder: (row, context) => _buildSignStatusBadge(row['status']?.toString() ?? '-'),
        ),
        DataTableColumn(
          label: '生效状态',
          builder: (row, context) => _buildEnableStatusBadge(row['enableStatus']),
        ),
        DataTableColumn(
          label: '开户方式',
          builder: (row, context) => Text(row['file_src_type']?.toString() ?? ''),
        ),
        DataTableColumn(
          label: '使用模板',
          builder: (row, context) => Text(row['template']?.toString() ?? '-'),
        ),
        DataTableColumn(
          label: '客户经理编号',
          builder: (row, context) => Text(row['managerCode']?.toString() ?? ''),
        ),
        DataTableColumn(
          label: '客户经理姓名',
          builder: (row, context) => Text(row['managerName']?.toString() ?? ''),
        ),
        DataTableColumn(
          label: '操作',
          builder: (row, context) => _buildActions(row),
        ),
      ],
      
      // 数据
      data: _data,
      
      // 分页配置
      currentPage: _currentPage,
      totalItems: _totalItems,
      itemsPerPage: 20,
      onPageChanged: _handlePageChanged,
    );
  }

  /// 构建查询条件区域
  Widget _buildQuerySection() {
    return Row(
      children: [
        // 客户姓名
        Expanded(
          child: _buildTextField(
            controller: _customerNameController,
            label: '客户姓名',
            hint: '请输入',
          ),
        ),
        const SizedBox(width: 16),
        
        // 电话号码
        Expanded(
          child: _buildTextField(
            controller: _phoneController,
            label: '电话号码',
            hint: '请输入',
          ),
        ),
        const SizedBox(width: 16),
        
        // 开户文件名
        Expanded(
          child: _buildTextField(
            controller: _fileNameController,
            label: '开户文件名',
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

  /// 格式化签署状态为显示文本
  String _formatSignStatus(Object? status) {
    if (status == null) return '未签署';
    if (status is int) {
      switch (status) {
        case 1:
          return '已签署';
        default:
          return '未签署';
      }
    }
    if (status is String) {
      // 兼容旧数据
      if (status == '已签署' || status == '1') return '已签署';
      if (status == '未签署' || status == '2') return '未签署';
      return status.isEmpty ? '-' : status;
    }
    return '-';
  }

  /// 构建签署状态标签
  Widget _buildSignStatusBadge(String? status) {
    return Text(status ?? '-');
    // if (status == null || status.isEmpty || status == '-') {
    //   return Text(status ?? '-');
    // }
    //
    // Color backgroundColor;
    // Color textColor;
    //
    // switch (status) {
    //   case '已签署':
    //     backgroundColor = Colors.green.shade100;
    //     textColor = Colors.green.shade800;
    //     break;
    //   case '未签署':
    //     backgroundColor = Colors.orange.shade100;
    //     textColor = Colors.orange.shade800;
    //     break;
    //   default:
    //     backgroundColor = Colors.grey.shade100;
    //     textColor = Colors.grey.shade800;
    // }
    //
    // return Container(
    //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    //   decoration: BoxDecoration(
    //     color: backgroundColor,
    //     borderRadius: BorderRadius.circular(4),
    //   ),
    //   child: Text(
    //     status,
    //     style: TextStyle(
    //       fontSize: 13,
    //       color: textColor,
    //       fontWeight: FontWeight.w500,
    //     ),
    //   ),
    // );
  }

  /// 构建生效状态标签
  Widget _buildEnableStatusBadge(Object? enableStatus) {
    final isEnabled = enableStatus != null && (enableStatus == 1 || enableStatus == '1');
    final statusText = isEnabled ? '生效中' : '已失效';
    
    Color backgroundColor;
    Color textColor;
    
    if (isEnabled) {
      // 已生效：绿色
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    } else {
      // 未生效：橙色/黄色
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 13,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 判断数据是否已生效
  bool _isEnabled(Map<String, dynamic> row) {
    final enableStatus = row['enableStatus'];
    return enableStatus != null && (enableStatus == 1 || enableStatus == '1');
  }

  /// 处理生效操作
  Future<void> _handleEnable(Map<String, dynamic> row) async {
    final accountFileUid = row['account_file_uid']?.toString();
    final fileVersion = row['fileVersion'];
    
    if (accountFileUid == null || accountFileUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('开户文件编号不能为空')),
        );
      }
      return;
    }

    if (fileVersion == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件版本号不能为空')),
        );
      }
      return;
    }

    try {
      // 验证文件是否存在
      final files = await _repository.findAccountFilesByAccountFileUid(accountFileUid);
      if (!files.any((file) => file.fileVersion == fileVersion)) {
        throw Exception('文件不存在');
      }

      // 获取登录用户信息
      final loginUser = await StorageUtils.getLoginUser();
      final now = DateTime.now();

      // 更新生效状态：将指定版本设为生效，同一开户文件uid下的其他版本设为失效
      await _repository.updateEnableStatusByAccountFileUid(
        accountFileUid,
        fileVersion,
        loginUser?.userName,
        now,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已生效: ${row['fileName']}（版本 $fileVersion）')),
        );
        // 刷新数据
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生效失败: $e')),
        );
      }
    }
  }

  /// 构建操作按钮
  Widget _buildActions(Map<String, dynamic> row) {
    // 判断是否为扫描生成的文件
    final fileSrcType = row['file_src_type']?.toString() ?? '';
    final isScanGenerated = fileSrcType == '扫描生成';
    // 判断是否已生效
    final isEnabled = _isEnabled(row);
    
    // 按钮列表，可以自动换行
    final buttons = <Widget>[
      // 预览按钮（蓝色，总是可用）
      ElevatedButton(
        onPressed: () {
          _navigateToPreviewPage(row, isEditMode: false);
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
        child: const Text('预览', style: TextStyle(fontSize: 13)),
      ),
      
      const SizedBox(width: 8),
      
      // 生效按钮（已生效时灰显，未生效时蓝色可用）
      ElevatedButton(
        onPressed: isEnabled ? null : () {
          _handleEnable(row);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? Colors.grey.shade300 : Colors.blue,
          foregroundColor: isEnabled ? Colors.grey.shade600 : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('生效', style: TextStyle(fontSize: 13)),
      ),
      
      const SizedBox(width: 8),
      
      // 修改按钮（已失效或扫描生成时灰显不可用）
      ElevatedButton(
        onPressed: (isEnabled && !isScanGenerated) ? () {
          _navigateToPreviewPage(row, isEditMode: true);
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: (isEnabled && !isScanGenerated) ? Colors.blue : Colors.grey.shade300,
          foregroundColor: (isEnabled && !isScanGenerated) ? Colors.white : Colors.grey.shade600,
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
      
      // 导出按钮（已失效时灰显不可用）
      ElevatedButton(
        onPressed: isEnabled ? () {
          _handleExportSingleFile(row);
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? Colors.blue : Colors.grey.shade300,
          foregroundColor: isEnabled ? Colors.white : Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('导出', style: TextStyle(fontSize: 13)),
      ),
      
      const SizedBox(width: 8),

      // 删除按钮（红色，仅超级管理员可用）
      if (_isSuperAdmin)
        ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认删除'),
                content: Text('确定要删除"${row['fileName']}"吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final accountFileUid = row['account_file_uid'] as String?;
                      final fileVersion = row['fileVersion'];
                      if (accountFileUid != null && fileVersion != null) {
                        try {
                          await _repository.deleteByAccountFileUidAndVersion(accountFileUid, fileVersion);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已删除: ${row['fileName']}')),
                            );
                            _loadData();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('删除失败: $e')),
                            );
                          }
                        }
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
          },
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
    ];
    
    // 使用Wrap使按钮可以自动换行
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  /// 导出单个文件
  Future<void> _handleExportSingleFile(Map<String, dynamic> row) async {
    // TODO: 实现单个文件导出功能
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出功能：${row['fileName']}')),
      );
    }
  }
}

