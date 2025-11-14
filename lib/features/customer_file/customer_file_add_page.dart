import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../utils/page_transition_animations.dart';
import '../../utils/file_manager.dart';
import '../../utils/storage_utils.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/models/customer.dart';
import '../../data/models/customer_account_file.dart';
import '../customer/customer_add_page.dart';
import 'customer_file_preview_page.dart';

/// 新增开户文件页面
class CustomerFileAddPage extends StatefulWidget {
  final int initialTabIndex;
  
  const CustomerFileAddPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<CustomerFileAddPage> createState() => _CustomerFileAddPageState();
}

class _CustomerFileAddPageState extends State<CustomerFileAddPage>
    with SingleTickerProviderStateMixin {
  // Tab控制器
  late TabController _tabController;

  // 表单控制器
  String? _selectedCustomerUid; // 存储选中的客户 UID
  final TextEditingController _fileNameController = TextEditingController();
  int? _selectedTemplateId; // 存储选中的模板 ID

  // 客户列表（从数据库获取）
  List<Customer> _customers = [];
  bool _isLoadingCustomers = false;

  // pdf模板数据
  List<Map<String, dynamic>> _allPdfData = [];
  
  // 上传的PDF文件信息
  String? _selectedPdfPath;
  String? _selectedPdfName;
  
  // Repository
  final CustomerRepository _repository = CustomerRepository();
  
  // UUID生成器
  static const _uuid = Uuid();

  // 模拟模板列表
  final List<String> _templates = [
    'Account Mandate for Business Account',
    'Application Form for Corporate Account',
    'Company Registration Certificate',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    // 加载客户列表
    _loadCustomers();
    // 加载PDF模板
    _loadPdfTemplate();
  }


  Future<void> _loadPdfTemplate() async {
    try {
      // 读取AssetManifest.json获取所有assets文件
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // 过滤出assets/pdf/目录下的PDF文件
      final pdfFiles = manifestMap.keys
          .where((key) => key.startsWith('assets/pdf/') && key.endsWith('.pdf'))
          .toList();

      // 构建数据列表
      _allPdfData = pdfFiles.asMap().entries.map((entry) {
        final index = entry.key;
        final assetPath = entry.value;
        final fileName = assetPath.split('/').last;

        return {
          'id': index + 1,
          'name': fileName,
          'assetPath': assetPath,
          'count': 0, // 引用次数暂时设为0，后续可以从数据库获取
        };
      }).toList();
      
      // 默认选择第一个模板
      if (_allPdfData.isNotEmpty && mounted) {
        setState(() {
          _selectedTemplateId = _allPdfData.first['id'] as int;
        });
      }
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
    }
  }

  /// 加载客户列表
  Future<void> _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
    });
    
    try {
      final customers = await _repository.findAll();
      setState(() {
        _customers = customers;
        // 如果有客户，默认选择第一个
        if (_customers.isNotEmpty && _selectedCustomerUid == null) {
          _selectedCustomerUid = _customers.first.customerUid;
          _fileNameController.text = '开户文件_${_customers.first.customerName}';
        }
        _isLoadingCustomers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCustomers = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载客户列表失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fileNameController.dispose();
    // 清理 file_picker 生成的临时文件
    FilePicker.platform.clearTemporaryFiles().catchError((error) {
      debugPrint('清理 file_picker 临时文件失败: $error');
    });
    super.dispose();
  }

  /// 选择客户变化
  void _onCustomerChanged(String? customerUid) {
    setState(() {
      _selectedCustomerUid = customerUid;
      // 自动更新文件名
      if (customerUid != null) {
        final customer = _customers.firstWhere(
          (c) => c.customerUid == customerUid,
          orElse: () => _customers.first,
        );
        _fileNameController.text = '开户文件_${customer.customerName}';
      }
    });
  }

  /// 新增客户
  Future<void> _handleAddCustomer() async {
    final bool? hasChanged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const CustomerAddPage()),
    );
    if (hasChanged == true && mounted) {
      // 重新加载客户列表
      await _loadCustomers();
    }
  }

  /// 生成预览
  void _handleGeneratePreview() {
    if (_selectedCustomerUid == null || _selectedTemplateId == null || _fileNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完整填写所有必填项')),
      );
      return;
    }
    
    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('客户列表为空')),
      );
      return;
    }
    
    final customer = _customers.firstWhere(
      (c) => c.customerUid == _selectedCustomerUid,
      orElse: () => _customers.first,
    );
    
    if (_allPdfData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模板列表为空')),
      );
      return;
    }
    
    final templateIndex = _allPdfData.indexWhere(
      (t) => t['id'] == _selectedTemplateId,
    );
    
    final template = templateIndex >= 0
        ? _allPdfData[templateIndex]
        : _allPdfData.first;
    
    // 跳转到预览页面，传递模板的完整信息
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return CustomerFilePreviewPage(
            customerName: customer.customerName,
            fileName: _fileNameController.text,
            templateName: template['name'] as String,
            templateAssetPath: template['assetPath'] as String,
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
  Future<void> _handleGenerateFile() async {
    // 根据当前Tab判断验证条件
    final isTemplateTab = _tabController.index == 0;
    
    if (_selectedCustomerUid == null || _fileNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完整填写所有必填项')),
      );
      return;
    }
    
    String? templateName;
    String? sourceFilePath;
    
    if (isTemplateTab) {
      // 模板生成Tab：需要选择模板
      if (_selectedTemplateId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择模板文件')),
        );
        return;
      }
      final templateIndex = _allPdfData.indexWhere(
        (t) => t['id'] == _selectedTemplateId,
      );
      final template = templateIndex >= 0
          ? _allPdfData[templateIndex]
          : _allPdfData.first;
      templateName = template['name'] as String;
      // 从assets加载文件到临时目录
      try {
        final ByteData data = await rootBundle.load(template['assetPath'] as String);
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = '${tempDir.path}/${template['name'] as String}';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(data.buffer.asUint8List());
        sourceFilePath = tempPath;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载模板文件失败: $e')),
        );
        return;
      }
    } else {
      // 上传PDF Tab：需要上传PDF文件
      if (_selectedPdfPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请上传PDF文件')),
        );
        return;
      }
      sourceFilePath = _selectedPdfPath;
      templateName = _selectedPdfName; // 使用文件名作为模板名称
    }
    
    if (sourceFilePath == null || templateName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件路径或模板名称为空')),
      );
      return;
    }
    
    try {
      // 显示加载提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在保存开户文件...')),
      );
      
      // 获取登录用户
      final loginUser = await StorageUtils.getLoginUser();
      final now = DateTime.now();
      
      // 1. 判断当前表中是否存在使用了当前选中模板的数据
      final existingFile = await _repository.findLatestByCustomerUidAndTemplate(
        _selectedCustomerUid!,
        templateName,
      );
      
      String accountFileUid;
      String fileVersion;
      
      if (existingFile != null) {
        // 如果存在，使用现有的 account_file_uid，查询该 account_file_uid 的最大版本号并加一
        accountFileUid = existingFile.accountFileUid;
        final maxVersion = await _repository.findMaxVersionByAccountFileUid(accountFileUid);
        if (maxVersion != null) {
          final currentVersion = int.tryParse(maxVersion) ?? 0;
          fileVersion = (currentVersion + 1).toString();
        } else {
          fileVersion = '1';
        }
      } else {
        // 如果不存在，使用 UUID 生成 account_file_uid，file_version 设为 1
        accountFileUid = _uuid.v4().replaceAll('-', '');
        fileVersion = '1';
      }
      
      // 2. 将选中的文件复制到沙盒目录下的 account 目录
      final savedFilePath = await FileManager.saveAccountFileWithName(
        sourcePath: sourceFilePath,
        accountFileUid: accountFileUid,
        fileVersion: fileVersion,
      );
      
      // 3. 插入数据库
      final accountFile = CustomerAccountFile(
        accountFileUid: accountFileUid,
        customerUid: _selectedCustomerUid!,
        accountFileName: _fileNameController.text,
        fileVersion: fileVersion,
        filePath: savedFilePath,
        templateName: templateName,
        fileSrcType: isTemplateTab ? '模板生成' : '上传PDF',
        createBy: loginUser?.userName,
        createTime: now,
        updateBy: loginUser?.userName,
        updateTime: now,
      );
      
      await _repository.addAccountFile(accountFile);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开户文件保存成功')),
      );
      
      // 返回上一页
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存开户文件失败: $e')),
      );
    }
  }

  /// 选择PDF文件
  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final selected = result.files.single;
      final String? path = selected.path;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取文件路径，请重试')),
        );
        return;
      }
      if (!await File(path).exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在，请重新选择')),
        );
        return;
      }
      setState(() {
        _selectedPdfPath = path;
        _selectedPdfName = selected.name;
      });
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败: $error')),
      );
    }
  }

  /// 清除PDF文件
  void _clearPdfFile() {
    setState(() {
      _selectedPdfPath = null;
      _selectedPdfName = null;
    });
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
                  child: _buildCustomerDropdownField(
                    label: '选择客户',
                    value: _selectedCustomerUid,
                    customers: _customers,
                    isLoading: _isLoadingCustomers,
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
            _buildPdfDropdownField(
              label: '选择模板文件',
              value: _selectedTemplateId,
              pdfData: _allPdfData,
              onChanged: (value) {
                setState(() {
                  _selectedTemplateId = value;
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
            // 选择客户 + 新增客户按钮
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildCustomerDropdownField(
              label: '选择客户',
                    value: _selectedCustomerUid,
                    customers: _customers,
                    isLoading: _isLoadingCustomers,
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

            // 上传PDF文件
            _buildPdfUploadTile(),

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

  /// 构建客户下拉框
  Widget _buildCustomerDropdownField({
    required String label,
    required String? value,
    required List<Customer> customers,
    required bool isLoading,
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
          items: isLoading
              ? [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('加载中...'),
                  ),
                ]
              : customers.map((customer) {
            return DropdownMenuItem<String>(
                    value: customer.customerUid,
                    child: Text(customer.customerName),
                  );
                }).toList(),
          onChanged: isLoading ? null : onChanged,
        ),
      ],
    );
  }

  /// 构建PDF上传区域
  Widget _buildPdfUploadTile() {
    final String? previewPath = _selectedPdfPath;
    final bool hasFile = previewPath != null;
    final String displayText = _selectedPdfName ?? '点击选择PDF文件';

    return Container(
      width: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                '上传PDF文件',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
          const SizedBox(height: 12),
          // 预览区域
          InkWell(
            onTap: _pickPdfFile,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade100,
              ),
              child: hasFile
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedPdfName ?? 'PDF文件',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            '点击选择PDF文件',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Text(
          //   displayText,
          //   style: TextStyle(
          //     fontSize: 13,
          //     color: hasFile ? Colors.black87 : Colors.grey.shade500,
          //   ),
          //   maxLines: 2,
          //   overflow: TextOverflow.ellipsis,
          // ),
          // const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: _pickPdfFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    hasFile ? '重新上传' : '上传',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (hasFile) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    onPressed: _clearPdfFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('清除', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 构建下拉框（用于模板选择）
  Widget _buildPdfDropdownField({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> pdfData,
    required ValueChanged<int?> onChanged,
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
        DropdownButtonFormField<int>(
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
          items: pdfData.map((item) {
            return DropdownMenuItem<int>(
              value: item['id'] as int,
              child: Text(item['name'] as String),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
