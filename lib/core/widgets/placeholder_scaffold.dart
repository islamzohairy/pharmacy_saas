import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';

/// Shared scaffold for P0 route stubs.
///
/// Every feature's entry screen is this placeholder until its dedicated
/// plan replaces it. Deliberately logic-free — no feature behavior lives
/// here.
class PlaceholderScaffold extends StatelessWidget {
  const PlaceholderScaffold({
    super.key,
    required this.title,
    this.actions,
    this.bottomBar,
  });

  final String title;
  final List<Widget>? actions;

  /// Optional bar pinned at the bottom (e.g. the backup status
  /// indicator).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(child: Text(context.l10n.screenUnderConstruction)),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: bottomBar,
              ),
            ),
    );
  }
}
