import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/widgets/placeholder_scaffold.dart';

/// Route stub for the onboarding/profile flow. Real flow: PLANS/02.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: context.l10n.onboardingTitle,
    );
  }
}
