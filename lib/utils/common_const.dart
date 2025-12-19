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

/// PDF表单字段默认值配置
class PdfFormFieldDefault {
  const PdfFormFieldDefault({
    required this.fieldName,
    required this.customerProperty,
    this.defaultValue,
    this.fieldType = 'text',
  });

  /// 表单字段名称
  final String fieldName;

  /// 对应的客户信息属性 (如: 'customerName', 'idCardNumber', 'phoneNumber')
  final String customerProperty;

  /// 静态默认值 (当无法从客户信息获取时使用)
  final String? defaultValue;

  /// 字段类型 ('text', 'combobox', 'checkbox')
  final String fieldType;
}

/// PDF表单字段配置类
class PdfFormConfig {
  const PdfFormConfig({
    this.fieldDefaults,
  });

  /// 字段默认值配置列表
  final List<PdfFormFieldDefault>? fieldDefaults;

  /// 根据字段名获取默认值配置
  PdfFormFieldDefault? getFieldConfig(String fieldName) {
    if (fieldDefaults == null) return null;

    try {
      return fieldDefaults!.firstWhere((config) => config.fieldName == fieldName);
    } catch (e) {
      return null;
    }
  }
}

class PdfTemplateInfo {
  const PdfTemplateInfo({
    required this.signCode,
    required this.assetsPath,
    required this.signFields,
    required this.signChecks,
    this.formConfig,
  });

  final String signCode;
  final String assetsPath;
  final List<String> signFields;
  final List<PdfSignCheckInfo> signChecks;

  /// 表单字段配置
  final PdfFormConfig? formConfig;

  String get fileName {
    if (assetsPath.isEmpty) {
      return '';
    }
    return p.basenameWithoutExtension(assetsPath);
  }
}

class PdfSignCheckInfo {
  const PdfSignCheckInfo({
    required this.chkFiledName,
    required this.signFieldName,
    required this.message,
  });

  final String chkFiledName;
  final String signFieldName;
  final String message;
}

/// PDF 模板常量列表
const Map<String, PdfTemplateInfo> ConstPdfTemplateMap = {
  "1": PdfTemplateInfo(
      signCode: '265xxaq545a2xq6x',
      assetsPath: 'assets/pdf/Account Mandate for BusinessAccount_201908.pdf',
      signFields: ['Signature1', 'Signature2'],
      signChecks: []
  ),
  "2": PdfTemplateInfo(
      signCode: 'x8q8a3d9dz771ds6',
      assetsPath: 'assets/pdf/Appendix A - SPDB Financial Institution Due Diligence Questionnaire_202406.pdf',
      signFields: [],
      signChecks: []
  ),
  "3": PdfTemplateInfo(
      signCode: 'fd50f3s9a15wagf3',
      assetsPath: 'assets/pdf/Appendix M (10) CustomerDeclaration and Undertaking in respect of Tax Evasion.pdf',
      signFields: ['Signature1', 'Signature2'],
      signChecks: [
        PdfSignCheckInfo(
            chkFiledName: 'Check Box3',
            signFieldName: 'Signature2',
            message: '请Director签名确认。')
      ],
      formConfig: PdfFormConfig(
        fieldDefaults: [
          PdfFormFieldDefault(
            fieldName: 'directorName',
            customerProperty: 'customerName',// 空字符串表示不从客户信息获取
            defaultValue: '',
          ),
        ],
      ),
  ),
  "4": PdfTemplateInfo(
      signCode: 'ds26dsvxv52a22cs',
      assetsPath: 'assets/pdf/Appendix 2a - Individual or CPSelf Certification Form 202506 (clean).pdf',
      signFields: ['Signature01', 'Signature02'],
      signChecks: []
  ),
  "5": PdfTemplateInfo(
      signCode: 'zcx26adsv220x3d2',
      assetsPath: 'assets/pdf/Appendix 2b - Entity SelfCertification Form_version202506 (clean).pdf',
      signFields: ['Signature1', 'Signature2'],
      signChecks: []
  ),
  "6": PdfTemplateInfo(
      signCode: 'vh821fdns93xdf23',
      assetsPath: 'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf',
      signFields: [
        'Signature1', 'Signature2', 'Signature3', 'Signature4', 'Signature5',
        'Signature6', 'Signature7', 'Signature8', 'Signature9', 'Signature10',
        'Signature11', 'Signature12', 'Signature', 'witnessedBy'
      ],
      signChecks: []
  ),
  "7": PdfTemplateInfo(
      signCode: 'af71b136e5sf66sd',
      assetsPath: 'assets/pdf/Letter of Declaration [Client]2019_July.pdf',
      signFields: ['Signature'],
      signChecks: []
  ),
  "8": PdfTemplateInfo(
      signCode: 'n6a9g46q9g4gfqr3',
      assetsPath: 'assets/pdf/Telephone & Fax Instructions andIndemnity_(For Business Account)_201908.pdf',
      signFields: ['Signature'],
      signChecks: []
  ),
};





