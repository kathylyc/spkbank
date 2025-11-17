import 'dart:io';

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';

import '../../data/models/customer.dart';
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
  Future<String?> _processCustomerExcelData(File excelFile) async {
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

    // 重新加载数据
    _loadData();

    return '导入成功：新增 $insertCount 条，更新 $updateCount 条';
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
    await ImportExportUtils.exportToZip(
      context,
      templateAssetPath: 'assets/excel/customer_info.xlsx',
      zipFileName: 'customer_info_export',
      excelFileName: 'customer_info_export',
      data: _tableData,
      headers: const ['客户编号', '客户姓名', '电话号码', '客户地址', '客户标签', '客户经理姓名', '客户经理编号', '最后更新时间'],
      loadingMessage: '正在导出客户数据...',
      successMessage: '客户数据导出成功',
      dataToExcelRows: (sheet, rowData, rowIndex) {
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
}

