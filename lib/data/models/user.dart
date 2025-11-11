import 'package:flutter/foundation.dart';

@immutable
class User {
  const User({
    this.id,
    required this.userName,
    required this.nickName,
    required this.userType,
    this.email,
    this.phoneNumber,
    this.sex,
    this.avatar,
    required this.password,
    this.status,
    this.loginDate,
    this.pwdUpdateDate,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
  });

  static const String tableName = 't_user';

  final int? id;
  final String userName;
  final String nickName;
  final String userType;
  final String? email;
  final String? phoneNumber;
  final int? sex;
  final String? avatar;
  final String password;
  final String? status;
  final DateTime? loginDate;
  final DateTime? pwdUpdateDate;
  final String? createBy;
  final DateTime? createTime;
  final String? updateBy;
  final DateTime? updateTime;

  factory User.fromMap(Map<String, Object?> map) {
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.tryParse(value as String);

    return User(
      id: map['id'] as int?,
      userName: map['user_name'] as String,
      nickName: map['nick_name'] as String? ?? '',
      userType: map['user_type'] as String,
      email: map['email'] as String?,
      phoneNumber: map['phonenumber'] as String?,
      sex: map['sex'] as int?,
      avatar: map['avatar'] as String?,
      password: map['password'] as String? ?? '',
      status: map['status'] as String?,
      loginDate: parseDate(map['login_date']),
      pwdUpdateDate: parseDate(map['pwd_update_date']),
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
      'user_name': userName,
      'nick_name': nickName,
      'user_type': userType,
      'email': email,
      'phonenumber': phoneNumber,
      'sex': sex,
      'avatar': avatar,
      'password': password,
      'status': status,
      'login_date': formatDate(loginDate),
      'pwd_update_date': formatDate(pwdUpdateDate),
      'create_by': createBy,
      'create_time': formatDate(createTime),
      'update_by': updateBy,
      'update_time': formatDate(updateTime),
    };
  }

  User copyWith({
    int? id,
    String? userName,
    String? nickName,
    String? userType,
    String? email,
    String? phoneNumber,
    int? sex,
    String? avatar,
    String? password,
    String? status,
    DateTime? loginDate,
    DateTime? pwdUpdateDate,
    String? createBy,
    DateTime? createTime,
    String? updateBy,
    DateTime? updateTime,
  }) {
    return User(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      nickName: nickName ?? this.nickName,
      userType: userType ?? this.userType,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      sex: sex ?? this.sex,
      avatar: avatar ?? this.avatar,
      password: password ?? this.password,
      status: status ?? this.status,
      loginDate: loginDate ?? this.loginDate,
      pwdUpdateDate: pwdUpdateDate ?? this.pwdUpdateDate,
      createBy: createBy ?? this.createBy,
      createTime: createTime ?? this.createTime,
      updateBy: updateBy ?? this.updateBy,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}

