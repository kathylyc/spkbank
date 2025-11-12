import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:uuid/uuid.dart';

final _uuid = Uuid();

String generateCustomerUid({
  required String customerName,
  required DateTime createTime,
}) {
  return _uuid.v4().replaceAll('-', '');
}

// String generateCustomerUid({
//   required String customerName,
//   required DateTime createTime,
// }) {
//   final buffer = StringBuffer()
//     ..write(customerName.trim())
//     ..write(createTime.toIso8601String());
//   final digest = md5.convert(utf8.encode(buffer.toString()));
//   return digest.toString();
// }
