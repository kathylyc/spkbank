import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_field_container.dart';
import 'simple_image_field_extension.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// 图像域Mixin
/// 可以轻松混入到现有的FormFieldContainer中以支持图像域功能
mixin ImageFieldMixin on State<FormFieldContainer> {
  /// 图像域名称列表
  List<String>? imageFieldNames;

  /// 初始化图像域支持
  @override
  void initState() {
    super.initState();
    // 配置图像域
    SimpleImageFieldExtension.configureImageFields(imageFieldNames);
  }

  /// 处理图像域点击
  Future<void> handleImageFieldTap(String fieldName) async {
    await SimpleImageFieldExtension.handleImageFieldClick(
      context,
      fieldName,
      maxFileSize: 5 * 1024 * 1024, // 5MB
      imageQuality: 85,
    );
  }

  /// 构建图像域Widget
  Widget buildImageFieldWidget(String fieldName, Rect bounds) {
    final imageData = SimpleImageFieldExtension.getImageData(fieldName);

    return Positioned(
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
      child: GestureDetector(
        onTap: () => handleImageFieldTap(fieldName),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
            color: imageData != null
                ? const Color(0xFFE8F5E8)
                : Colors.white,
          ),
          child: Center(
            child: imageData != null
                ? _buildImagePreview(imageData, bounds)
                : _buildUploadButton(bounds),
          ),
        ),
      ),
    );
  }

  /// 构建图像预览
  Widget _buildImagePreview(Uint8List imageData, Rect bounds) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.memory(
        imageData,
        fit: BoxFit.contain,
        width: bounds.width - 8,
        height: bounds.height - 8,
      ),
    );
  }

  /// 构建上传按钮
  Widget _buildUploadButton(Rect bounds) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload,
          color: Colors.grey.shade600,
          size: bounds.width * 0.3,
        ),
        const SizedBox(height: 4),
        Text(
          '点击上传',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: bounds.width * 0.08,
          ),
        ),
      ],
    );
  }

  /// 保存包含图像的PDF
  Future<List<int>> savePdfWithImages(PdfDocument document) async {
    return await SimpleImageFieldExtension.savePdfWithImages(document);
  }
}

/// 增强的FormFieldContainer，集成图像域支持
class EnhancedFormFieldContainer extends StatelessWidget {
  /// 图像域名称列表
  final List<String>? imageFieldNames;

  /// 表单域列表
  final List<dynamic> formFields;

  /// 点击回调
  final void Function(Offset)? onTap;

  /// 高度百分比
  final double heightPercentage;

  /// PDF查看器控制器
  final dynamic pdfViewerController;

  const EnhancedFormFieldContainer({
    super.key,
    required this.formFields,
    this.onTap,
    this.heightPercentage = 1,
    this.pdfViewerController,
    this.imageFieldNames,
  });

  @override
  Widget build(BuildContext context) {
    // 简化实现：只构建基础容器
    // 实际项目中需要更复杂的逻辑来集成图像域功能

    return Container(
      child: Text('图像域功能需要进一步实现'),
    );
  }
}