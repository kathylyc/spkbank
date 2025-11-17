import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../db/db_provider.dart';
import '../models/customer.dart';
import '../models/customer_account_file.dart';
import '../models/customer_attachment_file.dart';
import '../utils/customer_uid_generator.dart';

class ManagerCustomerStats {
  const ManagerCustomerStats({
    required this.managerAccount,
    required this.customerCount,
    this.latestEntryTime,
  });

  final String managerAccount;
  final int customerCount;
  final DateTime? latestEntryTime;
}

class CustomerRepository {
  CustomerRepository({DbProvider? provider}) : _provider = provider ?? DbProvider.instance;

  final DbProvider _provider;

  Future<Customer> create({
    String? customerUid,
    required String customerName,
    required String countryCode,
    required String managerAccount,
    String? phone,
    String? address,
    String? customerTag,
    String? createBy,
    DateTime? createTime,
  }) async {
    final now = createTime ?? DateTime.now();
    final customer = Customer(
      customerUid: customerUid ?? generateCustomerUid(customerName: customerName, createTime: now),
      customerName: customerName,
      customerTag: customerTag,
      countryCode: countryCode,
      phone: phone,
      address: address,
      managerAccount: managerAccount,
      createBy: createBy,
      createTime: now,
    );
    debugPrint('customer_repository.create()==>customerUid=$customerUid, genCustomerUid=${customer
        .customerUid}');
    final id = await _provider.customerDao.insert(customer, conflictAlgorithm: ConflictAlgorithm.abort);
    return customer.copyWith(id: id);
  }

  Future<Customer> upsert(Customer customer, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    if (customer.id == null) {
      final id = await _provider.customerDao.insert(customer, conflictAlgorithm: conflictAlgorithm);
      return customer.copyWith(id: id);
    } else {
      await _provider.customerDao.update(customer);
      return customer;
    }
  }

  Future<Customer?> findByUid(String customerUid) => _provider.customerDao.findByUid(customerUid);

  Future<List<Customer>> findByManager(String managerAccount) => _provider.customerDao.findByManager(managerAccount);

  Future<List<Customer>> searchByName(String keyword) => _provider.customerDao.searchByName(keyword);

  Future<int> deleteByUid(String customerUid) => _provider.customerDao.deleteByUid(customerUid);

  Future<List<Customer>> search({
    int? limit,
    int? offset,
    String? nameKeyword,
    String? phoneKeyword,
    String? managerAccount,
    String? tag,
  }) =>
      _provider.customerDao.search(
        limit: limit,
        offset: offset,
        nameKeyword: nameKeyword,
        phoneKeyword: phoneKeyword,
        managerAccount: managerAccount,
        tag: tag,
      );

  Future<int> count({
    String? nameKeyword,
    String? phoneKeyword,
    String? managerAccount,
    String? tag,
  }) =>
      _provider.customerDao.count(
        nameKeyword: nameKeyword,
        phoneKeyword: phoneKeyword,
        managerAccount: managerAccount,
        tag: tag,
      );

  Future<CustomerAccountFile> addAccountFile(CustomerAccountFile entity,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final id = await _provider.customerAccountFileDao.insert(entity, conflictAlgorithm: conflictAlgorithm);
    return entity.copyWith(id: id);
  }

  Future<List<CustomerAccountFile>> findAccountFiles(String customerUid) =>
      _provider.customerAccountFileDao.findByCustomerUid(customerUid);

  /// 根据客户UID和模板名称查找最新的账户文件
  Future<CustomerAccountFile?> findLatestByCustomerUidAndTemplate(
    String customerUid,
    String templateName,
  ) =>
      _provider.customerAccountFileDao.findLatestByCustomerUidAndTemplate(
        customerUid,
        templateName,
      );

  /// 根据账户文件UID查找所有记录
  Future<List<CustomerAccountFile>> findAccountFilesByAccountFileUid(String accountFileUid) =>
      _provider.customerAccountFileDao.findByAccountFileUid(accountFileUid);

  /// 根据账户文件UID查找最大版本号
  Future<String?> findMaxVersionByAccountFileUid(String accountFileUid) =>
      _provider.customerAccountFileDao.findMaxVersionByAccountFileUid(accountFileUid);

