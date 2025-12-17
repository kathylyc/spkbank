import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'pdf_form_field.dart';

// 如果需要使用ImagePicker，请在项目的pubspec.yaml中添加：
// dependencies:
//   image_picker: ^1.0.4

/// 简单的图像域扩展
/// 这个类为现有的SfPdfViewer添加图像域支持，只需要传入图像域名称即可
class SimpleImageFieldExtension {
  /// 存储图像数据的Map
  static final Map<String, Uint8List> _imageDataMap = <String, Uint8List>{};

  /// 图像域名称列表
  static List<String>? _imageFieldNames;

  /// 配置图像域
  ///
  /// [imageFieldNames] - 图像域名称列表，支持以下识别规则：
  ///   - 包含 'image', 'photo', '图片', '照片' 的字段名
  ///   - 以 'img_' 开头的字段名
  ///   - 明确指定的字段名
  static void configureImageFields(List<String>? imageFieldNames) {
    _imageFieldNames = imageFieldNames;
  }

  /// 设置图像域名称
  static set imageFieldNames(List<String>? imageFieldNames) {
    _imageFieldNames = imageFieldNames;
  }

  /// 判断是否为图像域
  static bool isImageField(String fieldName) {
    final lowerName = fieldName.toLowerCase();

    // 检查是否在明确指定的列表中
    if (_imageFieldNames != null && _imageFieldNames!.contains(fieldName)) {
      return true;
    }

    // 自动识别规则
    return lowerName.contains('image') ||
        lowerName.contains('photo') ||
        lowerName.contains('图片') ||
        lowerName.contains('照片') ||
        lowerName.startsWith('img_');
  }

  /// 设置图像数据
  static void setImageData(String fieldName, Uint8List imageData) {
    _imageDataMap[fieldName] = imageData;
  }

  /// 获取图像数据
  static Uint8List? getImageData(String fieldName) {
    return _imageDataMap[fieldName];
  }

  /// 删除图像数据
  static void removeImageData(String fieldName) {
    _imageDataMap.remove(fieldName);
  }

  /// 获取所有图像数据
  static Map<String, Uint8List> getAllImageData() {
    return Map<String, Uint8List>.from(_imageDataMap);
  }

  /// 处理图像域点击
  static Future<void> handleImageFieldClick(
    BuildContext context,
    String fieldName,
    {int maxFileSize = 5 * 1024 * 1024, // 5MB
    int imageQuality = 85,
    double? maxWidth,
    double? maxHeight}) async {
    try {
      // 这里需要根据项目实际需求实现图片选择逻辑
      // 可以使用 image_picker 包或其他图片选择方案

      // 示例实现：
      if (context.mounted) {
        _showMessage(context, '请实现图片选择逻辑');
      }

      // 实际项目中，您可以：
      // 1. 使用 image_picker: `ImagePicker().pickImage()`
      // 2. 使用 file_picker: `FilePicker.platform.pickFiles()`
      // 3. 使用 custom_gallery
      // 4. 使用 image_cropper

      // 获取图片数据后，调用：
      // setImageData(fieldName, imageData);
    } catch (e) {
      if (context.mounted) {
        _showMessage(context, '图片上传失败: $e', isError: true);
      }
    }
  }

  
  /// 显示消息
  static void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 保存包含图像的PDF文档
  ///
  /// 返回包含图像的PDF字节数据
  static Future<List<int>> savePdfWithImages(PdfDocument originalDocument) async {
    try {
      // 简化实现：实际应用中需要完整的页面复制和图像绘制逻辑
      // 这里提供一个基础的框架，您需要根据具体需求完善

      final List<int> originalBytes = await originalDocument.save();

      // 注意：这里返回原始文档字节
      // 在实际项目中，您需要：
      // 1. 创建新的PDF文档
      // 2. 复制原始页面内容
      // 3. 在适当位置绘制图像
      // 4. 返回新文档的字节数据

      return originalBytes;
    } catch (e) {
      debugPrint('保存PDF失败: $e');
      rethrow;
    }
  }

  /// 清空所有图像数据
  static void clearAllImageData() {
    _imageDataMap.clear();
  }

  /// 获取配置的图像域数量
  static int getImageFieldCount() {
    return _imageDataMap.length;
  }
}

/// 扩展PdfFormField以支持图像域
extension ImageFieldExtension on PdfFormField {
  /// 是否为图像域
  bool get isImageField => SimpleImageFieldExtension.isImageField(name);

  /// 获取图像数据
  Uint8List? get imageData => SimpleImageFieldExtension.getImageData(name);

  /// 设置图像数据
  set imageData(Uint8List? data) {
    if (data != null) {
      SimpleImageFieldExtension.setImageData(name, data);
    } else {
      SimpleImageFieldExtension.removeImageData(name);
    }
  }
}