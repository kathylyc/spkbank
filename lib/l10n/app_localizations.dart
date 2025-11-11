import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'浦发银行表单系统'**
  String get appName;

  /// No description provided for @roleAdmin.
  ///
  /// In zh, this message translates to:
  /// **'管理员'**
  String get roleAdmin;

  /// No description provided for @roleManager.
  ///
  /// In zh, this message translates to:
  /// **'客户经理'**
  String get roleManager;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入账号'**
  String get usernameHint;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get passwordHint;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @register.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get register;

  /// No description provided for @pleaseEnterUsernameAndPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入账号和密码'**
  String get pleaseEnterUsernameAndPassword;

  /// No description provided for @loginSuccess.
  ///
  /// In zh, this message translates to:
  /// **'登录成功！角色: {role}, 账号: {username}'**
  String loginSuccess(String role, String username);

  /// No description provided for @navigateToRegister.
  ///
  /// In zh, this message translates to:
  /// **'跳转到注册页面'**
  String get navigateToRegister;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出登录吗？'**
  String get logoutConfirm;

  /// No description provided for @logoutSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已退出登录'**
  String get logoutSuccess;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// No description provided for @templateManagement.
  ///
  /// In zh, this message translates to:
  /// **'模板管理'**
  String get templateManagement;

  /// No description provided for @customerManagement.
  ///
  /// In zh, this message translates to:
  /// **'客户管理'**
  String get customerManagement;

  /// No description provided for @userManagement.
  ///
  /// In zh, this message translates to:
  /// **'用户管理'**
  String get userManagement;

  /// No description provided for @changePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePassword;

  /// No description provided for @recentlyGeneratedPdfFiles.
  ///
  /// In zh, this message translates to:
  /// **'最近生成的PDF文件'**
  String get recentlyGeneratedPdfFiles;

  /// No description provided for @templateQuantity.
  ///
  /// In zh, this message translates to:
  /// **'模板数量'**
  String get templateQuantity;

  /// No description provided for @customerQuantity.
  ///
  /// In zh, this message translates to:
  /// **'客户数量'**
  String get customerQuantity;

  /// No description provided for @signedDocumentQuantity.
  ///
  /// In zh, this message translates to:
  /// **'已签署文件数量'**
  String get signedDocumentQuantity;

  /// No description provided for @pendingSignatureDocumentQuantity.
  ///
  /// In zh, this message translates to:
  /// **'待签署文件数量'**
  String get pendingSignatureDocumentQuantity;

  /// No description provided for @viewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get viewAll;

  /// No description provided for @customerName.
  ///
  /// In zh, this message translates to:
  /// **'客户姓名'**
  String get customerName;

  /// No description provided for @accountFileName.
  ///
  /// In zh, this message translates to:
  /// **'开户文件名'**
  String get accountFileName;

  /// No description provided for @fileVersion.
  ///
  /// In zh, this message translates to:
  /// **'文件版本'**
  String get fileVersion;

  /// No description provided for @templateUsed.
  ///
  /// In zh, this message translates to:
  /// **'使用模板'**
  String get templateUsed;

  /// No description provided for @accountManagerCode.
  ///
  /// In zh, this message translates to:
  /// **'客户经理编码'**
  String get accountManagerCode;

  /// No description provided for @accountManagerName.
  ///
  /// In zh, this message translates to:
  /// **'客户经理姓名'**
  String get accountManagerName;

  /// No description provided for @updateTime.
  ///
  /// In zh, this message translates to:
  /// **'更新时间'**
  String get updateTime;

  /// No description provided for @customerAccountFileCountStatistics.
  ///
  /// In zh, this message translates to:
  /// **'客户开户文件数统计'**
  String get customerAccountFileCountStatistics;

  /// No description provided for @monthlyNewCustomerAndNewAccountFileStatistics.
  ///
  /// In zh, this message translates to:
  /// **'每月新增客户数和新增开户文件统计'**
  String get monthlyNewCustomerAndNewAccountFileStatistics;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
