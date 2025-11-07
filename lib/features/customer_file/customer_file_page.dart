import 'package:flutter/material.dart';
import '../../widgets/common_data_table_page.dart';
import '../../utils/page_transition_animations.dart';
import 'customer_file_add_page.dart';

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
    _customerNameController.dispose();
    _phoneController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  /// 加载数据
  void _loadData() {
    // 生成模拟数据
    final names = ['张三', '李四', '王五'];
    final fileNames = [
      '开户文件_张三',
      '开户文件_李四',
      '开户文件_王五',
      '董事长签名扫描件',
    ];
    final versions = ['V1.0', 'V2.0', '-'];
    final statuses = ['未签署', '已签署', '-'];
    final templates = [
      'Account Mandate for Business Account',
      'Account Mandate for Business Account',
      '-',
    ];
    
    _mockData = List.generate(20, (index) {
      final nameIndex = index % 3;
      final fileIndex = index % 4;
      final versionIndex = index % 3;
      
      return {
        'id': (_currentPage - 1) * 20 + index + 1,
        'customerName': names[nameIndex],
        'phone': '17776666666',
        'fileName': fileNames[fileIndex],
        'version': versions[versionIndex],
        'status': statuses[versionIndex],
        'template': templates[versionIndex],
        'managerCode': '20030211',
        'managerName': '张经理',
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
    _customerNameController.clear();
    _phoneController.clear();
    _fileNameController.clear();
  }

  /// 页码变化
  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadData();
  }

  /// 扫描生成PDF
  void _handleScanToPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('扫描生成PDF')),
    );
  }

  /// 新增开户文件
  void _handleAddFile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const CustomerFileAddPage();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return PageTransitionAnimations.slideFromRight(child, animation);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// 导出压缩包
  void _handleExportZip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出压缩包')),
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
        ActionButton(
          label: '导出压缩包',
          onPressed: _handleExportZip,
        ),
      ],
      
      // 表格列定义
      columns: [
        DataTableColumn(
          label: 'id',
          builder: (row, context) => Text(row['id'].toString()),
        ),
        DataTableColumn(
          label: '客户姓名',
          builder: (row, context) => Text(row['customerName']),
        ),
        DataTableColumn(
          label: '电话号码',
          builder: (row, context) => Text(row['phone']),
        ),
        DataTableColumn(
          label: '开户文件名',
          builder: (row, context) => Text(row['fileName']),
        ),
        DataTableColumn(
          label: '文件版本',
          builder: (row, context) => Text(row['version']),
        ),
        DataTableColumn(
          label: '签署状态',
          builder: (row, context) => _buildStatusBadge(row['status']),
        ),
        DataTableColumn(
          label: '使用模板',
          builder: (row, context) => Text(row['template']),
        ),
        DataTableColumn(
          label: '客户经理编号',
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
  Widget _buildStatusBadge(String status) {
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 文件预览按钮（蓝色）
        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('文件预览: ${row['fileName']}')),
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
          child: const Text('文件预览', style: TextStyle(fontSize: 13)),
        ),
        
        const SizedBox(width: 8),
        
        // 修改按钮（灰色）
        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('修改: ${row['fileName']}')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.grey.shade800,
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
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已删除: ${row['fileName']}')),
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

