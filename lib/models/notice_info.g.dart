// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notice_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NoticeInfo _$NoticeInfoFromJson(Map<String, dynamic> json) => NoticeInfo(
  id: json['id'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  createTime: json['createTime'] == null
      ? null
      : DateTime.parse(json['createTime'] as String),
);

Map<String, dynamic> _$NoticeInfoToJson(NoticeInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'createTime': instance.createTime?.toIso8601String(),
    };
