import 'package:image_cropper/image_cropper.dart';

/// 图片裁剪比例类型
enum CropRatioType {
  /// 自由裁剪 - 不固定比例
  free,

  /// 正方形 - 1:1 比例
  square,

  /// 竖版证件照 - 3:4 比例
  portrait,

  /// 横版宽屏 - 16:9 比例
  landscape,

  /// 标准照片 - 4:3 比例
  standard,

  /// 自定义比例
  custom,
}

/// 图片裁剪比例配置
class CropRatioConfig {
  /// 比例类型
  final CropRatioType type;

  /// 自定义比例宽度（仅当 type 为 custom 时有效）
  final double? customRatioX;

  /// 自定义比例高度（仅当 type 为 custom 时有效）
  final double? customRatioY;

  const CropRatioConfig({
    this.type = CropRatioType.free,
    this.customRatioX,
    this.customRatioY,
  }) : assert(
         type == CropRatioType.custom ?
         (customRatioX != null && customRatioY != null && customRatioX > 0 && customRatioY > 0) :
         true,
         '自定义比例必须提供有效的宽度和高度值'
       );

  /// 创建自由裁剪配置
  const CropRatioConfig.free() : type = CropRatioType.free, customRatioX = null, customRatioY = null;

  /// 创建正方形比例配置 (1:1)
  const CropRatioConfig.square() : type = CropRatioType.square, customRatioX = null, customRatioY = null;

  /// 创建竖版证件照比例配置 (3:4)
  const CropRatioConfig.portrait() : type = CropRatioType.portrait, customRatioX = null, customRatioY = null;

  /// 创建横版宽屏比例配置 (16:9)
  const CropRatioConfig.landscape() : type = CropRatioType.landscape, customRatioX = null, customRatioY = null;

  /// 创建标准照片比例配置 (4:3)
  const CropRatioConfig.standard() : type = CropRatioType.standard, customRatioX = null, customRatioY = null;

  /// 创建自定义比例配置
  const CropRatioConfig.custom(double ratioX, double ratioY)
      : type = CropRatioType.custom,
        customRatioX = ratioX,
        customRatioY = ratioY;

  /// 获取显示名称
  String get displayName {
    switch (type) {
      case CropRatioType.free:
        return '自由裁剪';
      case CropRatioType.square:
        return '正方形 1:1';
      case CropRatioType.portrait:
        return '竖版 3:4';
      case CropRatioType.landscape:
        return '横版 16:9';
      case CropRatioType.standard:
        return '标准 4:3';
      case CropRatioType.custom:
        return '自定义 ${customRatioX?.toStringAsFixed(1)}:${customRatioY?.toStringAsFixed(1)}';
    }
  }

  /// 获取描述信息
  String get description {
    switch (type) {
      case CropRatioType.free:
        return '可以自由调整裁剪区域和比例';
      case CropRatioType.square:
        return '适用于头像、签名等正方形图片';
      case CropRatioType.portrait:
        return '适用于身份证、证件照等竖版图片';
      case CropRatioType.landscape:
        return '适用于横版文档、表单等宽屏图片';
      case CropRatioType.standard:
        return '适用于标准照片比例';
      case CropRatioType.custom:
        return '自定义裁剪比例';
    }
  }

  /// 获取 image_cropper 库对应的预设比例
  CropAspectRatioPreset? get preset {
    switch (type) {
      case CropRatioType.free:
        return null;
      case CropRatioType.square:
        return CropAspectRatioPreset.square;
      case CropRatioType.portrait:
        return CropAspectRatioPreset.ratio4x3;
      case CropRatioType.landscape:
        return CropAspectRatioPreset.ratio16x9;
      case CropRatioType.standard:
        return CropAspectRatioPreset.ratio4x3;
      case CropRatioType.custom:
        return null;
    }
  }

  /// 是否锁定比例
  bool get lockAspectRatio => type != CropRatioType.free;

  /// 获取自定义比例（如果适用）
  CropAspectRatio? get customAspectRatio {
    if (type == CropRatioType.custom && customRatioX != null && customRatioY != null) {
      return CropAspectRatio(ratioX: customRatioX!, ratioY: customRatioY!);
    }
    return null;
  }

  /// 获取推荐的初始预设
  CropAspectRatioPreset get initPreset {
    switch (type) {
      case CropRatioType.free:
        return CropAspectRatioPreset.original;
      case CropRatioType.square:
        return CropAspectRatioPreset.square;
      case CropRatioType.portrait:
        return CropAspectRatioPreset.ratio4x3;
      case CropRatioType.landscape:
        return CropAspectRatioPreset.ratio16x9;
      case CropRatioType.standard:
        return CropAspectRatioPreset.ratio4x3;
      case CropRatioType.custom:
        return CropAspectRatioPreset.original;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CropRatioConfig &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          customRatioX == other.customRatioX &&
          customRatioY == other.customRatioY;

  @override
  int get hashCode => type.hashCode ^ customRatioX.hashCode ^ customRatioY.hashCode;

  @override
  String toString() {
    return 'CropRatioConfig{type: $type, customRatioX: $customRatioX, customRatioY: $customRatioY}';
  }
}