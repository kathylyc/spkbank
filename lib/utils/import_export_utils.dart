import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 导入导出工具类
/// 提供通用的导入导出功能，包括密码保护、文件选择、压缩解压等
class ImportExportUtils {
  ImportExportUtils._();

  /// 获取Downloads目录
  static Future<Directory?> getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final rootPath = externalDir.path.split('/Android')[0];
          final downloadsDir = Directory(p.join(rootPath, 'Download'));
          if (!await downloadsDir.exists()) {
            final downloadsDirAlt = Directory(p.join(rootPath, 'Downloads'));
            if (await downloadsDirAlt.exists()) {
              return downloadsDirAlt;
            }
            await downloadsDir.create(recursive: true);
          }
          return downloadsDir;
        }
      } catch (e) {
        debugPrint('获取Android Downloads目录失败: $e');
      }
    } else if (Platform.isIOS) {
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory(p.join(documentsDir.path, 'Downloads'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      } catch (e) {
        debugPrint('获取iOS Downloads目录失败: $e');
      }
    }
    return null;
  }

  /// 提示输入压缩密码
  static Future<String?> promptZipPassword(BuildContext context) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('设置压缩包密码'),
              content: TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '压缩包密码',
                  hintText: '请输入密码',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final password = controller.text.trim();
                    if (password.isEmpty) {
                      setState(() {
                        errorText = '密码不能为空';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(password);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    // 延迟 dispose，确保 dialog 完全关闭后再清理 controller
    Future.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });
    return result;
  }

  /// 提示输入解压密码
  static Future<String?> promptUnzipPassword(BuildContext context) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('输入解压密码'),
              content: TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '解压密码',
                  hintText: '请输入密码',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final password = controller.text.trim();
                    if (password.isEmpty) {
                      setState(() {
                        errorText = '密码不能为空';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(password);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    // 延迟 dispose，确保 dialog 完全关闭后再清理 controller
    Future.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });
    return result;
  }

  /// 显示加载对话框
  static void showLoadingDialog(BuildContext context, {String message = '正在处理...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// 关闭加载对话框
  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// 下载导入模板
  /// [assetPath] assets中的模板文件路径
  /// [fileName] 保存的文件名
  static Future<void> downloadTemplate(
    BuildContext context, {
    required String assetPath,
    required String fileName,
  }) async {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在下载导入模板...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('无法获取Downloads目录，请检查存储权限');
      }

      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      final targetPath = p.join(downloadsDir.path, fileName);
      final targetFile = File(targetPath);

      String finalPath = targetPath;
      if (await targetFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        finalPath = p.join(downloadsDir.path, '${nameWithoutExt}_$timestamp$ext');
      }

      await File(finalPath).writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('导入模板下载成功'),
              const SizedBox(height: 4),
              Text(
                '保存为: ${p.basename(finalPath)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('下载导入模板失败: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载导入模板失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 导出数据到ZIP文件
  /// [context] BuildContext
  /// [templateAssetPath] 模板文件在assets中的路径
  /// [zipFileName] ZIP文件名（不含扩展名）
  /// [excelFileName] Excel文件名（不含扩展名）
  /// [data] 要导出的数据列表
  /// [dataToExcelRows] 将数据转换为Excel行的函数
  /// [headers] 表头列表（如果模板加载失败，将使用此表头创建新文件）
  /// [beforeDataToExcelRows] 在填充Excel数据之前执行的回调，用于复制文件等操作，返回相对路径映射（key: 原始路径, value: 相对路径）
  /// [loadingMessage] 加载对话框消息
  /// [successMessage] 成功消息（如果为null，使用默认消息）
  /// [onSuccess] 成功回调
  /// [onError] 错误回调
  static Future<void> exportToZip(
    BuildContext context, {
    required String templateAssetPath,
    required String zipFileName,
    required String excelFileName,
    required List<Map<String, dynamic>> data,
    required void Function(excel.Sheet sheet, Map<String, dynamic> rowData, int rowIndex, Map<String, String>? filePathMap) dataToExcelRows,
    List<String>? headers,
    Future<Map<String, String>> Function(String exportDirPath)? beforeDataToExcelRows,
    String loadingMessage = '正在导出数据...',
    String? successMessage,
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) async {
    if (data.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前没有可导出的数据'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 获取压缩密码
    final zipPassword = await promptZipPassword(context);
    if (zipPassword == null) {
      return;
    }

    // 显示加载对话框
    if (context.mounted) {
      showLoadingDialog(context, message: loadingMessage);
    }

    // 临时文件变量，用于在 finally 块中清理
    File? excelFile;
    File? zipFile;
    Directory? exportCurrentDir;

    try {
      excel.Excel excelBook;
      String sheetName;
      excel.Sheet sheet;

      bool useTemplate = true;
      // 尝试加载模板，如果失败则创建新的Excel文件
      try {
        final templateData = await rootBundle.load(templateAssetPath);
        final templateBytes = templateData.buffer.asUint8List();
        excelBook = excel.Excel.decodeBytes(templateBytes);
        sheetName = excelBook.tables.isNotEmpty
            ? excelBook.tables.keys.first
            : (excelBook.sheets.isNotEmpty ? excelBook.sheets.keys.first : 'Sheet1');
        if (sheetName.isEmpty) {
          throw Exception('模板中未找到可用的工作表');
        }
        sheet = excelBook[sheetName] ?? excelBook['Sheet1']!;
        // 如果使用模板，从第二行开始填充数据（第一行是表头）
      } catch (templateError) {
        // 模板加载失败，创建新的Excel文件
        debugPrint('模板加载失败，创建新的Excel文件: $templateError');
        useTemplate = false;
        excelBook = excel.Excel.createExcel();
        sheetName = 'Sheet1';
        sheet = excelBook[sheetName];
        
        // 如果提供了表头，添加表头
        if (headers != null && headers.isNotEmpty) {
          for (int i = 0; i < headers.length; i++) {
            sheet
                .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
                .value = excel.TextCellValue(headers[i]);
          }
        }
      }

      // 保存到临时目录
      final cacheDir = await getTemporaryDirectory();
      final exportDir = Directory(p.join(cacheDir.path, 'export'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      exportCurrentDir = Directory(p.join(exportDir.path, '$timestamp'));
      if (!await exportCurrentDir.exists()) {
        await exportCurrentDir.create(recursive: true);
      }

      // 在填充Excel数据之前执行文件复制等操作
      Map<String, String>? filePathMap = null; // key: 原始路径, value: 相对路径
      if (beforeDataToExcelRows != null) {
        filePathMap = await beforeDataToExcelRows(exportCurrentDir.path);
      }

      // 填充数据（从第二行开始，第一行是表头）
      final startRow = useTemplate ? 2 : (headers != null && headers.isNotEmpty ? 2 : 1);
      for (int i = 0; i < data.length; i++) {
        final rowData = data[i];
        final rowIndex = startRow - 1 + i;
        dataToExcelRows(sheet, rowData, rowIndex, filePathMap);
      }

      // 生成Excel文件
      final excelBytes = excelBook.encode();
      if (excelBytes == null) {
        throw Exception('生成Excel数据失败');
      }

      final excelName = '${excelFileName}_$timestamp.xlsx';
      final excelPath = p.join(exportCurrentDir.path, excelName);
      excelFile = File(excelPath);
      await excelFile.writeAsBytes(excelBytes, flush: true);

      // 创建ZIP文件
      final zipName = '${zipFileName}_$timestamp.zip';
      final zipPath = p.join(exportCurrentDir.path, zipName);
      zipFile = File(zipPath);
      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      // 使用 archive 包创建密码保护的 ZIP 文件
      final archive = Archive();
      final excelFileBytes = await excelFile.readAsBytes();
      final excelArchiveFile = ArchiveFile(
        excelName,
        excelFileBytes.length,
        excelFileBytes,
      );
      archive.addFile(excelArchiveFile);

      // 添加files目录下的所有文件到ZIP
      final filesDir = Directory(p.join(exportCurrentDir.path, 'files'));
      if (await filesDir.exists()) {
        final files = filesDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            final relativePath = p.relative(file.path, from: exportCurrentDir.path);
            final fileBytes = await file.readAsBytes();
            final archiveFile = ArchiveFile(
              relativePath.replaceAll('\\', '/'), // 统一使用正斜杠
              fileBytes.length,
              fileBytes,
            );
            archive.addFile(archiveFile);
          }
        }
      }

      // 编码 ZIP 文件（带密码保护）
      final zipEncoder = ZipEncoder(password: zipPassword);
      final zipBytes = zipEncoder.encode(
        archive,
        level: Deflate.BEST_COMPRESSION,
      );

      if (zipBytes == null) {
        throw Exception('生成 ZIP 文件失败');
      }

      await zipFile.writeAsBytes(zipBytes, flush: true);

      // 复制到Downloads目录
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('无法获取Downloads目录，请检查存储权限');
      }

      final targetZipPath = p.join(downloadsDir.path, zipName);
      final targetZipFile = File(targetZipPath);
      if (await targetZipFile.exists()) {
        await targetZipFile.delete();
      }
      await zipFile.copy(targetZipPath);

      // 关闭加载对话框
      if (context.mounted) {
        hideLoadingDialog(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(successMessage ?? '数据导出成功'),
                const SizedBox(height: 4),
                Text(
                  'ZIP 文件: ${p.basename(targetZipPath)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      onSuccess?.call();
    } catch (e, s) {
      debugPrint('导出数据失败: $e');
      debugPrintStack(stackTrace: s);

      // 关闭加载对话框
      if (context.mounted) {
        hideLoadingDialog(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      onError?.call(e.toString());
    } finally {
      // 无论成功还是失败，都清理临时文件
      try {
        // if (exportCurrentDir != null && await exportCurrentDir.exists()) {
        //   await exportCurrentDir.delete(recursive: true);
        // }
      } catch (e) {
        debugPrint('删除临时文件失败: $e');
      }
    }
  }

  /// 导入数据从ZIP文件
  /// [context] BuildContext
  /// [excelFileNamePrefix] Excel文件名前缀（用于验证）
  /// [validateExcelFile] 验证Excel文件的函数，返回错误信息，null表示验证通过
  /// [processExcelData] 处理Excel数据的函数，返回成功消息（可选）
  /// [loadingMessage] 加载对话框消息
  /// [onSuccess] 成功回调，参数为成功消息
  /// [onError] 错误回调
  static Future<void> importFromZip(
    BuildContext context, {
    required String excelFileNamePrefix,
    Future<String?> Function(File excelFile)? validateExcelFile,
    required Future<String?> Function(File excelFile, String importDirPath) processExcelData,
    String loadingMessage = '正在导入数据...',
    Function(String? successMessage)? onSuccess,
    Function(String error)? onError,
  }) async {
    try {
      // 获取下载目录作为初始目录
      final downloadsDir = await getDownloadsDirectory();
      String? initialDirectory;
      if (downloadsDir != null) {
        initialDirectory = downloadsDir.path;
      }

      // 弹出文件浏览器，仅可选择 zip 包
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        initialDirectory: initialDirectory,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selectedFile = result.files.single;
      final String? zipFilePath = selectedFile.path;
      if (zipFilePath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法获取文件路径，请重试'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文件不存在，请重新选择'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 弹出密码输入对话框
      final password = await promptUnzipPassword(context);
      if (password == null) {
        return;
      }

      // 显示加载对话框
      if (context.mounted) {
        showLoadingDialog(context, message: loadingMessage);
      }

      // 获取 cache/import 目录
      final cacheDir = await getTemporaryDirectory();
      final importDir = Directory(p.join(cacheDir.path, 'import'));
      if (!await importDir.exists()) {
        await importDir.create(recursive: true);
      }

      // 复制 zip 文件到 cache/import 目录
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final importCurrentDir = Directory(p.join(importDir.path, '$timestamp'));
      if (!await importCurrentDir.exists()) {
        await importCurrentDir.create(recursive: true);
      }
      final targetZipName = 'import_$timestamp.zip';
      final targetZipPath = p.join(importCurrentDir.path, targetZipName);
      final targetZipFile = File(targetZipPath);
      await zipFile.copy(targetZipPath);

      // 解压 zip 文件
      try {
        final zipBytes = await targetZipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(zipBytes, password: password);

        // 解压到 cache/import 目录
        for (final file in archive) {
          final filePath = p.join(importCurrentDir.path, file.name);
          if (file.isFile) {
            final outFile = File(filePath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            await Directory(filePath).create(recursive: true);
          }
        }

        // 查找Excel文件
        File? excelFile;
        final importFiles = importCurrentDir.listSync();
        for (final file in importFiles) {
          debugPrint('importFiles...file=${file.path}');
          if (file is File) {
            final fileName = p.basename(file.path);
            if (fileName.toLowerCase().startsWith(excelFileNamePrefix.toLowerCase()) &&
                fileName.toLowerCase().endsWith('.xlsx')) {
              excelFile = file;
              debugPrint('importFiles...excelFile=${excelFile.path}');
              break;
            }
          }
        }

        if (excelFile == null || !await excelFile.exists()) {
          // 删除临时文件
          try {
            // if (await importCurrentDir.exists()) {
            //   await importCurrentDir.delete(recursive: true);
            // }
          } catch (deleteError) {
            debugPrint('删除临时文件失败: $deleteError');
          }

          if (context.mounted) {
            hideLoadingDialog(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('非标准压缩包，不支持导入1'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          onError?.call('非标准压缩包，不支持导入1');
          return;
        }

        // 验证Excel文件
        if (validateExcelFile != null) {
          final validationError = await validateExcelFile(excelFile);
          if (validationError != null) {
            // 删除临时文件
            try {
              if (await targetZipFile.exists()) {
                await targetZipFile.delete();
              }
              if (await importDir.exists()) {
                await importDir.delete(recursive: true);
              }
            } catch (deleteError) {
              debugPrint('删除临时文件失败: $deleteError');
            }

            if (context.mounted) {
              hideLoadingDialog(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(validationError),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            onError?.call(validationError);
            return;
          }
        }

        // 处理Excel数据
        final successMessage = await processExcelData(excelFile, importCurrentDir.path);

        // 删除临时文件
        try {
          if (await targetZipFile.exists()) {
            await targetZipFile.delete();
          }
          if (await importCurrentDir.exists()) {
            await importCurrentDir.delete(recursive: true);
          }
        } catch (deleteError) {
          debugPrint('删除临时文件失败: $deleteError');
        }

        // 关闭加载对话框
        if (context.mounted) {
          hideLoadingDialog(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage ?? '导入成功'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        onSuccess?.call(successMessage);
      } catch (e) {
        // 解压失败（可能是密码错误）
        debugPrint('解压失败: $e');

        // 关闭加载对话框
        if (context.mounted) {
          hideLoadingDialog(context);
        }

        // 删除临时文件
        try {
          if (await targetZipFile.exists()) {
            await targetZipFile.delete();
          }
          if (await importCurrentDir.exists()) {
            await importCurrentDir.delete(recursive: true);
          }
        } catch (deleteError) {
          debugPrint('删除临时文件失败: $deleteError');
        }

        final errorMessage = e.toString().contains('password') || e.toString().contains('密码')
            ? '密码错误'
            : e.toString();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('解压失败: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        onError?.call(errorMessage);
      }
    } catch (e, s) {
      debugPrint('导入数据失败: $e');
      debugPrintStack(stackTrace: s);

      // 关闭加载对话框（如果还在显示）
      if (context.mounted) {
        hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      onError?.call(e.toString());
    }
  }
}

