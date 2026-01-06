import 'package:sqflite/sqflite.dart';

import 'dao/customer_account_file_dao.dart';
import 'dao/customer_attachment_file_dao.dart';
import 'dao/customer_dao.dart';
import 'dao/user_dao.dart';
import 'database_manager.dart';

/// 应用内部访问数据库资源的统一入口。
/// 避免在业务层直接和 [DatabaseManager] 打交道。
class DbProvider {
  DbProvider._(this._manager);

  static final DbProvider instance = DbProvider._(DatabaseManager.instance);

  final DatabaseManager _manager;

  /// 获取数据库实例（用于事务操作）
  Future<Database> get database async => await _manager.database;

  late final UserDao userDao = UserDao(_manager);
  late final CustomerDao customerDao = CustomerDao(_manager);
  late final CustomerAccountFileDao customerAccountFileDao =
      CustomerAccountFileDao(_manager);
  late final CustomerAttachmentFileDao customerAttachmentFileDao =
      CustomerAttachmentFileDao(_manager);
}

