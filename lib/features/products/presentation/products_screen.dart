import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/widgets/placeholder_scaffold.dart';

/// Route stub for product entry. Real flow: PLANS/05.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: context.l10n.productsTitle,
    );
  }
}
