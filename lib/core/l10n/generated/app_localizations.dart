import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// Application title shown in the app bar and launcher context
  ///
  /// In ar, this message translates to:
  /// **'إدارة الصيدلية'**
  String get appTitle;

  /// Title of the onboarding/profile placeholder screen
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك'**
  String get onboardingTitle;

  /// Title of the products placeholder screen
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get productsTitle;

  /// Title of the sales entry placeholder screen
  ///
  /// In ar, this message translates to:
  /// **'المبيعات'**
  String get salesTitle;

  /// Title of the cash draws placeholder screen
  ///
  /// In ar, this message translates to:
  /// **'السحوبات'**
  String get drawsTitle;

  /// Title of the supplier debt placeholder screen
  ///
  /// In ar, this message translates to:
  /// **'ديون الموردين'**
  String get supplierDebtTitle;

  /// Title of the customer debt placeholder screen
  ///
  /// In ar, this message translates to:
  /// **'ديون العملاء'**
  String get customerDebtTitle;

  /// Title of the dashboard placeholder screen
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get dashboardTitle;

  /// Placeholder body text shown on stub screens
  ///
  /// In ar, this message translates to:
  /// **'هذه الشاشة قيد الإنشاء'**
  String get screenUnderConstruction;

  /// Label for the pharmacy name input during onboarding
  ///
  /// In ar, this message translates to:
  /// **'اسم الصيدلية'**
  String get pharmacyNameLabel;

  /// Validation error when pharmacy name is empty
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم الصيدلية'**
  String get pharmacyNameRequired;

  /// Label for the owner display name input during onboarding
  ///
  /// In ar, this message translates to:
  /// **'اسمك'**
  String get ownerDisplayNameLabel;

  /// Validation error when owner display name is empty
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسمك'**
  String get ownerDisplayNameRequired;

  /// Currency notice shown during onboarding; P0 is EGP only
  ///
  /// In ar, this message translates to:
  /// **'العملة: جنيه مصري (EGP)'**
  String get currencyIsEgp;

  /// Submit button of the onboarding creation form
  ///
  /// In ar, this message translates to:
  /// **'إنشاء والبدء'**
  String get createAndStart;

  /// Title of the profile switcher screen
  ///
  /// In ar, this message translates to:
  /// **'الملفات الشخصية'**
  String get profilesTitle;

  /// Badge marking the currently active profile in the switcher
  ///
  /// In ar, this message translates to:
  /// **'الملف الحالي'**
  String get currentProfileBadge;

  /// Button to add a family-role profile for the shared-shift pattern
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملف عائلة'**
  String get addFamilyProfile;

  /// Label for the family member display name input
  ///
  /// In ar, this message translates to:
  /// **'اسم العضو'**
  String get familyProfileNameLabel;

  /// Validation error when family member name is empty
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم العضو'**
  String get familyProfileNameRequired;

  /// Confirm button of the add-family-profile dialog
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get addProfile;

  /// Generic cancel button
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// Action to set a PIN on a profile
  ///
  /// In ar, this message translates to:
  /// **'تعيين رمز الدخول'**
  String get setPin;

  /// Action to remove a profile PIN
  ///
  /// In ar, this message translates to:
  /// **'إزالة رمز الدخول'**
  String get clearPin;

  /// Title of the PIN setup dialog
  ///
  /// In ar, this message translates to:
  /// **'إعداد رمز الدخول'**
  String get setPinTitle;

  /// Label for the PIN input
  ///
  /// In ar, this message translates to:
  /// **'رمز الدخول'**
  String get pinLabel;

  /// Label for the PIN confirmation input
  ///
  /// In ar, this message translates to:
  /// **'تأكيد رمز الدخول'**
  String get confirmPinLabel;

  /// Error shown when PIN and confirmation differ
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير متطابق'**
  String get pinMismatch;

  /// Generic save button
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// Title of the PIN entry dialog shown when switching to a protected profile
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز الدخول'**
  String get enterPinTitle;

  /// Error shown when the entered PIN does not match
  ///
  /// In ar, this message translates to:
  /// **'رمز الدخول غير صحيح'**
  String get pinWrong;

  /// Link shown on the PIN entry dialog for the no-recovery path
  ///
  /// In ar, this message translates to:
  /// **'نسيت رمز الدخول؟'**
  String get forgotPin;

  /// Title of the forgot-PIN reset dialog
  ///
  /// In ar, this message translates to:
  /// **'إعادة بدء الصيدلية'**
  String get forgotPinTitle;

  /// Explains the wipe-based PIN reset and its limitation, in-app
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد استرداد لرمز الدخول في هذه المرحلة. إعادة البدء ستحذف الملفات الشخصية والبيانات من هذا الجهاز فقط.'**
  String get forgotPinBody;

  /// Destructive confirm button of the forgot-PIN dialog
  ///
  /// In ar, this message translates to:
  /// **'حذف وإعادة البدء'**
  String get confirmReset;

  /// Tooltip for the profile switcher entry icon
  ///
  /// In ar, this message translates to:
  /// **'الملفات الشخصية'**
  String get profilesTooltip;

  /// Display label for the owner role (informational — role is not enforced in P0)
  ///
  /// In ar, this message translates to:
  /// **'المالك'**
  String get roleOwner;

  /// Display label for the family role (informational — role is not enforced in P0)
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get roleFamily;

  /// Display label for the employee role (informational — role is not enforced in P0)
  ///
  /// In ar, this message translates to:
  /// **'موظف'**
  String get roleEmployee;

  /// Tooltip for the add-profile action on the switcher screen
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملف'**
  String get addProfileTooltip;

  /// Backup indicator: the device has never backed up
  ///
  /// In ar, this message translates to:
  /// **'لم تتم المزامنة بعد'**
  String get backupNeverSynced;

  /// Backup indicator: a sync pass is in progress
  ///
  /// In ar, this message translates to:
  /// **'جارٍ النسخ الاحتياطي…'**
  String get backupSyncing;

  /// Backup indicator: last successful backup time
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة: {time}'**
  String backupSyncedAt(String time);

  /// Backup indicator: the last sync attempt failed
  ///
  /// In ar, this message translates to:
  /// **'تعذر النسخ الاحتياطي — سنحاول مرة أخرى'**
  String get backupError;
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
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
