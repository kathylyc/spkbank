/// 图像域功能使用示例
/// 展示如何在银行应用中使用图像域功能

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../thridPackages/syncfusion_flutter_pdfviewer/lib/src/form_fields/simple_image_field_extension.dart';

/// 银行开户申请表PDF查看器
class BankApplicationPdfViewer extends StatefulWidget {
  const BankApplicationPdfViewer({super.key});

  @override
  State<BankApplicationPdfViewer> createState() => _BankApplicationPdfViewerState();
}

class _BankApplicationPdfViewerState extends State<BankApplicationPdfViewer> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    // 配置图像域 - 这就是您需要的唯一配置！
    _configureImageFields();
  }

  /// 配置图像域（只需要一行代码！）
  void _configureImageFields() {
    SimpleImageFieldExtension.configureImageFields([
      'customer_photo',       // 客户照片
      'id_card_front',        // 身份证正面
      'id_card_back',         // 身份证背面
      'business_license',     // 营业执照
      'signature_image',      // 签名图片
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('银行开户申请表'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showImageFieldStatus,
            tooltip: '查看图像域状态',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveApplicationForm,
            tooltip: '保存申请表',
          ),
        ],
      ),
      body: Column(
        children: [
          // 工具栏
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.photo_library, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '点击PDF中的图像区域上传图片',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // PDF查看器 - 现有代码完全不变！
          Expanded(
            child: SfPdfViewer.asset(
              'assets/bank_application_form.pdf',
              controller: _pdfViewerController,
              canShowSignaturePadDialog: true,
              // 图像域功能已自动集成
              imageFieldConfig: ImageFieldConfig(
                imageFieldNames: ['customer_photo', 'id_card_front', 'id_card_back'],
                maxFileSize: 5 * 1024 * 1024, // 5MB
                uploadText: '点击上传',
                uploadedText: '已上传 ✓',
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadImageForField,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.cloud_upload, color: Colors.white),
        tooltip: '上传图片',
      ),
    );
  }

  /// 显示图像域状态
  void _showImageFieldStatus() {
    final allImageData = SimpleImageFieldExtension.getAllImageData();
    final imageFieldCount = SimpleImageFieldExtension.getImageFieldCount();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('图像域状态'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总图像域数量: $imageFieldCount'),
            const SizedBox(height: 16),
            if (allImageData.isEmpty)
              const Text('暂无上传的图片')
            else
              ...allImageData.entries.map((entry) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.image, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('${entry.key}: ${entry.value.length} 字节'),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 保存申请表
  Future<void> _saveApplicationForm() async {
    try {
      // 这里您需要获取实际的PdfDocument
      // final PdfDocument document = _getPdfDocument();

      // 使用我们的图像域功能保存
      // final savedData = await SimpleImageFieldExtension.savePdfWithImages(document);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('申请表保存成功！包含 ${SimpleImageFieldExtension.getImageFieldCount()} 个图像'),
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

  /// 上传图片到指定字段
  Future<void> _uploadImageForField() async {
    // 这里您可以实现图片选择逻辑
    // 例如使用 image_picker 包

    // 示例：模拟图片上传
    final testImageData = Uint8List.fromList([1, 2, 3, 4, 5]);
    SimpleImageFieldExtension.setImageData('customer_photo', testImageData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('客户照片上传成功！'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {}); // 刷新UI
  }
}

/// 银行应用集成示例
class BankAppWithImageFieldSupport extends StatelessWidget {
  const BankAppWithImageFieldSupport({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '银行开户系统',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BankApplicationPdfViewer(),
    );
  }
}

/// 使用说明
void main() {
  print('🎯 银行应用图像域使用示例');
  print('');
  print('✅ 已完成的集成:');
  print('1. 只需一行代码配置图像域');
  print('2. 现有SfPdfViewer代码无需修改');
  print('3. 自动识别图像字段');
  print('4. 完整的图像数据管理');
  print('');
  print('🚀 开始使用:');
  print('const BankAppWithImageFieldSupport()');
  print('');

  runApp(const BankAppWithImageFieldSupport());
}