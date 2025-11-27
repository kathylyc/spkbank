import 'dart:io';
import 'dart:typed_data';

import 'package:bank_flutter/utils/version_utils.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../../utils/file_manager.dart';
import '../../utils/storage_utils.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/models/customer.dart';
import '../../data/models/customer_account_file.dart';
import '../customer/customer_add_page.dart';

/// 扫描生成PDF文件页面
class CustomerFileAddPicturePage extends StatefulWidget {
  const CustomerFileAddPicturePage({super.key});

  @override
  State<CustomerFileAddPicturePage> createState() => _CustomerFileAddPicturePageState();
}

class _CustomerFileAddPicturePageState extends State<CustomerFileAddPicturePage> {
  // 表单控制器
  String? _selectedCustomerUid;
  final TextEditingController _fileNameController = TextEditingController();

  // 客户列表
  List<Customer> _customers = [];
  bool _isLoadingCustomers = false;

  // 图片列表
  List<String> _imagePaths = [];
  
  // 拖拽相关
  int? _draggedIndex;

  // Repository
  final CustomerRepository _repository = CustomerRepository();

  // UUID生成器
  static const _uuid = Uuid();

  // 图片选择器
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    // 清理临时图片文件
    _cleanupTempImages();
    super.dispose();
  }

  /// 清理临时图片文件
  Future<void> _cleanupTempImages() async {
    for (final path in _imagePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('清理临时图片失败: $e');
      }
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

  /// 拍照扫描
  Future<void> _handleTakePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      // 将图片保存到临时目录
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = '${_uuid.v4()}.jpg';
      final String tempPath = p.join(tempDir.path, fileName);
      final File tempFile = File(tempPath);
      await image.saveTo(tempPath);

      setState(() {
        _imagePaths.add(tempPath);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  /// 删除图片
  void _deleteImage(int index) {
    setState(() {
      final path = _imagePaths[index];
      _imagePaths.removeAt(index);
      // 异步删除文件
      File(path).delete().catchError((e) {
        debugPrint('删除图片失败: $e');
      });
    });
  }

  /// 重新排序图片
  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _imagePaths.removeAt(oldIndex);
      _imagePaths.insert(newIndex, item);
    });
  }

  /// 处理拖拽开始
  void _onDragStart(int index) {
    setState(() {
      _draggedIndex = index;
    });
  }

  /// 处理拖拽结束
  void _onDragEnd() {
    setState(() {
      _draggedIndex = null;
    });
  }

  /// 处理拖拽到目标位置
  void _onDragAccept(int sourceIndex, int targetIndex) {
    if (sourceIndex == targetIndex) {
      return;
    }
    setState(() {
      final item = _imagePaths.removeAt(sourceIndex);
      int insertIndex = targetIndex;
      if (sourceIndex < targetIndex) {
        insertIndex = targetIndex - 1;
      }
      _imagePaths.insert(insertIndex, item);
      _draggedIndex = null;
    });
  }

  /// 生成开户文件
  Future<void> _handleGenerateFile() async {
    if (_selectedCustomerUid == null || _fileNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完整填写所有必填项')),
      );
      return;
    }

    if (_imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少拍摄一张图片')),
      );
      return;
    }

    try {
      // 显示加载提示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('正在生成PDF文件...'),
            ],
          ),
          duration: Duration(seconds: 5),
        ),
      );

      // 创建PDF文档
      final PdfDocument document = PdfDocument();

      // 遍历所有图片，每张图片作为一页
      for (final imagePath in _imagePaths) {
        final File imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          continue;
        }

        // 读取图片字节
        final Uint8List imageBytes = await imageFile.readAsBytes();

        // 创建PDF页面
        final PdfPage page = document.pages.add();

        // 获取页面尺寸
        final Size pageSize = page.size;

        // 加载图片
        final PdfBitmap image = PdfBitmap(imageBytes);

        // 计算图片尺寸，保持宽高比，适应页面宽度
        double imageWidth = image.width.toDouble();
        double imageHeight = image.height.toDouble();
        final double aspectRatio = imageWidth / imageHeight;

        // 适应页面宽度，保持比例
        double displayWidth = pageSize.width - 40; // 左右各留20边距
        double displayHeight = displayWidth / aspectRatio;

        // 如果高度超过页面，则适应高度
        if (displayHeight > pageSize.height - 40) {
          displayHeight = pageSize.height - 40;
          displayWidth = displayHeight * aspectRatio;
        }

        // 居中绘制图片
        final double x = (pageSize.width - displayWidth) / 2;
        final double y = (pageSize.height - displayHeight) / 2;

        page.graphics.drawImage(
          image,
          Rect.fromLTWH(x, y, displayWidth, displayHeight),
        );
      }

      // 保存PDF到临时目录
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPdfPath = p.join(tempDir.path, '${_uuid.v4()}.pdf');
      final File tempPdfFile = File(tempPdfPath);
      await tempPdfFile.writeAsBytes(await document.save());

      // 释放文档资源
      document.dispose();

      // 获取登录用户
      final loginUser = await StorageUtils.getLoginUser();
      final now = DateTime.now();

      // 扫描生成PDF：每次生成时都创建新的 account_file_uid，fileVersion 固定为 1.0.0
      final templateName = '扫描生成PDF';
      final String accountFileUid = _uuid.v4().replaceAll('-', '');
      final int fileVersion = VersionUtils.baseVersion;

      // 将PDF文件复制到沙盒目录下的 account 目录
      final savedFilePath = await FileManager.saveAccountFileWithName(
        sourcePath: tempPdfPath,
        accountFileUid: accountFileUid,
        fileVersion: fileVersion,
      );

      // 删除临时PDF文件
      await tempPdfFile.delete();

      // 插入数据库
      final accountFile = CustomerAccountFile(
        accountFileUid: accountFileUid,
        customerUid: _selectedCustomerUid!,
        accountFileName: _fileNameController.text,
        fileVersion: fileVersion,
        filePath: savedFilePath,
        templateName: templateName,
        fileSrcType: '扫描生成',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('扫描生成PDF文件'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 描述文字
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Text(
                '可以拍照扫描上传一张或多张图片,最终合并生成一份PDF文件进行保存。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            // 表单区域
            Container(
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
                    hint: '请输入',
                    required: true,
                  ),

                  const SizedBox(height: 24),

                  // 拍照扫描按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _handleTakePicture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text('拍照扫描'),
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

            // 图片预览区域
            if (_imagePaths.isNotEmpty) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '图片预览',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 横向可拖拽图片列表
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagePaths.length,
                        itemBuilder: (context, index) {
                          return _buildDraggableThumbnail(index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 纵向图片预览区域
            if (_imagePaths.isNotEmpty) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    _imagePaths.length,
                    (index) => _buildImagePreview(index),
                  ),
                ),
              ),
            ],

            // 如果没有图片，显示提示
            if (_imagePaths.isEmpty)
              Container(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    '请点击"拍照扫描"按钮拍摄图片',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建可拖拽的图片缩略图（横向列表）
  Widget _buildDraggableThumbnail(int index) {
    final imagePath = _imagePaths[index];
    final isDragging = _draggedIndex == index;
    
    return DragTarget<int>(
      onAccept: (draggedIndex) {
        // draggedIndex 是拖拽的源索引，index 是目标索引
        if (draggedIndex != index) {
          _onDragAccept(draggedIndex, index);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return Draggable<int>(
          data: index,
          feedback: Material(
            elevation: 6,
            child: Opacity(
              opacity: 0.8,
              child: _buildThumbnailContent(index, imagePath, isDragging),
            ),
          ),
          onDragStarted: () => _onDragStart(index),
          onDragEnd: (_) => _onDragEnd(),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildThumbnailContent(index, imagePath, isDragging),
          ),
          child: Container(
            decoration: isTarget
                ? BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: _buildThumbnailContent(index, imagePath, isDragging),
          ),
        );
      },
    );
  }

  /// 构建缩略图内容
  Widget _buildThumbnailContent(int index, String imagePath, bool isDragging) {
    return Container(
      key: ValueKey(imagePath),
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDragging ? Colors.blue : Colors.orange,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(imagePath),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          // 序号
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 删除按钮
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _deleteImage(index),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图片预览（纵向列表）
  Widget _buildImagePreview(int index) {
    final imagePath = _imagePaths[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '图片 ${index + 1}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(imagePath),
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        ],
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
}

