import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/backup_status_indicator.dart';
import '../../../core/widgets/placeholder_scaffold.dart';

/// Route stub for the profit dashboard. Real flow: PLANS/07.
///
/// The profile entry action is navigation chrome only (opens the profile
/// switcher) — it will move into the real dashboard navigation when
/// PLANS/07 lands. The backup indicator is permanent chrome: the owner
/// always sees when the device last backed up (plan 03 step 6).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: context.l10n.dashboardTitle,
      actions: [
        IconButton(
          tooltip: context.l10n.profilesTooltip,
          icon: const Icon(Icons.person),
          onPressed: () => context.goNamed(AppRoutes.profiles),
        ),
      ],
      bottomBar: const BackupStatusIndicator(),
    );
  }
}
