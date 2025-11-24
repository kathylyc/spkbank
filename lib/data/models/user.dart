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
    required this.groupCode,
    this.loginDate,
    this.pwdUpdateDate,
    this.isFirstLogin,
    this.loginFailCount,
    this.lockUntil,
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
  final String groupCode;
  final DateTime? loginDate;
  final DateTime? pwdUpdateDate;
  final bool? isFirstLogin;
  final int? loginFailCount;
  final DateTime? lockUntil;
  final String? createBy;
  final DateTime? createTime;
  final String? updateBy;
  final DateTime? updateTime;

  factory User.fromMap(Map<String, Object?> map) {
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.tryParse(value as String);
    
    // 将 int 值（0 或 1）转换为 bool?
    bool? parseBool(Object? value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is int) return value != 0;
      return null;
    }

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
      groupCode: map['group_code'] as String? ?? '',
      loginDate: parseDate(map['login_date']),
      pwdUpdateDate: parseDate(map['pwd_update_date']),
      isFirstLogin: parseBool(map['is_first_login']),
      loginFailCount: map['login_fail_count'] as int?,
      lockUntil: parseDate(map['lock_until']),
      createBy: map['create_by'] as String?,
      createTime: parseDate(map['create_time']),
      updateBy: map['update_by'] as String?,
      updateTime: parseDate(map['update_time']),
    );
  }

  Map<String, Object?> toMap() {
    String? formatDate(DateTime? value) => value?.toIso8601String();
    // 将 bool? 转换为 int（0 或 1）
    int? formatBool(bool? value) => value == null ? null : (value ? 1 : 0);

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
      'group_code': groupCode,
      'login_date': formatDate(loginDate),
      'pwd_update_date': formatDate(pwdUpdateDate),
      'is_first_login': formatBool(isFirstLogin),
      'login_fail_count': loginFailCount,
      'lock_until': formatDate(lockUntil),
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
    String? groupCode,
    DateTime? loginDate,
    DateTime? pwdUpdateDate,
    bool? isFirstLogin,
    int? loginFailCount,
    DateTime? lockUntil,
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
      groupCode: groupCode ?? this.groupCode,
      loginDate: loginDate ?? this.loginDate,
      pwdUpdateDate: pwdUpdateDate ?? this.pwdUpdateDate,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      loginFailCount: loginFailCount ?? this.loginFailCount,
      lockUntil: lockUntil ?? this.lockUntil,
      createBy: createBy ?? this.createBy,
      createTime: createTime ?? this.createTime,
      updateBy: updateBy ?? this.updateBy,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}

