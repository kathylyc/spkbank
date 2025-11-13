import 'package:flutter/material.dart';
import '../../widgets/common_data_table_page.dart';
import '../../utils/page_transition_animations.dart';
import '../../data/repositories/customer_repository.dart';
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
  int _totalItems = 0;
  
  // 数据
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  
  // Repository
  final CustomerRepository _repository = CustomerRepository();

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
        ),
        _repository.countAccountFiles(
          customerNameKeyword: customerNameKeyword,
          phoneKeyword: phoneKeyword,
          fileNameKeyword: fileNameKeyword,
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
  void _handleScanToPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('扫描生成PDF')),
    );
  }

  /// 新增开户文件
  void _handleAddFile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '新增开户文件',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '请选择新增方式：',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          // 取消按钮
          // TextButton(
          //   onPressed: () => Navigator.pop(context),
          //   style: TextButton.styleFrom(
          //     foregroundColor: Colors.grey.shade700,
          //   ),
          //   child: const Text('取消'),
          // ),
          // 从模板新增按钮
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAddPage(0); // 0 表示模板生成 Tab
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('从模板新增'),
          ),
          // 上传PDF新增按钮
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAddPage(1); // 1 表示上传PDF Tab
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('上传PDF新增'),
          ),
        ],
      ),
    );
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

