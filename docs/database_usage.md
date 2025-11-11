# SQLite 封装使用说明

> 该文档对应 `lib/data/db` 目录下的 SQLite 封装实现，包含数据库初始化、迁移和常用数据访问方法。

## 1. 初始化

```dart
import 'package:bank_flutter/data/db/db_provider.dart';

Future<void> bootstrap() async {
  // 可在应用启动（如 main 函数中）提前触发数据库初始化
  await DbProvider.instance.userDao.findAll(limit: 1);
}
```

`DbProvider` 内部统一持有 `DatabaseManager` 实例，保证全局单例。

## 2. 常用操作

### 用户

```dart
import 'package:bank_flutter/data/models/user.dart';
import 'package:bank_flutter/data/repositories/user_repository.dart';

final userRepo = UserRepository();

Future<User> createAdmin() async {
  return userRepo.upsert(
    const User(
      userName: 'new-admin',
      nickName: '系统管理员',
      userType: '00',
      password: 'hashed-password',
    ),
  );
}
```

### 客户及附件

```dart
import 'package:bank_flutter/data/repositories/customer_repository.dart';
import 'package:bank_flutter/data/models/customer_attachment_file.dart';

final customerRepo = CustomerRepository();

Future<void> createCustomerWithAttachment() async {
  final customer = await customerRepo.create(
    customerName: '张三',
    countryCode: '86',
    managerAccount: 'manager001',
  );

  await customerRepo.addAttachmentFile(
    CustomerAttachmentFile(
      customerUid: customer.customerUid,
      attachmentType: '身份证',
      filePath: '/path/to/idcard.png',
      createBy: 'manager001',
      createTime: DateTime.now(),
    ),
  );
}
```

## 3. 表结构演进与迁移

- 所有迁移文件位于 `lib/data/db/migrations`。
- 新增字段/表时，新增一个 `MigrationV{n}` 并更新 `DatabaseManager._migrations` 列表。
- `MigrationStep` 中可同时包含 DDL 与初始化数据，推荐使用 `Batch` 保证事务性。

```dart
class MigrationV2 implements MigrationStep {
  @override
  int get version => 2;

  @override
  Future<void> up(Database db) async {
    await runBatch(db, [
      'ALTER TABLE t_user ADD COLUMN last_login_ip TEXT',
      'CREATE INDEX IF NOT EXISTS idx_user_type ON t_user(user_type)',
    ]);
  }
}
```

将新迁移追加到 `DatabaseManager`：

```dart
final List<MigrationStep> _migrations = [
  MigrationV1(),
  MigrationV2(), // 新增
];
```

## 4. 约定与最佳实践

- 所有时间字段统一使用 ISO 8601 字符串存储，模型层负责转换。
- 默认开启外键约束（`PRAGMA foreign_keys = ON`），确保引用完整性。
- 数据访问只通过 DAO/Repository，禁止业务层直接持有 `Database` 实例，以便集中维护事务与迁移。
- 客户唯一标识 `customer_uid` 使用 `md5(姓名 + createTime)`，相关方法封装在 `lib/data/utils/customer_uid_generator.dart`。
- 若需要事务，可直接操作底层 `Database`：

```dart
final db = await DatabaseManager.instance.database;
await db.transaction((txn) async {
  await txn.update(...);
});
```

> 更多问题可在 `lib/data/db` 下补充测试或扩展 DAO。

