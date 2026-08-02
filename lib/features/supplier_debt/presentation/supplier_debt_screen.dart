import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/widgets/placeholder_scaffold.dart';

/// Route stub for supplier debt tracking. Real flow: PLANS/06.
class SupplierDebtScreen extends StatelessWidget {
  const SupplierDebtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: context.l10n.supplierDebtTitle,
    );
  }
}
