import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'common_const.dart';

/// 文件管理类
/// 负责管理应用沙盒目录中的文件存储
class FileManager {
  FileManager._();

  static const _uuid = Uuid();

  /// 获取缓存目录
  static Future<Directory> get _cacheDir async {
    final cacheDir = await getApplicationCacheDirectory();
    return cacheDir;
  }

  /// 获取客户附件目录
  /// 路径: cache/customer/{customerUid}/
  static Future<Directory> _getCustomerAttachmentDir(String customerUid) async {
    final cacheDir = await _cacheDir;
    final customerDir = Directory(p.join(cacheDir.path, 'customer', customerUid));
    if (!await customerDir.exists()) {
      await customerDir.create(recursive: true);
    }
    return customerDir;
  }

  /// 获取账户文件目录
  /// 路径: cache/account/
  static Future<Directory> _getAccountDir() async {
    final cacheDir = await _cacheDir;
    final accountDir = Directory(p.join(cacheDir.path, 'account'));
    if (!await accountDir.exists()) {
      await accountDir.create(recursive: true);
    }
    return accountDir;
  }

  /// 将附件类型转换为文件名前缀
  static String _getFileNamePrefix(String attachmentType) {
    switch (attachmentType) {
      case ConstCustomerAttachmentType.idCardFront:
        return 'idCard_front';
      case ConstCustomerAttachmentType.idCardBack:
        return 'idCard_back';
      case ConstCustomerAttachmentType.businessLicense:
        return 'businessLicense';
      default:
        return attachmentType;
    }
  }

  /// 保存客户附件文件
  /// 
  /// [sourcePath] 源文件路径
  /// [customerUid] 客户UID
  /// [attachmentType] 附件类型（使用 ConstCustomerAttachmentType 常量）
  /// 
  /// 返回保存后的文件路径（沙盒中的路径）
  static Future<String> saveCustomerAttachment({
    required String sourcePath,
    required String customerUid,
    required String attachmentType,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在: $sourcePath');
    }

    // 获取目标目录
    final targetDir = await _getCustomerAttachmentDir(customerUid);

    // 获取文件扩展名
    final extension = p.extension(sourcePath);
    
    // 生成文件名
    final fileNamePrefix = _getFileNamePrefix(attachmentType);
    final fileName = '$fileNamePrefix$extension';
    final targetPath = p.join(targetDir.path, fileName);

    // 复制文件
    final targetFile = await sourceFile.copy(targetPath);

    return targetFile.path;
  }

  /// 保存账户文件
  /// 
  /// [sourcePath] 源文件路径
  /// 
  /// 返回保存后的文件路径（沙盒中的路径）
  /// 文件名格式: {UUID}.pdf
  static Future<String> saveAccountFile({
    required String sourcePath,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在: $sourcePath');
    }

    // 获取目标目录
    final targetDir = await _getAccountDir();

    // 生成文件名（使用UUID）
    final uuid = _uuid.v4();
    final fileName = '$uuid.pdf';
    final targetPath = p.join(targetDir.path, fileName);

    // 复制文件
    final targetFile = await sourceFile.copy(targetPath);

    return targetFile.path;
  }

  /// 保存账户文件（指定文件名）
  /// 
  /// [sourcePath] 源文件路径
  /// [accountFileUid] 账户文件UID
  /// [fileVersion] 文件版本号
  /// 
  /// 返回保存后的文件路径（沙盒中的路径）
  /// 文件名格式: {account_file_uid}_{file_version}.pdf
  static Future<String> saveAccountFileWithName({
    required String sourcePath,
    required String accountFileUid,
    required int fileVersion,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在: $sourcePath');
    }

    // 获取目标目录
    final targetDir = await _getAccountDir();

    // 生成文件名
    final fileName = '${accountFileUid}_$fileVersion.pdf';
    final targetPath = p.join(targetDir.path, fileName);

    // 复制文件
    final targetFile = await sourceFile.copy(targetPath);

    return targetFile.path;
  }

  /// 删除客户附件文件
  /// 
  /// [filePath] 文件路径（沙盒中的路径）
  static Future<void> deleteCustomerAttachment(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 删除账户文件
  /// 
  /// [filePath] 文件路径（沙盒中的路径）
  static Future<void> deleteAccountFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 检查文件是否存在
  /// 
  /// [filePath] 文件路径
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// 获取客户附件目录中的所有文件
  /// 
  /// [customerUid] 客户UID
  static Future<List<File>> getCustomerAttachmentFiles(String customerUid) async {
    final dir = await _getCustomerAttachmentDir(customerUid);
    if (!await dir.exists()) {
      return [];
    }
    final files = dir.listSync()
        .whereType<File>()
        .toList();
    return files;
  }

  /// 获取账户目录中的所有文件
  static Future<List<File>> getAccountFiles() async {
    final dir = await _getAccountDir();
    if (!await dir.exists()) {
      return [];
    }
    final files = dir.listSync()
        .whereType<File>()
        .toList();
    return files;
  }

  /// 获取临时文件目录
  /// 路径: cache/temp/
  static Future<Directory> _getTempDir() async {
    final cacheDir = await _cacheDir;
    final tempDir = Directory(p.join(cacheDir.path, 'temp'));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  /// 创建临时PDF文件
  ///
  /// [bytes] PDF字节数据
  /// [fileName] 文件名（可选）
  ///
  /// 返回创建的临时文件路径
  static Future<String> createTempPdfFile(Uint8List bytes, {String? fileName}) async {
    final tempDir = await _getTempDir();

    // 生成唯一文件名
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuid = _uuid.v4();
    final finalFileName = fileName ?? 'temp_${timestamp}_$uuid.pdf';
    final tempFile = File(p.join(tempDir.path, finalFileName));

    // 写入文件
    await tempFile.writeAsBytes(bytes);

    return tempFile.path;
  }

  /// 从现有文件创建临时PDF文件
  ///
  /// [sourcePath] 源文件路径
  /// [fileName] 新文件名（可选）
  ///
  /// 返回创建的临时文件路径
  static Future<String> createTempPdfFileFromSource(String sourcePath, {String? fileName}) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在: $sourcePath');
    }

    // 读取源文件字节数据
    final bytes = await sourceFile.readAsBytes();

    // 创建临时文件
    return await createTempPdfFile(bytes, fileName: fileName);
  }

  /// 删除临时文件
  ///
  /// [filePath] 文件路径
  static Future<void> deleteTempFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 静默处理删除失败，避免影响主流程
      print('删除临时文件失败: $e');
    }
  }

  /// 清理所有临时文件
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await _getTempDir();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('清理临时文件失败: $e');
    }
  }
}

