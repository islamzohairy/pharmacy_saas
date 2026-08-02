import 'package:go_router/go_router.dart';

import '../../features/customer_debt/presentation/customer_debt_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/draws/presentation/draws_screen.dart';
import '../../features/identity/presentation/onboarding/onboarding_screen.dart';
import '../../features/identity/presentation/profiles/profile_switcher_screen.dart';
import '../../features/products/domain/product.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/supplier_debt/presentation/supplier_debt_screen.dart';

/// Route names — used for [GoRouter.goNamed] navigation.
abstract final class AppRoutes {
  static const onboarding = 'onboarding';
  static const products = 'products';
  static const productForm = 'product-form';
  static const sales = 'sales';
  static const draws = 'draws';
  static const supplierDebt = 'supplier-debt';
  static const customerDebt = 'customer-debt';
  static const dashboard = 'dashboard';
  static const profiles = 'profiles';
}

/// P0 route table.
///
/// The initial location is decided at startup: first launch (no local
/// profiles yet) starts at onboarding; otherwise the dashboard is the
/// default post-onboarding route.
GoRouter buildRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/onboarding',
        name: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/products',
        name: AppRoutes.products,
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/product-form',
        name: AppRoutes.productForm,
        builder: (context, state) =>
            ProductFormScreen(product: state.extra as Product?),
      ),
      GoRoute(
        path: '/sales',
        name: AppRoutes.sales,
        builder: (context, state) => const SalesScreen(),
      ),
      GoRoute(
        path: '/draws',
        name: AppRoutes.draws,
        builder: (context, state) => const DrawsScreen(),
      ),
      GoRoute(
        path: '/supplier-debt',
        name: AppRoutes.supplierDebt,
        builder: (context, state) => const SupplierDebtScreen(),
      ),
      GoRoute(
        path: '/customer-debt',
        name: AppRoutes.customerDebt,
        builder: (context, state) => const CustomerDebtScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/profiles',
        name: AppRoutes.profiles,
        builder: (context, state) => const ProfileSwitcherScreen(),
      ),
    ],
  );
}
