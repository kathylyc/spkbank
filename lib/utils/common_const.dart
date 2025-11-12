/// 客户标签常量映射
class ConstCustomerTag  {
  static const keyCustomer = "1";// 大客户
  static const publicOfficials = "2";// 公职人员
  static const highQualityCredit = "3";// 优质征信
}

class ConstSex  {
  static const man = 0;// 男
  static const woman = 1;// 女
}

class ConstSignatureStatus  {
  static const signed = 1;// 已签署
  static const notSigned = 2;// 未签署
}

class PdfTemplateInfo {
  const PdfTemplateInfo({
    required this.signCode,
    required this.assetsPath,
  });

  final String signCode;
  final String assetsPath;
}

/// PDF 模板常量列表
const List<PdfTemplateInfo> ConstPdfTemplate = [
  PdfTemplateInfo(
    signCode: '1111111111111111',
    assetsPath: 'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf',
  ),
];