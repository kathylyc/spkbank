import 'package:flutter/material.dart';

import '../../data/models/customer.dart';
import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/common_const.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
          label: '导入客户',
          onPressed: () {
            // TODO: 实现导入客户
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('导入客户')),
            );
          },
        ),
        ActionButton(
          label: '导出客户',
          onPressed: () {
            // TODO: 实现导出客户
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('导出客户')),
            );
          },
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
          builder: (row, context) => _buildAttachments(row['attachments']),
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
  Widget _buildAttachments(List<String> attachments) {
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
        // TODO: 查看附件
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查看附件: $displayText')),
        );
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

