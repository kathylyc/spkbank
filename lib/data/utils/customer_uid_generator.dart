import 'dart:convert';

import 'package:crypto/crypto.dart';

String generateCustomerUid({
  required String customerName,
  required DateTime createTime,
}) {
  final buffer = StringBuffer()
    ..write(customerName.trim())
    ..write(createTime.toIso8601String());
  final digest = md5.convert(utf8.encode(buffer.toString()));
  return digest.toString();
}

