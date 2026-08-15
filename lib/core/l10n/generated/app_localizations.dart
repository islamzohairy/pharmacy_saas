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

  /// Title of the expenses screen (replaces the old draws screen)
  ///
  /// In ar, this message translates to:
  /// **'المصروفات'**
  String get expensesTitle;

  /// Label for the expense category picker
  ///
  /// In ar, this message translates to:
  /// **'نوع المصروف'**
  String get expenseCategoryLabel;

  /// Expense category: cash taken out by the owner (the default option)
  ///
  /// In ar, this message translates to:
  /// **'سحب المالك'**
  String get expenseCategoryOwnerDraw;

  /// Expense category: rent
  ///
  /// In ar, this message translates to:
  /// **'إيجار'**
  String get expenseCategoryRent;

  /// Expense category: utilities (electricity, water, ...)
  ///
  /// In ar, this message translates to:
  /// **'مرافق'**
  String get expenseCategoryUtilities;

  /// Expense category: supplies
  ///
  /// In ar, this message translates to:
  /// **'مستلزمات'**
  String get expenseCategorySupplies;

  /// Expense category: anything not covered by the other categories
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get expenseCategoryOther;

  /// Section title of the recent expenses list
  ///
  /// In ar, this message translates to:
  /// **'آخر المصروفات'**
  String get expensesHistoryTitle;

  /// Empty state of the recent expenses list
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مصروفات مسجلة بعد'**
  String get expensesHistoryEmpty;

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

  /// Title of the activity history screen
  ///
  /// In ar, this message translates to:
  /// **'النشاط'**
  String get activityTitle;

  /// Empty state of the activity feed
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركة مسجلة بعد'**
  String get activityEmpty;

  /// Attribution line on an activity row, {name} is the recorder's display name
  ///
  /// In ar, this message translates to:
  /// **'بواسطة: {name}'**
  String activityRecordedBy(String name);

  /// Ledger type label for a debt repayment entry in the activity feed
  ///
  /// In ar, this message translates to:
  /// **'سداد دين'**
  String get debtRepaymentLabel;

  /// Ledger type label for a sale entry in the activity feed
  ///
  /// In ar, this message translates to:
  /// **'مبيعات'**
  String get ledgerTypeSale;

  /// Ledger type label for an expense entry in the activity feed
  ///
  /// In ar, this message translates to:
  /// **'مصروف'**
  String get ledgerTypeExpense;

  /// Ledger type label for a supplier debt entry in the activity feed
  ///
  /// In ar, this message translates to:
  /// **'دين مورد'**
  String get ledgerTypeSupplierDebt;

  /// Ledger type label for a customer debt entry in the activity feed
  ///
  /// In ar, this message translates to:
  /// **'دين عميل'**
  String get ledgerTypeCustomerDebt;

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

  /// Tooltip for the settings entry icon on the dashboard app bar
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTooltip;

  /// Title of the settings screen
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// Section title for the compliance-prep fields — inert data capture, not a compliance feature
  ///
  /// In ar, this message translates to:
  /// **'بيانات الفوترة (تحضيري)'**
  String get settingsComplianceSection;

  /// Label for the tax registration number input
  ///
  /// In ar, this message translates to:
  /// **'الرقم الضريبي'**
  String get settingsTaxRegistrationLabel;

  /// Label for the legal business name input
  ///
  /// In ar, this message translates to:
  /// **'الاسم القانوني للنشاط'**
  String get settingsLegalBusinessNameLabel;

  /// Note explaining the compliance-prep fields are optional and inert today
  ///
  /// In ar, this message translates to:
  /// **'تُحفظ هذه البيانات محليًا لاستخدامها مستقبلًا في الفوترة الإلكترونية، ولا تؤثر على استخدام التطبيق حاليًا.'**
  String get settingsComplianceNote;

  /// Snackbar confirmation after settings are saved
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الإعدادات'**
  String get settingsSaved;

  /// Snackbar error after settings save fails
  ///
  /// In ar, this message translates to:
  /// **'تعذر حفظ الإعدادات — حاول مرة أخرى'**
  String get settingsSaveFailed;

  /// Button that saves the settings screen fields
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get settingsSave;

  /// Section title for the inventory settings block (PLANS/13)
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get settingsInventorySection;

  /// Settings toggle: when ON, a sale automatically posts a stock_out movement for tracked products
  ///
  /// In ar, this message translates to:
  /// **'خصم المخزون تلقائيًا عند البيع'**
  String get autoDeductStockLabel;

  /// Helper line under the auto-deduct toggle explaining its behavior
  ///
  /// In ar, this message translates to:
  /// **'عند تفعيله تُخصم الكميات المباعة من المخزون تلقائيًا للمنتجات المُتتبَّعة'**
  String get autoDeductStockHelper;

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

  /// Backup indicator: unsynced entries sit past the 48h staleness threshold — warns the owner to check connectivity
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة احتياطية قديمة — تحقق من الاتصال'**
  String get backupStale;

  /// Title of the staleness explanation dialog
  ///
  /// In ar, this message translates to:
  /// **'نسخة احتياطية قديمة'**
  String get backupStaleDialogTitle;

  /// Non-destructive explanation of the stale backup state and what to do
  ///
  /// In ar, this message translates to:
  /// **'هناك عمليات لم تُنسخ احتياطيًا منذ أكثر من يومين. بياناتك ما زالت محفوظة على هذا الجهاز. تأكد من اتصال الإنترنت وأبقِ التطبيق مفتوحًا بعض الوقت حتى تتم المزامنة تلقائيًا.'**
  String get backupStaleDialogBody;

  /// Dismiss button of the staleness explanation dialog
  ///
  /// In ar, this message translates to:
  /// **'فهمت'**
  String get backupStaleDialogGotIt;

  /// Fatal-error screen title shown when the local database cannot open
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح البيانات'**
  String get fatalDatabaseTitle;

  /// Fatal-error screen body: reassures data is intact, asks to copy the report and retry — never suggests clearing data
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع أثناء فتح ملف البيانات المحلي. بياناتك لم تُمس — لا تحذف التطبيق أو البيانات. انسخ التقرير وأرسله للدعم، ثم أعد المحاولة.'**
  String get fatalDatabaseBody;

  /// Fatal-error screen action that copies the minimal error report to the clipboard
  ///
  /// In ar, this message translates to:
  /// **'نسخ التقرير'**
  String get fatalDatabaseCopyReport;

  /// Snackbar after the fatal-error report is copied
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ التقرير إلى الحافظة'**
  String get fatalDatabaseReportCopied;

  /// Snackbar shown when the user-triggered retry fails again
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح البيانات — حاول مرة أخرى'**
  String get fatalDatabaseRetryFailed;

  /// Action/button to create a new product
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج'**
  String get addProduct;

  /// Action/title for editing an existing product
  ///
  /// In ar, this message translates to:
  /// **'تعديل منتج'**
  String get editProduct;

  /// Action/title for soft-deactivating (hiding) a product
  ///
  /// In ar, this message translates to:
  /// **'تعطيل المنتج'**
  String get deactivateProduct;

  /// Confirmation body when deactivating a product — soft delete, ledger history stays valid
  ///
  /// In ar, this message translates to:
  /// **'سيُخفى «{name}» من قوائم المنتجات ولن يُحذف سجل مبيعاته السابق.'**
  String deactivateConfirmBody(String name);

  /// Confirm button of the deactivate dialog
  ///
  /// In ar, this message translates to:
  /// **'تعطيل'**
  String get deactivateConfirmAction;

  /// Empty state title of the products list
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات بعد'**
  String get productsEmpty;

  /// Empty state hint of the products list
  ///
  /// In ar, this message translates to:
  /// **'أضف أول منتج للبدء في تسجيل المبيعات'**
  String get productsEmptyHint;

  /// Generic load-error message with retry
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل البيانات'**
  String get loadError;

  /// Generic retry button
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// Label for the product name input
  ///
  /// In ar, this message translates to:
  /// **'اسم المنتج'**
  String get productNameLabel;

  /// Validation error when product name is empty
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المنتج'**
  String get productNameRequired;

  /// Label for the purchase/cost price input
  ///
  /// In ar, this message translates to:
  /// **'سعر الشراء'**
  String get costPriceLabel;

  /// Label for the sell price input
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get sellPriceLabel;

  /// Helper text under price inputs showing the accepted format
  ///
  /// In ar, this message translates to:
  /// **'مثال: 25.50'**
  String get priceHelper;

  /// Validation error when a price is not a valid number
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغًا صحيحًا (مثال: 25.50)'**
  String get priceInvalid;

  /// Validation error when a price field is empty
  ///
  /// In ar, this message translates to:
  /// **'أدخل السعر'**
  String get priceRequired;

  /// Validation error when a price is zero or negative
  ///
  /// In ar, this message translates to:
  /// **'يجب أن يكون السعر أكبر من صفر'**
  String get priceMustBePositive;

  /// Label for the optional expiry date input
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get expiryDateLabel;

  /// Helper text marking the expiry date as optional
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get expiryDateOptional;

  /// Tooltip to remove the chosen expiry date
  ///
  /// In ar, this message translates to:
  /// **'إزالة التاريخ'**
  String get clearExpiry;

  /// Label of the optional initial-stock input on product creation (PLANS/12)
  ///
  /// In ar, this message translates to:
  /// **'المخزون الابتدائي'**
  String get initialStockLabel;

  /// Helper text under the initial-stock input, only shown on product creation
  ///
  /// In ar, this message translates to:
  /// **'اختياري — عدد الوحدات المتوفرة عند الإنشاء'**
  String get initialStockOptional;

  /// Validation error when initial stock is not a whole number or is negative
  ///
  /// In ar, this message translates to:
  /// **'أدخل عددًا صحيحًا (مثال: 25)'**
  String get initialStockInvalid;

  /// Product-list row label for the live on-hand quantity
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get onHandLabel;

  /// Label of the optional low-stock threshold input on the product form (PLANS/14, D15)
  ///
  /// In ar, this message translates to:
  /// **'حد تنبيه المخزون'**
  String get lowStockThresholdLabel;

  /// Helper text under the low-stock threshold input, shown in both create and edit; guides toward >= 1 since 0 adds nothing beyond out-of-stock (D15)
  ///
  /// In ar, this message translates to:
  /// **'اختياري — يُنبّه عندما يصل المخزون إلى هذا الحد فأقل (من الأفضل 1 فأكثر)'**
  String get lowStockThresholdHelper;

  /// Validation error when the threshold is not a whole number or is negative
  ///
  /// In ar, this message translates to:
  /// **'أدخل عددًا صحيحًا (مثال: 25)'**
  String get lowStockThresholdInvalid;

  /// Product-list badge for a tracked product at or below its low-stock threshold (PLANS/14, D14)
  ///
  /// In ar, this message translates to:
  /// **'مخزون منخفض'**
  String get lowStockBadge;

  /// Product-list badge for a tracked product with zero or negative on-hand (PLANS/14, D14)
  ///
  /// In ar, this message translates to:
  /// **'نفد المخزون'**
  String get outOfStockBadge;

  /// Product-row action-sheet entry opening the stock adjustment sheet (distinct from editing the product itself)
  ///
  /// In ar, this message translates to:
  /// **'المخزون: إضافة / تصحيح'**
  String get adjustStockAction;

  /// Product-row action-sheet entry opening the product edit form
  ///
  /// In ar, this message translates to:
  /// **'تعديل بيانات المنتج'**
  String get editProductAction;

  /// Adjustment-sheet header label for the current on-hand quantity
  ///
  /// In ar, this message translates to:
  /// **'المخزون الحالي'**
  String get currentOnHandLabel;

  /// Adjustment-sheet mode segment: post a positive stock_in
  ///
  /// In ar, this message translates to:
  /// **'إضافة كمية'**
  String get addQuantity;

  /// Adjustment-sheet mode segment: set the quantity to an exact target
  ///
  /// In ar, this message translates to:
  /// **'تصحيح الكمية'**
  String get correctQuantity;

  /// Adjustment-sheet input label for the quantity field
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantityLabel;

  /// Add-mode live preview of the resulting on-hand quantity
  ///
  /// In ar, this message translates to:
  /// **'بعد الإضافة: {quantity}'**
  String afterAddPreview(String quantity);

  /// Correct-mode live preview of the signed delta and the new total
  ///
  /// In ar, this message translates to:
  /// **'الفرق: {delta} · الجديد: {total}'**
  String correctPreview(String delta, String total);

  /// Correct-mode inline state when the target equals the current on-hand (commit disabled)
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد تغيير'**
  String get noChange;

  /// Optional free-text note field on the adjustment sheet
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get noteOptional;

  /// Adjustment-sheet commit button posting the stock movement
  ///
  /// In ar, this message translates to:
  /// **'تحديث المخزون'**
  String get updateStock;

  /// Snackbar shown when the stock movement write fails
  ///
  /// In ar, this message translates to:
  /// **'فشل تحديث المخزون'**
  String get stockUpdateFailed;

  /// Activity-feed label for a manual stock_in movement, naming the product
  ///
  /// In ar, this message translates to:
  /// **'إضافة مخزون: {product}'**
  String stockAddLabel(String product);

  /// Activity-feed label for a manual adjustment movement, naming the product
  ///
  /// In ar, this message translates to:
  /// **'تصحيح مخزون: {product}'**
  String stockAdjustLabel(String product);

  /// Hint of the product search field in sales entry
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن منتج…'**
  String get searchProducts;

  /// Label of the running sales total
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get totalLabel;

  /// Label of a single sales line's total
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get lineTotal;

  /// Button that commits all sales lines to the ledger
  ///
  /// In ar, this message translates to:
  /// **'تأكيد البيع'**
  String get confirmSale;

  /// Snackbar confirmation after a successful sale
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل البيع'**
  String get saleRecorded;

  /// Snackbar error after a failed sale
  ///
  /// In ar, this message translates to:
  /// **'تعذر تسجيل البيع — حاول مرة أخرى'**
  String get saleFailed;

  /// Tooltip for decreasing a line quantity
  ///
  /// In ar, this message translates to:
  /// **'تقليل الكمية'**
  String get decreaseQuantity;

  /// Tooltip for increasing a line quantity
  ///
  /// In ar, this message translates to:
  /// **'زيادة الكمية'**
  String get increaseQuantity;

  /// Tooltip for removing a line from the sale
  ///
  /// In ar, this message translates to:
  /// **'إزالة الصنف'**
  String get removeLine;

  /// Empty state title of the sales screen
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات بعد'**
  String get salesEmpty;

  /// Empty state hint of the sales screen
  ///
  /// In ar, this message translates to:
  /// **'أضف منتجًا أولاً لتتمكن من تسجيل عملية بيع'**
  String get salesEmptyHint;

  /// Button navigating from the sales empty state to the products screen
  ///
  /// In ar, this message translates to:
  /// **'الذهاب إلى المنتجات'**
  String get goToProducts;

  /// Button that records an expense
  ///
  /// In ar, this message translates to:
  /// **'تسجيل المصروف'**
  String get recordExpense;

  /// Label for the expense amount input
  ///
  /// In ar, this message translates to:
  /// **'مبلغ المصروف'**
  String get expenseAmountLabel;

  /// Label for an optional free-text note
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get noteOptionalLabel;

  /// Snackbar confirmation after a successful expense recording
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل المصروف'**
  String get expenseRecorded;

  /// Snackbar error after a failed expense recording
  ///
  /// In ar, this message translates to:
  /// **'تعذر تسجيل المصروف — حاول مرة أخرى'**
  String get expenseFailed;

  /// Action/button to create a new supplier
  ///
  /// In ar, this message translates to:
  /// **'إضافة مورد'**
  String get addSupplier;

  /// Label for the supplier name input
  ///
  /// In ar, this message translates to:
  /// **'اسم المورد'**
  String get supplierNameLabel;

  /// Validation error when the supplier name is empty
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المورد'**
  String get supplierNameRequired;

  /// Action/button to create a new customer
  ///
  /// In ar, this message translates to:
  /// **'إضافة عميل'**
  String get addCustomer;

  /// Label for the customer name input
  ///
  /// In ar, this message translates to:
  /// **'اسم العميل'**
  String get customerNameLabel;

  /// Validation error when the customer name is empty
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم العميل'**
  String get customerNameRequired;

  /// Confirm button of party-creation dialogs
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get confirmAdd;

  /// Action that records a debt owed to a supplier
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دين'**
  String get recordSupplierDebt;

  /// Action that records a debt a customer owes
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دين'**
  String get recordCustomerDebt;

  /// Action that records a repayment to/from a party
  ///
  /// In ar, this message translates to:
  /// **'تسجيل سداد'**
  String get recordRepayment;

  /// Label for the debt/repayment amount input
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get debtAmountLabel;

  /// Title of the record-debt dialog
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دين'**
  String get recordDebtTitle;

  /// Title of the record-repayment dialog
  ///
  /// In ar, this message translates to:
  /// **'تسجيل سداد'**
  String get recordRepaymentTitle;

  /// Snackbar confirmation after recording a debt
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدين'**
  String get debtRecorded;

  /// Snackbar confirmation after recording a repayment
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل السداد'**
  String get repaymentRecorded;

  /// Snackbar error after a failed debt/repayment save
  ///
  /// In ar, this message translates to:
  /// **'تعذر الحفظ — حاول مرة أخرى'**
  String get recordFailed;

  /// Empty state title of the supplier list
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موردون بعد'**
  String get suppliersEmpty;

  /// Empty state hint of the supplier list
  ///
  /// In ar, this message translates to:
  /// **'أضف موردًا لتسجيل الديون المستحقة له'**
  String get suppliersEmptyHint;

  /// Empty state title of the customer list
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد عملاء بعد'**
  String get customersEmpty;

  /// Empty state hint of the customer list
  ///
  /// In ar, this message translates to:
  /// **'أضف عميلًا لتسجيل ديون العملاء'**
  String get customersEmptyHint;

  /// Label marking a negative balance as a credit (overpayment)
  ///
  /// In ar, this message translates to:
  /// **'رصيد دائن'**
  String get creditBalance;

  /// Date-range option: today (the default dashboard view)
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get dashboardRangeToday;

  /// Date-range option: this week (starts Saturday, Egyptian calendar)
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get dashboardRangeWeek;

  /// Date-range option: this month
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get dashboardRangeMonth;

  /// Dashboard headline figure: sales minus cost minus draws
  ///
  /// In ar, this message translates to:
  /// **'صافي الربح'**
  String get dashboardNetProfit;

  /// Dashboard figure: cost of goods sold in the selected range
  ///
  /// In ar, this message translates to:
  /// **'تكلفة البضاعة'**
  String get dashboardCost;

  /// Dashboard insight line label: the expense category with the largest total in the selected range (PLANS/14, D16)
  ///
  /// In ar, this message translates to:
  /// **'أعلى مصروف'**
  String get topExpenseLabel;

  /// Tooltip/semantics for the dashboard products-tile attention count (PLANS/14 §5.4)
  ///
  /// In ar, this message translates to:
  /// **'منتجات تحتاج انتباهًا'**
  String get attentionCountTooltip;

  /// Dashboard section header: all-time supplier/customer debt balances
  ///
  /// In ar, this message translates to:
  /// **'الأرصدة الحالية'**
  String get dashboardCurrentBalances;

  /// Dashboard figure: total currently owed to all suppliers
  ///
  /// In ar, this message translates to:
  /// **'المستحق للموردين'**
  String get dashboardOwedToSuppliers;

  /// Dashboard figure: total currently owed by all customers
  ///
  /// In ar, this message translates to:
  /// **'المستحق من العملاء'**
  String get dashboardOwedByCustomers;

  /// Dashboard empty-state title shown on first day of use
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بتسجيل أول عملية بيع'**
  String get dashboardEmptyTitle;

  /// Dashboard empty-state hint explaining what appears once data is logged
  ///
  /// In ar, this message translates to:
  /// **'ستظهر أرقامك هنا: المبيعات، التكلفة، السحوبات، وصافي الربح — كلها محسوبة من سجلاتك مباشرة'**
  String get dashboardEmptyHint;

  /// Dashboard empty-state button navigating to the sales screen
  ///
  /// In ar, this message translates to:
  /// **'تسجيل عملية بيع'**
  String get dashboardEmptyAction;

  /// Label (with count) on the dashboard error-log indicator for unreported crashes
  ///
  /// In ar, this message translates to:
  /// **'أخطاء غير مُبلَّغ عنها'**
  String get errorLogUnreported;

  /// Title of the error-log export dialog
  ///
  /// In ar, this message translates to:
  /// **'سجل الأخطاء المحلي'**
  String get errorLogDialogTitle;

  /// Button that copies the error report as plain text to the clipboard
  ///
  /// In ar, this message translates to:
  /// **'نسخ التقرير'**
  String get errorLogExportReport;

  /// Button marking the error log as externally reported/dismissed (clears the indicator)
  ///
  /// In ar, this message translates to:
  /// **'تم التبليغ'**
  String get errorLogReportedDismiss;

  /// Snackbar shown after the error report is copied
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ تقرير الأخطاء إلى الحافظة'**
  String get errorLogCopiedSnackbar;

  /// Header line of the exported plain-text report
  ///
  /// In ar, this message translates to:
  /// **'تقرير أخطاء التطبيق'**
  String get errorLogReportHeader;

  /// Empty state in the error-log dialog
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أخطاء مُسجَّلة'**
  String get errorLogNoEntries;
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
