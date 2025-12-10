import 'package:path/path.dart' as p;

class ConstZip {
  static const pcPwd = "MVJNGVvEXKp7NVy3";// PC端导出的默认密码
}

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
    required this.signFields,
  });

  final String signCode;
  final String assetsPath;
  final List<String>? signFields;

  String get fileName {
    if (assetsPath.isEmpty) {
      return '';
    }
    return p.basenameWithoutExtension(assetsPath);
  }
}

/// PDF 模板常量列表
const Map<String, PdfTemplateInfo> ConstPdfTemplateMap = {
  "1": PdfTemplateInfo(
      signCode: '265xxaq545a2xq6x',
      assetsPath: 'assets/pdf/Account Mandate for BusinessAccount_201908.pdf',
      signFields: ['Signature1', 'Signature2'],
  ),
  "2": PdfTemplateInfo(
      signCode: 'x8q8a3d9dz771ds6',
      assetsPath: 'assets/pdf/Appendix A - SPDB Financial Institution Due Diligence Questionnaire_202406.pdf',
      signFields: [],
  ),
  "3": PdfTemplateInfo(
      signCode: 'fd50f3s9a15wagf3',
      assetsPath: 'assets/pdf/Appendix M (10) CustomerDeclaration and Undertaking in respect of Tax Evasion.pdf',
      signFields: ['Signature1', 'Signature2'],
  ),
  "4": PdfTemplateInfo(
      signCode: 'ds26dsvxv52a22cs',
      assetsPath: 'assets/pdf/Appendix 2a - Individual or CPSelf Certification Form 202506 (clean).pdf',
      signFields: ['Signature01', 'Signature02'],
  ),
  "5": PdfTemplateInfo(
      signCode: 'zcx26adsv220x3d2',
      assetsPath: 'assets/pdf/Appendix 2b - Entity SelfCertification Form_version202506 (clean).pdf',
      signFields: ['Signature1', 'Signature2', 'Signature3', 'Signature4', 'Signature5', 'Signature6'],
  ),
  "6": PdfTemplateInfo(
      signCode: 'vh821fdns93xdf23',
      assetsPath: 'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf',
      signFields: [
        'Signature1', 'Signature2', 'Signature3', 'Signature4', 'Signature5',
        'Signature6', 'Signature7', 'Signature8', 'Signature9', 'Signature10',
        'Signature11', 'Signature12', 'Signature',
      ],
  ),
  "7": PdfTemplateInfo(
      signCode: 'af71b136e5sf66sd',
      assetsPath: 'assets/pdf/Letter of Declaration [Client]2019_July.pdf',
      signFields: ['Signature'],
  ),
  "8": PdfTemplateInfo(
      signCode: 'n6a9g46q9g4gfqr3',
      assetsPath: 'assets/pdf/Telephone & Fax Instructions andIndemnity_(For Business Account)_201908.pdf',
      signFields: ['Signature'],
  ),
};





