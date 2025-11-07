import 'package:flutter/material.dart';
import '../../utils/page_transition_animations.dart';
import 'customer_file_preview_page.dart';

/// 新增开户文件页面
class CustomerFileAddPage extends StatefulWidget {
  const CustomerFileAddPage({super.key});

  @override
  State<CustomerFileAddPage> createState() => _CustomerFileAddPageState();
}

class _CustomerFileAddPageState extends State<CustomerFileAddPage>
    with SingleTickerProviderStateMixin {
  // Tab控制器
  late TabController _tabController;

  // 表单控制器
  String? _selectedCustomer;
  final TextEditingController _fileNameController = TextEditingController();
  String? _selectedTemplate;

  // 模拟客户列表
  final List<String> _customers = ['张三', '李四', '王五'];

  // 模拟模板列表
  final List<String> _templates = [
    'Account Mandate for Business Account',
    'Application Form for Corporate Account',
    'Company Registration Certificate',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 默认选择第一个客户和模板
    _selectedCustomer = _customers.isNotEmpty ? _customers[1] : null;
    _selectedTemplate = _templates.isNotEmpty ? _templates[0] : null;
    // 初始化文件名
    if (_selectedCustomer != null) {
      _fileNameController.text = '开户文件_$_selectedCustomer';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  /// 选择客户变化
  void _onCustomerChanged(String? value) {
    setState(() {
      _selectedCustomer = value;
      // 自动更新文件名
      if (value != null) {
        _fileNameController.text = '开户文件_$value';
      }
    });
  }

  /// 新增客户
  void _handleAddCustomer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('跳转到新增客户页面')),
    );
  }

  /// 生成预览
  void _handleGeneratePreview() {
    if (_selectedCustomer == null || _selectedTemplate == null || _fileNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完整填写所有必填项')),
      );
      return;
    }
    
    // 跳转到预览页面
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return CustomerFilePreviewPage(
            customerName: _selectedCustomer!,
            fileName: _fileNameController.text,
            templateName: _selectedTemplate!,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return PageTransitionAnimations.slideFromRight(child, animation);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// 生成开户文件
  void _handleGenerateFile() {
    if (_selectedCustomer == null || _selectedTemplate == null || _fileNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完整填写所有必填项')),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在生成开户文件：${_fileNameController.text}')),
    );
  }

  /// 上传PDF文件
  void _handleUploadPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('选择PDF文件上传')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('新增开户文件'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          // 描述文字
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Text(
              '选择以下任意一种方式生成客户专属PDF文件,并进行版本管理和内容编辑。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          // Tab导航栏
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: '模板生成开户文件'),
                Tab(text: '上传PDF生成开户文件'),
              ],
            ),
          ),

          // Tab内容区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 模板生成方式
                _buildTemplateGenerateTab(),
                // 上传PDF方式
                _buildUploadPdfTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建模板生成Tab
  Widget _buildTemplateGenerateTab() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选择客户 + 新增客户按钮
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: '选择客户',
                    value: _selectedCustomer,
                    items: _customers,
                    onChanged: _onCustomerChanged,
                    required: true,
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: ElevatedButton(
                    onPressed: _handleAddCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('新增客户'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 开户文件名
            _buildTextField(
              label: '开户文件名',
              controller: _fileNameController,
              hint: '请输入开户文件名',
              required: true,
            ),

            const SizedBox(height: 24),

            // 选择模板文件
            _buildDropdownField(
              label: '选择模板文件',
              value: _selectedTemplate,
              items: _templates,
              onChanged: (value) {
                setState(() {
                  _selectedTemplate = value;
                });
              },
              required: true,
            ),

            const SizedBox(height: 32),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _handleGeneratePreview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('生成预览'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _handleGenerateFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('生成开户文件'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建上传PDF Tab
  Widget _buildUploadPdfTab() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选择客户
            _buildDropdownField(
              label: '选择客户',
              value: _selectedCustomer,
              items: _customers,
              onChanged: _onCustomerChanged,
              required: true,
            ),

            const SizedBox(height: 24),

            // 开户文件名
            _buildTextField(
              label: '开户文件名',
              controller: _fileNameController,
              hint: '请输入开户文件名',
              required: true,
            ),

            const SizedBox(height: 24),

            // 上传PDF文件
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '上传PDF文件',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '*',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _handleUploadPdf,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('选择文件'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _handleGenerateFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('生成开户文件'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建文本输入框
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ],
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
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
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
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
