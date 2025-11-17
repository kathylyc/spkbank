import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/customer.dart';
import '../../data/models/customer_attachment_file.dart';
import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/common_const.dart';
import '../../utils/import_export_utils.dart';
import '../../utils/storage_utils.dart';
import '../../widgets/common_data_table_page.dart';
import 'customer_add_page.dart';
import 'customer_attachment_page.dart';

/// 客户管理页面
class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  // 查询条件
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedTag;
  final CustomerRepository _customerRepository = CustomerRepository();
  final UserRepository _userRepository = UserRepository();
  
  static const int _itemsPerPage = 20;
  
  // 分页
  int _currentPage = 1;
  int _totalItems = 0;
  
  // 表格数据
  List<Map<String, dynamic>> _tableData = [];
  
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
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// 加载数据
  Future<void> _loadData() async {
    final nameKeyword = _nameController.text.trim();
    final phoneKeyword = _phoneController.text.trim();
    final tagKeyword = _selectedTag?.trim();

    try {
      final totalItems = await _customerRepository.count(
        nameKeyword: nameKeyword.isEmpty ? null : nameKeyword,
        phoneKeyword: phoneKeyword.isEmpty ? null : phoneKeyword,
        managerAccount: _managerAccount,
        tag: tagKeyword != null && tagKeyword.isNotEmpty ? tagKeyword : null,
      );
      final totalPages = (totalItems / _itemsPerPage).ceil();
      var currentPage = _currentPage;
      if (totalPages == 0) {
        currentPage = 1;
      } else if (currentPage > totalPages) {
        currentPage = totalPages;
      }

      final offset = totalItems == 0 ? 0 : (currentPage - 1) * _itemsPerPage;
      final customers = totalItems == 0
          ? <Customer>[]
          : await _customerRepository.search(
              limit: _itemsPerPage,
              offset: offset,
              nameKeyword: nameKeyword.isEmpty ? null : nameKeyword,
              phoneKeyword: phoneKeyword.isEmpty ? null : phoneKeyword,
              managerAccount: _managerAccount,
              tag: tagKeyword != null && tagKeyword.isNotEmpty ? tagKeyword : null,
            );

      final managerAccounts = customers.map((customer) => customer.managerAccount).toSet();
      final managerMap = <String, User>{};
      for (final account in managerAccounts) {
        final manager = await _userRepository.findByUserName(account);
        if (manager != null) {
          managerMap[account] = manager;
        }
      }

      final attachmentsList = await Future.wait(
        customers.map((customer) => _customerRepository.findAttachmentFiles(customer.customerUid)),
      );

      final tableData = <Map<String, dynamic>>[];
      for (int index = 0; index < customers.length; index++) {
        final customer = customers[index];
        final attachments = attachmentsList[index];
        final manager = managerMap[customer.managerAccount];
        tableData.add({
          'customer': customer,
          'id': offset + index + 1,
          'customerUid': customer.customerUid,
          'name': customer.customerName,
          'phone': customer.phone ?? '-',
          'address': customer.address ?? '-',
          'tags': _resolveTags(customer),
          'attachments': attachments.map((file) => file.attachmentType).toList(),
          'managerCode': customer.managerAccount,
          'managerName': _resolveManagerName(manager, customer.managerAccount),
          'updateTime': customer.updateTime?.toIso8601String() ?? '-',
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
        SnackBar(content: Text('加载客户数据失败: $error')),
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
    // 这里可以根据查询条件过滤数据
  }

  /// 重置
  void _handleReset() {
    _nameController.clear();
    _phoneController.clear();
    setState(() {
      _selectedTag = null;
      _currentPage = 1;
    });
    _loadData();
  }

  /// 页码变化
  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadData();
  }

  Future<void> _handleAddCustomer() async {
    final bool? hasChanged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const CustomerAddPage()),
    );
    if (hasChanged == true) {
      _loadData();
    }
  }

  Future<void> _handleEditCustomer(Customer customer) async {
    final bool? hasChanged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => CustomerAddPage(customer: customer)),
    );
    if (hasChanged == true) {
      _loadData();
    }
  }

  Future<void> _handleUploadAttachment(Customer customer) async {
    final bool? hasChanged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CustomerAttachmentPage(customer: customer),
      ),
    );
    if (hasChanged == true) {
      _loadData();
    }
  }

  /// 下载导入模板
  void _handleDownloadTemplate() async {
    await ImportExportUtils.downloadTemplate(
      context,
      assetPath: 'assets/excel/customer_info.xlsx',
      fileName: 'customer_info.xlsx',
    );
  }

  /// 验证客户Excel文件
  Future<String?> _validateCustomerExcelFile(File excelFile) async {
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

      const expectedHeaders = ['客户编号', '客户姓名', '电话号码', '客户地址', '客户标签', '客户经理姓名', '客户经理编号', '最后更新时间'];
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

  /// 处理客户Excel数据
  Future<String?> _processCustomerExcelData(File excelFile, String importDirPath) async {
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

    // 获取所有现有客户，优先使用customerUid匹配，其次使用customerName和managerAccount匹配
    final allCustomers = await _customerRepository.search(
      limit: 10000, // 获取所有客户用于匹配
    );
    final customersByUidMap = <String, Customer>{}; // key: customerUid
    final customersByNameMap = <String, Customer>{}; // key: customerName_managerAccount
    for (final customer in allCustomers) {
      customersByUidMap[customer.customerUid] = customer;
      final key = '${customer.customerName}_${customer.managerAccount}';
      customersByNameMap[key] = customer;
    }

    // 从第二行开始读取数据（第一行是表头）
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty || row[0]?.value == null) {
        continue; // 跳过空行
      }

      final customerUid = (row[0]?.value?.toString() ?? '').trim();
      final customerName = (row[1]?.value?.toString() ?? '').trim();
      final phone = row[2]?.value?.toString()?.trim();
      final address = row[3]?.value?.toString()?.trim();
      final customerTag = row[4]?.value?.toString()?.trim();
      final managerName = (row[5]?.value?.toString() ?? '').trim();
      final managerAccount = (row[6]?.value?.toString() ?? '').trim();
      final updateTime = (row[7]?.value?.toString() ?? '').trim();

      if (customerName.isEmpty) {
        continue; // 跳过客户姓名为空的行
      }

      if (managerAccount.isEmpty) {
        continue; // 跳过客户经理编码为空的行
      }

      // 验证客户经理是否存在
      final manager = await _userRepository.findByUserName(managerAccount);
      if (manager == null) {
        continue; // 跳过客户经理不存在的行
      }

      // 尝试匹配现有客户（优先使用customerUid，其次使用客户姓名和客户经理编码）
      Customer? existingCustomer;
      if (customerUid.isNotEmpty) {
        existingCustomer = customersByUidMap[customerUid];
      }
      if (existingCustomer == null) {
        final key = '${customerName}_$managerAccount';
        existingCustomer = customersByNameMap[key];
      }

      if (existingCustomer != null) {
        // 更新现有客户
        final updatedCustomer = existingCustomer.copyWith(
          phone: phone?.isNotEmpty == true ? phone : existingCustomer.phone,
          address: address?.isNotEmpty == true ? address : existingCustomer.address,
          customerTag: customerTag?.isNotEmpty == true ? customerTag : existingCustomer.customerTag,
          updateBy: loginUser?.userName,
          updateTime: now,
        );
        await _customerRepository.upsert(updatedCustomer);
        updateCount++;
      } else {
        // 插入新客户
        await _customerRepository.create(
          customerUid: customerUid,
          customerName: customerName,
          countryCode: '86', // 默认国家代码
          managerAccount: managerAccount,
          phone: phone?.isNotEmpty == true ? phone : null,
          address: address?.isNotEmpty == true ? address : null,
          customerTag: customerTag?.isNotEmpty == true ? customerTag : null,
          createBy: loginUser?.userName,
          createTime: now,
        );
        insertCount++;
      }
    }

    // 处理客户附件信息（customer_attachment_info.xlsx 和 files 目录）
    int attachmentInsertCount = 0;
    int attachmentUpdateCount = 0;
    
    // 查找 customer_attachment_info.xlsx 文件
    final importDir = Directory(importDirPath);
    File? attachmentInfoFile;
    if (await importDir.exists()) {
      final files = importDir.listSync();
      for (final file in files) {
        if (file is File) {
          final fileName = p.basename(file.path);
          if (fileName.toLowerCase().startsWith('customer_attachment_info') &&
              fileName.toLowerCase().endsWith('.xlsx')) {
            attachmentInfoFile = file;
            break;
          }
        }
      }
    }
    
    // 如果存在附件信息文件，处理附件
    if (attachmentInfoFile != null) {
      // 获取APP缓存附件目录（使用与FileManager相同的目录结构）
      final cacheDir = await getApplicationCacheDirectory();
      
      // 检查是否有files目录
      final filesDir = Directory(p.join(importDirPath, 'files'));
      final hasFilesDir = await filesDir.exists();
      
      // 读取附件信息Excel文件
      final attachmentExcelBytes = await attachmentInfoFile.readAsBytes();
      final attachmentExcelBook = excel.Excel.decodeBytes(attachmentExcelBytes);
      final attachmentSheetName = attachmentExcelBook.tables.isNotEmpty
          ? attachmentExcelBook.tables.keys.first
          : (attachmentExcelBook.sheets.isNotEmpty ? attachmentExcelBook.sheets.keys.first : null);
      
      if (attachmentSheetName != null) {
        final attachmentSheet = attachmentExcelBook[attachmentSheetName];
        
        // 获取所有现有附件（用于匹配）
        final allExistingAttachments = <String, CustomerAttachmentFile>{}; // key: customerUid_attachmentType
        for (final customerUid in customersByUidMap.keys) {
          final attachments = await _customerRepository.findAttachmentFiles(customerUid);
          for (final attachment in attachments) {
            final key = '${attachment.customerUid}_${attachment.attachmentType}';
            allExistingAttachments[key] = attachment;
          }
        }
        
        // 从第二行开始读取附件数据（第一行是表头）
        for (int i = 1; i < attachmentSheet.rows.length; i++) {
          final row = attachmentSheet.rows[i];
          if (row.isEmpty || row[0]?.value == null) {
            continue; // 跳过空行
          }
          
          final attachmentCustomerUid = (row[0]?.value?.toString() ?? '').trim();
          final phone = (row[1]?.value?.toString() ?? '').trim();
          final attachmentType = (row[2]?.value?.toString() ?? '').trim(); // 文件名（文件类型）
          final relativeFilePath = (row[3]?.value?.toString() ?? '').trim(); // 文件路径（相对路径）
          
          if (attachmentCustomerUid.isEmpty || attachmentType.isEmpty) {
            continue; // 跳过客户编码或附件类型为空的行
          }
          
          // 验证客户是否存在
          final customer = customersByUidMap[attachmentCustomerUid];
          if (customer == null) {
            debugPrint('客户不存在，跳过附件: customerUid=$attachmentCustomerUid, attachmentType=$attachmentType');
            continue; // 跳过客户不存在的附件
          }
          
          // 处理文件路径：如果Excel中有相对路径，且files目录存在，则复制文件到APP缓存目录
          String? appCacheFilePath;
          if (relativeFilePath.isNotEmpty && 
              relativeFilePath != '-' && 
              hasFilesDir && 
              relativeFilePath.startsWith('files/')) {
            try {
              // 获取源文件路径（在解压目录中）
              final sourceFilePath = p.join(importDirPath, relativeFilePath);
              final sourceFile = File(sourceFilePath);
              
              if (await sourceFile.exists()) {
                // 使用与FileManager相同的目录结构：cache/customer/{customerUid}/
                final customerAttachmentDir = Directory(p.join(cacheDir.path, 'customer', attachmentCustomerUid));
                if (!await customerAttachmentDir.exists()) {
                  await customerAttachmentDir.create(recursive: true);
                }
                
                // 生成目标文件名：使用原始文件名
                final fileName = p.basename(relativeFilePath);
                final targetFilePath = p.join(customerAttachmentDir.path, fileName);
                final targetFile = File(targetFilePath);
                
                // 如果目标文件已存在，先删除（替换）
                if (await targetFile.exists()) {
                  await targetFile.delete();
                }
                
                // 复制文件到APP缓存目录
                await sourceFile.copy(targetFilePath);
                appCacheFilePath = targetFilePath;
              } else {
                debugPrint('附件文件不存在，跳过: $sourceFilePath');
              }
            } catch (e) {
              debugPrint('复制附件文件失败: $relativeFilePath, 错误: $e');
              // 继续处理，不中断导入流程
            }
          }
          
          // 如果文件路径为空，跳过
          if (appCacheFilePath == null || appCacheFilePath.isEmpty) {
            continue;
          }
          
          // 尝试匹配现有附件
          final key = '${attachmentCustomerUid}_$attachmentType';
          final existingAttachment = allExistingAttachments[key];
          
          if (existingAttachment != null) {
            // 更新现有附件
            final updatedAttachment = existingAttachment.copyWith(
              filePath: appCacheFilePath,
              updateBy: loginUser?.userName,
              updateTime: now,
            );
            await _customerRepository.addAttachmentFile(updatedAttachment);
            attachmentUpdateCount++;
          } else {
            // 插入新附件
            final newAttachment = CustomerAttachmentFile(
              customerUid: attachmentCustomerUid,
              attachmentType: attachmentType,
              filePath: appCacheFilePath,
              createBy: loginUser?.userName,
              createTime: now,
              updateBy: loginUser?.userName,
              updateTime: now,
            );
            await _customerRepository.addAttachmentFile(newAttachment);
            attachmentInsertCount++;
          }
        }
      }
    }
    
    // 重新加载数据
    _loadData();
    
    final attachmentMessage = attachmentInsertCount > 0 || attachmentUpdateCount > 0
        ? '；附件：新增 $attachmentInsertCount 条，更新 $attachmentUpdateCount 条'
        : '';
    
    return '导入成功：新增 $insertCount 条，更新 $updateCount 条$attachmentMessage';
  }

  /// 导入客户
  Future<void> _handleImportCustomer() async {
    await ImportExportUtils.importFromZip(
      context,
      excelFileNamePrefix: 'customer_info',
      validateExcelFile: _validateCustomerExcelFile,
      processExcelData: _processCustomerExcelData,
      loadingMessage: '正在导入客户数据...',
      onSuccess: (_) {
        // 数据已在 processExcelData 中重新加载
      },
      onError: (error) {
        debugPrint('导入客户失败: $error');
      },
    );
  }

  /// 导出客户
  Future<void> _handleExportCustomer() async {
    // 收集所有客户的附件数据
    final allAttachments = <CustomerAttachmentFile>[];
    for (final rowData in _tableData) {
      final customer = rowData['customer'] as Customer?;
      if (customer != null) {
        final attachments = await _customerRepository.findAttachmentFiles(customer.customerUid);
        allAttachments.addAll(attachments);
      }
    }

    await ImportExportUtils.exportToZip(
      context,
      templateAssetPath: 'assets/excel/customer_info.xlsx',
      zipFileName: 'customer_info_export',
      excelFileName: 'customer_info_export',
      data: _tableData,
      headers: const ['客户编号', '客户姓名', '电话号码', '客户地址', '客户标签', '客户经理姓名', '客户经理编号', '最后更新时间'],
      beforeDataToExcelRows: (exportDirPath) async {
        // 复制附件文件到files文件夹，并返回相对路径映射
        final filesDir = Directory(p.join(exportDirPath, 'files'));
        if (!await filesDir.exists()) {
          await filesDir.create(recursive: true);
        }

        final filePathMap = <String, String>{}; // key: 原始路径, value: 相对路径

        // 复制所有附件文件
        for (final attachment in allAttachments) {
          final originalFilePath = attachment.filePath;
          if (originalFilePath.isEmpty) {
            continue;
          }

          try {
            final sourceFile = File(originalFilePath);
            if (!await sourceFile.exists()) {
              debugPrint('附件文件不存在，跳过: $originalFilePath');
              continue;
            }

            // 为每个客户创建单独的子目录：files/customerUid/
            final customerFilesDir = Directory(p.join(filesDir.path, attachment.customerUid));
            if (!await customerFilesDir.exists()) {
              await customerFilesDir.create(recursive: true);
            }

            // 生成文件名
            final fileName = p.basename(originalFilePath);
            final nameWithoutExt = p.basenameWithoutExtension(fileName);
            final ext = p.extension(fileName);
            final targetFileName = fileName;
            final targetFilePath = p.join(customerFilesDir.path, targetFileName);
            final targetFile = File(targetFilePath);

            // 如果文件名已存在，添加时间戳
            String finalFileName = targetFileName;
            if (await targetFile.exists()) {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              finalFileName = '${nameWithoutExt}_$timestamp$ext';
              final uniqueTargetPath = p.join(customerFilesDir.path, finalFileName);
              await sourceFile.copy(uniqueTargetPath);
            } else {
              await sourceFile.copy(targetFilePath);
            }

            // 相对路径：files/customerUid/文件名
            filePathMap[originalFilePath] = 'files/${attachment.customerUid}/$finalFileName';
          } catch (e) {
            debugPrint('复制附件文件失败: $originalFilePath, 错误: $e');
            // 继续处理其他文件
          }
        }

        return filePathMap;
      },
      generateExtraExcelFiles: (exportDirPath, filePathMap, timestamp) async {
        // 如果有附件数据，生成附件信息Excel文件
        if (allAttachments.isEmpty) {
          return [];
        }

        // 查询所有相关客户的手机号，建立映射
        final customerUids = allAttachments.map((a) => a.customerUid).toSet();
        final customerPhoneMap = <String, String>{}; // key: customerUid, value: phone
        for (final customerUid in customerUids) {
          final customer = await _customerRepository.findByUid(customerUid);
          if (customer != null) {
            customerPhoneMap[customerUid] = customer.phone ?? '';
          }
        }

        final attachmentExcelName = 'customer_attachment_info_$timestamp.xlsx';
        
        // 尝试加载模板，如果失败则创建新的Excel文件（使用模板的表头结构）
        excel.Excel attachmentExcelBook;
        String attachmentSheetName;
        excel.Sheet attachmentSheet;
        bool useTemplate = true;
        const attachmentHeaders = ['客户编码', '电话号码', '文件名（文件类型）', '文件路径'];

        try {
          // 加载模板文件并修复 numFmtId 问题
          final templateData = await rootBundle.load('assets/excel/customer_attachment_info.xlsx');
          final templateBytes = templateData.buffer.asUint8List();
          
          // 修复模板文件中的 numFmtId 问题
          final fixedBytes = _fixExcelNumFmtId(templateBytes);
          
          attachmentExcelBook = excel.Excel.decodeBytes(fixedBytes);
          
          // 获取所有 sheet 名称用于调试
          final allSheetNames = attachmentExcelBook.tables.isNotEmpty
              ? attachmentExcelBook.tables.keys.toList()
              : attachmentExcelBook.sheets.keys.toList();
          debugPrint('模板文件中的所有 sheet: $allSheetNames');
          
          attachmentSheetName = allSheetNames.isNotEmpty
              ? allSheetNames.first
              : 'Sheet1';
          if (attachmentSheetName.isEmpty) {
            throw Exception('模板中未找到可用的工作表');
          }
          
          debugPrint('使用 sheet: $attachmentSheetName');
          
          // 直接使用找到的第一个 sheet，确保使用模板中的原始 sheet
          attachmentSheet = attachmentExcelBook[attachmentSheetName];
          if (attachmentSheet == null) {
            throw Exception('无法访问工作表: $attachmentSheetName');
          }
        } catch (templateError, s) {
          // 模板加载失败，抛出错误（不允许加载失败）
          debugPrint('附件模板加载失败: $templateError');
          debugPrintStack(stackTrace: s);
          throw Exception('无法加载附件信息模板文件，请检查模板文件格式: $templateError');
        }

        // 填充附件数据（从第二行开始，第一行是表头）
        final startRow = 2; // 始终从第2行开始，因为第1行是表头
        for (int i = 0; i < allAttachments.length; i++) {
          final attachment = allAttachments[i];
          final rowIndex = startRow - 1 + i;
          
          // 客户编码
          attachmentSheet
              .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
              .value = excel.TextCellValue(attachment.customerUid);
          // 电话号码（根据customerUid查询）
          final phone = customerPhoneMap[attachment.customerUid] ?? '';
          attachmentSheet
              .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
              .value = excel.TextCellValue(phone);
          // 文件名（文件类型）
          attachmentSheet
              .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
              .value = excel.TextCellValue(attachment.attachmentType);
          // 文件路径（相对路径）
          final relativePath = filePathMap?[attachment.filePath] ?? attachment.filePath;
          attachmentSheet
              .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
              .value = excel.TextCellValue(relativePath);
        }

        // 生成Excel字节
        final attachmentExcelBytes = attachmentExcelBook.encode();
        if (attachmentExcelBytes == null) {
          throw Exception('生成附件信息Excel失败');
        }

        return [
          ExtraExcelFile(
            fileName: attachmentExcelName,
            bytes: attachmentExcelBytes,
            templateAssetPath: 'assets/excel/customer_attachment_info.xlsx',
          ),
        ];
      },
      loadingMessage: '正在导出客户数据...',
      successMessage: '客户数据导出成功',
      dataToExcelRows: (sheet, rowData, rowIndex, filePathMap) {
        final customer = rowData['customer'] as Customer?;
        if (customer == null) return;

        // 客户编号
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = excel.TextCellValue(customer.customerUid);
        // 客户姓名
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = excel.TextCellValue(customer.customerName);
        // 电话号码
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = excel.TextCellValue(customer.phone ?? '');
        // 客户地址
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = excel.TextCellValue(customer.address ?? '');
        // 客户标签
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = excel.TextCellValue(customer.customerTag ?? '');
        // 客户经理姓名
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = excel.TextCellValue(rowData['managerName'] ?? '');
        // 客户经理编码
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = excel.TextCellValue(customer.managerAccount);
        // 最后更新时间
        final updateTimeStr = customer.updateTime != null
            ? customer.updateTime!.toIso8601String()
            : '';
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
            .value = excel.TextCellValue(updateTimeStr);
      },
      onSuccess: () {
        // 导出成功，无需额外操作
      },
      onError: (error) {
        debugPrint('导出客户数据失败: $error');
      },
    );
  }

  List<String> _resolveTags(Customer customer) {
    final raw = customer.customerTag;
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  String _resolveManagerName(User? manager, String fallbackAccount) {
    if (manager == null) {
      return fallbackAccount;
    }
    if (manager.nickName.isNotEmpty) {
      return manager.nickName;
    }
    return manager.userName;
  }

  @override
  Widget build(BuildContext context) {
    return CommonDataTablePage(
      // 查询条件区域
      querySection: _buildQuerySection(),
      
      // 表格标题
      tableTitle: '维护客户基础信息',
      
      // 功能按钮
      actionButtons: [
        ActionButton(
          label: '新增客户',
          onPressed: _handleAddCustomer,
        ),
        ActionButton(
          label: '下载导入模板',
          onPressed: _handleDownloadTemplate,
        ),
        ActionButton(
          label: '导入客户',
          onPressed: _handleImportCustomer,
        ),
        ActionButton(
          label: '导出客户',
          onPressed: _handleExportCustomer,
        ),
      ],
      
      // 表格列定义
      columns: [
        DataTableColumn(
          label: '客户编号',
          builder: (row, context) => Text(row['customerUid']),
        ),
        DataTableColumn(
          label: '客户姓名',
          builder: (row, context) => Text(row['name']),
        ),
        DataTableColumn(
          label: '电话号码',
          builder: (row, context) => Text(row['phone']),
        ),
        DataTableColumn(
          label: '地址',
          builder: (row, context) => Text(row['address']),
        ),
        DataTableColumn(
          label: '客户标签',
          builder: (row, context) => _buildTags(row['tags']),
        ),
        DataTableColumn(
          label: '客户信息附件',
          builder: (row, context) => _buildAttachments(row),
        ),
        DataTableColumn(
          label: '客户经理编码',
          builder: (row, context) => Text(row['managerCode']),
        ),
        DataTableColumn(
          label: '客户经理姓名',
          builder: (row, context) => Text(row['managerName']),
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
        // 客户姓名
        Expanded(
          child: _buildTextField(
            controller: _nameController,
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
        
        // 客户标签
        Expanded(
          child: _buildDropdown(),
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

  /// 构建下拉框
  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '客户标签',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTag,
          decoration: InputDecoration(
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
          items: _buildTagDropdownItems(),
          onChanged: (value) {
            setState(() {
              if (value != null && value.isEmpty) {
                _selectedTag = null;
              } else {
                _selectedTag = value;
              }
            });
          },
        ),
      ],
    );
  }

  /// 构建标签
  Widget _buildTags(List<String> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: tags.map((tag) {
        final String displayTag = _resolveTagLabel(tag);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            displayTag,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _resolveTagLabel(String tag) {
    switch (tag) {
      case ConstCustomerTag.keyCustomer:
        return '大客户';
      case ConstCustomerTag.publicOfficials:
        return '公职人员';
      case ConstCustomerTag.highQualityCredit:
        return '优质征信';
      default:
        return tag;
    }
  }

  List<DropdownMenuItem<String>> _buildTagDropdownItems() {
    final List<MapEntry<String?, String>> options = [
      const MapEntry(null, '请选择'),
      MapEntry(ConstCustomerTag.keyCustomer, _resolveTagLabel(ConstCustomerTag.keyCustomer)),
      MapEntry(ConstCustomerTag.publicOfficials, _resolveTagLabel(ConstCustomerTag.publicOfficials)),
      MapEntry(ConstCustomerTag.highQualityCredit, _resolveTagLabel(ConstCustomerTag.highQualityCredit)),
    ];
    return options
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.key ?? '',
            child: Text(item.value),
          ),
        )
        .toList();
  }

  /// 构建附件链接
  Widget _buildAttachments(Map<String, dynamic> row) {
    final Customer customer = row['customer'] as Customer;
    final attachments = row['attachments'];
    if (attachments.isEmpty) {
      return Text(
        '-',
        style: TextStyle(
          color: Colors.grey.shade500,
        ),
      );
    }
    final displayText = attachments.join(', ');
    return InkWell(
      onTap: () {
        // 查看附件
        _handleUploadAttachment(customer);
      },
      child: Text(
        displayText,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActions(Map<String, dynamic> row) {
    final Customer customer = row['customer'] as Customer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 修改按钮
        ElevatedButton(
          onPressed: () => _handleEditCustomer(customer),
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
        
        // 上传附件按钮
        ElevatedButton(
          onPressed: () => _handleUploadAttachment(customer),
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
          child: const Text('上传附件', style: TextStyle(fontSize: 13)),
        ),
        
        const SizedBox(width: 8),
        
        // 删除按钮
        ElevatedButton(
          onPressed: () {
            // TODO: 实现删除功能
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认删除'),
                content: Text('确定要删除客户"${row['name']}"吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已删除: ${row['name']}')),
                      );
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

  /// 修复 Excel 文件中的 numFmtId 问题
  /// Excel 文件中的自定义数字格式 ID 必须从 164 开始
  /// 此方法会解压 Excel 文件，修复 styles.xml 中的 numFmtId，然后重新压缩
  List<int> _fixExcelNumFmtId(List<int> excelBytes) {
    try {
      // 解压 Excel 文件（.xlsx 实际上是一个 ZIP 文件）
      final archive = ZipDecoder().decodeBytes(excelBytes);
      
      // 查找并修复 styles.xml 文件
      ArchiveFile? stylesFile;
      for (final file in archive) {
        if (file.name == 'xl/styles.xml' || file.name == 'xl\\styles.xml') {
          stylesFile = file;
          break;
        }
      }
      
      if (stylesFile != null) {
        // 读取 styles.xml 内容
        final stylesContent = utf8.decode(stylesFile.content as List<int>);
        
        // 使用两个正则表达式分别匹配双引号和单引号格式
        final doubleQuotePattern = RegExp(r'numFmtId="(\d+)"');
        final singleQuotePattern = RegExp(r"numFmtId='(\d+)'");
        final numFmtDefPattern = RegExp(r'<numFmt\s+numFmtId="(\d+)"');
        final numFmtDefPatternSingle = RegExp(r"<numFmt\s+numFmtId='(\d+)'");
        
        // 第一步：收集所有格式定义中的 numFmtId
        final definedIds = <int>{};
        for (final match in numFmtDefPattern.allMatches(stylesContent)) {
          final id = int.tryParse(match.group(1) ?? '');
          if (id != null) {
            definedIds.add(id);
          }
        }
        for (final match in numFmtDefPatternSingle.allMatches(stylesContent)) {
          final id = int.tryParse(match.group(1) ?? '');
          if (id != null) {
            definedIds.add(id);
          }
        }
        
        // 第二步：收集所有引用中的 numFmtId
        final referencedIds = <int>{};
        for (final match in doubleQuotePattern.allMatches(stylesContent)) {
          final id = int.tryParse(match.group(1) ?? '');
          if (id != null) {
            referencedIds.add(id);
          }
        }
        for (final match in singleQuotePattern.allMatches(stylesContent)) {
          final id = int.tryParse(match.group(1) ?? '');
          if (id != null) {
            referencedIds.add(id);
          }
        }
        
        // 第三步：找到所有需要修复的 numFmtId（小于 164 的，且在格式定义中存在的）
        final idsToFix = <int>{};
        for (final id in definedIds) {
          if (id >= 0 && id < 164) {
            idsToFix.add(id);
          }
        }
        
        // 第四步：为每个需要修复的 ID 分配一个新的唯一 ID（从 164 开始）
        final idMapping = <int, int>{};
        final allExistingIds = <int>{...definedIds, ...referencedIds};
        int nextId = 164;
        for (final oldId in idsToFix) {
          // 找到一个不冲突的新 ID
          while (allExistingIds.contains(nextId)) {
            nextId++;
          }
          idMapping[oldId] = nextId;
          allExistingIds.add(nextId); // 标记为已使用
          nextId++;
        }
        
        // 第五步：替换所有需要修复的 numFmtId（包括格式定义和引用）
        // 注意：需要按从大到小的顺序替换，避免替换冲突
        String fixedContent = stylesContent;
        final sortedMappings = idMapping.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)); // 从大到小排序
        
        for (final entry in sortedMappings) {
          final oldId = entry.key;
          final newId = entry.value;
          debugPrint('修复 numFmtId: $oldId -> $newId');
          
          // 替换格式定义中的 numFmtId（<numFmt numFmtId="..."/>）
          fixedContent = fixedContent.replaceAll(
            '<numFmt numFmtId="$oldId"',
            '<numFmt numFmtId="$newId"',
          );
          fixedContent = fixedContent.replaceAll(
            "<numFmt numFmtId='$oldId'",
            "<numFmt numFmtId='$newId'",
          );
          
          // 替换引用中的 numFmtId（numFmtId="..."）
          fixedContent = fixedContent.replaceAll(
            'numFmtId="$oldId"',
            'numFmtId="$newId"',
          );
          // 替换单引号格式
          fixedContent = fixedContent.replaceAll(
            "numFmtId='$oldId'",
            "numFmtId='$newId'",
          );
        }
        
        // 更新 archive 中的文件
        final fixedStylesBytes = utf8.encode(fixedContent);
        archive.removeFile(stylesFile);
        archive.addFile(ArchiveFile(
          stylesFile.name,
          fixedStylesBytes.length,
          fixedStylesBytes,
        ));
      }
      
      // 重新压缩为 Excel 文件
      final encoder = ZipEncoder();
      final fixedBytes = encoder.encode(archive);
      
      if (fixedBytes == null) {
        debugPrint('重新压缩 Excel 文件失败，返回原始字节');
        return excelBytes;
      }
      
      return fixedBytes;
    } catch (e, s) {
      debugPrint('修复 Excel numFmtId 失败: $e');
      debugPrintStack(stackTrace: s);
      // 如果修复失败，返回原始字节，让后续的错误处理来处理
      return excelBytes;
    }
  }
}

