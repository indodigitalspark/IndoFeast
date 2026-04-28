import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/customer/presentation/pages/customer_dashboard_page.dart';
import '../features/delivery/presentation/pages/delivery_dashboard_page.dart';
import '../features/vendor/presentation/pages/vendor_dashboard_page.dart';
import '../models/user_role.dart';
import '../shared/layout/responsive_scaffold.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: RouteNames.login,
    redirect: (context, state) {
      if (authState.isLoading) {
        return null;
      }

      final session = authState.valueOrNull;
      final user = session?.user;
      final isAtLogin = state.matchedLocation == RouteNames.login;

      if (user == null || !user.canAccessDashboard) {
        return isAtLogin ? null : RouteNames.login;
      }

      final expectedRoute = user.role.dashboardRoute;
      if (isAtLogin) {
        return expectedRoute;
      }

      if (state.matchedLocation != expectedRoute) {
        return expectedRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => LoginPage(
          initialMode: state.uri.queryParameters['mode'],
          initialRole: state.uri.queryParameters['role'],
        ),
      ),
      GoRoute(
        path: RouteNames.customer,
        builder: (context, state) => const CustomerDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.vendor,
        builder: (context, state) => const AppWorkspaceShell(
          title: 'Vendor Store Portal',
          child: VendorDashboardPage(),
        ),
      ),
      GoRoute(
        path: RouteNames.delivery,
        builder: (context, state) => const DeliveryDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.admin,
        builder: (context, state) => const AppWorkspaceShell(
          title: 'Operations Portal',
          child: AdminDashboardPage(),
        ),
      ),
    ],
  );
});

class AppWorkspaceShell extends ConsumerWidget {
  const AppWorkspaceShell({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull?.user;
    final shellTitle = user?.role.portalTitle ?? title;
    final destination = switch (user?.role) {
      UserRole.vendor => const NavigationDestination(
        icon: Icon(Icons.restaurant_outlined),
        selectedIcon: Icon(Icons.restaurant),
        label: 'Store',
      ),
      UserRole.deliveryPartner => const NavigationDestination(
        icon: Icon(Icons.delivery_dining_outlined),
        selectedIcon: Icon(Icons.delivery_dining),
        label: 'Deliveries',
      ),
      UserRole.customer => const NavigationDestination(
        icon: Icon(Icons.storefront_outlined),
        selectedIcon: Icon(Icons.storefront),
        label: 'Customer',
      ),
      _ => const NavigationDestination(
        icon: Icon(Icons.admin_panel_settings_outlined),
        selectedIcon: Icon(Icons.admin_panel_settings),
        label: 'Admin',
      ),
    };

    return ResponsiveScaffold(
      title: shellTitle,
      selectedIndex: 0,
      destinations: [destination],
      onDestinationSelected: (_) {},
      body: child,
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) {
              context.go(RouteNames.login);
            }
          },
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }
}
