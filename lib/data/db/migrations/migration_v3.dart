import 'package:bank_flutter/utils/pdf_template_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import 'migration.dart';
import '../../../utils/common_const.dart';

class MigrationV3 implements MigrationStep {
  @override
  int get version => 3;

  @override
  Future<void> up(Database db) async {
    // 创建 t_pdf_template_info 表
    await db.execute('''
      CREATE TABLE t_pdf_template_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sign_code TEXT NOT NULL,
        usage_count INTEGER DEFAULT 0,
        remark TEXT,
        UNIQUE(sign_code)
      )
    ''');

    // 插入 ConstPdfTemplateMap 中的数据
    final Map<String, PdfTemplateInfo> pdfTemplateMap = PdfTemplateUtils.getPdfTemplateMap();
    for (final entry in pdfTemplateMap.entries) {
      final templateInfo = entry.value;
      final signCode = templateInfo.signCode;

      await db.insert(
        't_pdf_template_info',
        {
          'sign_code': signCode,
          'usage_count': 0,
          'remark': '',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore, // 忽略重复的sign_code
      );
    }

    debugPrint('MigrationV3().up()==> Created t_pdf_template_info table and inserted ${pdfTemplateMap.length} records');
  }

  @override
  Future<void> down(Database db) async {
    await db.execute('DROP TABLE IF EXISTS t_pdf_template_info');
    debugPrint('MigrationV3().down()==> Dropped t_pdf_template_info table');
  }
}