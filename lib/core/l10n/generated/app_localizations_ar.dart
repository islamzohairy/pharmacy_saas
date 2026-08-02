// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'إدارة الصيدلية';

  @override
  String get onboardingTitle => 'مرحباً بك';

  @override
  String get productsTitle => 'المنتجات';

  @override
  String get salesTitle => 'المبيعات';

  @override
  String get drawsTitle => 'السحوبات';

  @override
  String get supplierDebtTitle => 'ديون الموردين';

  @override
  String get customerDebtTitle => 'ديون العملاء';

  @override
  String get dashboardTitle => 'لوحة التحكم';

  @override
  String get screenUnderConstruction => 'هذه الشاشة قيد الإنشاء';
}
