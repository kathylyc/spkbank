import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../form_fields/pdf_form_field.dart';
import '../form_fields/pdf_image_field.dart';

/// 图像域工具类 - 提供通用的图像域判断和处理功能
class ImageFieldUtils {
  /// 判断是否为图像域
  ///
  /// [formField] 要判断的表单域
  /// [imageFieldNames] 外部配置的图像域名称列表，如果为null则使用默认判断逻辑
  ///
  /// 返回 true 如果是图像域，否则返回 false
  static bool isImageField(PdfFormField formField, List<String>? imageFieldNames) {
    final String? fieldName = formField.name;
    if (fieldName == null) {
      return false;
    }

    final lowerName = fieldName.toLowerCase();

    // 如果外部配置了 imageFieldNames，优先使用外部配置
    if (imageFieldNames != null && imageFieldNames.isNotEmpty) {
      return imageFieldNames.contains(fieldName);
    }

    // 默认判断逻辑：通过字段名称特征识别
    return _isImageFieldByName(lowerName);
  }

  /// 判断是否为图像域按钮字段（针对 PdfButtonField 的特殊判断）
  ///
  /// [field] 按钮字段
  /// [imageFieldNames] 外部配置的图像域名称列表
  ///
  /// 返回 true 如果是图像域按钮字段，否则返回 false
  static bool isImageButtonField(PdfButtonField field, List<String>? imageFieldNames) {
    final String? fieldName = field.name;
    if (fieldName == null) {
      return false;
    }

    // 如果外部配置了 imageFieldNames，优先使用外部配置
    if (imageFieldNames != null && imageFieldNames.isNotEmpty) {
      return imageFieldNames.contains(fieldName);
    }

    // 默认判断逻辑
    return _isImageFieldByName(fieldName.toLowerCase());
  }

  /// 通过字段名称特征判断是否为图像域（私有方法）
  ///
  /// [fieldName] 字段名称（已转换为小写）
  ///
  /// 返回 true 如果字段名称符合图像域特征
  static bool _isImageFieldByName(String fieldName) {
    return fieldName.contains('image') ||
        fieldName.contains('photo') ||
        fieldName.contains('图片') ||
        fieldName.contains('照片') ||
        fieldName.startsWith('img_');
  }

  /// 获取图像域的显示名称（用于调试和日志）
  ///
  /// [formField] 表单域
  ///
  /// 返回图像域的友好显示名称
  static String getImageFieldDisplayName(PdfFormField formField) {
    final String? fieldName = formField.name;
    if (fieldName == null) {
      return '未命名的图像域';
    }

    // 根据字段名称特征返回友好的显示名称
    final lowerName = fieldName.toLowerCase();
    if (lowerName.contains('signature') || lowerName.contains('签名')) {
      return '签名域';
    } else if (lowerName.contains('photo') || lowerName.contains('照片')) {
      return '照片域';
    } else if (lowerName.contains('image') || lowerName.contains('图片')) {
      return '图片域';
    } else if (lowerName.startsWith('img_')) {
      return '图像域 ($fieldName)';
    } else {
      return '图像域 ($fieldName)';
    }
  }

  /// 验证图像域名称是否有效
  ///
  /// [fieldName] 字段名称
  ///
  /// 返回 true 如果字段名称有效，否则返回 false
  static bool isValidImageFieldName(String? fieldName) {
    if (fieldName == null || fieldName.trim().isEmpty) {
      return false;
    }

    // 检查是否包含有效的图像域特征
    final lowerName = fieldName.toLowerCase();
    return _isImageFieldByName(lowerName);
  }

  /// 从表单域集合中筛选出所有图像域
  ///
  /// [formFields] 表单域集合
  /// [imageFieldNames] 外部配置的图像域名称列表
  ///
  /// 返回所有图像域的列表
  static List<PdfFormField> filterImageFields(
    List<PdfFormField> formFields,
    List<String>? imageFieldNames,
  ) {
    return formFields.where((field) => isImageField(field, imageFieldNames)).toList();
  }

  /// 从按钮字段集合中筛选出所有图像域按钮
  ///
  /// [buttonFields] 按钮字段集合
  /// [imageFieldNames] 外部配置的图像域名称列表
  ///
  /// 返回所有图像域按钮的列表
  static List<PdfButtonField> filterImageButtons(
    List<PdfButtonField> buttonFields,
    List<String>? imageFieldNames,
  ) {
    return buttonFields.where((field) => isImageButtonField(field, imageFieldNames)).toList();
  }
}