import 'package:flutter/foundation.dart';

@immutable
class Customer {
  const Customer({
    this.id,
    required this.customerUid,
    required this.customerName,
    this.customerTag,
    required this.countryCode,
    this.phone,
    this.address,
    required this.company,
    required this.managerAccount,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
  });

  static const String tableName = 't_customer';

  final int? id;
  final String customerUid;
  final String customerName;
  final String? customerTag;
  final String countryCode;
  final String? phone;
  final String? address;
  final String company;
  final String managerAccount;
  final String? createBy;
  final DateTime? createTime;
  final String? updateBy;
  final DateTime? updateTime;

  factory Customer.fromMap(Map<String, Object?> map) {
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.tryParse(value as String);

    return Customer(
      id: map['id'] as int?,
      customerUid: map['customer_uid'] as String,
      customerName: map['customer_name'] as String,
      customerTag: map['customer_tag'] as String?,
      countryCode: map['country_code'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      company: map['company'] as String? ?? '',
      managerAccount: map['manager_account'] as String,
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
      'customer_name': customerName,
      'customer_tag': customerTag,
      'country_code': countryCode,
      'phone': phone,
      'address': address,
      'company': company,
      'manager_account': managerAccount,
      'create_by': createBy,
      'create_time': formatDate(createTime),
      'update_by': updateBy,
      'update_time': formatDate(updateTime),
    };
  }

  Customer copyWith({
    int? id,
    String? customerUid,
    String? customerName,
    String? customerTag,
    String? countryCode,
    String? phone,
    String? address,
    String? company,
    String? managerAccount,
    String? createBy,
    DateTime? createTime,
    String? updateBy,
    DateTime? updateTime,
  }) {
    return Customer(
      id: id ?? this.id,
      customerUid: customerUid ?? this.customerUid,
      customerName: customerName ?? this.customerName,
      customerTag: customerTag ?? this.customerTag,
      countryCode: countryCode ?? this.countryCode,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      company: company ?? this.company,
      managerAccount: managerAccount ?? this.managerAccount,
      createBy: createBy ?? this.createBy,
      createTime: createTime ?? this.createTime,
      updateBy: updateBy ?? this.updateBy,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}

