import 'package:sqflite/sqflite.dart';

import '../../models/pdf_template_info.dart';
import '../database_manager.dart';

/// PDF模板信息数据访问对象
class PdfTemplateInfoDao {
  final DatabaseManager _databaseManager;

  const PdfTemplateInfoDao(this._databaseManager);

  /// 获取所有PDF模板信息
  Future<List<PdfTemplateInfo>> findAll() async {
    final db = await _databaseManager.database;
    final List<Map<String, dynamic>> maps = await db.query('t_pdf_template_info');
    return maps.map((map) => PdfTemplateInfo.fromMap(map)).toList();
  }

  /// 根据signCode查找PDF模板信息
  Future<PdfTemplateInfo?> findBySignCode(String signCode) async {
    final db = await _databaseManager.database;
    final List<Map<String, dynamic>> maps = await db.query(
      't_pdf_template_info',
      where: 'sign_code = ?',
      whereArgs: [signCode],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }
    return PdfTemplateInfo.fromMap(maps.first);
  }

  /// 根据ID查找PDF模板信息
  Future<PdfTemplateInfo?> findById(int id) async {
    final db = await _databaseManager.database;
    final List<Map<String, dynamic>> maps = await db.query(
      't_pdf_template_info',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }
    return PdfTemplateInfo.fromMap(maps.first);
  }

  /// 插入新的PDF模板信息
  Future<int> insert(PdfTemplateInfo templateInfo) async {
    final db = await _databaseManager.database;
    return await db.insert('t_pdf_template_info', templateInfo.toMap());
  }

  /// 插入或更新PDF模板信息（基于signCode）
  Future<int> insertOrUpdate(PdfTemplateInfo templateInfo) async {
    final db = await _databaseManager.database;

    // 首先尝试查找是否存在相同signCode的记录
    final existing = await findBySignCode(templateInfo.signCode);

    if (existing != null) {
      // 如果存在，更新记录
      return await db.update(
        't_pdf_template_info',
        templateInfo.toMap(),
        where: 'sign_code = ?',
        whereArgs: [templateInfo.signCode],
      );
    } else {
      // 如果不存在，插入新记录
      return await db.insert('t_pdf_template_info', templateInfo.toMap());
    }
  }

  /// 更新PDF模板信息
  Future<int> update(PdfTemplateInfo templateInfo) async {
    final db = await _databaseManager.database;
    if (templateInfo.id == null) {
      throw ArgumentError('Cannot update PdfTemplateInfo without id');
    }

    return await db.update(
      't_pdf_template_info',
      templateInfo.toMap(),
      where: 'id = ?',
      whereArgs: [templateInfo.id],
    );
  }

  /// 删除PDF模板信息
  Future<int> delete(int id) async {
    final db = await _databaseManager.database;
    return await db.delete(
      't_pdf_template_info',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据signCode删除PDF模板信息
  Future<int> deleteBySignCode(String signCode) async {
    final db = await _databaseManager.database;
    return await db.delete(
      't_pdf_template_info',
      where: 'sign_code = ?',
      whereArgs: [signCode],
    );
  }

  /// 增加使用次数
  Future<int> incrementUsageCount(String signCode) async {
    final db = await _databaseManager.database;
    return await db.rawUpdate(
      'UPDATE t_pdf_template_info SET usage_count = usage_count + 1 WHERE sign_code = ?',
      [signCode],
    );
  }

  /// 获取总使用次数
  Future<int> getTotalUsageCount() async {
    final db = await _databaseManager.database;
    final result = await db.rawQuery(
      'SELECT SUM(usage_count) as total FROM t_pdf_template_info',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取按使用次数排序的模板列表
  Future<List<PdfTemplateInfo>> findAllOrderByUsageCount({bool descending = true}) async {
    final db = await _databaseManager.database;
    final List<Map<String, dynamic>> maps = await db.query(
      't_pdf_template_info',
      orderBy: 'usage_count ${descending ? 'DESC' : 'ASC'}',
    );
    return maps.map((map) => PdfTemplateInfo.fromMap(map)).toList();
  }

  /// 根据备注搜索模板
  Future<List<PdfTemplateInfo>> findByRemark(String keyword) async {
    final db = await _databaseManager.database;
    final List<Map<String, dynamic>> maps = await db.query(
      't_pdf_template_info',
      where: 'remark LIKE ?',
      whereArgs: ['%$keyword%'],
    );
    return maps.map((map) => PdfTemplateInfo.fromMap(map)).toList();
  }

  /// 清空所有数据
  Future<int> clearAll() async {
    final db = await _databaseManager.database;
    return await db.delete('t_pdf_template_info');
  }

  /// 获取记录总数
  Future<int> getCount() async {
    final db = await _databaseManager.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM t_pdf_template_info');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}