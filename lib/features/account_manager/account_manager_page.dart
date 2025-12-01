import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;

import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/file_manager.dart';
import '../../utils/import_export_utils.dart';
import '../../utils/password_utils.dart';
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

  // 选中的行ID集合
  Set<String> _selectedIds = {};

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
          'groupCode': manager.groupCode.isEmpty ? '' : manager.groupCode,
          'managerName': displayName,
          'managerPhone': (phone != null && phone.isNotEmpty) ? phone : '',
          'customerCount': stats?.customerCount ?? 0,
          'latestEntry': latestEntry != null
              ? _dateFormatter.format(latestEntry)
              : '',
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
      // 在 setState 之前保存 ScaffoldMessenger 引用
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
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

  /// 删除客户经理
  Future<void> _handleDeleteManager(Map<String, dynamic> row) async {
    // 在异步操作前保存 ScaffoldMessenger 引用
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final managerAccount = row['managerAccount'] as String?;
    final managerName = row['managerName'] as String?;
    
    if (managerAccount == null || managerAccount.isEmpty) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
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
          scaffoldMessenger.showSnackBar(
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
        // 在异步操作后使用保存的引用
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
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
        // 在异步操作后使用保存的引用
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('删除失败: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 选择状态变化处理
  void _handleSelectionChanged(List<int> selectedIds) {
    // 根据行索引获取对应的managerAccount
    final selectedManagerAccounts = <String>{};
    for (final id in selectedIds) {
      for (int i = 0; i < _tableData.length; i++) {
        dynamic row = _tableData[i];
        if (id == row['id']) {
          selectedManagerAccounts.add(row['managerAccount'] as String);
          break;
        }
      }
    }
    setState(() {
      _selectedIds = selectedManagerAccounts;
    });
  }

  /// 新增客户经理
  Future<void> _handleAddManager() async {
    // 在异步操作前保存 ScaffoldMessenger 引用
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => const AccountManagerAddPage(),
          ),
        ) ??
        false;

    if (!mounted) return;
    if (saved) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      _loadData();
    }
  }


  /// 下载导入模板 - 将assets中的Excel文件复制到Downloads目录
  void _handleDownloadTemplate() async {
    await ImportExportUtils.downloadTemplate(
      context,
      assetPath: 'assets/excel/customer_manager_info.xlsx',
      fileName: 'customer_manager_info.xlsx',
    );
  }


  /// 验证客户经理Excel文件
  Future<String?> _validateManagerExcelFile(File excelFile) async {
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
      if (sheet == null) {
        return '非标准压缩包，不支持导入2';
      }

      // 检查前四列表头
      const expectedHeaders = ['客户经理编号', '客户经理姓名', '客户经理手机号码', '团队编码'];
      final headerRow = sheet.rows[0];
      if (headerRow.length < 4) {
        return '非标准压缩包，不支持导入2';
      }

      // 检查表头是否匹配
      for (int i = 0; i < 4; i++) {
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

  /// 处理客户经理Excel数据
  Future<String?> _processManagerExcelData(File excelFile, String importDirPath) async {
    final excelBytes = await excelFile.readAsBytes();
    final excelBook = excel.Excel.decodeBytes(excelBytes);
    final sheetName = excelBook.tables.isNotEmpty
        ? excelBook.tables.keys.first
        : (excelBook.sheets.isNotEmpty ? excelBook.sheets.keys.first : null);
    if (sheetName == null) {
      throw Exception('无法读取Excel工作表');
    }

    final sheet = excelBook[sheetName];
    if (sheet == null) {
      throw Exception('无法访问Excel工作表');
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
      final teamCode = row[3]?.value?.toString() ?? '';

      if (managerCode.isEmpty) {
        continue; // 跳过客户经理编号为空的行
      }

      final existingManager = existingManagersMap[managerCode];
      if (existingManager != null) {
        // 更新现有用户
        final updatedManager = existingManager.copyWith(
          groupCode: teamCode, // 使用 Excel 中的团队编码
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
          groupCode: teamCode, // 使用 Excel 中的团队编码
          pwdUpdateDate: now, // 导入客户经理时，设置密码更新日期为当前时间
          createBy: loginUser?.userName,
          createTime: now,
          updateBy: loginUser?.userName,
          updateTime: now,
        );
        await _userRepository.upsert(newManager);
        insertCount++;
      }
    }

    // 重新加载数据
    _loadData();

    return '导入成功：新增 $insertCount 条，更新 $updateCount 条';
  }

  /// 导入客户经理
  Future<void> _handleImportManager() async {
    await ImportExportUtils.importFromZip(
      context,
      excelFileNamePrefix: 'customer_manager_info',
      validateExcelFile: _validateManagerExcelFile,
      processExcelData: _processManagerExcelData,
      loadingMessage: '正在导入客户经理数据...',
      onSuccess: (_) {
        // 数据已在 processExcelData 中重新加载
      },
      onError: (error) {
        debugPrint('导入客户经理失败: $error');
      },
    );
  }


  /// 导出客户经理
  Future<void> _handleExportManager() async {
    // 检查是否有选中的数据
    if (_selectedIds.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('没有勾选数据，无法导出'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    // 过滤选中的数据（客户经理使用managerAccount作为唯一标识）
    final selectedData = _tableData.where((row) => _selectedIds.contains(row['managerAccount'])).toList();

    await ImportExportUtils.exportToZip(
      context,
      templateAssetPath: 'assets/excel/customer_manager_info.xlsx',
      zipFileName: 'customer_manager_info_export',
      excelFileName: 'customer_manager_info_export',
      addTimestamp: true,
      data: selectedData,
      loadingMessage: '正在导出客户经理数据...',
      successMessage: '客户经理数据导出成功',
      headers: ['客户经理编号', '客户经理姓名', '客户经理手机号码', '团队编码'],
      dataToExcelRows: (sheet, rowData, rowIndex, filePathMap) {
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = excel.TextCellValue('${rowData['managerCode'] ?? ''}');
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = excel.TextCellValue('${rowData['managerName'] ?? ''}');
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = excel.TextCellValue('${rowData['managerPhone'] ?? ''}');
        sheet
            .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = excel.TextCellValue('${rowData['groupCode'] ?? ''}');
      },
      onSuccess: () {
        // 导出成功，无需额外操作
      },
      onError: (error) {
        debugPrint('导出客户经理数据失败: $error');
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
          label: '团队编码',
          builder: (row, context) => Text(row['groupCode']),
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
          label: '密码状态',
          builder: (row, context) => _buildPasswordStatus(row),
        ),
        DataTableColumn(
          label: '登录时间',
          builder: (row, context) => Text(row['latestEntry']),
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

        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
          child: Row(
              children: [
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
              ]
          ),
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
            // 在异步操作前保存 ScaffoldMessenger 引用
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final managerAccount = row['managerAccount'] as String?;
            if (managerAccount == null || managerAccount.isEmpty) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('无法获取客户经理编号')),
              );
              return;
            }
            try {
              final manager = await _userRepository.findByUserName(managerAccount);
              if (!mounted) return;
              if (manager == null) {
                scaffoldMessenger.showSnackBar(
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
              if (!mounted) return;
              if (saved) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('保存成功')),
                );
                _loadData();
              }
            } catch (error) {
              if (!mounted) return;
              scaffoldMessenger.showSnackBar(
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
                      // 在异步操作前保存 ScaffoldMessenger 引用
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      if (managerAccount == null || managerAccount.isEmpty) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('无法获取客户经理编号')),
                          );
                        }
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
                        // 重置密码时设置为首次登录
                        await _userRepository.setFirstLogin(managerAccount, true);
                        // 重置密码成功后自动解锁账号
                        await _userRepository.unlockAccount(managerAccount);
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('已重置密码: ${row['managerName']}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData(); // 重新加载数据以更新状态
                        }
                      } catch (error, stackTrace) {
                        debugPrintStack(stackTrace: stackTrace);
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('重置密码失败: $error')),
                          );
                        }
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

  /// 构建密码状态显示
  Widget _buildPasswordStatus(Map<String, dynamic> row) {
    final managerAccount = row['managerAccount'] as String?;
    if (managerAccount == null || managerAccount.isEmpty) {
      return const Text('未知');
    }

    return FutureBuilder<User?>(
      future: _userRepository.findByUserName(managerAccount),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('加载中...');
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Text('未知', style: TextStyle(color: Colors.grey));
        }

        final user = snapshot.data!;
        final List<String> statusItems = [];

        // 检查账号锁定状态
        if (PasswordUtils.isAccountLocked(user.lockUntil)) {
          final remainingMinutes = PasswordUtils.getLockMinutesRemaining(user.lockUntil);
          statusItems.add('已锁定(${remainingMinutes}分钟)');
        }

        // 检查首次登录状态
        else if (user.isFirstLogin == true) {
          statusItems.add('未修改默认密码');
        }

        // 检查密码过期状态
        else if (PasswordUtils.isPasswordExpired(user.pwdUpdateDate)) {
          statusItems.add('已过期');
        }
        else {
          final remainingDays = PasswordUtils.getPasswordExpiryDays(user.pwdUpdateDate);
          if (remainingDays <= 7) {
            statusItems.add('即将过期(${remainingDays}天)');
          }
        }

        if (statusItems.isEmpty) {
          return Text(
            '正常',
            style: TextStyle(
              color: Colors.green.shade600,
              fontWeight: FontWeight.w500,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: statusItems.map((status) {
            Color statusColor = Colors.grey;
            if (status.contains('已锁定')) {
              statusColor = Colors.red;
            } else if (status.contains('首次登录') || status.contains('已过期')) {
              statusColor = Colors.orange;
            } else if (status.contains('即将过期')) {
              statusColor = Colors.amber.shade700;
            }

            return Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

