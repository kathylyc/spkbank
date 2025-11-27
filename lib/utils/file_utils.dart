import 'dart:io';
import 'dart:typed_data';
import 'package:bank_flutter/utils/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

/// 文件工具类，用于处理文件存储、打开和分享
class FileUtils {
  /// 获取应用文档目录（iOS Files应用可访问）
  static Future<Directory?> _getDocumentsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      print('获取文档目录失败: $e');
      return null;
    }
  }

  /// 获取 Android 公共 Downloads 目录
  static Future<Directory?> _getAndroidDownloadsDirectory() async {
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // 获取外部存储的根目录（通常是 /storage/emulated/0）
        final externalPath = externalDir.path;
        // 找到外部存储根目录
        final rootPath = externalPath.split('/Android')[0];
        final downloadsDir = Directory(p.join(rootPath, 'Download'));

        // 如果Download目录不存在，尝试Downloads（某些设备使用复数形式）
        if (!await downloadsDir.exists()) {
          final downloadsDirAlt = Directory(p.join(rootPath, 'Downloads'));
          if (await downloadsDirAlt.exists()) {
            return downloadsDirAlt;
          }
          // 如果都不存在，创建Download目录
          await downloadsDir.create(recursive: true);
        }

        return downloadsDir;
      }
    } catch (e) {
      print('获取Android Downloads目录失败: $e');
    }
    return null;
  }

  /// 平台特定的文件保存方法
  static Future<String?> saveFileForPlatform({
    required Uint8List bytes,
    required String fileName,
    String? subDirectory,
  }) async {
    if (Platform.isAndroid) {
      return await _saveToAndroidDownloads(bytes: bytes, fileName: fileName);
    } else {
      // iOS 和其他平台使用文档目录
      return await saveToDocuments(
        bytes: bytes,
        fileName: fileName,
        subDirectory: subDirectory ?? 'Downloads',
      );
    }
  }

  /// 保存文件到 Android 公共 Downloads 目录
  static Future<String?> _saveToAndroidDownloads({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final downloadsDir = await _getAndroidDownloadsDirectory();
      if (downloadsDir == null) {
        print('无法获取Android Downloads目录');
        return null;
      }

      String targetPath = p.join(downloadsDir.path, fileName);
      final targetFile = File(targetPath);

      // 如果文件已存在，添加时间戳后缀
      if (await targetFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        targetPath = p.join(downloadsDir.path, '${nameWithoutExt}_$timestamp$ext');
      }

      await File(targetPath).writeAsBytes(bytes);
      print('文件保存成功到Android Downloads: $targetPath');
      return targetPath;
    } catch (e) {
      print('保存文件到Android Downloads失败: $e');
      return null;
    }
  }

  /// 保存文件到应用文档目录
  static Future<String?> saveToDocuments({
    required Uint8List bytes,
    required String fileName,
    String? subDirectory,
  }) async {
    try {
      final dir = await _getDocumentsDirectory();
      if (dir == null) return null;

      String targetPath;
      if (subDirectory != null && subDirectory.isNotEmpty) {
        final subDir = Directory(p.join(dir.path, subDirectory));
        if (!await subDir.exists()) {
          await subDir.create(recursive: true);
        }
        targetPath = p.join(subDir.path, fileName);
      } else {
        targetPath = p.join(dir.path, fileName);
      }

      final file = File(targetPath);

      // 如果文件已存在，添加时间戳后缀
      if (await file.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        targetPath = p.join(p.dirname(targetPath), '${nameWithoutExt}_$timestamp$ext');
      }

      await File(targetPath).writeAsBytes(bytes);
      print('文件保存成功: $targetPath');
      return targetPath;
    } catch (e) {
      print('保存文件失败: $e');
      return null;
    }
  }

  /// 打开文件
  static Future<bool> openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('无法打开文件: $filePath');
        return false;
      }
    } catch (e) {
      print('打开文件失败: $e');
      return false;
    }
  }

  /// 分享文件
  static Future<void> shareFile(
    String filePath, {
    String? subject,
    String? text,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('文件不存在: $filePath');
        return;
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: subject,
        text: text,
      );
    } catch (e) {
      print('分享文件失败: $e');
    }
  }

  /// 显示文件操作对话框
  static Future<void> showFileActionDialog(
    BuildContext context, {
    required String fileName,
    required String filePath,
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('文件已下载'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('文件名: $fileName'),
              // const SizedBox(height: 8),
              // Text(
              //   '保存位置: ${p.dirname(filePath)}',
              //   style: Theme.of(context).textTheme.bodySmall,
              // ),
              const SizedBox(height: 16),
              Text(
                '您可以通过以下方式访问文件：',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                Platform.isAndroid
                    ? '• 在设备"文件管理器-Download"文件夹中找到文件'
                    : '• 在iPad"文件-我的iPad-${context.S.appName}-Downloads"中找到文件',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
            // TextButton(
            //   onPressed: () {
            //     Navigator.of(context).pop();
            //     openFile(filePath);
            //   },
            //   child: const Text('打开文件'),
            // ),
            // ElevatedButton(
            //   onPressed: () {
            //     Navigator.of(context).pop();
            //     shareFile(filePath, subject: fileName);
            //   },
            //   child: const Text('分享'),
            // ),
          ],
        );
      },
    );
  }

  /// 获取友好的文件大小显示
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 检查文件是否可访问
  static Future<bool> isFileAccessible(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}