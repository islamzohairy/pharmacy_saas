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

  @override
  String get pharmacyNameLabel => 'اسم الصيدلية';

  @override
  String get pharmacyNameRequired => 'أدخل اسم الصيدلية';

  @override
  String get ownerDisplayNameLabel => 'اسمك';

  @override
  String get ownerDisplayNameRequired => 'أدخل اسمك';

  @override
  String get currencyIsEgp => 'العملة: جنيه مصري (EGP)';

  @override
  String get createAndStart => 'إنشاء والبدء';

  @override
  String get profilesTitle => 'الملفات الشخصية';

  @override
  String get currentProfileBadge => 'الملف الحالي';

  @override
  String get addFamilyProfile => 'إضافة ملف عائلة';

  @override
  String get familyProfileNameLabel => 'اسم العضو';

  @override
  String get familyProfileNameRequired => 'أدخل اسم العضو';

  @override
  String get addProfile => 'إضافة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get setPin => 'تعيين رمز الدخول';

  @override
  String get clearPin => 'إزالة رمز الدخول';

  @override
  String get setPinTitle => 'إعداد رمز الدخول';

  @override
  String get pinLabel => 'رمز الدخول';

  @override
  String get confirmPinLabel => 'تأكيد رمز الدخول';

  @override
  String get pinMismatch => 'الرمز غير متطابق';

  @override
  String get save => 'حفظ';

  @override
  String get enterPinTitle => 'أدخل رمز الدخول';

  @override
  String get pinWrong => 'رمز الدخول غير صحيح';

  @override
  String get forgotPin => 'نسيت رمز الدخول؟';

  @override
  String get forgotPinTitle => 'إعادة بدء الصيدلية';

  @override
  String get forgotPinBody =>
      'لا يوجد استرداد لرمز الدخول في هذه المرحلة. إعادة البدء ستحذف الملفات الشخصية والبيانات من هذا الجهاز فقط.';

  @override
  String get confirmReset => 'حذف وإعادة البدء';

  @override
  String get profilesTooltip => 'الملفات الشخصية';

  @override
  String get roleOwner => 'المالك';

  @override
  String get roleFamily => 'العائلة';

  @override
  String get roleEmployee => 'موظف';

  @override
  String get addProfileTooltip => 'إضافة ملف';

  @override
  String get backupNeverSynced => 'لم تتم المزامنة بعد';

  @override
  String get backupSyncing => 'جارٍ النسخ الاحتياطي…';

  @override
  String backupSyncedAt(String time) {
    return 'آخر نسخة: $time';
  }

  @override
  String get backupError => 'تعذر النسخ الاحتياطي — سنحاول مرة أخرى';
}
