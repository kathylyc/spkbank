import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// 图像域示例
class ImageFieldExample extends StatefulWidget {
  const ImageFieldExample({super.key});

  @override
  State<ImageFieldExample> createState() => _ImageFieldExampleState();
}

class _ImageFieldExampleState extends State<ImageFieldExample> {
  late PdfViewerController _pdfViewerController;
  late ImageFieldManager _imageFieldManager;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();

    // 创建图像域管理器
    _imageFieldManager = ImageFieldManager(
      config: const ImageFieldConfig(
        imageFieldNames: [
          'customer_photo',
          'id_card_front',
          'id_card_back',
          'business_license'
        ],
        maxFileSize: 5 * 1024 * 1024, // 5MB
        uploadText: '点击上传图片',
        uploadedText: '图片已上传 ✓',
        enableCrop: false,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      ),
    );
  }

  @override
  void dispose() {
    _imageFieldManager.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图像域示例'),
        actions: [
          IconButton(
            onPressed: _savePdfWithImages,
            icon: const Icon(Icons.save),
            tooltip: '保存PDF（包含图片）',
          ),
        ],
      ),
      body: SfPdfViewer.asset(
        'assets/sample_form.pdf', // 需要包含按钮域的PDF文件
        controller: _pdfViewerController,
        key: _pdfViewerKey,
        canShowSignaturePadDialog: true,
        // 图像域配置
        imageFieldConfig: _imageFieldManager.config,
      ),
    );
  }

  /// 保存包含图像的PDF
  Future<void> _savePdfWithImages() async {
    try {
      // 获取当前PDF文档
      final PdfDocument? document = _getPdfDocument();
      if (document == null) {
        _showMessage('无法获取PDF文档', isError: true);
        return;
      }

      // 使用图像域管理器保存文档
      final List<int> savedData = await _imageFieldManager.saveDocumentWithImageFields(document);

      _showMessage('PDF保存成功！');
    } catch (e) {
      _showMessage('保存失败: $e', isError: true);
    }
  }

  /// 获取PDF文档
  PdfDocument? _getPdfDocument() {
    // 这里需要根据实际的Syncfusion API来获取文档
    // 这是一个示例实现
    return null;
  }

  /// 显示消息
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}

/// 简化的使用示例
class SimpleImageFieldExample extends StatelessWidget {
  const SimpleImageFieldExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('简单图像域示例')),
      body: SfPdfViewer.asset(
        'assets/form_with_images.pdf',
        // 只需指定图像域名称，其他都由底层库处理
        imageFieldConfig: const ImageFieldConfig(
          imageFieldNames: ['photo', 'signature_image', 'document_image'],
        ),
      ),
    );
  }
}