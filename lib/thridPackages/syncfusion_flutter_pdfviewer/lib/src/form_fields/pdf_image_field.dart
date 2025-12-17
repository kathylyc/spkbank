import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../control/pdfviewer_callback_details.dart';
import 'image_field_manager.dart';
import 'pdf_form_field.dart';
import '../utils/image_field_utils.dart';

/// 表单字段值变化回调
typedef PdfFormFieldValueChangedCallback = void Function(
  PdfFormFieldValueChangedDetails details,
);

/// 图像域文件选择回调
typedef PdfImageFieldFileCallback = Future<PdfImageSelectedFile?> Function(
  BuildContext context,
  PdfImageFormField imageField,
);

/// 图像域状态变化回调
typedef PdfImageFieldCallback = void Function(
  PdfImageFieldDetails details,
);

/// 图像域表单字段
class PdfImageFormField extends PdfFormField {
  PdfImageFormFieldHelper? _helper;

  /// 图像数据
  Uint8List? imageData;

  /// 原始图像路径
  String? originalImagePath;

  /// 图像域配置
  final ImageFieldConfig? config;

  /// 创建图像域表单字段
  PdfImageFormField({
    required this.config,
  });

  /// 是否为图像域（通过名称判断）
  bool get isImageField => ImageFieldUtils.isImageField(this, config?.imageFieldNames);

  /// 设置图像
  void setImage(Uint8List imageBytes, {String? originalPath}) {
    imageData = imageBytes;
    originalImagePath = originalPath;
    _updateButtonAppearance();
    _helper?.rebuild();
  }

  /// 安全地初始化辅助对象
  void initializeHelper(PdfImageFormFieldHelper helper) {
    _helper = helper;
  }

  /// 清除图像
  void clearImage() {
    imageData = null;
    originalImagePath = null;
    _updateButtonAppearance(clear: true);
    _helper?.rebuild();
  }

  /// 更新按钮外观
  void _updateButtonAppearance({bool clear = false}) {
    if (_helper?.pdfField is PdfButtonField) {
      final buttonField = _helper!.pdfField as PdfButtonField;
      if (clear || imageData == null) {
        buttonField.text = config?.uploadText ?? '点击上传图片';
      } else {
        buttonField.text = config?.uploadedText ?? '图片已上传 ✓';
      }
    }
  }

  /// 获取辅助对象
  PdfFormFieldHelper? get helper => _helper;

  /// 获取字段名（安全访问）
  String? get safeName {
    try {
      return name;
    } catch (e) {
      return null;
    }
  }
}

/// 图像域表单字段辅助类
class PdfImageFormFieldHelper extends PdfFormFieldHelper {
  /// PDF控制器
  dynamic pdfViewerController;

  /// 图像域管理器
  ImageFieldManager? imageFieldManager;

  /// 图像域配置
  final ImageFieldConfig? config;

  /// 表单字段值变化回调
  final PdfFormFieldValueChangedCallback? onValueChanged;

  /// 创建图像域表单字段辅助类
  PdfImageFormFieldHelper(
    super.pdfField,
    super.pageIndex, {
    this.config,
    this.pdfViewerController,
    this.imageFieldManager,
    this.onValueChanged,
  }) {
    bounds = pdfField.bounds;
  }

  /// 获取图像域表单字段
  PdfImageFormField getFormField() {
    final imageFormField = PdfImageFormField(config: config);
    super.load(imageFormField);

    // 检查是否为图像域
    if (pdfField.name != null && ImageFieldUtils.isImageFieldWithFieldName(pdfField.name!, config?.imageFieldNames)) {
      // 设置初始状态
      _updateButtonAppearance();
    }

    return imageFormField;
  }

  @override
  void load(PdfFormField formField) {
    super.load(formField);
    if (formField is PdfImageFormField) {
      formField._helper = this;
      // 检查是否为图像域
      if (formField.isImageField) {
        _updateButtonAppearance();
      }
    }
  }

