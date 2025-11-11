// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '浦发银行表单系统';

  @override
  String get roleAdmin => '管理员';

  @override
  String get roleManager => '客户经理';

  @override
  String get username => '账号';

  @override
  String get usernameHint => '请输入账号';

  @override
  String get password => '密码';

  @override
  String get passwordHint => '请输入密码';

  @override
  String get login => '登录';

  @override
  String get register => '注册';

  @override
  String get pleaseEnterUsernameAndPassword => '请输入账号和密码';

  @override
  String loginSuccess(String role, String username) {
    return '登录成功！角色: $role, 账号: $username';
  }

  @override
  String get navigateToRegister => '跳转到注册页面';

  @override
  String get logout => '退出登录';

  @override
  String get logoutConfirm => '确定要退出登录吗？';

  @override
  String get logoutSuccess => '已退出登录';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get home => '首页';

  @override
  String get templateManagement => '模板管理';

  @override
  String get customerManagement => '客户管理';

  @override
  String get userManagement => '用户管理';

  @override
  String get changePassword => '修改密码';

  @override
  String get recentlyGeneratedPdfFiles => '最近生成的PDF文件';

  @override
  String get templateQuantity => '模板数量';

  @override
  String get customerQuantity => '客户数量';

  @override
  String get signedDocumentQuantity => '已签署文件数量';

  @override
  String get pendingSignatureDocumentQuantity => '待签署文件数量';

  @override
  String get viewAll => '查看全部';

  @override
  String get customerName => '客户姓名';

  @override
  String get accountFileName => '开户文件名';

  @override
  String get fileVersion => '文件版本';

  @override
  String get templateUsed => '使用模板';

  @override
  String get accountManagerCode => '客户经理编码';

  @override
  String get accountManagerName => '客户经理姓名';

  @override
  String get updateTime => '更新时间';

  @override
  String get customerAccountFileCountStatistics => '客户开户文件数统计';

  @override
  String get monthlyNewCustomerAndNewAccountFileStatistics =>
      '每月新增客户数和新增开户文件统计';
}