  Future<int> deleteByAccountFileUidAndVersion(String accountFileUid, String fileVersion) => _provider.customerAccountFileDao.deleteByAccountFileUidAndVersion(accountFileUid, fileVersion);

  /// 查询开户文件列表，关联客户信息和客户经理信息
  Future<List<Map<String, Object?>>> findAccountFilesWithDetails({
    int? limit,
    int? offset,
    String? customerNameKeyword,
    String? phoneKeyword,
    String? fileNameKeyword,
    String? managerAccount,
  }) =>
      _provider.customerAccountFileDao.findWithCustomerAndManager(
        limit: limit,
        offset: offset,
        customerNameKeyword: customerNameKeyword,
        phoneKeyword: phoneKeyword,
        fileNameKeyword: fileNameKeyword,
        managerAccount: managerAccount,
      );

  /// 统计开户文件总数（带查询条件）
  Future<int> countAccountFiles({
    String? customerNameKeyword,
    String? phoneKeyword,
    String? fileNameKeyword,
    String? managerAccount,
  }) =>
      _provider.customerAccountFileDao.countWithCustomerAndManager(
        customerNameKeyword: customerNameKeyword,
        phoneKeyword: phoneKeyword,
        fileNameKeyword: fileNameKeyword,
        managerAccount: managerAccount,
      );

  Future<CustomerAttachmentFile> addAttachmentFile(CustomerAttachmentFile entity,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final id = await _provider.customerAttachmentFileDao.insert(entity, conflictAlgorithm: conflictAlgorithm);
    return entity.copyWith(id: id);
  }

  Future<int> updateAttachmentFile(CustomerAttachmentFile entity) async {
    return await _provider.customerAttachmentFileDao.update(entity);
  }

  Future<List<CustomerAttachmentFile>> findAttachmentFiles(String customerUid) =>
      _provider.customerAttachmentFileDao.findByCustomerUid(customerUid);

  Future<List<CustomerAttachmentFile>> findAttachmentFilesByType(String customerUid, String type) =>
      _provider.customerAttachmentFileDao.findByType(customerUid, type);

  Future<int> deleteAttachmentFile(int id) => _provider.customerAttachmentFileDao.deleteById(id);

  Future<List<Customer>> findAll({int? limit, int? offset}) =>
      _provider.customerDao.findAll(limit: limit, offset: offset);

  Future<List<ManagerCustomerStats>> findManagerStats(List<String> managerAccounts) async {
    final rows = await _provider.customerDao.managerStats(managerAccounts);
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.tryParse(value as String);

    return rows.map((row) {
      return ManagerCustomerStats(
        managerAccount: row['managerAccount'] as String,
        customerCount: ((row['customerCount'] as num?) ?? 0).toInt(),
        latestEntryTime: parseDate(row['latestEntryTime']),
      );
    }).toList();
  }

  /// 统计不同模板数量
  Future<int> countDistinctTemplates({String? managerAccount}) =>
      _provider.customerAccountFileDao.countDistinctTemplates(managerAccount: managerAccount);

  /// 统计已签署文档数量
  Future<int> countSignedDocuments({String? managerAccount}) =>
      _provider.customerAccountFileDao.countSignedDocuments(managerAccount: managerAccount);

  /// 统计待签署文档数量
  Future<int> countPendingDocuments({String? managerAccount}) =>
      _provider.customerAccountFileDao.countPendingDocuments(managerAccount: managerAccount);

  /// 按客户统计账户文件数量（用于饼图）
  Future<List<Map<String, Object?>>> countFilesByCustomer({
    int limit = 10,
    String? managerAccount,
  }) =>
      _provider.customerAccountFileDao.countFilesByCustomer(
        limit: limit,
        managerAccount: managerAccount,
      );

  /// 每月新客户和新账户文件统计（用于柱状图）
  Future<List<Map<String, Object?>>> getMonthlyStats({
    int months = 5,
    String? managerAccount,
  }) =>
      _provider.customerAccountFileDao.getMonthlyStats(
        months: months,
        managerAccount: managerAccount,
      );
}

