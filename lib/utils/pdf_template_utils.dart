import 'common_const.dart';

/// PDF模板工具类
/// 提供获取PDF模板列表的通用方法
class PdfTemplateUtils {
  PdfTemplateUtils._();

  /// 从ConstPdfTemplateMap常量获取PDF模板Map
  ///
  /// includeTemplatePreviewOnly=false 时过滤掉 signCode 为 'urbqq67tjx2jd6hq' 的模板
  static Map<String, PdfTemplateInfo> getPdfTemplateMap({includeTemplatePreviewOnly = false}) {
    final entries = includeTemplatePreviewOnly
        ? ConstPdfTemplateMap.entries
        : ConstPdfTemplateMap.entries.where((entry) {
            return entry.value.signCode != 'urbqq67tjx2jd6hq';
          });
    return Map.fromEntries(entries);
  }

  /// 从ConstPdfTemplateMap常量获取PDF模板列表
  /// 
  /// 返回格式化的PDF模板数据列表，每个元素包含：
  /// - id: 模板ID（int类型）
  /// - name: 文件名（String类型）
  /// - assetPath: 资源路径（String类型）
  /// - count: 引用次数（int类型，默认为0）
  static List<Map<String, dynamic>> getPdfTemplateList({includeTemplatePreviewOnly=false}) {
    return ConstPdfTemplateMap.entries
        .where((entry) {
          // includeTemplatePreviewOnly=false 时过滤掉 signCode 为 'urbqq67tjx2jd6hq' 的模板
          if (!includeTemplatePreviewOnly) {
            return entry.value.signCode != 'urbqq67tjx2jd6hq';
          }
          return true;
        })
        .map((entry) {
          final id = int.parse(entry.key);
          final templateInfo = entry.value;
          final signCode = templateInfo.signCode;
          final assetPath = templateInfo.assetsPath;
          final fileName = templateInfo.fileName;
          final signFields = templateInfo.signFields;

          return {
            'id': id,
            'signCode': signCode,
            'name': fileName,
            'assetPath': assetPath,
            'signFields': signFields
          };
        })
        .toList();
  }
}

