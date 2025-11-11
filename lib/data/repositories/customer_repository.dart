import 'package:sqflite/sqflite.dart';

import '../db/db_provider.dart';
import '../models/customer.dart';
import '../models/customer_account_file.dart';
import '../models/customer_attachment_file.dart';
import '../utils/customer_uid_generator.dart';

class CustomerRepository {
  CustomerRepository({DbProvider? provider}) : _provider = provider ?? DbProvider.instance;

  final DbProvider _provider;

  Future<Customer> create({
    required String customerName,
    required String countryCode,
    required String managerAccount,
    String? phone,
    String? address,
    String? createBy,
    DateTime? createTime,
  }) async {
    final now = createTime ?? DateTime.now();
    final customer = Customer(
      customerUid: generateCustomerUid(customerName: customerName, createTime: now),
      customerName: customerName,
      countryCode: countryCode,
      phone: phone,
      address: address,
      managerAccount: managerAccount,
      createBy: createBy,
      createTime: now,
    );
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

  Future<CustomerAccountFile> addAccountFile(CustomerAccountFile entity,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final id = await _provider.customerAccountFileDao.insert(entity, conflictAlgorithm: conflictAlgorithm);
    return entity.copyWith(id: id);
  }

  Future<List<CustomerAccountFile>> findAccountFiles(String customerUid) =>
      _provider.customerAccountFileDao.findByCustomerUid(customerUid);

  Future<int> deleteAccountFile(int id) => _provider.customerAccountFileDao.deleteById(id);

  Future<CustomerAttachmentFile> addAttachmentFile(CustomerAttachmentFile entity,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final id = await _provider.customerAttachmentFileDao.insert(entity, conflictAlgorithm: conflictAlgorithm);
    return entity.copyWith(id: id);
  }

  Future<List<CustomerAttachmentFile>> findAttachmentFiles(String customerUid) =>
      _provider.customerAttachmentFileDao.findByCustomerUid(customerUid);

  Future<List<CustomerAttachmentFile>> findAttachmentFilesByType(String customerUid, String type) =>
      _provider.customerAttachmentFileDao.findByType(customerUid, type);

  Future<int> deleteAttachmentFile(int id) => _provider.customerAttachmentFileDao.deleteById(id);
}

