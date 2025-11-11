import 'package:flutter/foundation.dart';

@immutable
class CustomerAttachmentFile {
  const CustomerAttachmentFile({
    this.id,
    required this.customerUid,
    required this.attachmentType,
    required this.filePath,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
  });

  static const String tableName = 't_customer_attachment_file';

  final int? id;
  final String customerUid;
  final String attachmentType;
  final String filePath;
  final String? createBy;
  final DateTime? createTime;
  final String? updateBy;
  final DateTime? updateTime;

  factory CustomerAttachmentFile.fromMap(Map<String, Object?> map) {
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.tryParse(value as String);

    return CustomerAttachmentFile(
      id: map['id'] as int?,
      customerUid: map['customer_uid'] as String,
      attachmentType: map['attachment_type'] as String,
      filePath: map['file_path'] as String,
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
      'customer_uid': customerUid,
      'attachment_type': attachmentType,
      'file_path': filePath,
      'create_by': createBy,
      'create_time': formatDate(createTime),
      'update_by': updateBy,
      'update_time': formatDate(updateTime),
    };
  }

  CustomerAttachmentFile copyWith({
    int? id,
    String? customerUid,
    String? attachmentType,
    String? filePath,
    String? createBy,
    DateTime? createTime,
    String? updateBy,
    DateTime? updateTime,
  }) {
    return CustomerAttachmentFile(
      id: id ?? this.id,
      customerUid: customerUid ?? this.customerUid,
      attachmentType: attachmentType ?? this.attachmentType,
      filePath: filePath ?? this.filePath,
      createBy: createBy ?? this.createBy,
      createTime: createTime ?? this.createTime,
      updateBy: updateBy ?? this.updateBy,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}

