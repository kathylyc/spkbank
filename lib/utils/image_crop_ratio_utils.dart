import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../data/models/crop_ratio.dart';

/// 图片裁剪比例工具类
class ImageCropRatioUtils {
  /// 根据图片域名称智能匹配推荐的比例类型
  static CropRatioType getRecommendedRatioType(String fieldName) {
    final lowerFieldName = fieldName.toLowerCase();

    // 签名类域 - 使用正方形
    if (_isSignatureField(lowerFieldName)) {
      return CropRatioType.square;
    }

    // 证件照片类域 - 使用竖版3:4
    if (_isIdPhotoField(lowerFieldName)) {
      return CropRatioType.portrait;
    }

    // 文档附件类域 - 使用横版16:9
    if (_isDocumentField(lowerFieldName)) {
      return CropRatioType.landscape;
    }

    // 默认使用标准4:3比例
    return CropRatioType.standard;
  }

  /// 生成裁剪配置
  static Future<CroppedFile?> cropImageWithRatio(
    String sourcePath, {
    CropRatioConfig ratioConfig = const CropRatioConfig.free(),
    int? maxWidth,
    int? maxHeight,
    int compressQuality = 80,
    String toolbarTitle = '裁剪图片',
    Color toolbarColor = Colors.blue,
    Color toolbarWidgetColor = Colors.white,
  }) async {
    try {
      // 准备UI设置
      List<PlatformUiSettings> uiSettings = [];

      // Android 设置
      if (defaultTargetPlatform == TargetPlatform.android) {
        uiSettings.add(AndroidUiSettings(
          toolbarTitle: toolbarTitle,
          toolbarColor: toolbarColor,
          toolbarWidgetColor: toolbarWidgetColor,
          initAspectRatio: ratioConfig.initPreset,
          lockAspectRatio: ratioConfig.lockAspectRatio,
          hideBottomControls: false,
        ));
      }

      // iOS 设置
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        uiSettings.add(IOSUiSettings(
          title: toolbarTitle,
          cancelButtonTitle: '取消',
          doneButtonTitle: '确定',
          aspectRatioLockEnabled: ratioConfig.lockAspectRatio,
          resetAspectRatioEnabled: !ratioConfig.lockAspectRatio,
        ));
      }

      // 准备裁剪参数
      Map<String, dynamic> cropParams = {
        'sourcePath': sourcePath,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'compressQuality': compressQuality,
        'uiSettings': uiSettings,
      };

      // 设置比例相关参数
      if (ratioConfig.customAspectRatio != null) {
        cropParams['aspectRatio'] = ratioConfig.customAspectRatio;
      }

      // 执行裁剪
      return await ImageCropper().cropImage(
        sourcePath: cropParams['sourcePath'],
        maxWidth: cropParams['maxWidth'],
        maxHeight: cropParams['maxHeight'],
        compressQuality: cropParams['compressQuality'],
        aspectRatio: cropParams['aspectRatio'],
        uiSettings: cropParams['uiSettings'],
      );

    } catch (e) {
      debugPrint('图片裁剪失败: $e');
      return null;
    }
  }

  /// 判断是否为签名类型域
  static bool _isSignatureField(String fieldName) {
    const signatureKeywords = [
      'signature', 'sign', '签名', '签字', '署名',
      'autograph', '手写签名', '电子签名'
    ];

    return signatureKeywords.any((keyword) => fieldName.contains(keyword));
  }

  /// 判断是否为证件照片类型域
  static bool _isIdPhotoField(String fieldName) {
    const idPhotoKeywords = [
      'id', 'photo', '证件', '照片', '身份证', 'idcard',
      'portrait', '头像', '正面照', '证件照', '人像'
    ];

    return idPhotoKeywords.any((keyword) => fieldName.contains(keyword));
  }

  /// 判断是否为文档附件类型域
  static bool _isDocumentField(String fieldName) {
    const documentKeywords = [
      'document', 'doc', 'attachment', '附件', '文档',
      'attachment_file', '材料', '文件', '资料', '证明'
    ];

    return documentKeywords.any((keyword) => fieldName.contains(keyword));
  }

  /// 获取所有可用的比例配置
  static List<CropRatioConfig> getAllRatioConfigs() {
    return [
      const CropRatioConfig.free(),
      const CropRatioConfig.square(),
      const CropRatioConfig.portrait(),
      const CropRatioConfig.landscape(),
      const CropRatioConfig.standard(),
      const CropRatioConfig.custom(2.0, 3.0), // 2:3 比例示例
    ];
  }

  /// 从字符串解析比例配置（支持自定义比例如 "173:67"）
  static CropRatioConfig? parseRatioFromString(String ratioString) {
    final trimmedString = ratioString.trim();

    // 检查是否为自定义比例格式（如 "173:67", "4:3", "16:9" 等）
    if (_isCustomRatioFormat(trimmedString)) {
      final parts = trimmedString.split(':');
      if (parts.length == 2) {
        try {
          final double ratioX = double.parse(parts[0].trim());
          final double ratioY = double.parse(parts[1].trim());

          if (ratioX > 0 && ratioY > 0) {
            debugPrint('解析自定义比例: $ratioX:$ratioY');
            return CropRatioConfig.custom(ratioX, ratioY);
          }
        } catch (e) {
          debugPrint('解析自定义比例失败: $e');
        }
      }
    }

    // 检查预设比例类型
    final CropRatioType? ratioType = parseRatioType(trimmedString);
    if (ratioType != null) {
      return CropRatioConfig(type: ratioType);
    }

    debugPrint('无法解析比例字符串: $ratioString');
    return null;
  }

  /// 检查字符串是否为自定义比例格式（如 "173:67"）
  static bool _isCustomRatioFormat(String ratioString) {
    final RegExp customRatioRegex = RegExp(r'^\s*\d+\.?\d*\s*:\s*\d+\.?\d*\s*$');
    return customRatioRegex.hasMatch(ratioString);
  }

  /// 根据字符串解析比例类型
  static CropRatioType? parseRatioType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'free':
      case '自由':
        return CropRatioType.free;
      case 'square':
      case '1:1':
      case '正方形':
        return CropRatioType.square;
      case 'portrait':
      case '3:4':
      case '竖版':
      case '证件照':
        return CropRatioType.portrait;
      case 'landscape':
      case '16:9':
      case '横版':
      case '宽屏':
        return CropRatioType.landscape;
      case 'standard':
      case '4:3':
      case '标准':
        return CropRatioType.standard;
      case 'custom':
      case '自定义':
        return CropRatioType.custom;
      default:
        return null;
    }
  }

  /// 验证自定义比例是否有效
  static bool isValidCustomRatio(double ratioX, double ratioY) {
    return ratioX > 0 && ratioY > 0 && ratioX != ratioY;
  }

  /// 计算推荐的比例尺寸
  static Size calculateRecommendedSize(
    Size originalSize,
    CropRatioConfig ratioConfig,
  ) {
    if (ratioConfig.type == CropRatioType.free) {
      return originalSize;
    }

    double targetRatio;
    switch (ratioConfig.type) {
      case CropRatioType.square:
        targetRatio = 1.0;
        break;
      case CropRatioType.portrait:
        targetRatio = 3.0 / 4.0;
        break;
      case CropRatioType.landscape:
        targetRatio = 16.0 / 9.0;
        break;
      case CropRatioType.standard:
        targetRatio = 4.0 / 3.0;
        break;
      case CropRatioType.custom:
        if (ratioConfig.customRatioX != null && ratioConfig.customRatioY != null) {
          targetRatio = ratioConfig.customRatioX! / ratioConfig.customRatioY!;
        } else {
          return originalSize;
        }
        break;
      case CropRatioType.free:
        return originalSize;
    }

    double newWidth, newHeight;
    final originalRatio = originalSize.width / originalSize.height;

    if (originalRatio > targetRatio) {
      // 原图更宽，以高度为准
      newHeight = originalSize.height;
      newWidth = newHeight * targetRatio;
    } else {
      // 原图更高，以宽度为准
      newWidth = originalSize.width;
      newHeight = newWidth / targetRatio;
    }

    return Size(newWidth, newHeight);
  }
}