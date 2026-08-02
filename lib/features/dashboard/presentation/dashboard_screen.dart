import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/widgets/placeholder_scaffold.dart';

/// Route stub for the profit dashboard. Real flow: PLANS/07.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: context.l10n.dashboardTitle,
    );
  }
}
