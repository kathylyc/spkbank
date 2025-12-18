import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// 图像适配辅助类
/// 提供类似 BoxFit.cover 的 PDF 图像绘制功能
class ImageFitHelper {

  /// 计算 BoxFit.cover 的绘制矩形
  ///
  /// [imageWidth] 原始图像宽度
  /// [imageHeight] 原始图像高度
  /// [targetWidth] 目标区域宽度
  /// [targetHeight] 目标区域高度
  ///
  /// 返回绘制矩形，保持图像宽高比并居中裁剪
  static Rect calculateCoverRect(
    double imageWidth,
    double imageHeight,
    double targetWidth,
    double targetHeight,
  ) {
    if (imageWidth == 0 || imageHeight == 0) {
      return Rect.fromLTWH(0, 0, targetWidth, targetHeight);
    }

    // 计算缩放比例
    final double scaleX = targetWidth / imageWidth;
    final double scaleY = targetHeight / imageHeight;

    // 选择较大的缩放比例，确保完全覆盖目标区域
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    // 计算缩放后的图像尺寸
    final double scaledWidth = imageWidth * scale;
    final double scaledHeight = imageHeight * scale;

    // 计算居中位置
    final double offsetX = (targetWidth - scaledWidth) / 2;
    final double offsetY = (targetHeight - scaledHeight) / 2;

    return Rect.fromLTWH(
      offsetX,
      offsetY,
      scaledWidth,
      scaledHeight,
    );
  }

  /// 计算 BoxFit.contain 的绘制矩形
  ///
  /// 保持图像宽高比，完整显示在目标区域内
  static Rect calculateContainRect(
    double imageWidth,
    double imageHeight,
    double targetWidth,
    double targetHeight,
  ) {
    if (imageWidth == 0 || imageHeight == 0) {
      return Rect.fromLTWH(0, 0, targetWidth, targetHeight);
    }

    // 计算缩放比例
    final double scaleX = targetWidth / imageWidth;
    final double scaleY = targetHeight / imageHeight;

    // 选择较小的缩放比例，确保图像完全显示在目标区域内
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // 计算缩放后的图像尺寸
    final double scaledWidth = imageWidth * scale;
    final double scaledHeight = imageHeight * scale;

    // 计算居中位置
    final double offsetX = (targetWidth - scaledWidth) / 2;
    final double offsetY = (targetHeight - scaledHeight) / 2;

    return Rect.fromLTWH(
      offsetX,
      offsetY,
      scaledWidth,
      scaledHeight,
    );
  }

  /// 计算 BoxFit.fill 的绘制矩形
  ///
  /// 直接拉伸填满目标区域，不保持宽高比
  static Rect calculateFillRect(
    double targetWidth,
    double targetHeight,
  ) {
    return Rect.fromLTWH(0, 0, targetWidth, targetHeight);
  }

  /// 计算 BoxFit.scaleDown 的绘制矩形
  ///
  /// 如果图像比目标区域大，则使用 contain 模式；否则保持原始尺寸
  static Rect calculateScaleDownRect(
    double imageWidth,
    double imageHeight,
    double targetWidth,
    double targetHeight,
  ) {
    if (imageWidth <= targetWidth && imageHeight <= targetHeight) {
      // 图像比目标区域小，直接居中显示
      final double offsetX = (targetWidth - imageWidth) / 2;
      final double offsetY = (targetHeight - imageHeight) / 2;
      return Rect.fromLTWH(offsetX, offsetY, imageWidth, imageHeight);
    } else {
      // 图像比目标区域大，使用 contain 模式
      return calculateContainRect(imageWidth, imageHeight, targetWidth, targetHeight);
    }
  }

