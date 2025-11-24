/// PDF模板信息模型
class PdfTemplateInfo {
  final int? id;
  final String signCode;
  final int usageCount;
  final String? remark;

  PdfTemplateInfo({
    this.id,
    required this.signCode,
    this.usageCount = 0,
    this.remark,
  });

  /// 从数据库Map创建模型实例
  factory PdfTemplateInfo.fromMap(Map<String, dynamic> map) {
    return PdfTemplateInfo(
      id: map['id'] as int?,
      signCode: map['sign_code'] as String,
      usageCount: map['usage_count'] as int? ?? 0,
      remark: map['remark'] as String?,
    );
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sign_code': signCode,
      'usage_count': usageCount,
      'remark': remark,
    };
  }

  /// 创建副本，可用于修改特定字段
  PdfTemplateInfo copyWith({
    int? id,
    String? signCode,
    int? usageCount,
    String? remark,
  }) {
    return PdfTemplateInfo(
      id: id ?? this.id,
      signCode: signCode ?? this.signCode,
      usageCount: usageCount ?? this.usageCount,
      remark: remark ?? this.remark,
    );
  }

  @override
  String toString() {
    return 'PdfTemplateInfo{id: $id, signCode: $signCode, usageCount: $usageCount, remark: $remark}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PdfTemplateInfo &&
      other.id == id &&
      other.signCode == signCode &&
      other.usageCount == usageCount &&
      other.remark == remark;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      signCode.hashCode ^
      usageCount.hashCode ^
      remark.hashCode;
  }
}