  /// 构建图像域Widget
  Widget build(BuildContext context, double heightPercentage) {
    if (pdfField is! PdfButtonField) {
      return const SizedBox.shrink();
    }

    final imageField = _formField;
    if (!imageField.isImageField) {
      return const SizedBox.shrink();
    }

    final Rect fieldBounds = Rect.fromLTWH(
      bounds.left / heightPercentage,
      bounds.top / heightPercentage,
      bounds.width / heightPercentage,
      bounds.height / heightPercentage,
    );

    return Positioned(
      left: fieldBounds.left,
      top: fieldBounds.top,
      width: fieldBounds.width,
      height: fieldBounds.height,
      child: GestureDetector(
        onTap: () {
          if (!pdfField.readOnly) {
            _handleImageFieldClick(context, imageField);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(2),
            color: imageField.imageData != null
                ? (config?.uploadedColor ?? const Color(0xFFE8F5E8))
                : Colors.white,
          ),
          child: Center(
            child: imageField.imageData != null
                ? _buildImagePreview(imageField.imageData!)
                : _buildUploadButton(),
          ),
        ),
      ),
    );
  }

  /// 构建图像预览
  Widget _buildImagePreview(Uint8List imageData) {
    return Image.memory(
      imageData,
      fit: BoxFit.cover,
      width: bounds.width - 4,
      height: bounds.height - 4,
    );
  }

  /// 构建上传按钮
  Widget _buildUploadButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload,
          color: config?.iconColor ?? Colors.grey,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          config?.uploadText ?? '点击上传图片',
          style: TextStyle(
            color: config?.textColor ?? Colors.grey,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 处理图像域点击
  Future<void> _handleImageFieldClick(
    BuildContext context,
    PdfImageFormField imageField,
  ) async {
    await imageFieldManager?.handleImageFieldClick(context, imageField);
  }

  /// 更新按钮外观
  void _updateButtonAppearance() {
    // 注意：PdfField没有text属性，这个方法为空实现
    // 在实际应用中，可能需要通过其他方式更新按钮外观
    // 例如通过自定义绘制或状态管理
  }

  /// 获取表单字段引用
  PdfImageFormField get _formField {
    return pdfField as PdfImageFormField;
  }
}

/// 选择文件的结果
class PdfImageSelectedFile {
  /// 图像字节数据
  final Uint8List imageData;

  /// 原始文件路径
  final String? originalPath;

  /// 文件名
  final String? fileName;

  /// MIME类型
  final String? mimeType;

  /// 文件大小（字节）
  final int fileSize;

  /// 文件日期
  final DateTime? fileDate;

  const PdfImageSelectedFile({
    required this.imageData,
    this.originalPath,
    this.fileName,
    this.mimeType,
    this.fileSize = 0,
    this.fileDate,
  });
}

/// 图像域变化详情
class PdfImageFieldDetails {
  /// 表单字段
  final PdfImageFormField formField;

  /// 选择的文件
  final PdfImageSelectedFile? selectedFile;

  /// 之前的文件
  final PdfImageSelectedFile? oldFile;

  /// 错误信息
  final String? errorMessage;

  const PdfImageFieldDetails({
    required this.formField,
    required this.selectedFile,
    required this.oldFile,
    this.errorMessage,
  });
}

/// 图像域配置类
class ImageFieldConfig {
  /// 图像域名称列表
  final List<String>? imageFieldNames;

  /// 最大文件大小（字节）
  final int maxFileSize;

  /// 允许的文件格式
  final List<String> allowedFormats;

  /// 上传按钮文本
  final String uploadText;

  /// 已上传文本
  final String uploadedText;

  /// 上传按钮颜色
  final Color uploadColor;

  /// 已上传状态颜色
  final Color uploadedColor;

  /// 图标颜色
  final Color iconColor;

  /// 文本颜色
  final Color textColor;

  /// 是否启用裁剪
  final bool enableCrop;

  /// 最大宽度
  final double? maxWidth;

  /// 最大高度
  final double? maxHeight;

  /// 图像质量 (0-100)
  final int imageQuality;

  /// 文件选择回调
  final PdfImageFieldFileCallback? onFileSelect;

  /// 图像选择成功回调
  final PdfImageFieldCallback? onImageSelected;

  /// 图像清除回调
  final PdfImageFieldCallback? onImageCleared;

  const ImageFieldConfig({
    this.imageFieldNames,
    this.maxFileSize = 5 * 1024 * 1024, // 5MB
    this.allowedFormats = const ['jpg', 'jpeg', 'png', 'bmp'],
    this.uploadText = '点击上传图片',
    this.uploadedText = '图片已上传 ✓',
    this.uploadColor = Colors.white,
    this.uploadedColor = const Color(0xFFE8F5E8),
    this.iconColor = Colors.grey,
    this.textColor = Colors.grey,
    this.enableCrop = false,
    this.maxWidth = 1920,
    this.maxHeight = 1080,
    this.imageQuality = 85,
    this.onFileSelect,
    this.onImageSelected,
    this.onImageCleared,
  });
}