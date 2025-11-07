import 'package:json_annotation/json_annotation.dart';

// 告诉代码生成器为这个文件生成序列化代码
part 'notice_info.g.dart';

/// 通知信息模型
@JsonSerializable()
class NoticeInfo {
  final String id;
  final String title;
  final String content;
  final DateTime? createTime;

  const NoticeInfo({
    required this.id,
    required this.title,
    required this.content,
    this.createTime,
  });

  /// 从 JSON 反序列化（由代码生成器自动实现）
  factory NoticeInfo.fromJson(Map<String, dynamic> json) => _$NoticeInfoFromJson(json);

  /// 转换为 JSON（由代码生成器自动实现）
  Map<String, dynamic> toJson() => _$NoticeInfoToJson(this);
}

