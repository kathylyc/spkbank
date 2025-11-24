import '../models/pdf_template_info.dart';
import '../db/dao/pdf_template_info_dao.dart';
import '../db/database_manager.dart';

/// PDF模板信息仓库
class PdfTemplateInfoRepository {
  final PdfTemplateInfoDao _dao;

  PdfTemplateInfoRepository() : _dao = PdfTemplateInfoDao(DatabaseManager.instance);

  /// 获取所有PDF模板信息
  Future<List<PdfTemplateInfo>> findAll() async {
    try {
      return await _dao.findAll();
    } catch (e) {
      throw Exception('Failed to fetch PDF template info: $e');
    }
  }

  /// 根据signCode查找PDF模板信息
  Future<PdfTemplateInfo?> findBySignCode(String signCode) async {
    try {
      return await _dao.findBySignCode(signCode);
    } catch (e) {
      throw Exception('Failed to find PDF template info by sign code: $e');
    }
  }

  /// 根据ID查找PDF模板信息
  Future<PdfTemplateInfo?> findById(int id) async {
    try {
      return await _dao.findById(id);
    } catch (e) {
      throw Exception('Failed to find PDF template info by ID: $e');
    }
  }

  /// 保存PDF模板信息（插入或更新）
  Future<int> save(PdfTemplateInfo templateInfo) async {
    try {
      return await _dao.insertOrUpdate(templateInfo);
    } catch (e) {
      throw Exception('Failed to save PDF template info: $e');
    }
  }

  /// 插入新的PDF模板信息
  Future<int> insert(PdfTemplateInfo templateInfo) async {
    try {
      return await _dao.insert(templateInfo);
    } catch (e) {
      throw Exception('Failed to insert PDF template info: $e');
    }
  }

  /// 更新PDF模板信息
  Future<int> update(PdfTemplateInfo templateInfo) async {
    try {
      return await _dao.update(templateInfo);
    } catch (e) {
      throw Exception('Failed to update PDF template info: $e');
    }
  }

  /// 删除PDF模板信息
  Future<int> delete(int id) async {
    try {
      return await _dao.delete(id);
    } catch (e) {
      throw Exception('Failed to delete PDF template info: $e');
    }
  }

  /// 根据signCode删除PDF模板信息
  Future<int> deleteBySignCode(String signCode) async {
    try {
      return await _dao.deleteBySignCode(signCode);
    } catch (e) {
      throw Exception('Failed to delete PDF template info by sign code: $e');
    }
  }

  /// 增加使用次数
  Future<int> incrementUsageCount(String signCode) async {
    try {
      return await _dao.incrementUsageCount(signCode);
    } catch (e) {
      throw Exception('Failed to increment usage count: $e');
    }
  }

  /// 获取总使用次数
  Future<int> getTotalUsageCount() async {
    try {
      return await _dao.getTotalUsageCount();
    } catch (e) {
      throw Exception('Failed to get total usage count: $e');
    }
  }

  /// 获取按使用次数排序的模板列表
  Future<List<PdfTemplateInfo>> findAllOrderByUsageCount({bool descending = true}) async {
    try {
      return await _dao.findAllOrderByUsageCount(descending: descending);
    } catch (e) {
      throw Exception('Failed to get PDF template info ordered by usage count: $e');
    }
  }

  /// 根据备注搜索模板
  Future<List<PdfTemplateInfo>> findByRemark(String keyword) async {
    try {
      return await _dao.findByRemark(keyword);
    } catch (e) {
      throw Exception('Failed to search PDF template info by remark: $e');
    }
  }

  /// 批量保存模板信息
  Future<List<int>> saveAll(List<PdfTemplateInfo> templateInfos) async {
    try {
      final results = <int>[];
      for (final templateInfo in templateInfos) {
        final result = await save(templateInfo);
        results.add(result);
      }
      return results;
    } catch (e) {
      throw Exception('Failed to save PDF template info batch: $e');
    }
  }

  /// 清空所有数据
  Future<int> clearAll() async {
    try {
      return await _dao.clearAll();
    } catch (e) {
      throw Exception('Failed to clear all PDF template info: $e');
    }
  }

  /// 获取记录总数
  Future<int> getCount() async {
    try {
      return await _dao.getCount();
    } catch (e) {
      throw Exception('Failed to get PDF template info count: $e');
    }
  }

  /// 验证signCode是否已存在
  Future<bool> existsBySignCode(String signCode) async {
    try {
      final templateInfo = await findBySignCode(signCode);
      return templateInfo != null;
    } catch (e) {
      throw Exception('Failed to check if PDF template info exists by sign code: $e');
    }
  }

  /// 初始化模板数据（从常量创建）
  Future<void> initializeFromConstants() async {
    try {
      // 这个方法可以用来初始化数据，但实际的数据插入已经在migration中完成
      // 这里提供一个接口，以防需要手动重新初始化
    } catch (e) {
      throw Exception('Failed to initialize PDF template info from constants: $e');
    }
  }
}