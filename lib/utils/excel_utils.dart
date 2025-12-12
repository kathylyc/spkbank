import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

/// Excel工具类
/// 提供Excel文件处理相关的通用方法
class ExcelUtils {
  ExcelUtils._();

  /// 解码 Excel 字节并自动修复 numFmtId 问题（如果需要）
///
/// [excelBytes] Excel文件的字节数组
///
/// 返回解码后的 Excel 对象，如果检测到 numFmtId 问题会自动修复
/// 如果修复失败，会抛出相应的异常
static Excel decodeBytesOrFixExcelNumFmtIdIfNeed(List<int> excelBytes) {
    try {
      // 首先尝试直接解码
      final excelBook = Excel.decodeBytes(excelBytes);
      return excelBook;
    } catch(e) {
      debugPrint('Excel解码失败: $e');

      // 检查是否是 numFmtId 相关的异常
      final errorString = e.toString();
      if (errorString.contains('numFmtId') &&
          errorString.contains('found a value of')) {
        debugPrint('检测到 numFmtId 异常，尝试自动修复...');

        try {
          // 修复 numFmtId 问题
          final fixedBytes = fixExcelNumFmtId(excelBytes);
          final fixedExcelBook = Excel.decodeBytes(fixedBytes);
          debugPrint('numFmtId 自动修复成功');
          return fixedExcelBook;
        } catch(fixError) {
          debugPrint('numFmtId 自动修复失败: $fixError');
          // 抛出修复失败的异常
          rethrow;
        }
      }

      // 如果不是 numFmtId 异常，直接抛出原始异常
      rethrow;
    }
  }

  /// 修复 Excel 文件中的 numFmtId 问题
  /// Excel 文件中的自定义数字格式 ID 必须从 164 开始（根据 ECMA-376 标准）
  /// 此方法会解压 Excel 文件，修复 styles.xml 中的 numFmtId，然后重新压缩
  ///
  /// [excelBytes] Excel文件的字节数组
  ///
  /// 返回修复后的Excel文件字节数组，如果修复失败则返回原始字节数组
  static List<int> fixExcelNumFmtId(List<int> excelBytes) {
    try {
      // 解压 Excel 文件（.xlsx 实际上是一个 ZIP 文件）
      final archive = ZipDecoder().decodeBytes(excelBytes);

      // 查找并修复 styles.xml 文件
      ArchiveFile? stylesFile;
      for (final file in archive) {
        if (file.name == 'xl/styles.xml' || file.name == 'xl\\styles.xml') {
          stylesFile = file;
          break;
        }
      }

      if (stylesFile != null) {
        // 读取 styles.xml 内容
        final stylesContent = utf8.decode(stylesFile.content as List<int>);

        // 使用两个正则表达式分别匹配双引号和单引号格式
        final doubleQuotePattern = RegExp(r'numFmtId="(\d+)"');
        final singleQuotePattern = RegExp(r"numFmtId='(\d+)'");
        final numFmtDefPattern = RegExp(r'<numFmt\s+numFmtId="(\d+)"');
        final numFmtDefPatternSingle = RegExp(r"<numFmt\s+numFmtId='(\d+)'");

        // 第一步：收集所有格式定义中的 numFmtId
        final definedIds = <int>{};
        for (final match in numFmtDefPattern.allMatches(stylesContent)) {
          final id = int.tryParse(match.group(1) ?? '');
          if (id != null) {
            definedIds.add(id);
          }
        }
        for (final match in numFmtDefPatternSingle.allMatches(stylesContent)) {
          final id = int.tryParse(match.group(1) ?? '');
          if (id != null) {
            definedIds.add(id);
          }
        }

        // 第二步：收集所有引用中的 numFmtId
        final referencedIds = <int>{};
        for (final match in doubleQuotePattern.allMatches(stylesContent)) {
          final id = int.tryParse(match.group(1) ?? '');
          if (id != null) {
            referencedIds.add(id);
          }
        }
        for (final match in singleQuotePattern.allMatches(stylesContent)) {
          final id = int.tryParse(match.group(1) ?? '');
          if (id != null) {
            referencedIds.add(id);
          }
        }

        // 第三步：找到所有需要修复的 numFmtId（小于 164 的，且在格式定义中存在的）
        final idsToFix = <int>{};
        for (final id in definedIds) {
          if (id >= 0 && id < 164) {
            idsToFix.add(id);
          }
        }

        // 第四步：为每个需要修复的 ID 分配一个新的唯一 ID（从 164 开始）
        final idMapping = <int, int>{};
        final allExistingIds = <int>{...definedIds, ...referencedIds};
        int nextId = 164;
        for (final oldId in idsToFix) {
          // 找到一个不冲突的新 ID
          while (allExistingIds.contains(nextId)) {
            nextId++;
          }
          idMapping[oldId] = nextId;
          allExistingIds.add(nextId); // 标记为已使用
          nextId++;
        }

        // 第五步：替换所有需要修复的 numFmtId（包括格式定义和引用）
        // 注意：需要按从大到小的顺序替换，避免替换冲突
        String fixedContent = stylesContent;
        final sortedMappings = idMapping.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)); // 从大到小排序

        for (final entry in sortedMappings) {
          final oldId = entry.key;
          final newId = entry.value;
          debugPrint('修复 numFmtId: $oldId -> $newId');

          // 替换格式定义中的 numFmtId（<numFmt numFmtId="..."/>）
          fixedContent = fixedContent.replaceAll(
            '<numFmt numFmtId="$oldId"',
            '<numFmt numFmtId="$newId"',
          );
          fixedContent = fixedContent.replaceAll(
            "<numFmt numFmtId='$oldId'",
            "<numFmt numFmtId='$newId'",
          );

          // 替换引用中的 numFmtId（numFmtId="..."）
          fixedContent = fixedContent.replaceAll(
            'numFmtId="$oldId"',
            'numFmtId="$newId"',
          );
          // 替换单引号格式
          fixedContent = fixedContent.replaceAll(
            "numFmtId='$oldId'",
            "numFmtId='$newId'",
          );
        }

        // 更新 archive 中的文件
        final fixedStylesBytes = utf8.encode(fixedContent);
        archive.removeFile(stylesFile);
        archive.addFile(ArchiveFile(
          stylesFile.name,
          fixedStylesBytes.length,
          fixedStylesBytes,
        ));
      }

      // 重新压缩为 Excel 文件
      final encoder = ZipEncoder();
      final fixedBytes = encoder.encode(archive);

      if (fixedBytes == null) {
        debugPrint('重新压缩 Excel 文件失败，返回原始字节');
        return excelBytes;
      }

      return fixedBytes;
    } catch (e, s) {
      debugPrint('修复 Excel numFmtId 失败: $e');
      debugPrintStack(stackTrace: s);
      // 如果修复失败，返回原始字节，让后续的错误处理来处理
      return excelBytes;
    }
  }
}