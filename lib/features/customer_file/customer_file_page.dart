import 'dart:io';

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../widgets/common_data_table_page.dart';
import '../../utils/page_transition_animations.dart';
import '../../utils/storage_utils.dart';
import '../../utils/import_export_utils.dart';
import '../../data/models/user.dart';
import '../../data/models/customer_account_file.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'customer_file_add_page.dart';
import 'customer_file_add_picture_page.dart';
import 'customer_file_preview_page.dart';

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
  
  // Repository
  final CustomerRepository _repository = CustomerRepository();
  final UserRepository _userRepository = UserRepository();
  
  User? _loginUser;
  
  bool get _isAccountManager => _loginUser?.userType == '01';
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
      
      // 查询数据和总数
      final results = await Future.wait([
        _repository.findAccountFilesWithDetails(
          limit: itemsPerPage,
          offset: offset,
          customerNameKeyword: customerNameKeyword,
          phoneKeyword: phoneKeyword,
          fileNameKeyword: fileNameKeyword,
          managerAccount: _managerAccount,
        ),
        _repository.countAccountFiles(
          customerNameKeyword: customerNameKeyword,
          phoneKeyword: phoneKeyword,
          fileNameKeyword: fileNameKeyword,
          managerAccount: _managerAccount,
        ),
      ]);
      
      final rawData = results[0] as List<Map<String, Object?>>;
      final total = results[1] as int;
      
      // 转换数据格式以匹配表格显示
      _data = rawData.map((row) {
        return {
          'account_file_uid': row['account_file_uid'] ?? '-',
          'customerName': row['customer_name'] ?? '',
          'phone': row['phone'] ?? '',
          'fileName': row['account_file_name'] ?? '',
          'version': row['file_version'] ?? '-',
          'status': row['sign_status'] ?? '-',
          'file_src_type': row['file_src_type'] ?? '',
          'template': row['template_name'] ?? '-',
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
    _loadData();
  }

  /// 页码变化
  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadData();
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
    final fileVersion = row['version']?.toString();
    final fileSrcType = row['file_src_type']?.toString();

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
        '签署状态',
        '开户方式',
        '使用模板',
        '客户经理编号'
      ];
      final headerRow = sheet.rows[0];
      if (headerRow.length < expectedHeaders.length) {
        return '非标准压缩包，不支持导入2';
      }

      // 检查表头是否匹配
      for (int i = 0; i < expectedHeaders.length; i++) {
        final cellValue = headerRow[i]?.value?.toString() ?? '';
        if (cellValue != expectedHeaders[i]) {
          return '非标准压缩包，不支持导入2';
        }
      }

      return null; // 验证通过
    } catch (e) {
      return '验证Excel文件失败: $e';
    }
  }

  /// 处理开户文件Excel数据
  Future<String?> _processAccountFileExcelData(File excelFile) async {
    final excelBytes = await excelFile.readAsBytes();
    final excelBook = excel.Excel.decodeBytes(excelBytes);
    final sheetName = excelBook.tables.isNotEmpty
        ? excelBook.tables.keys.first
        : (excelBook.sheets.isNotEmpty ? excelBook.sheets.keys.first : null);
    if (sheetName == null) {
      throw Exception('无法读取Excel工作表');
    }

    final sheet = excelBook[sheetName];

    // 读取 Excel 数据并导入数据库
    final loginUser = await StorageUtils.getLoginUser();
    final now = DateTime.now();
    int insertCount = 0;
    int updateCount = 0;

    // 获取所有现有客户（用于匹配）
    final allCustomers = await _repository.search(limit: 10000);
    final customersByNameMap = <String, String>{}; // key: customerName, value: customerUid
    final customersByPhoneMap = <String, String>{}; // key: phone, value: customerUid
    for (final customer in allCustomers) {
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
      final fileVersion = (row[3]?.value?.toString() ?? '').trim();
      final signStatus = row[4]?.value?.toString()?.trim();
      final fileSrcType = row[5]?.value?.toString()?.trim();
      final templateName = row[6]?.value?.toString()?.trim();
      final managerAccount = (row[7]?.value?.toString() ?? '').trim();

      if (accountFileName.isEmpty) {
        continue; // 跳过开户文件名为空的行
      }

      // 查找客户UID
      if (customerUid.isEmpty) {
        continue; // 跳过客户编码为空的行
      }

      // 验证客户经理是否存在
      if (managerAccount.isNotEmpty) {
        final manager = await _userRepository.findByUserName(managerAccount);
        if (manager == null) {
          continue; // 跳过客户经理不存在的行
        }
      }

      // 尝试匹配现有开户文件
      final key = accountFileUid.isNotEmpty
          ? '${accountFileUid}_$fileVersion'
          : '${customerUid}_${accountFileName}_$fileVersion';
      final existingFile = accountFilesMap[key];

      if (existingFile != null) {
        // 更新现有开户文件
        final updatedFile = existingFile.copyWith(
          accountFileName: accountFileName.isNotEmpty ? accountFileName : existingFile.accountFileName,
          fileVersion: fileVersion.isNotEmpty ? fileVersion : existingFile.fileVersion,
          signStatus: signStatus?.isNotEmpty == true ? signStatus : existingFile.signStatus,
          fileSrcType: fileSrcType?.isNotEmpty == true ? fileSrcType : existingFile.fileSrcType,
          templateName: templateName?.isNotEmpty == true ? templateName : existingFile.templateName,
          updateBy: loginUser?.userName,
          updateTime: now,
        );
        await _repository.addAccountFile(
          updatedFile,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        updateCount++;
      } else {
        // 插入新开户文件
        // 注意：这里无法导入文件路径，因为实际文件不在Excel中
        // 如果需要导入文件，需要额外的处理逻辑
        final newFile = CustomerAccountFile(
          accountFileUid: accountFileUid.isNotEmpty
              ? accountFileUid
              : '${customerUid}_${DateTime.now().millisecondsSinceEpoch}',
          customerUid: customerUid,
          accountFileName: accountFileName,
          fileVersion: fileVersion.isNotEmpty ? fileVersion : '1',
          filePath: '', // 文件路径需要单独处理
          signStatus: signStatus,
          fileSrcType: fileSrcType,
          templateName: templateName,
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

  /// 导出开户文件
  Future<void> _handleExportAccountFile() async {
    await ImportExportUtils.exportToZip(
      context,
      templateAssetPath: 'assets/excel/account_file_info.xlsx',
      zipFileName: 'account_file_info_export',
      excelFileName: 'account_file_info_export',
      data: _data,
      headers: const [
        '开户文件编号',
        '客户编码',
        '开户文件名',
        '文件版本',
        '文件路径',
        '签署状态',
        '开户方式',
        '使用模板',
        '客户经理编号'
      ],
      beforeDataToExcelRows: (exportDirPath) async {
        // 复制文件到files文件夹，并返回相对路径映射
        final filesDir = Directory(p.join(exportDirPath, 'files'));
        if (!await filesDir.exists()) {
          await filesDir.create(recursive: true);
        }

        final filePathMap = <String, String>{}; // key: 原始路径, value: 相对路径

        for (final rowData in _data) {
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
            final targetFileName = fileName;
            final targetFilePath = p.join(filesDir.path, targetFileName);
            final targetFile = File(targetFilePath);

            // 如果目标文件已存在，添加时间戳
            if (await targetFile.exists()) {
              final nameWithoutExt = p.basenameWithoutExtension(fileName);
              final ext = p.extension(fileName);
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final uniqueFileName = '${nameWithoutExt}_$timestamp$ext';
              final uniqueTargetPath = p.join(filesDir.path, uniqueFileName);
              await sourceFile.copy(uniqueTargetPath);
              // 相对路径：files/文件名
              filePathMap[originalFilePath] = 'files/$uniqueFileName';
            } else {
              await sourceFile.copy(targetFilePath);
              // 相对路径：files/文件名
              filePathMap[originalFilePath] = 'files/$fileName';
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
            .value = excel.TextCellValue(rowData['version']?.toString() ?? '-');
        // 文件路径（相对路径，如 files/xxx.pdf）
        String localPath = rowData['filePath']?.toString() ?? '-';
        String? relativePath = localPath;
        if (filePathMap != null && filePathMap.containsKey(localPath)) {
          relativePath = filePathMap[localPath];
        }
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = excel.TextCellValue(relativePath!);
        // 签署状态
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['status']?.toString() ?? '-');
        // 开户方式
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['file_src_type']?.toString() ?? '');
        // 使用模板
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['template']?.toString() ?? '-');
        // 客户经理编号
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
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
          builder: (row, context) => Text(row['version']?.toString() ?? '-'),
        ),
        DataTableColumn(
          label: '签署状态',
          builder: (row, context) => _buildStatusBadge(row['status']?.toString() ?? '-'),
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

  /// 构建状态标签
  Widget _buildStatusBadge(String? status) {
    if (status == null || status.isEmpty || status == '-') {
      return Text(status ?? '-');
    }
    
    Color backgroundColor;
    Color textColor;
    
    switch (status) {
      case '已签署':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case '未签署':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 13,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActions(Map<String, dynamic> row) {
    // 判断是否为扫描生成的文件
    final fileSrcType = row['file_src_type']?.toString() ?? '';
    final isScanGenerated = fileSrcType == '扫描生成';
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 文件预览按钮（蓝色）
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
          child: const Text('文件预览', style: TextStyle(fontSize: 13)),
        ),
        
        const SizedBox(width: 8),
        
        // 修改按钮（如果是扫描生成则灰显不可用）
        ElevatedButton(
          onPressed: isScanGenerated ? null : () {
            _navigateToPreviewPage(row, isEditMode: true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isScanGenerated ? Colors.grey.shade300 : Colors.blue,
            foregroundColor: isScanGenerated ? Colors.grey.shade600 : Colors.white,
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
        
        // 删除按钮（红色）
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
                      final fileVersion = row['file_version'] as String?;
                      if (accountFileUid != null) {
                        try {
                          await _repository.deleteByAccountFileUidAndVersion(accountFileUid, fileVersion!);
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
      ],
    );
  }
}

