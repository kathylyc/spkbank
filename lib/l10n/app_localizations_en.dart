// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Bank Form System';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleManager => 'Account Manager';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => 'Please enter username';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Please enter password';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get pleaseEnterUsernameAndPassword =>
      'Please enter username and password';

  @override
  String loginSuccess(String role, String username) {
    return 'Login successful! Role: $role, Username: $username';
  }

  @override
  String get navigateToRegister => 'Navigate to register page';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get logoutSuccess => 'Logged out successfully';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get home => 'Home';

  @override
  String get templateManagement => 'Template Management';

  @override
  String get userManagement => 'User Management';

  @override
  String get changePassword => 'Change Password';

  @override
  String get recentlyGeneratedPdfFiles => 'Recently Generated PDF Files';

  @override
  String get templateQuantity => 'Template Quantity';

  @override
  String get customerQuantity => 'Customer Quantity';

  @override
  String get signedDocumentQuantity => 'Signed Document Quantity';

  @override
  String get pendingSignatureDocumentQuantity =>
      'Pending Signature Document Quantity';

  @override
  String get viewAll => 'View All';

  @override
  String get customerName => 'Customer Name';

  @override
  String get accountFileName => 'Account File Name';

  @override
  String get fileVersion => 'File Version';

  @override
  String get templateUsed => 'Template Used';

  @override
  String get accountManagerCode => 'Account Manager Code';

  @override
  String get accountManagerName => 'Account Manager Name';

  @override
  String get updateTime => 'Update Time';

  @override
  String get customerAccountFileCountStatistics =>
      'Customer Account File Count Statistics';

  @override
  String get monthlyNewCustomerAndNewAccountFileStatistics =>
      'Monthly New Customer and New Account File Statistics';
}
