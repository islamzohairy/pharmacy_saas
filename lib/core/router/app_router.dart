import 'package:go_router/go_router.dart';

import '../../features/customer_debt/presentation/customer_debt_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/draws/presentation/draws_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/supplier_debt/presentation/supplier_debt_screen.dart';

/// Route names — used for [GoRouter.goNamed] navigation.
abstract final class AppRoutes {
  static const onboarding = 'onboarding';
  static const products = 'products';
  static const sales = 'sales';
  static const draws = 'draws';
  static const supplierDebt = 'supplier-debt';
  static const customerDebt = 'customer-debt';
  static const dashboard = 'dashboard';
}

/// P0 route table. Every route points at a stub screen for now.
///
/// Onboarding is the initial route; the dashboard becomes the default
/// post-onboarding route once PLANS/02 lands.
final appRouter = GoRouter(
  initialLocation: '/onboarding',
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
  ],
);
