import 'package:flutter/foundation.dart';

@immutable
class CustomerAccountFile {
  const CustomerAccountFile({
    this.id,
    required this.accountFileUid,
    required this.customerUid,
    required this.accountFileName,
    this.fileVersion,
    required this.filePath,
    this.signStatus,
    this.enableStatus,
    this.fileSrcType,
    this.templateName,
    this.templateSignCode,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
  });

  static const String tableName = 't_customer_account_file';

  final int? id;
  final String accountFileUid;
  final String customerUid;
  final String accountFileName;
  final int? fileVersion;
  final String filePath;
  final int? signStatus;
  final int? enableStatus;
  final String? fileSrcType;
  final String? templateName;
  final String? templateSignCode;
  final String? createBy;
  final DateTime? createTime;
  final String? updateBy;
  final DateTime? updateTime;

  factory CustomerAccountFile.fromMap(Map<String, Object?> map) {
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.tryParse(value as String);

    // 处理 signStatus
    int? parseSignStatus(Object? value) {
      if (value == null) return null;
      if (value is int) return value;
      return null;
    }

    // 处理 enableStatus：可能是 int 或 null
    int? parseEnableStatus(Object? value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return CustomerAccountFile(
      id: map['id'] as int?,
      accountFileUid: map['account_file_uid'] as String,
      customerUid: map['customer_uid'] as String,
      accountFileName: map['account_file_name'] as String,
      fileVersion: map['file_version'] as int?,
      filePath: map['file_path'] as String,
      signStatus: parseSignStatus(map['sign_status']),
      enableStatus: parseEnableStatus(map['enable_status']),
      fileSrcType: map['file_src_type'] as String?,
      templateName: map['template_name'] as String?,
      templateSignCode: map['template_sign_code'] as String?,
      createBy: map['create_by'] as String?,
      createTime: parseDate(map['create_time']),
      updateBy: map['update_by'] as String?,
      updateTime: parseDate(map['update_time']),
    );
  }

  Map<String, Object?> toMap() {
    String? formatDate(DateTime? value) => value?.toIso8601String();

    return {
      'id': id,
      'account_file_uid': accountFileUid,
      'customer_uid': customerUid,
      'account_file_name': accountFileName,
      'file_version': fileVersion,
      'file_path': filePath,
      'sign_status': signStatus,
      'enable_status': enableStatus,
      'file_src_type': fileSrcType,
      'template_name': templateName,
      'template_sign_code': templateSignCode,
      'create_by': createBy,
      'create_time': formatDate(createTime),
      'update_by': updateBy,
      'update_time': formatDate(updateTime),
    };
  }

  CustomerAccountFile copyWith({
    int? id,
    String? accountFileUid,
    String? customerUid,
    String? accountFileName,
    int? fileVersion,
    String? filePath,
    int? signStatus,
    int? enableStatus,
    String? fileSrcType,
    String? templateName,
    String? templateSignCode,
    String? createBy,
    DateTime? createTime,
    String? updateBy,
    DateTime? updateTime,
  }) {
    return CustomerAccountFile(
      id: id ?? this.id,
      accountFileUid: accountFileUid ?? this.accountFileUid,
      customerUid: customerUid ?? this.customerUid,
      accountFileName: accountFileName ?? this.accountFileName,
      fileVersion: fileVersion ?? this.fileVersion,
      filePath: filePath ?? this.filePath,
      signStatus: signStatus ?? this.signStatus,
      enableStatus: enableStatus ?? this.enableStatus,
      fileSrcType: fileSrcType ?? this.fileSrcType,
      templateName: templateName ?? this.templateName,
      templateSignCode: templateSignCode ?? this.templateSignCode,
      createBy: createBy ?? this.createBy,
      createTime: createTime ?? this.createTime,
      updateBy: updateBy ?? this.updateBy,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}

