import 'package:flutter/material.dart';
import '../../widgets/common_data_table_page.dart';

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
  
  // 分页
  int _currentPage = 1;
  int _totalItems = 100; // 示例总数
  
  // 模拟数据
  List<Map<String, dynamic>> _mockData = [];

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
  void _loadData() {
    // 生成模拟数据
    final names = ['张经理', '李经理', '王经理'];
    final customerCounts = [4, 6, 10, 12, 8];
    
    _mockData = List.generate(20, (index) {
      final nameIndex = index % 3;
      final countIndex = index % 5;
      
      return {
        'id': (_currentPage - 1) * 20 + index + 1,
        'managerCode': '20030211',
        'managerName': names[nameIndex],
        'managerPhone': '18987765666',
        'customerCount': customerCounts[countIndex],
        'entryTime': '2025-10-12',
      };
    });
    
    setState(() {});
  }

  /// 查询
  void _handleQuery() {
    _currentPage = 1;
    _loadData();
    // 这里可以根据查询条件过滤数据
  }

  /// 重置
  void _handleReset() {
    _managerCodeController.clear();
    _managerNameController.clear();
    _managerPhoneController.clear();
  }

  /// 页码变化
  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadData();
  }

  /// 新增客户经理
  void _handleAddManager() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('新增客户经理')),
    );
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
        DataTableColumn(
          label: 'id',
          builder: (row, context) => Text(row['id'].toString()),
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
      data: _mockData,
      
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
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('修改客户经理: ${row['managerName']}')),
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
          child: const Text('修改', style: TextStyle(fontSize: 13)),
        ),
        
        const SizedBox(width: 8),
        
        // 重置密码按钮（蓝色）
        ElevatedButton(
          onPressed: () {
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
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已重置密码: ${row['managerName']}')),
                      );
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