  /// 裁剪图像数据用于 BoxFit.cover 模式
  ///
  /// [imageData] 原始图像数据
  /// [targetWidth] 目标宽度
  /// [targetHeight] 目标高度
  ///
  /// 返回裁剪后的图像数据
  static Future<Uint8List> cropImageForCoverFit(
    Uint8List imageData,
    double targetWidth,
    double targetHeight,
  ) async {
    try {
      // 解码图像
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final ui.Image originalImage = frame.image;

      final int imageWidth = originalImage.width;
      final int imageHeight = originalImage.height;

      // 计算缩放比例
      final double scaleX = targetWidth / imageWidth;
      final double scaleY = targetHeight / imageHeight;
      final double scale = scaleX > scaleY ? scaleX : scaleY;

      // 计算裁剪区域
      Rect cropRect;
      if (scaleX > scaleY) {
        // 宽度超出，裁剪左右两边
        final double cropWidth = targetHeight / scale;
        final double cropX = (imageWidth - cropWidth) / 2;
        cropRect = Rect.fromLTWH(cropX, 0, cropWidth, imageHeight.toDouble());
      } else {
        // 高度超出，裁剪上下两边
        final double cropHeight = targetWidth / scale;
        final double cropY = (imageHeight - cropHeight) / 2;
        cropRect = Rect.fromLTWH(0, cropY, imageWidth.toDouble(), cropHeight);
      }

      // 创建裁剪后的图像
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = Canvas(recorder);

      // 绘制裁剪区域
      canvas.drawImageRect(
        originalImage,
        cropRect,
        Rect.fromLTWH(0, 0, cropRect.width, cropRect.height),
        Paint(),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImage = await picture.toImage(
        cropRect.width.round(),
        cropRect.height.round(),
      );

      // 转换为字节数据
      final ByteData? byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      originalImage.dispose();
      croppedImage.dispose();
      picture.dispose();

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }

      return imageData; // 如果裁剪失败，返回原始数据
    } catch (e) {
      debugPrint('裁剪图像失败: $e');
      return imageData; // 如果裁剪失败，返回原始数据
    }
  }

  /// 绘制图像到 PDF 页面，支持 BoxFit 模式
  ///
  /// [graphics] PDF 图形对象
  /// [imageData] 图像字节数据
  /// [targetRect] 目标绘制区域
  /// [boxFit] 适配模式，默认为 BoxFit.cover
  /// [padding] 内边距，默认为 0
  static Future<void> drawImageWithFit(
    PdfGraphics graphics,
    Uint8List imageData,
    Rect targetRect, {
    BoxFit boxFit = BoxFit.cover,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    try {
      // 计算实际绘制区域（减去内边距）
      final Rect actualTargetRect = Rect.fromLTRB(
        targetRect.left + padding.left,
        targetRect.top + padding.top,
        targetRect.right - padding.right,
        targetRect.bottom - padding.bottom,
      );

      Uint8List finalImageData = imageData;

      // 对于 BoxFit.cover，先裁剪图像数据
      if (boxFit == BoxFit.cover) {
        finalImageData = await cropImageForCoverFit(
          imageData,
          actualTargetRect.width,
          actualTargetRect.height,
        );
      }

      // 创建 PDF 图像对象
      final PdfImage pdfImage = PdfBitmap(finalImageData);

      // 直接绘制到目标区域
      graphics.drawImage(pdfImage, actualTargetRect);

    } catch (e) {
      debugPrint('绘制图像失败: $e');
      // 降级处理：使用原始的 fill 模式
      try {
        final PdfImage pdfImage = PdfBitmap(imageData);
        graphics.drawImage(pdfImage, targetRect);
      } catch (fallbackError) {
        debugPrint('降级绘制也失败: $fallbackError');
      }
    }
  }

  /// 从图像字节数据获取图像尺寸
  ///
  /// [imageData] 图像字节数据
  ///
  /// 返回图像尺寸，如果无法获取则返回 null
  static Future<Size?> getImageSize(Uint8List imageData) async {
    try {
      // 使用 Flutter 的 Image API 解码图像信息
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      return Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (e) {
      debugPrint('获取图像尺寸失败: $e');
      return null;
    }
  }
}