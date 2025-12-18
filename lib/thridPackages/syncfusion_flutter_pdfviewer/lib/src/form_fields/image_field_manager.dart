import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'pdf_image_field.dart';

// 如果需要使用ImagePicker，请在项目的pubspec.yaml中添加：
// dependencies:
//   image_picker: ^1.0.4

/// 图像域管理器
class ImageFieldManager {
  /// 图像域配置
  final ImageFieldConfig? config;

  /// 存储图像数据的Map
  final Map<String, Uint8List> _imageDataMap = <String, Uint8List>{};

  /// 创建图像域管理器
  ImageFieldManager({this.config});

  /// 显示消息
  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 获取图像数据
  Uint8List? getImageData(String fieldName) {
    return _imageDataMap[fieldName];
  }

  /// 保存图像数据
  void saveImageData(String fieldName, Uint8List imageData) {
    _imageDataMap[fieldName] = imageData;
  }

  /// 删除图像数据
  void removeImageData(String fieldName) {
    _imageDataMap.remove(fieldName);
  }

  /// 获取所有图像数据
  Map<String, Uint8List> getAllImageData() {
    return Map<String, Uint8List>.from(_imageDataMap);
  }

  /// 处理图像域点击
  Future<void> handleImageFieldClick(
    BuildContext context,
    PdfImageFormField imageField,
  ) async {
    if (context.mounted) {
      try {
        // 调用文件选择回调
        if (config?.onFileSelect != null) {
          final PdfImageSelectedFile? selectedFile = await config!.onFileSelect!(
            context,
            imageField,
          );

          if (selectedFile != null) {
            // 验证是否为删除图片
            final isDelete = selectedFile.fileName == 'deleted' && selectedFile.fileSize == 0;
            if (isDelete) {
              // 本次删除图片
              removeImageData(imageField.name);
            }
            else {
              // 非删除，即选择了图片
              // 验证文件大小
              if (config!.maxFileSize > 0 && selectedFile.fileSize > config!.maxFileSize) {
                _showMessage(
                  context,
                  '文件大小超过限制 (${config!.maxFileSize ~/ 1024 ~/ 1024}MB)',
                  isError: true,
                );
                return;
              }

              // 验证文件格式
              if (config!.allowedFormats.isNotEmpty) {
                final fileName = selectedFile.fileName?.toLowerCase() ?? '';
                final hasValidFormat = config!.allowedFormats.any((format) =>
                    fileName.endsWith('.$format'));
                if (!hasValidFormat) {
                  _showMessage(
                    context,
                    '不支持的文件格式，支持的格式：${config!.allowedFormats.join(', ')}',
                    isError: true,
                  );
                  return;
                }
              }


              // 获取之前的文件信息
              final PdfImageSelectedFile? oldFile = _getPreviousFile(imageField.name);

              // 保存图像数据
              saveImageData(imageField.name, selectedFile.imageData);

              // 设置图像路径
              imageField.originalImagePath = selectedFile.originalPath;

              // 更新表单字段
              imageField.setImage(selectedFile.imageData, originalPath: selectedFile.originalPath);

              // 调用图像选择成功回调
              if (config?.onImageSelected != null) {
                config!.onImageSelected!(
                  PdfImageFieldDetails(
                    formField: imageField,
                    selectedFile: selectedFile,
                    oldFile: oldFile,
                  ),
                );
              }
            }
          }
        } else {
          // 回退到默认提示
          _showMessage(context, '请配置文件选择回调', isError: true);
        }
      } catch (e, s) {
        debugPrint('图片选择失败: $e');
        debugPrintStack(stackTrace: s);
        _showMessage(context, '图片选择失败: $e', isError: true);
      }
    }
  }

  /// 获取之前的文件信息
  PdfImageSelectedFile? _getPreviousFile(String? fieldName) {
    if (fieldName == null) {
      return null;
    }
    final imageData = getImageData(fieldName);
    if (imageData != null) {
      return PdfImageSelectedFile(
        imageData: imageData,
        fileSize: imageData.length,
        fileDate: DateTime.now(),
      );
    }
    return null;
  }

  
  
  /// 保存所有图像域到PDF文档
  Future<List<int>> saveDocumentWithImageFields(
    PdfDocument document,
  ) async {
    // 使用内部存储的图像数据
    final imageDataMap = getAllImageData();
    return saveDocumentWithImageFieldsMap(document, imageDataMap);
  }

  /// 保存所有图像域到PDF文档（带指定图像数据）
  Future<List<int>> saveDocumentWithImageFieldsMap(
    PdfDocument document,
    Map<String, Uint8List> imageDataMap,
  ) async {
    // 创建新文档副本
    final PdfDocument saveDocument = PdfDocument();

    // 复制页面和处理图像域
    for (int i = 0; i < document.pages.count; i++) {
      final PdfPage sourcePage = document.pages[i];
      final PdfPage newPage = saveDocument.pages.add();

      // 复制页面内容
      await _copyPageContent(sourcePage, newPage);

      // 处理图像域
      await _processImageFieldsOnPage(sourcePage, newPage, imageDataMap, i);
    }

    // 保存文档
    return saveDocument.save();
  }

  /// 复制页面内容（简化实现）
  Future<void> _copyPageContent(PdfPage sourcePage, PdfPage newPage) async {
    // 简化实现：实际应用中需要完整的页面复制逻辑
    // 这里提供一个基础的框架，您需要根据具体需求完善
  }

  /// 处理页面上的图像域（简化实现）
  Future<void> _processImageFieldsOnPage(
    PdfPage sourcePage,
    PdfPage newPage,
    Map<String, Uint8List> imageDataMap,
    int pageIndex,
  ) async {
    // 简化实现：实际应用中需要完整的图像处理逻辑
    // 这里提供一个基础的框架，您需要根据具体需求完善
  }

  
  /// 从图像域收集所有图像数据（简化实现）
  Map<String, Uint8List> collectImageDataFromFields(
    List<dynamic> imageFields,
  ) {
    final Map<String, Uint8List> imageDataMap = <String, Uint8List>{};

    // 简化实现：实际应用中需要完整的图像数据收集逻辑
    for (final field in imageFields) {
      if (field.name != null) {
        final imageData = getImageData(field.name);
        if (imageData != null) {
          imageDataMap[field.name] = imageData;
        }
      }
    }

    return imageDataMap;
  }

  /// 释放资源
  void dispose() {
    // 清理资源
  }
}
