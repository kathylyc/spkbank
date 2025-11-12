import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/user_repository.dart';
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

  /// 下载导入模板
  void _handleDownloadTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('下载导入模板')),
    );
  }

  /// 导入客户经理
  void _handleImportManager() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导入客户经理')),
    );
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
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认删除'),
                content: Text('确定要删除客户经理"${row['managerName']}"吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已删除: ${row['managerName']}')),
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

