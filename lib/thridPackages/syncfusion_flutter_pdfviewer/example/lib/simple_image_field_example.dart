import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
// 注意：在实际使用中，simple_image_field_extension 会被自动导入

/// 简单的图像域使用示例
/// 展示如何只需传入图像域名称即可使用图像域功能
class SimpleImageFieldExample extends StatefulWidget {
  const SimpleImageFieldExample({super.key});

  @override
  State<SimpleImageFieldExample> createState() => _SimpleImageFieldExampleState();
}

class _SimpleImageFieldExampleState extends State<SimpleImageFieldExample> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    // 配置图像域 - 只需传入字段名称即可
    SimpleImageFieldExtension.configureImageFields([
      'customer_photo',      // 客户照片
      'id_card_front',       // 身份证正面
      'id_card_back',        // 身份证反面
      'business_license',    // 营业执照
      // 其他字段会自动识别：包含image、photo、图片、照片等关键词的字段
    ]);
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('简单图像域示例'),
        actions: [
          IconButton(
            onPressed: _savePdfWithImages,
            icon: const Icon(Icons.save),
            tooltip: '保存PDF（包含图片）',
          ),
          IconButton(
            onPressed: _showImageFieldsStatus,
            icon: const Icon(Icons.info),
            tooltip: '查看图像域状态',
          ),
        ],
      ),
      body: SfPdfViewer.asset(
        'assets/sample_form.pdf',
        controller: _pdfViewerController,
        canShowSignaturePadDialog: true,
        // 图像域功能已自动集成，无需额外配置
        imageFieldConfig: ImageFieldConfig(
          imageFieldNames: ['customer_photo', 'id_card_front', 'id_card_back'],
        ),
      ),
    );
  }

  /// 处理PDF点击事件（简化示例）
  void _handlePdfTap(PdfGestureDetails details) {
    // 注意：点击检测需要根据实际PDF结构和表单域位置来实现
    // 这只是一个示例框架
    print('PDF被点击了，位置：${details.pagePosition}');
  }

  /// 处理图像域点击
  Future<void> _handleImageFieldClick(String fieldName) async {
    await SimpleImageFieldExtension.handleImageFieldClick(
      context,
      fieldName,
      maxFileSize: 5 * 1024 * 1024, // 5MB
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
  }

  /// 保存包含图像的PDF
  Future<void> _savePdfWithImages() async {
    try {
      // 获取PDF文档（这里需要根据实际情况获取）
      // final PdfDocument document = _getPdfDocument();

      // 模拟保存过程
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF保存成功！包含 ${SimpleImageFieldExtension.getImageFieldCount()} 个图像'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 显示图像域状态
  void _showImageFieldsStatus() {
    final imageCount = SimpleImageFieldExtension.getImageFieldCount();
    final imageData = SimpleImageFieldExtension.getAllImageData();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('图像域状态 ($imageCount 个)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('已上传的图像：'),
              const SizedBox(height: 8),
              ...imageData.entries.map((entry) {
                return Text('• ${entry.key}: ${entry.value.length} 字节');
              }).toList(),
              if (imageData.isEmpty) const Text('暂无图像'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
            if (imageData.isNotEmpty)
              TextButton(
                onPressed: () {
                  SimpleImageFieldExtension.clearAllImageData();
                  Navigator.of(context).pop();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('所有图像已清空')),
                  );
                },
                child: const Text('清空所有', style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      },
    );
  }
}

/// 最简单的使用示例
/// 只需要一行代码即可启用图像域功能
class MinimalImageFieldExample extends StatelessWidget {
  const MinimalImageFieldExample({super.key});

  @override
  Widget build(BuildContext context) {
    // 配置图像域 - 只需指定字段名，其他都自动处理
    SimpleImageFieldExtension.configureImageFields([
      'photo', 'signature', 'document', 'id_card'
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('最小图像域示例')),
      body: SfPdfViewer.asset(
        'assets/form_with_images.pdf',
        // 图像域功能已完全集成，无需其他配置
      ),
    );
  }
}

/// 动态配置图像域的示例
class DynamicImageFieldExample extends StatefulWidget {
  const DynamicImageFieldExample({super.key});

  @override
  State<DynamicImageFieldExample> createState() => _DynamicImageFieldExampleState();
}

class _DynamicImageFieldExampleState extends State<DynamicImageFieldExample> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('动态配置图像域')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: '图像域名称',
                      hintText: '输入字段名，如 customer_photo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addImageField,
                  child: const Text('添加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SfPdfViewer.asset(
              'assets/sample_form.pdf',
            ),
          ),
        ],
      ),
    );
  }

  void _addImageField() {
    final fieldName = _controller.text.trim();
    if (fieldName.isNotEmpty) {
      // 动态添加图像域
      final currentFields = <String>[];
      currentFields.add(fieldName);

      SimpleImageFieldExtension.configureImageFields(currentFields);

      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加图像域: $fieldName')),
      );
    }
  }

  void _handlePdfTap(PdfGestureDetails details) {
    // 处理点击事件
    SimpleImageFieldExtension.handleImageFieldClick(
      context,
      _controller.text.trim(),
    );
  }
}