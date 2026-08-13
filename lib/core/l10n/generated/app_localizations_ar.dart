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
  String get expensesTitle => 'المصروفات';

  @override
  String get expenseCategoryLabel => 'نوع المصروف';

  @override
  String get expenseCategoryOwnerDraw => 'سحب المالك';

  @override
  String get expenseCategoryRent => 'إيجار';

  @override
  String get expenseCategoryUtilities => 'مرافق';

  @override
  String get expenseCategorySupplies => 'مستلزمات';

  @override
  String get expenseCategoryOther => 'أخرى';

  @override
  String get expensesHistoryTitle => 'آخر المصروفات';

  @override
  String get expensesHistoryEmpty => 'لا توجد مصروفات مسجلة بعد';

  @override
  String get supplierDebtTitle => 'ديون الموردين';

  @override
  String get customerDebtTitle => 'ديون العملاء';

  @override
  String get dashboardTitle => 'لوحة التحكم';

  @override
  String get activityTitle => 'النشاط';

  @override
  String get activityEmpty => 'لا توجد حركة مسجلة بعد';

  @override
  String activityRecordedBy(String name) {
    return 'بواسطة: $name';
  }

  @override
  String get debtRepaymentLabel => 'سداد دين';

  @override
  String get ledgerTypeSale => 'مبيعات';

  @override
  String get ledgerTypeExpense => 'مصروف';

  @override
  String get ledgerTypeSupplierDebt => 'دين مورد';

  @override
  String get ledgerTypeCustomerDebt => 'دين عميل';

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
  String get settingsTooltip => 'الإعدادات';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsComplianceSection => 'بيانات الفوترة (تحضيري)';

  @override
  String get settingsTaxRegistrationLabel => 'الرقم الضريبي';

  @override
  String get settingsLegalBusinessNameLabel => 'الاسم القانوني للنشاط';

  @override
  String get settingsComplianceNote =>
      'تُحفظ هذه البيانات محليًا لاستخدامها مستقبلًا في الفوترة الإلكترونية، ولا تؤثر على استخدام التطبيق حاليًا.';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات';

  @override
  String get settingsSaveFailed => 'تعذر حفظ الإعدادات — حاول مرة أخرى';

  @override
  String get settingsSave => 'حفظ';

  @override
  String get settingsInventorySection => 'المخزون';

  @override
  String get autoDeductStockLabel => 'خصم المخزون تلقائيًا عند البيع';

  @override
  String get autoDeductStockHelper =>
      'عند تفعيله تُخصم الكميات المباعة من المخزون تلقائيًا للمنتجات المُتتبَّعة';

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

  @override
  String get backupStale => 'آخر نسخة احتياطية قديمة — تحقق من الاتصال';

  @override
  String get backupStaleDialogTitle => 'نسخة احتياطية قديمة';

  @override
  String get backupStaleDialogBody =>
      'هناك عمليات لم تُنسخ احتياطيًا منذ أكثر من يومين. بياناتك ما زالت محفوظة على هذا الجهاز. تأكد من اتصال الإنترنت وأبقِ التطبيق مفتوحًا بعض الوقت حتى تتم المزامنة تلقائيًا.';

  @override
  String get backupStaleDialogGotIt => 'فهمت';

  @override
  String get fatalDatabaseTitle => 'تعذر فتح البيانات';

  @override
  String get fatalDatabaseBody =>
      'حدث خطأ غير متوقع أثناء فتح ملف البيانات المحلي. بياناتك لم تُمس — لا تحذف التطبيق أو البيانات. انسخ التقرير وأرسله للدعم، ثم أعد المحاولة.';

  @override
  String get fatalDatabaseCopyReport => 'نسخ التقرير';

  @override
  String get fatalDatabaseReportCopied => 'تم نسخ التقرير إلى الحافظة';

  @override
  String get fatalDatabaseRetryFailed => 'تعذر فتح البيانات — حاول مرة أخرى';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get editProduct => 'تعديل منتج';

  @override
  String get deactivateProduct => 'تعطيل المنتج';

  @override
  String deactivateConfirmBody(String name) {
    return 'سيُخفى «$name» من قوائم المنتجات ولن يُحذف سجل مبيعاته السابق.';
  }

  @override
  String get deactivateConfirmAction => 'تعطيل';

  @override
  String get productsEmpty => 'لا توجد منتجات بعد';

  @override
  String get productsEmptyHint => 'أضف أول منتج للبدء في تسجيل المبيعات';

  @override
  String get loadError => 'تعذر تحميل البيانات';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get productNameLabel => 'اسم المنتج';

  @override
  String get productNameRequired => 'أدخل اسم المنتج';

  @override
  String get costPriceLabel => 'سعر الشراء';

  @override
  String get sellPriceLabel => 'سعر البيع';

  @override
  String get priceHelper => 'مثال: 25.50';

  @override
  String get priceInvalid => 'أدخل مبلغًا صحيحًا (مثال: 25.50)';

  @override
  String get priceRequired => 'أدخل السعر';

  @override
  String get priceMustBePositive => 'يجب أن يكون السعر أكبر من صفر';

  @override
  String get expiryDateLabel => 'تاريخ الانتهاء';

  @override
  String get expiryDateOptional => 'اختياري';

  @override
  String get clearExpiry => 'إزالة التاريخ';

  @override
  String get initialStockLabel => 'المخزون الابتدائي';

  @override
  String get initialStockOptional =>
      'اختياري — عدد الوحدات المتوفرة عند الإنشاء';

  @override
  String get initialStockInvalid => 'أدخل عددًا صحيحًا (مثال: 25)';

  @override
  String get onHandLabel => 'المخزون';

  @override
  String get lowStockThresholdLabel => 'حد تنبيه المخزون';

  @override
  String get lowStockThresholdHelper =>
      'اختياري — يُنبّه عندما يصل المخزون إلى هذا الحد فأقل (من الأفضل 1 فأكثر)';

  @override
  String get lowStockThresholdInvalid => 'أدخل عددًا صحيحًا (مثال: 25)';

  @override
  String get adjustStockAction => 'المخزون: إضافة / تصحيح';

  @override
  String get editProductAction => 'تعديل بيانات المنتج';

  @override
  String get currentOnHandLabel => 'المخزون الحالي';

  @override
  String get addQuantity => 'إضافة كمية';

  @override
  String get correctQuantity => 'تصحيح الكمية';

  @override
  String get quantityLabel => 'الكمية';

  @override
  String afterAddPreview(String quantity) {
    return 'بعد الإضافة: $quantity';
  }

  @override
  String correctPreview(String delta, String total) {
    return 'الفرق: $delta · الجديد: $total';
  }

  @override
  String get noChange => 'لا يوجد تغيير';

  @override
  String get noteOptional => 'ملاحظة (اختياري)';

  @override
  String get updateStock => 'تحديث المخزون';

  @override
  String get stockUpdateFailed => 'فشل تحديث المخزون';

  @override
  String stockAddLabel(String product) {
    return 'إضافة مخزون: $product';
  }

  @override
  String stockAdjustLabel(String product) {
    return 'تصحيح مخزون: $product';
  }

  @override
  String get searchProducts => 'ابحث عن منتج…';

  @override
  String get totalLabel => 'الإجمالي';

  @override
  String get lineTotal => 'الإجمالي';

  @override
  String get confirmSale => 'تأكيد البيع';

  @override
  String get saleRecorded => 'تم تسجيل البيع';

  @override
  String get saleFailed => 'تعذر تسجيل البيع — حاول مرة أخرى';

  @override
  String get decreaseQuantity => 'تقليل الكمية';

  @override
  String get increaseQuantity => 'زيادة الكمية';

  @override
  String get removeLine => 'إزالة الصنف';

  @override
  String get salesEmpty => 'لا توجد منتجات بعد';

  @override
  String get salesEmptyHint => 'أضف منتجًا أولاً لتتمكن من تسجيل عملية بيع';

  @override
  String get goToProducts => 'الذهاب إلى المنتجات';

  @override
  String get recordExpense => 'تسجيل المصروف';

  @override
  String get expenseAmountLabel => 'مبلغ المصروف';

  @override
  String get noteOptionalLabel => 'ملاحظة (اختياري)';

  @override
  String get expenseRecorded => 'تم تسجيل المصروف';

  @override
  String get expenseFailed => 'تعذر تسجيل المصروف — حاول مرة أخرى';

  @override
  String get addSupplier => 'إضافة مورد';

  @override
  String get supplierNameLabel => 'اسم المورد';

  @override
  String get supplierNameRequired => 'أدخل اسم المورد';

  @override
  String get addCustomer => 'إضافة عميل';

  @override
  String get customerNameLabel => 'اسم العميل';

  @override
  String get customerNameRequired => 'أدخل اسم العميل';

  @override
  String get confirmAdd => 'إضافة';

  @override
  String get recordSupplierDebt => 'تسجيل دين';

  @override
  String get recordCustomerDebt => 'تسجيل دين';

  @override
  String get recordRepayment => 'تسجيل سداد';

  @override
  String get debtAmountLabel => 'المبلغ';

  @override
  String get recordDebtTitle => 'تسجيل دين';

  @override
  String get recordRepaymentTitle => 'تسجيل سداد';

  @override
  String get debtRecorded => 'تم تسجيل الدين';

  @override
  String get repaymentRecorded => 'تم تسجيل السداد';

  @override
  String get recordFailed => 'تعذر الحفظ — حاول مرة أخرى';

  @override
  String get suppliersEmpty => 'لا يوجد موردون بعد';

  @override
  String get suppliersEmptyHint => 'أضف موردًا لتسجيل الديون المستحقة له';

  @override
  String get customersEmpty => 'لا يوجد عملاء بعد';

  @override
  String get customersEmptyHint => 'أضف عميلًا لتسجيل ديون العملاء';

  @override
  String get creditBalance => 'رصيد دائن';

  @override
  String get dashboardRangeToday => 'اليوم';

  @override
  String get dashboardRangeWeek => 'هذا الأسبوع';

  @override
  String get dashboardRangeMonth => 'هذا الشهر';

  @override
  String get dashboardNetProfit => 'صافي الربح';

  @override
  String get dashboardCost => 'تكلفة البضاعة';

  @override
  String get dashboardCurrentBalances => 'الأرصدة الحالية';

  @override
  String get dashboardOwedToSuppliers => 'المستحق للموردين';

  @override
  String get dashboardOwedByCustomers => 'المستحق من العملاء';

  @override
  String get dashboardEmptyTitle => 'ابدأ بتسجيل أول عملية بيع';

  @override
  String get dashboardEmptyHint =>
      'ستظهر أرقامك هنا: المبيعات، التكلفة، السحوبات، وصافي الربح — كلها محسوبة من سجلاتك مباشرة';

  @override
  String get dashboardEmptyAction => 'تسجيل عملية بيع';

  @override
  String get errorLogUnreported => 'أخطاء غير مُبلَّغ عنها';

  @override
  String get errorLogDialogTitle => 'سجل الأخطاء المحلي';

  @override
  String get errorLogExportReport => 'نسخ التقرير';

  @override
  String get errorLogReportedDismiss => 'تم التبليغ';

  @override
  String get errorLogCopiedSnackbar => 'تم نسخ تقرير الأخطاء إلى الحافظة';

  @override
  String get errorLogReportHeader => 'تقرير أخطاء التطبيق';

  @override
  String get errorLogNoEntries => 'لا توجد أخطاء مُسجَّلة';
}
