import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../models/account_status.dart';
import '../../../../models/admin_notification.dart';
import '../../../../models/admin_models.dart';
import '../../../../models/app_user.dart';
import '../../../../models/user_role.dart';
import '../../../../shared/widgets/app_async_state.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_paginated_column.dart';
import '../../../../shared/widgets/app_section_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/admin_dashboard_controller.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  late final ProviderSubscription<AsyncValue<AdminDashboardState>>
  _subscription;
  int _reportDays = 30;
  _AdminModule _selectedModule = _AdminModule.overview;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(adminDashboardControllerProvider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }

      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminDashboardControllerProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull?.user;

    return state.when(
      data: (data) => _AdminDashboardBody(
        data: data,
        currentUser: currentUser,
        reportDays: _reportDays,
        selectedModule: _selectedModule,
        onModuleSelected: (value) => setState(() => _selectedModule = value),
        onReportDaysChanged: (value) async {
          setState(() => _reportDays = value);
          await ref
              .read(adminDashboardControllerProvider.notifier)
              .generateReport(value);
        },
      ),
      loading: () =>
          const AppLoadingState(message: 'Loading your admin dashboard...'),
      error: (error, stackTrace) => AppErrorState(
        message: error.toString(),
        onRetry: () =>
            ref.read(adminDashboardControllerProvider.notifier).refresh(),
      ),
    );
  }
}

class _AdminDashboardBody extends ConsumerWidget {
  const _AdminDashboardBody({
    required this.data,
    required this.currentUser,
    required this.reportDays,
    required this.selectedModule,
    required this.onModuleSelected,
    required this.onReportDaysChanged,
  });

  final AdminDashboardState data;
  final AppUser? currentUser;
  final int reportDays;
  final _AdminModule selectedModule;
  final ValueChanged<_AdminModule> onModuleSelected;
  final ValueChanged<int> onReportDaysChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(adminDashboardControllerProvider.notifier);
    final canManageApprovals =
        currentUser?.hasPermission('approvals:manage') ?? false;
    final canManageUsers = currentUser?.hasPermission('users:manage') ?? false;
    final canManageCommission =
        currentUser?.hasPermission('commission:manage') ?? false;
    final canManageRoles = currentUser?.hasPermission('roles:manage') ?? false;
    final canManageCategories =
        currentUser?.hasPermission('categories:manage') ?? false;
    final canManageBanners =
        currentUser?.hasPermission('banners:manage') ?? false;
    final canBroadcast =
        currentUser?.hasPermission('notifications:broadcast') ?? false;
    final canViewTransactions =
        currentUser?.hasPermission('transactions:view') ?? false;
    final canViewReports = currentUser?.hasPermission('reports:view') ?? false;
    final modules = _visibleModulesForUser(
      currentUser,
      canManageUsers: canManageUsers,
      canManageApprovals: canManageApprovals,
      canManageCommission: canManageCommission,
      canManageRoles: canManageRoles,
      canManageCategories: canManageCategories,
      canManageBanners: canManageBanners,
      canBroadcast: canBroadcast,
      canViewTransactions: canViewTransactions,
      canViewReports: canViewReports,
    );
    final activeModule = modules.contains(selectedModule)
        ? selectedModule
        : modules.first;
    final content = _buildModuleSections(
      context,
      currentUser: currentUser,
      canManageUsers: canManageUsers,
      canManageApprovals: canManageApprovals,
      canManageCommission: canManageCommission,
      canManageRoles: canManageRoles,
      canManageCategories: canManageCategories,
      canManageBanners: canManageBanners,
      canBroadcast: canBroadcast,
      canViewTransactions: canViewTransactions,
      canViewReports: canViewReports,
      activeModule: activeModule,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = constraints.maxWidth >= 1100;
        final contentList = RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              _AdminWorkspaceTopbar(
                currentUser: currentUser,
                activeModule: activeModule,
                notificationCount: data.notifications.length,
              ),
              const SizedBox(height: AppSpacing.md),
              _HeroStrip(
                analytics: data.analytics,
                commissionRate: data.config.globalCommissionRate,
                onRefresh: notifier.refresh,
                currentUser: currentUser,
                activeModule: activeModule,
              ),
              const SizedBox(height: AppSpacing.md),
              if (!showSidebar) ...[
                _AdminModuleTabBar(
                  modules: modules,
                  selectedModule: activeModule,
                  onSelected: onModuleSelected,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              ...content,
            ],
          ),
        );

        if (!showSidebar) {
          return contentList;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: _AdminModuleSidebar(
                currentUser: currentUser,
                modules: modules,
                selectedModule: activeModule,
                onSelected: onModuleSelected,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: contentList),
          ],
        );
      },
    );
  }

  List<Widget> _buildModuleSections(
    BuildContext context, {
    required AppUser? currentUser,
    required bool canManageUsers,
    required bool canManageApprovals,
    required bool canManageCommission,
    required bool canManageRoles,
    required bool canManageCategories,
    required bool canManageBanners,
    required bool canBroadcast,
    required bool canViewTransactions,
    required bool canViewReports,
    required _AdminModule activeModule,
  }) {
    switch (activeModule) {
      case _AdminModule.overview:
        return [
          _ModuleOverviewBand(
            currentUser: currentUser,
            analytics: data.analytics,
            notificationsCount: data.notifications.length,
          ),
          const SizedBox(height: AppSpacing.md),
          _AnalyticsGrid(analytics: data.analytics),
          if (canManageApprovals) ...[
            const SizedBox(height: AppSpacing.md),
            _ApprovalBoard(
              vendorApprovals: data.vendorApprovals,
              deliveryApprovals: data.deliveryApprovals,
            ),
          ],
          if (canViewTransactions || canViewReports) ...[
            const SizedBox(height: AppSpacing.md),
            _FinanceWorkspace(
              report: data.report,
              reportDays: reportDays,
              transactions: data.transactions,
              canViewTransactions: canViewTransactions,
              canViewReports: canViewReports,
              onReportDaysChanged: onReportDaysChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _NotificationsSection(notifications: data.notifications),
        ];
      case _AdminModule.systemControl:
        return [
          const _RightsChecklistCard(
            title: 'System control rights',
            icon: Icons.security_outlined,
            rights: [
              'Create / Edit / Delete Admin',
              'Create roles dynamically',
              'Assign permissions',
              'Modify commission globally',
              'Access all modules',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final showSplit = constraints.maxWidth >= 1100;
              final platformControls = _PlatformControlsSection(
                data: data,
                currentUser: currentUser,
              );
              final adminRoster = _UserRosterSection(
                title: 'IndoFeast employee roster',
                emptyTitle: 'No employee accounts yet',
                emptyMessage:
                    'Admin, vendor, and delivery employee accounts will appear here.',
                users: data.users
                    .where((user) => user.role != UserRole.customer)
                    .toList(growable: false),
                config: data.config,
                currentUser: currentUser,
              );

              if (showSplit) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: platformControls),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: adminRoster),
                  ],
                );
              }

              return Column(
                children: [
                  platformControls,
                  const SizedBox(height: AppSpacing.md),
                  adminRoster,
                ],
              );
            },
          ),
        ];
      case _AdminModule.userControl:
        return [
          const _RightsChecklistCard(
            title: 'User control rights',
            icon: Icons.groups_outlined,
            rights: [
              'View all users',
              'Suspend / Delete accounts',
              'Reset passwords',
              'Block fraudulent users',
            ],
          ),
          if (canManageUsers) ...[
            const SizedBox(height: AppSpacing.md),
            _UserManagementSection(data: data, currentUser: currentUser),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            const _RestrictedModuleCard(
              message:
                  'This admin account does not currently have user management permission.',
            ),
          ],
        ];
      case _AdminModule.vendorControl:
        return [
          const _RightsChecklistCard(
            title: 'Vendor control rights',
            icon: Icons.storefront_outlined,
            rights: [
              'Approve / Reject vendor registration',
              'Set vendor commission %',
              'Suspend vendor',
              'Force close vendor',
              'View vendor analytics',
              'Edit vendor profile manually',
            ],
          ),
          if (canManageApprovals) ...[
            const SizedBox(height: AppSpacing.md),
            _ApprovalSection(
              title: 'Vendor approvals',
              users: data.vendorApprovals,
            ),
          ],
          if (canManageUsers) ...[
            const SizedBox(height: AppSpacing.md),
            _UserRosterSection(
              title: 'Vendor roster',
              emptyTitle: 'No vendor accounts yet',
              emptyMessage:
                  'Approved and pending vendor accounts will appear here.',
              users: data.users
                  .where((user) => user.role == UserRole.vendor)
                  .toList(growable: false),
              config: data.config,
              currentUser: currentUser,
            ),
            const SizedBox(height: AppSpacing.md),
            _VendorStoreManagementSection(
              restaurants: data.restaurants,
              vendors: data.users
                  .where((user) => user.role == UserRole.vendor)
                  .toList(growable: false),
            ),
          ],
        ];
      case _AdminModule.deliveryControl:
        return [
          const _RightsChecklistCard(
            title: 'Delivery partner control rights',
            icon: Icons.delivery_dining_outlined,
            rights: [
              'Approve documents',
              'Suspend delivery partner',
              'Assign manual orders',
              'Modify payout rate',
            ],
          ),
          if (canManageApprovals) ...[
            const SizedBox(height: AppSpacing.md),
            _ApprovalSection(
              title: 'Delivery partner approvals',
              users: data.deliveryApprovals,
            ),
          ],
          if (canManageUsers) ...[
            const SizedBox(height: AppSpacing.md),
            _UserRosterSection(
              title: 'Delivery partner roster',
              emptyTitle: 'No delivery partners yet',
              emptyMessage:
                  'Approved and pending delivery partner accounts will appear here.',
              users: data.users
                  .where((user) => user.role == UserRole.deliveryPartner)
                  .toList(growable: false),
              config: data.config,
              currentUser: currentUser,
            ),
          ],
        ];
      case _AdminModule.orderControl:
        return [
          const _RightsChecklistCard(
            title: 'Order control rights',
            icon: Icons.receipt_long_outlined,
            rights: [
              'View all orders',
              'Cancel any order',
              'Force refund',
              'Modify order status manually',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _FinanceWorkspace(
            report: data.report,
            reportDays: reportDays,
            transactions: data.transactions,
            canViewTransactions: canViewTransactions,
            canViewReports: canViewReports,
            onReportDaysChanged: onReportDaysChanged,
          ),
        ];
      case _AdminModule.financialControl:
        return [
          const _RightsChecklistCard(
            title: 'Financial control rights',
            icon: Icons.account_balance_wallet_outlined,
            rights: [
              'View total platform revenue',
              'Access transaction history',
              'Modify commission %',
              'Generate settlement reports',
              'Trigger vendor payouts',
              'Trigger delivery payouts',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final showSplit = constraints.maxWidth >= 1100;
              final commissionCard = _PlatformControlsSection(
                data: data,
                currentUser: currentUser,
              );
              final financeWorkspace = _FinanceWorkspace(
                report: data.report,
                reportDays: reportDays,
                transactions: data.transactions,
                canViewTransactions: canViewTransactions,
                canViewReports: canViewReports,
                onReportDaysChanged: onReportDaysChanged,
              );

              if (showSplit) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: commissionCard),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: financeWorkspace),
                  ],
                );
              }

              return Column(
                children: [
                  commissionCard,
                  const SizedBox(height: AppSpacing.md),
                  financeWorkspace,
                ],
              );
            },
          ),
        ];
      case _AdminModule.contentMarketing:
        return [
          const _RightsChecklistCard(
            title: 'Content & marketing rights',
            icon: Icons.campaign_outlined,
            rights: [
              'Create banners',
              'Manage coupons',
              'Manage categories',
              'Broadcast push notifications',
              'Create featured vendor slots',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _GrowthControlsSection(
            data: data,
            currentUser: currentUser,
            onReportRequested: onReportDaysChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          _NotificationsSection(notifications: data.notifications),
        ];
    }
  }
}

enum _AdminModule {
  overview,
  systemControl,
  userControl,
  vendorControl,
  deliveryControl,
  orderControl,
  financialControl,
  contentMarketing,
}

extension on _AdminModule {
  String get label => switch (this) {
    _AdminModule.overview => 'Overview',
    _AdminModule.systemControl => 'System Control',
    _AdminModule.userControl => 'User Control',
    _AdminModule.vendorControl => 'Vendor Control',
    _AdminModule.deliveryControl => 'Delivery Control',
    _AdminModule.orderControl => 'Order Control',
    _AdminModule.financialControl => 'Financial Control',
    _AdminModule.contentMarketing => 'Content & Marketing',
  };

  IconData get icon => switch (this) {
    _AdminModule.overview => Icons.dashboard_outlined,
    _AdminModule.systemControl => Icons.admin_panel_settings_outlined,
    _AdminModule.userControl => Icons.groups_outlined,
    _AdminModule.vendorControl => Icons.storefront_outlined,
    _AdminModule.deliveryControl => Icons.delivery_dining_outlined,
    _AdminModule.orderControl => Icons.receipt_long_outlined,
    _AdminModule.financialControl => Icons.account_balance_wallet_outlined,
    _AdminModule.contentMarketing => Icons.campaign_outlined,
  };

  String get helper => switch (this) {
    _AdminModule.overview => 'Health, queues, finance, and alerts',
    _AdminModule.systemControl => 'Admins, roles, and platform policy',
    _AdminModule.userControl => 'Customer account oversight',
    _AdminModule.vendorControl => 'Vendor approvals and operations',
    _AdminModule.deliveryControl => 'Fleet approvals and payouts',
    _AdminModule.orderControl => 'Refund and status intervention',
    _AdminModule.financialControl => 'Revenue, commission, and settlements',
    _AdminModule.contentMarketing => 'Banners, categories, and broadcasts',
  };
}

List<_AdminModule> _visibleModulesForUser(
  AppUser? currentUser, {
  required bool canManageUsers,
  required bool canManageApprovals,
  required bool canManageCommission,
  required bool canManageRoles,
  required bool canManageCategories,
  required bool canManageBanners,
  required bool canBroadcast,
  required bool canViewTransactions,
  required bool canViewReports,
}) {
  final modules = <_AdminModule>[_AdminModule.overview];

  if (currentUser?.hasFullAdminAccess ?? false) {
    modules.addAll(
      _AdminModule.values.where((module) => module != _AdminModule.overview),
    );
    return modules;
  }

  if (canManageUsers || canManageRoles || canManageCommission) {
    modules.add(_AdminModule.systemControl);
  }
  if (canManageUsers) {
    modules.add(_AdminModule.userControl);
  }
  if (canManageUsers || canManageApprovals) {
    modules.add(_AdminModule.vendorControl);
    modules.add(_AdminModule.deliveryControl);
  }
  if (canViewTransactions || canViewReports) {
    modules.add(_AdminModule.orderControl);
    modules.add(_AdminModule.financialControl);
  }
  if (canManageCategories || canManageBanners || canBroadcast) {
    modules.add(_AdminModule.contentMarketing);
  }

  return modules.toSet().toList(growable: false);
}

class _AdminWorkspaceTopbar extends ConsumerWidget {
  const _AdminWorkspaceTopbar({
    required this.currentUser,
    required this.activeModule,
    required this.notificationCount,
  });

  final AppUser? currentUser;
  final _AdminModule activeModule;
  final int notificationCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminTopbarTitle(activeModule: activeModule),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Notifications',
                            onPressed: () {},
                            icon: Badge.count(
                              count: notificationCount,
                              isLabelVisible: notificationCount > 0,
                              child: const Icon(Icons.notifications_none),
                            ),
                          ),
                          _AdminProfileMenu(currentUser: currentUser),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _AdminTopbarTitle(activeModule: activeModule),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Notifications',
                        onPressed: () {},
                        icon: Badge.count(
                          count: notificationCount,
                          isLabelVisible: notificationCount > 0,
                          child: const Icon(Icons.notifications_none),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _AdminProfileMenu(currentUser: currentUser),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _AdminTopbarTitle extends StatelessWidget {
  const _AdminTopbarTitle({required this.activeModule});

  final _AdminModule activeModule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeModule.label,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Dashboard', style: Theme.of(context).textTheme.bodySmall),
            const Icon(Icons.chevron_right, size: 16),
            Text(
              activeModule.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.saffron,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminProfileMenu extends ConsumerWidget {
  const _AdminProfileMenu({required this.currentUser});

  final AppUser? currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 420;

    return PopupMenuButton<String>(
      tooltip: 'Admin profile',
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            _showSimpleInfoDialog(
              context,
              title: 'My Profile',
              message:
                  '${currentUser?.displayName ?? 'Admin'}\n${currentUser?.email ?? ''}\nRole: ${currentUser?.role.label ?? 'Admin'}',
            );
          case 'password':
            _showSimpleInfoDialog(
              context,
              title: 'Change Password',
              message:
                  'Password management is not wired into this build yet. The panel structure is ready for that flow.',
            );
          case 'logout':
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Logged out successfully.')),
                );
            }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'profile', child: Text('My Profile')),
        PopupMenuItem(value: 'password', child: Text('Change Password')),
        PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.sand,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.saffron,
              foregroundColor: Colors.white,
              child: Text(
                (currentUser?.displayName.isNotEmpty ?? false)
                    ? currentUser!.displayName.characters.first
                    : 'A',
              ),
            ),
            if (!isCompact) ...[
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser?.displayName ?? 'Admin',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    currentUser?.role.label ?? 'Admin',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.keyboard_arrow_down),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminSidebarGroup {
  const _AdminSidebarGroup({required this.title, required this.items});

  final String title;
  final List<_AdminSidebarItem> items;
}

class _AdminSidebarItem {
  const _AdminSidebarItem({
    required this.label,
    required this.module,
    this.icon,
  });

  final String label;
  final _AdminModule module;
  final IconData? icon;
}

List<_AdminSidebarGroup> _buildSidebarGroups(List<_AdminModule> modules) {
  final visible = modules.toSet();
  final groups = <_AdminSidebarGroup>[];

  if (visible.contains(_AdminModule.overview) ||
      visible.contains(_AdminModule.financialControl) ||
      visible.contains(_AdminModule.orderControl)) {
    groups.add(
      _AdminSidebarGroup(
        title: 'Dashboard',
        items: [
          if (visible.contains(_AdminModule.overview))
            const _AdminSidebarItem(
              label: 'Overview',
              module: _AdminModule.overview,
              icon: Icons.dashboard_outlined,
            ),
          if (visible.contains(_AdminModule.financialControl))
            const _AdminSidebarItem(
              label: 'Revenue Analytics',
              module: _AdminModule.financialControl,
            ),
          if (visible.contains(_AdminModule.orderControl))
            const _AdminSidebarItem(
              label: 'Order Analytics',
              module: _AdminModule.orderControl,
            ),
        ],
      ),
    );
  }

  if (visible.contains(_AdminModule.userControl) ||
      visible.contains(_AdminModule.vendorControl) ||
      visible.contains(_AdminModule.deliveryControl) ||
      visible.contains(_AdminModule.systemControl)) {
    groups.add(
      _AdminSidebarGroup(
        title: 'User Management',
        items: [
          if (visible.contains(_AdminModule.userControl))
            const _AdminSidebarItem(
              label: 'Customers',
              module: _AdminModule.userControl,
              icon: Icons.groups_outlined,
            ),
          if (visible.contains(_AdminModule.vendorControl))
            const _AdminSidebarItem(
              label: 'Vendors',
              module: _AdminModule.vendorControl,
            ),
          if (visible.contains(_AdminModule.deliveryControl))
            const _AdminSidebarItem(
              label: 'Delivery Partners',
              module: _AdminModule.deliveryControl,
            ),
          if (visible.contains(_AdminModule.systemControl))
            const _AdminSidebarItem(
              label: 'Admins',
              module: _AdminModule.systemControl,
            ),
        ],
      ),
    );
  }

  if (visible.contains(_AdminModule.orderControl)) {
    groups.add(
      const _AdminSidebarGroup(
        title: 'Order Management',
        items: [
          _AdminSidebarItem(
            label: 'All Orders',
            module: _AdminModule.orderControl,
            icon: Icons.receipt_long_outlined,
          ),
          _AdminSidebarItem(
            label: 'Active Orders',
            module: _AdminModule.orderControl,
          ),
          _AdminSidebarItem(
            label: 'Cancelled Orders',
            module: _AdminModule.orderControl,
          ),
          _AdminSidebarItem(
            label: 'Refund Requests',
            module: _AdminModule.orderControl,
          ),
        ],
      ),
    );
  }

  if (visible.contains(_AdminModule.financialControl)) {
    groups.add(
      const _AdminSidebarGroup(
        title: 'Finance',
        items: [
          _AdminSidebarItem(
            label: 'Transactions',
            module: _AdminModule.financialControl,
            icon: Icons.account_balance_wallet_outlined,
          ),
          _AdminSidebarItem(
            label: 'Commission Settings',
            module: _AdminModule.financialControl,
          ),
          _AdminSidebarItem(
            label: 'Vendor Settlements',
            module: _AdminModule.financialControl,
          ),
          _AdminSidebarItem(
            label: 'Delivery Payouts',
            module: _AdminModule.financialControl,
          ),
          _AdminSidebarItem(
            label: 'Wallet Management',
            module: _AdminModule.financialControl,
          ),
        ],
      ),
    );
  }

  if (visible.contains(_AdminModule.contentMarketing)) {
    groups.add(
      const _AdminSidebarGroup(
        title: 'Marketing',
        items: [
          _AdminSidebarItem(
            label: 'Banners',
            module: _AdminModule.contentMarketing,
            icon: Icons.campaign_outlined,
          ),
          _AdminSidebarItem(
            label: 'Coupons',
            module: _AdminModule.contentMarketing,
          ),
          _AdminSidebarItem(
            label: 'Offers',
            module: _AdminModule.contentMarketing,
          ),
          _AdminSidebarItem(
            label: 'Push Notifications',
            module: _AdminModule.contentMarketing,
          ),
        ],
      ),
    );
    groups.add(
      const _AdminSidebarGroup(
        title: 'Category Management',
        items: [
          _AdminSidebarItem(
            label: 'Food',
            module: _AdminModule.contentMarketing,
            icon: Icons.category_outlined,
          ),
          _AdminSidebarItem(
            label: 'Grocery',
            module: _AdminModule.contentMarketing,
          ),
          _AdminSidebarItem(
            label: 'Medicine',
            module: _AdminModule.contentMarketing,
          ),
          _AdminSidebarItem(
            label: 'Add Category',
            module: _AdminModule.contentMarketing,
          ),
        ],
      ),
    );
  }

  if (visible.contains(_AdminModule.systemControl)) {
    groups.add(
      const _AdminSidebarGroup(
        title: 'Roles & Permissions',
        items: [
          _AdminSidebarItem(
            label: 'Create Role',
            module: _AdminModule.systemControl,
            icon: Icons.admin_panel_settings_outlined,
          ),
          _AdminSidebarItem(
            label: 'Assign Permissions',
            module: _AdminModule.systemControl,
          ),
          _AdminSidebarItem(
            label: 'View Roles',
            module: _AdminModule.systemControl,
          ),
        ],
      ),
    );
    groups.add(
      const _AdminSidebarGroup(
        title: 'Settings',
        items: [
          _AdminSidebarItem(
            label: 'App Settings',
            module: _AdminModule.systemControl,
            icon: Icons.settings_outlined,
          ),
          _AdminSidebarItem(
            label: 'Commission Control',
            module: _AdminModule.systemControl,
          ),
          _AdminSidebarItem(
            label: 'Tax Settings',
            module: _AdminModule.systemControl,
          ),
          _AdminSidebarItem(
            label: 'Payment Gateway Config',
            module: _AdminModule.systemControl,
          ),
        ],
      ),
    );
  }

  if (visible.contains(_AdminModule.financialControl) ||
      visible.contains(_AdminModule.overview)) {
    groups.add(
      _AdminSidebarGroup(
        title: 'Reports',
        items: [
          _AdminSidebarItem(
            label: 'Daily Report',
            module: visible.contains(_AdminModule.financialControl)
                ? _AdminModule.financialControl
                : _AdminModule.overview,
            icon: Icons.assessment_outlined,
          ),
          _AdminSidebarItem(
            label: 'Weekly Report',
            module: visible.contains(_AdminModule.financialControl)
                ? _AdminModule.financialControl
                : _AdminModule.overview,
          ),
          _AdminSidebarItem(
            label: 'Monthly Report',
            module: visible.contains(_AdminModule.financialControl)
                ? _AdminModule.financialControl
                : _AdminModule.overview,
          ),
          _AdminSidebarItem(
            label: 'Export Data',
            module: visible.contains(_AdminModule.financialControl)
                ? _AdminModule.financialControl
                : _AdminModule.overview,
          ),
        ],
      ),
    );
  }

  return groups;
}

class _AdminModuleSidebar extends StatelessWidget {
  const _AdminModuleSidebar({
    required this.currentUser,
    required this.modules,
    required this.selectedModule,
    required this.onSelected,
  });

  final AppUser? currentUser;
  final List<_AdminModule> modules;
  final _AdminModule selectedModule;
  final ValueChanged<_AdminModule> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDefaultSuperAdmin =
        currentUser?.email.toLowerCase() == AppConfig.defaultAdminEmail;
    final groups = _buildSidebarGroups(modules);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser?.displayName ?? 'Admin',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(currentUser?.email ?? ''),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Chip(
                      avatar: const Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                      ),
                      label: Text(currentUser?.role.label ?? 'ADMIN'),
                    ),
                    if (isDefaultSuperAdmin)
                      const Chip(label: Text('Default super admin')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: groups
                  .expand(
                    (group) => [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          AppSpacing.sm,
                          AppSpacing.sm,
                          AppSpacing.xs,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            group.title,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      ...group.items.map(
                        (item) => _AdminSidebarTile(
                          item: item,
                          selected: item.module == selectedModule,
                          onTap: () => onSelected(item.module),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminSidebarTile extends StatelessWidget {
  const _AdminSidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _AdminSidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.darkGreen : Colors.transparent;
    final textColor = selected ? Colors.white : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(item.icon ?? item.module.icon, color: textColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.module.helper,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected ? Colors.white70 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminModuleTabBar extends StatelessWidget {
  const _AdminModuleTabBar({
    required this.modules,
    required this.selectedModule,
    required this.onSelected,
  });

  final List<_AdminModule> modules;
  final _AdminModule selectedModule;
  final ValueChanged<_AdminModule> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: AppSpacing.sm,
        children: modules
            .map(
              (module) => ChoiceChip(
                avatar: Icon(module.icon, size: 18),
                label: Text(module.label),
                selected: module == selectedModule,
                onSelected: (_) => onSelected(module),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ModuleOverviewBand extends StatelessWidget {
  const _ModuleOverviewBand({
    required this.currentUser,
    required this.analytics,
    required this.notificationsCount,
  });

  final AppUser? currentUser;
  final AdminAnalytics analytics;
  final int notificationsCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _OverviewInfoCard(
            title: 'Signed-in authority',
            value: currentUser?.role.label ?? 'ADMIN',
            subtitle: currentUser?.email ?? '',
            icon: Icons.security_outlined,
          ),
          _OverviewInfoCard(
            title: 'Pending approvals',
            value: '${analytics.pendingApprovals}',
            subtitle: 'Vendors and delivery partners waiting review',
            icon: Icons.fact_check_outlined,
          ),
          _OverviewInfoCard(
            title: 'Suspended accounts',
            value: '${analytics.suspendedAccounts}',
            subtitle: 'Accounts currently blocked from the platform',
            icon: Icons.block_outlined,
          ),
          _OverviewInfoCard(
            title: 'Recent alerts',
            value: '$notificationsCount',
            subtitle: 'Broadcast and admin notifications in the queue',
            icon: Icons.notifications_active_outlined,
          ),
        ];
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }
}

class _OverviewInfoCard extends StatelessWidget {
  const _OverviewInfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.saffron),
            const SizedBox(height: AppSpacing.sm),
            Text(title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _RightsChecklistCard extends StatelessWidget {
  const _RightsChecklistCard({
    required this.title,
    required this.icon,
    required this.rights,
  });

  final String title;
  final IconData icon;
  final List<String> rights;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      trailing: CircleAvatar(
        backgroundColor: AppColors.saffron.withValues(alpha: 0.14),
        child: Icon(icon, color: AppColors.saffron),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: rights
            .map(
              (right) => Chip(
                avatar: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(right),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _RestrictedModuleCard extends StatelessWidget {
  const _RestrictedModuleCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: 'Permission required',
      message: message,
      icon: Icons.lock_outline,
    );
  }
}

class _ApprovalBoard extends StatelessWidget {
  const _ApprovalBoard({
    required this.vendorApprovals,
    required this.deliveryApprovals,
  });

  final List<AppUser> vendorApprovals;
  final List<AppUser> deliveryApprovals;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSplit = constraints.maxWidth >= 1100;
        if (showSplit) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ApprovalSection(
                  title: 'Vendor approvals',
                  users: vendorApprovals,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ApprovalSection(
                  title: 'Delivery partner approvals',
                  users: deliveryApprovals,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _ApprovalSection(title: 'Vendor approvals', users: vendorApprovals),
            const SizedBox(height: AppSpacing.md),
            _ApprovalSection(
              title: 'Delivery partner approvals',
              users: deliveryApprovals,
            ),
          ],
        );
      },
    );
  }
}

class _FinanceWorkspace extends StatelessWidget {
  const _FinanceWorkspace({
    required this.report,
    required this.reportDays,
    required this.transactions,
    required this.canViewTransactions,
    required this.canViewReports,
    required this.onReportDaysChanged,
  });

  final AdminReportModel report;
  final int reportDays;
  final List<AdminTransactionModel> transactions;
  final bool canViewTransactions;
  final bool canViewReports;
  final ValueChanged<int> onReportDaysChanged;

  @override
  Widget build(BuildContext context) {
    if (!canViewTransactions && !canViewReports) {
      return const _RestrictedModuleCard(
        message: 'Finance data is unavailable for this admin account.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final reports = _ReportsSection(
          report: report,
          reportDays: reportDays,
          onReportDaysChanged: onReportDaysChanged,
        );
        final transactionList = _TransactionsSection(
          transactions: transactions,
        );
        final showSplit =
            constraints.maxWidth >= 1100 &&
            canViewTransactions &&
            canViewReports;

        if (showSplit) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: transactionList),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: reports),
            ],
          );
        }

        return Column(
          children: [
            if (canViewTransactions) transactionList,
            if (canViewTransactions && canViewReports)
              const SizedBox(height: AppSpacing.md),
            if (canViewReports) reports,
          ],
        );
      },
    );
  }
}

class _UserRosterSection extends StatelessWidget {
  const _UserRosterSection({
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.users,
    required this.config,
    required this.currentUser,
  });

  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final List<AppUser> users;
  final AdminPlatformConfig config;
  final AppUser? currentUser;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      child: users.isEmpty
          ? AppEmptyState(
              title: emptyTitle,
              message: emptyMessage,
              icon: Icons.person_off_outlined,
            )
          : AppPaginatedColumn<AppUser>(
              items: users,
              initialCount: 8,
              step: 8,
              itemBuilder: (context, user, index) => _UserTile(
                user: user,
                config: config,
                currentUser: currentUser,
              ),
            ),
    );
  }
}

class _VendorStoreManagementSection extends StatelessWidget {
  const _VendorStoreManagementSection({
    required this.restaurants,
    required this.vendors,
  });

  final List<AdminRestaurantModel> restaurants;
  final List<AppUser> vendors;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Vendor stores',
      trailing: FilledButton.icon(
        onPressed: vendors.isEmpty
            ? null
            : () => _showVendorStoreDialog(context, null, vendors),
        icon: const Icon(Icons.storefront_outlined),
        label: const Text('Create store'),
      ),
      child: restaurants.isEmpty
          ? const AppEmptyState(
              title: 'No vendor stores yet',
              message:
                  'Create a store from admin when a vendor needs manual setup.',
              icon: Icons.store_mall_directory_outlined,
            )
          : AppPaginatedColumn<AdminRestaurantModel>(
              items: restaurants,
              initialCount: 8,
              step: 8,
              itemBuilder: (context, restaurant, index) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurant.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${restaurant.category} • ${restaurant.cuisine.join(', ')}',
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${restaurant.ownerName ?? 'Unassigned vendor'}${restaurant.ownerEmail == null ? '' : ' • ${restaurant.ownerEmail}'}',
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _showVendorStoreDialog(
                              context,
                              restaurant,
                              vendors,
                            ),
                            child: const Text('Manage store'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          Chip(
                            label: Text('${restaurant.productCount} products'),
                          ),
                          Chip(
                            label: Text(
                              '${(restaurant.commissionRate * 100).toStringAsFixed(0)}% commission',
                            ),
                          ),
                          Chip(label: Text('${restaurant.deliveryTime} min')),
                          Chip(label: Text(restaurant.priceLevel)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _HeroStrip extends StatelessWidget {
  const _HeroStrip({
    required this.analytics,
    required this.commissionRate,
    required this.onRefresh,
    required this.currentUser,
    required this.activeModule,
  });

  final AdminAnalytics analytics;
  final double commissionRate;
  final Future<void> Function() onRefresh;
  final AppUser? currentUser;
  final _AdminModule activeModule;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF081C15), Color(0xFF1B4332)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeModule == _AdminModule.overview
                            ? 'IndoFeast Super Admin Command Center'
                            : activeModule.label,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        currentUser?.email.toLowerCase() ==
                                AppConfig.defaultAdminEmail
                            ? '${currentUser?.email} is signed in with the default super admin workspace.'
                            : 'Run operations, approvals, platform growth, payouts, and reports from one admin workspace.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.saffron,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => onRefresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh dashboard'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _HeroMetric(
                  label: 'Total revenue',
                  value: 'Rs ${analytics.totalRevenue}',
                ),
                _HeroMetric(
                  label: 'Commission',
                  value:
                      '${(commissionRate * 100).toStringAsFixed(0)}% platform cut',
                ),
                _HeroMetric(
                  label: 'Pending approvals',
                  value: '${analytics.pendingApprovals} accounts',
                ),
                _HeroMetric(
                  label: 'Completion rate',
                  value: '${analytics.completionRate}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsGrid extends StatelessWidget {
  const _AnalyticsGrid({required this.analytics});

  final AdminAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _AnalyticsCardData(
        title: 'Total revenue',
        value: 'Rs ${analytics.totalRevenue}',
        subtitle: 'Completed delivery and order revenue',
        icon: Icons.payments_outlined,
      ),
      _AnalyticsCardData(
        title: 'Total orders',
        value: '${analytics.totalOrders}',
        subtitle: 'All-time order volume',
        icon: Icons.receipt_long_outlined,
      ),
      _AnalyticsCardData(
        title: 'Active vendors',
        value: '${analytics.activeVendors}',
        subtitle: 'Approved vendor accounts',
        icon: Icons.storefront_outlined,
      ),
      _AnalyticsCardData(
        title: 'Active delivery partners',
        value: '${analytics.activeDeliveryPartners}',
        subtitle: 'Approved and currently online',
        icon: Icons.delivery_dining_outlined,
      ),
      _AnalyticsCardData(
        title: 'Users',
        value: '${analytics.totalUsers}',
        subtitle: 'Total registered accounts',
        icon: Icons.groups_outlined,
      ),
      _AnalyticsCardData(
        title: 'Suspended accounts',
        value: '${analytics.suspendedAccounts}',
        subtitle: 'Accounts currently blocked',
        icon: Icons.block_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: _AnalyticsCard(card: card),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ApprovalSection extends StatelessWidget {
  const _ApprovalSection({required this.title, required this.users});

  final String title;
  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      child: users.isEmpty
          ? const AppEmptyState(
              title: 'Queue is clear',
              message:
                  'New registrations will appear here for approval and rejection.',
              icon: Icons.verified_user_outlined,
            )
          : Column(
              children: users
                  .map((user) => _ApprovalTile(user: user))
                  .toList(growable: false),
            ),
    );
  }
}

class _ApprovalTile extends ConsumerWidget {
  const _ApprovalTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(adminDashboardControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.displayName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('${user.email} • ${user.phoneNumber}'),
            const SizedBox(height: AppSpacing.xs),
            Text('Role: ${user.role.label}'),
            if (user.documentUrl != null && user.documentUrl!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              SelectableText('Document: ${user.documentUrl}'),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => notifier.approveUser(user.id),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: () => notifier.rejectUser(
                    user.id,
                    reason: 'Rejected during admin verification.',
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserManagementSection extends StatelessWidget {
  const _UserManagementSection({required this.data, required this.currentUser});

  final AdminDashboardState data;
  final AppUser? currentUser;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Manage users',
      trailing: Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${data.users.length} accounts',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          FilledButton.icon(
            onPressed: () =>
                _showCreateUserDialog(context, data.config, currentUser),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Create credentials'),
          ),
        ],
      ),
      child: AppPaginatedColumn<AppUser>(
        items: data.users,
        initialCount: 12,
        step: 12,
        itemBuilder: (context, user, index) => _UserTile(
          user: user,
          config: data.config,
          currentUser: currentUser,
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({
    required this.user,
    required this.config,
    required this.currentUser,
  });

  final AppUser user;
  final AdminPlatformConfig config;
  final AppUser? currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(adminDashboardControllerProvider.notifier);
    final isCurrentUserSuperAdmin = currentUser?.role == UserRole.superAdmin;
    final isAdminFamilyTarget = user.role.isAdminFamily;
    final canEditProfile =
        (currentUser?.hasPermission('users:manage') ?? false) &&
        (!isAdminFamilyTarget || isCurrentUserSuperAdmin);
    final canDeleteUser =
        isCurrentUserSuperAdmin &&
        user.email.toLowerCase() != AppConfig.defaultAdminEmail &&
        currentUser?.id != user.id;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('${user.email} • ${user.phoneNumber}'),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Base role: ${user.role.label}${user.customRoleName == null ? '' : ' • Custom role: ${user.customRoleName}'}',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Joined ${_formatDate(user.createdAt)} • Wallet Rs ${user.walletBalance}',
                      ),
                      if (user.documentName != null || user.documentUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'Document: ${user.documentName ?? user.documentUrl}',
                          ),
                        ),
                      if (user.rejectionReason != null &&
                          user.rejectionReason!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text('Review note: ${user.rejectionReason}'),
                        ),
                    ],
                  ),
                ),
                _StatusChip(status: user.status.label),
              ],
            ),
            if (user.permissions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: user.permissions
                    .map((item) => Chip(label: Text(item)))
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (user.status.value != 'APPROVED')
                  FilledButton(
                    onPressed: () => notifier.approveUser(user.id),
                    child: const Text('Approve'),
                  ),
                if (user.status.value != 'SUSPENDED')
                  OutlinedButton(
                    onPressed: () => notifier.suspendUser(user.id),
                    child: const Text('Suspend'),
                  ),
                if (user.status.value == 'SUSPENDED')
                  FilledButton.tonal(
                    onPressed: () => notifier.reactivateUser(user.id),
                    child: const Text('Reactivate'),
                  ),
                if (canEditProfile)
                  OutlinedButton(
                    onPressed: () =>
                        _showEditUserDialog(context, ref, user, config),
                    child: const Text('View / edit details'),
                  ),
                if (canEditProfile)
                  FilledButton.tonal(
                    onPressed: () =>
                        _showResetPasswordDialog(context, ref, user),
                    child: const Text('Reset password'),
                  ),
                if (canEditProfile)
                  OutlinedButton(
                    onPressed: () =>
                        _showRoleAssignmentDialog(context, ref, user, config),
                    child: const Text('Assign role'),
                  ),
                if (canDeleteUser)
                  FilledButton.tonalIcon(
                    onPressed: () => _showDeleteUserDialog(context, ref, user),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformControlsSection extends StatelessWidget {
  const _PlatformControlsSection({
    required this.data,
    required this.currentUser,
  });

  final AdminDashboardState data;
  final AppUser? currentUser;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (currentUser?.hasPermission('commission:manage') ?? false)
        _InlineControlCard(
          title: 'Set commission %',
          subtitle:
              'Update the platform commission used for vendor payouts and new vendor setup.',
          actionLabel:
              'Current ${(data.config.globalCommissionRate * 100).toStringAsFixed(0)}%',
          onTap: () => _showCommissionDialog(context, data.config),
        ),
      if (currentUser?.hasPermission('roles:manage') ?? false)
        _InlineControlCard(
          title: 'Roles & permissions',
          subtitle:
              'Create and edit custom admin role packs, then assign them to users.',
          actionLabel: '${data.config.roleDefinitions.length} role definitions',
          onTap: () => _showRolesDialog(context, data.config),
        ),
      if (currentUser?.hasPermission('categories:manage') ?? false)
        _InlineControlCard(
          title: 'Manage categories',
          subtitle:
              'Keep storefront category options curated for customer and vendor experiences.',
          actionLabel: '${data.config.managedCategories.length} categories',
          onTap: () => _showCategoriesDialog(context, data.config),
        ),
    ];

    return AppSectionCard(
      title: 'Platform controls',
      child: cards.isEmpty
          ? const AppEmptyState(
              title: 'No platform controls assigned',
              message:
                  'Ask a platform admin to assign more permissions to this admin role.',
              icon: Icons.lock_outline,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _withSectionSpacing(cards),
            ),
    );
  }
}

class _GrowthControlsSection extends StatelessWidget {
  const _GrowthControlsSection({
    required this.data,
    required this.currentUser,
    required this.onReportRequested,
  });

  final AdminDashboardState data;
  final AppUser? currentUser;
  final ValueChanged<int> onReportRequested;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (currentUser?.hasPermission('banners:manage') ?? false)
        _InlineControlCard(
          title: 'Manage banners',
          subtitle:
              'Control the customer-facing marketing banners shown on the storefront.',
          actionLabel: '${data.config.marketingBanners.length} banners',
          onTap: () => _showBannersDialog(context, data.config),
        ),
      if (currentUser?.role == UserRole.superAdmin)
        _InlineControlCard(
          title: 'Website & QR access',
          subtitle:
              'Manage the simple public website cards and QR links for sign in and registration.',
          actionLabel: '${data.config.websiteSettings.qrLinks.length} QR links',
          onTap: () =>
              _showWebsiteSettingsDialog(context, data.config.websiteSettings),
        ),
      if (currentUser?.hasPermission('notifications:broadcast') ?? false)
        _InlineControlCard(
          title: 'Broadcast notifications',
          subtitle:
              'Send updates to customers, vendors, delivery partners, or the whole platform.',
          actionLabel: '${data.notifications.length} recent alerts',
          onTap: () => _showBroadcastDialog(context),
        ),
      if (currentUser?.hasPermission('reports:view') ?? false)
        _InlineControlCard(
          title: 'Generate reports',
          subtitle:
              'Refresh operational reports for finance and marketplace reviews.',
          actionLabel: 'Last ${data.report.days} days',
          onTap: () => _showReportPeriodDialog(context, onReportRequested),
        ),
    ];

    return AppSectionCard(
      title: 'Growth & communication',
      child: cards.isEmpty
          ? const AppEmptyState(
              title: 'No growth controls assigned',
              message:
                  'This admin role can view notifications but cannot manage broadcasts, banners, or reports yet.',
              icon: Icons.campaign_outlined,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _withSectionSpacing(cards),
            ),
    );
  }
}

class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({required this.transactions});

  final List<AdminTransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'All transactions',
      child: transactions.isEmpty
          ? const AppEmptyState(
              title: 'No transactions yet',
              message: 'Wallet top-ups and delivery earnings will appear here.',
              icon: Icons.receipt_long_outlined,
            )
          : AppPaginatedColumn<AdminTransactionModel>(
              items: transactions,
              initialCount: 14,
              step: 14,
              itemBuilder: (context, transaction, index) =>
                  _TransactionRow(item: transaction),
            ),
    );
  }
}

class _ReportsSection extends StatelessWidget {
  const _ReportsSection({
    required this.report,
    required this.reportDays,
    required this.onReportDaysChanged,
  });

  final AdminReportModel report;
  final int reportDays;
  final ValueChanged<int> onReportDaysChanged;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Reports',
      trailing: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 7, label: Text('7D')),
          ButtonSegment(value: 30, label: Text('30D')),
          ButtonSegment(value: 90, label: Text('90D')),
        ],
        selected: {reportDays},
        onSelectionChanged: (value) => onReportDaysChanged(value.first),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _MiniMetric(label: 'Credits', value: 'Rs ${report.totalCredits}'),
              _MiniMetric(label: 'Debits', value: 'Rs ${report.totalDebits}'),
              _MiniMetric(
                label: 'Platform profit',
                value: 'Rs ${report.totalPlatformProfit}',
              ),
              _MiniMetric(
                label: 'Vendor earnings',
                value: 'Rs ${report.totalVendorEarnings}',
              ),
              _MiniMetric(
                label: 'Generated',
                value: _formatDate(report.generatedAt),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Orders by status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: report.ordersByStatus.entries
                .map(
                  (entry) => Chip(
                    label: Text(
                      '${entry.key.replaceAll('_', ' ')}: ${entry.value}',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Top vendors',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (report.topVendors.isEmpty)
            const Text('No vendor activity in the selected period.')
          else
            Column(
              children: report.topVendors
                  .map(
                    (vendor) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(vendor.restaurantName),
                      subtitle: Text(
                        '${vendor.orders} orders • Profit Rs ${vendor.platformProfit} • Vendor Rs ${vendor.vendorEarnings}',
                      ),
                      trailing: Text('Rs ${vendor.revenue}'),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.notifications});

  final List<AdminNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Audit log & notifications',
      child: notifications.isEmpty
          ? const AppEmptyState(
              title: 'No notifications yet',
              message:
                  'Approval updates and admin broadcasts will show up here.',
              icon: Icons.notifications_none,
            )
          : AppPaginatedColumn<AdminNotification>(
              items: notifications,
              initialCount: 8,
              step: 8,
              itemBuilder: (context, notification, index) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.notifications_active_outlined),
                ),
                title: Text(notification.title),
                subtitle: Text(notification.body),
                trailing: Text(_formatDate(notification.createdAt)),
              ),
            ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.card});

  final _AnalyticsCardData card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(card.icon, color: AppColors.saffron),
            const SizedBox(height: AppSpacing.sm),
            Text(
              card.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              card.value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(card.subtitle),
          ],
        ),
      ),
    );
  }
}

class _InlineControlCard extends StatelessWidget {
  const _InlineControlCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(subtitle),
        ),
        trailing: FilledButton.tonal(
          onPressed: onTap,
          child: Text(actionLabel),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.item});

  final AdminTransactionModel item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: item.type == 'CREDIT'
            ? AppColors.mist
            : AppColors.sand,
        child: Icon(
          item.type == 'CREDIT'
              ? Icons.south_west_rounded
              : Icons.north_east_rounded,
          color: item.type == 'CREDIT'
              ? AppColors.darkGreen
              : AppColors.saffron,
        ),
      ),
      title: Text(item.description),
      subtitle: Text('${item.userName} • ${item.userRole} • ${item.category}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${item.type == 'CREDIT' ? '+' : '-'}Rs ${item.amount}',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(_formatDate(item.createdAt)),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final color = switch (normalized) {
      'APPROVED' => AppColors.darkGreen,
      'SUSPENDED' => Colors.redAccent,
      'PENDING' => AppColors.saffron,
      _ => Colors.blueGrey,
    };

    return Chip(
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text(status),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _AnalyticsCardData {
  const _AnalyticsCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
}

List<Widget> _withSectionSpacing(List<Widget> widgets) {
  final items = <Widget>[];
  for (var index = 0; index < widgets.length; index++) {
    if (index > 0) {
      items.add(const SizedBox(height: AppSpacing.sm));
    }
    items.add(widgets[index]);
  }
  return items;
}

Future<void> _showCreateUserDialog(
  BuildContext context,
  AdminPlatformConfig config,
  AppUser? currentUser,
) async {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  var selectedRole = UserRole.vendor;
  var selectedStatus = AccountStatus.approved;
  String? selectedCustomRole;
  final availableRoles = currentUser?.role == UserRole.superAdmin
      ? UserRole.values
      : UserRole.values
            .where((role) => role != UserRole.superAdmin)
            .toList(growable: false);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            title: const Text('Create user credentials'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Temporary password',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Base role'),
                      items: availableRoles
                          .map(
                            (role) => DropdownMenuItem<UserRole>(
                              value: role,
                              child: Text(role.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          selectedRole = value;
                          if (!selectedRole.isAdminFamily) {
                            selectedCustomRole = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<AccountStatus>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Account status',
                      ),
                      items: AccountStatus.values
                          .map(
                            (status) => DropdownMenuItem<AccountStatus>(
                              value: status,
                              child: Text(status.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStatus = value);
                        }
                      },
                    ),
                    if (selectedRole.isAdminFamily) ...[
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedCustomRole,
                        decoration: const InputDecoration(
                          labelText: 'Custom admin role',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No custom role'),
                          ),
                          ...config.roleDefinitions.map(
                            (role) => DropdownMenuItem<String?>(
                              value: role.key,
                              child: Text(role.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedCustomRole = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ProviderScope.containerOf(context)
                      .read(adminDashboardControllerProvider.notifier)
                      .createUser(
                        displayName: nameController.text.trim(),
                        email: emailController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        password: passwordController.text.trim(),
                        role: selectedRole.value,
                        status: selectedStatus.value,
                        customRoleKey: selectedRole.isAdminFamily
                            ? selectedCustomRole
                            : null,
                      );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showCommissionDialog(
  BuildContext context,
  AdminPlatformConfig config,
) async {
  final controller = TextEditingController(
    text: (config.globalCommissionRate * 100).toStringAsFixed(0),
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: const Text('Update commission'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Commission %',
            hintText: '18',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value =
                  (double.tryParse(controller.text.trim()) ?? 0) / 100;
              await ProviderScope.containerOf(context)
                  .read(adminDashboardControllerProvider.notifier)
                  .updateCommission(value);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<void> _showSimpleInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _showEditUserDialog(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
  AdminPlatformConfig config,
) async {
  final nameController = TextEditingController(text: user.displayName);
  final emailController = TextEditingController(text: user.email);
  final phoneController = TextEditingController(text: user.phoneNumber);
  var selectedRole = user.role;
  var selectedStatus = user.status;
  String? selectedCustomRole = user.customRoleKey;
  final currentUser = ref.read(authControllerProvider).valueOrNull?.user;
  final availableRoles = currentUser?.role == UserRole.superAdmin
      ? UserRole.values
      : UserRole.values
            .where((role) => role != UserRole.superAdmin)
            .toList(growable: false);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            title: Text('Employee details: ${user.displayName}'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account created ${_formatDate(user.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Base role'),
                      items: availableRoles
                          .map(
                            (role) => DropdownMenuItem<UserRole>(
                              value: role,
                              child: Text(role.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          selectedRole = value;
                          if (!selectedRole.isAdminFamily) {
                            selectedCustomRole = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<AccountStatus>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Account status',
                      ),
                      items: AccountStatus.values
                          .map(
                            (status) => DropdownMenuItem<AccountStatus>(
                              value: status,
                              child: Text(status.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStatus = value);
                        }
                      },
                    ),
                    if (selectedRole.isAdminFamily) ...[
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedCustomRole,
                        decoration: const InputDecoration(
                          labelText: 'Custom role',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No custom role'),
                          ),
                          ...config.roleDefinitions.map(
                            (role) => DropdownMenuItem<String?>(
                              value: role.key,
                              child: Text(role.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedCustomRole = value),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        Chip(label: Text('Wallet Rs ${user.walletBalance}')),
                        Chip(label: Text('Status ${user.status.label}')),
                        if (user.documentName != null ||
                            user.documentUrl != null)
                          Chip(
                            label: Text(
                              'Doc ${user.documentName ?? 'Available'}',
                            ),
                          ),
                      ],
                    ),
                    if (user.rejectionReason != null &&
                        user.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text('Review note: ${user.rejectionReason}'),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(adminDashboardControllerProvider.notifier)
                      .updateUserProfile(
                        userId: user.id,
                        displayName: nameController.text.trim(),
                        email: emailController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        role: selectedRole.value,
                        status: selectedStatus.value,
                        customRoleKey: selectedRole.isAdminFamily
                            ? selectedCustomRole
                            : null,
                      );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Save changes'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showResetPasswordDialog(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) async {
  final passwordController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: Text('Reset password: ${user.displayName}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              hintText: 'Minimum 8 characters',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(adminDashboardControllerProvider.notifier)
                  .resetUserPassword(
                    userId: user.id,
                    password: passwordController.text.trim(),
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Reset password'),
          ),
        ],
      );
    },
  );
}

Future<void> _showVendorStoreDialog(
  BuildContext context,
  AdminRestaurantModel? restaurant,
  List<AppUser> vendors,
) async {
  if (vendors.isEmpty) {
    return;
  }

  final ownerOptions = vendors
      .where((user) => user.status == AccountStatus.approved)
      .toList(growable: false);
  final ownerChoices = ownerOptions.isNotEmpty ? ownerOptions : vendors;
  final fallbackOwnerId = ownerChoices.first.id;
  var selectedOwnerId = restaurant?.ownerId ?? fallbackOwnerId;
  final nameController = TextEditingController(text: restaurant?.name ?? '');
  final categoryController = TextEditingController(
    text: restaurant?.category ?? 'Meals',
  );
  final cuisineController = TextEditingController(
    text: restaurant?.cuisine.join(', ') ?? '',
  );
  final descriptionController = TextEditingController(
    text: restaurant?.description ?? '',
  );
  final offerController = TextEditingController(
    text: restaurant?.offerText ?? '',
  );
  final deliveryTimeController = TextEditingController(
    text: restaurant?.deliveryTime.toString() ?? '25',
  );
  final priceLevelController = TextEditingController(
    text: restaurant?.priceLevel ?? 'Rs 300 for two',
  );
  final commissionController = TextEditingController(
    text: (restaurant?.commissionRate ?? 0.18).toString(),
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, _) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: true,
              title: Text(
                restaurant == null
                    ? 'Create vendor store'
                    : 'Manage vendor store',
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedOwnerId,
                        decoration: const InputDecoration(
                          labelText: 'Vendor owner',
                        ),
                        items: ownerChoices
                            .map(
                              (vendor) => DropdownMenuItem<String>(
                                value: vendor.id,
                                child: Text(
                                  '${vendor.displayName} • ${vendor.email}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedOwnerId = value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Store name',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: cuisineController,
                        decoration: const InputDecoration(
                          labelText: 'Cuisine',
                          hintText: 'North Indian, Snacks',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: offerController,
                        decoration: const InputDecoration(
                          labelText: 'Offer text',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: deliveryTimeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Delivery time',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextField(
                              controller: commissionController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Commission rate',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: priceLevelController,
                        decoration: const InputDecoration(
                          labelText: 'Price level',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final notifier = ref.read(
                      adminDashboardControllerProvider.notifier,
                    );
                    if (restaurant == null) {
                      await notifier.createVendorStore(
                        ownerId: selectedOwnerId,
                        name: nameController.text.trim(),
                        category: categoryController.text.trim(),
                        cuisine: cuisineController.text.trim(),
                        description: descriptionController.text.trim(),
                        offerText: offerController.text.trim(),
                        deliveryTime:
                            int.tryParse(deliveryTimeController.text.trim()) ??
                            25,
                        priceLevel: priceLevelController.text.trim(),
                        commissionRate:
                            double.tryParse(commissionController.text.trim()) ??
                            0.18,
                      );
                    } else {
                      await notifier.updateVendorStore(
                        restaurantId: restaurant.id,
                        ownerId: selectedOwnerId,
                        name: nameController.text.trim(),
                        category: categoryController.text.trim(),
                        cuisine: cuisineController.text.trim(),
                        description: descriptionController.text.trim(),
                        offerText: offerController.text.trim(),
                        deliveryTime:
                            int.tryParse(deliveryTimeController.text.trim()) ??
                            25,
                        priceLevel: priceLevelController.text.trim(),
                        commissionRate:
                            double.tryParse(commissionController.text.trim()) ??
                            0.18,
                      );
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(
                    restaurant == null ? 'Create store' : 'Save store',
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

Future<void> _showDeleteUserDialog(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: Text('Delete ${user.displayName}?'),
        content: Text(
          'This will permanently remove the ${user.role.label.toLowerCase()} account for ${user.email}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              await ref
                  .read(adminDashboardControllerProvider.notifier)
                  .deleteUser(user.id);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Delete account'),
          ),
        ],
      );
    },
  );
}

Future<void> _showRoleAssignmentDialog(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
  AdminPlatformConfig config,
) async {
  String selectedBaseRole = user.role.value;
  String? selectedCustomRole = user.customRoleKey;
  final currentUser = ref.read(authControllerProvider).valueOrNull?.user;
  final availableRoles = currentUser?.role == UserRole.superAdmin
      ? UserRole.values
      : UserRole.values
            .where((role) => role != UserRole.superAdmin)
            .toList(growable: false);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            title: Text('Assign role to ${user.displayName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedBaseRole,
                  decoration: const InputDecoration(labelText: 'Base role'),
                  items: availableRoles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role.value,
                          child: Text(role.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedBaseRole = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: selectedCustomRole,
                  decoration: const InputDecoration(labelText: 'Custom role'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No custom role'),
                    ),
                    ...config.roleDefinitions.map(
                      (role) => DropdownMenuItem(
                        value: role.key,
                        child: Text(role.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedCustomRole = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(adminDashboardControllerProvider.notifier)
                      .assignCustomRole(
                        userId: user.id,
                        role: selectedBaseRole,
                        customRoleKey: selectedCustomRole,
                      );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showRolesDialog(
  BuildContext context,
  AdminPlatformConfig config,
) async {
  final nameController = TextEditingController();
  final permissionsController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: const Text('Roles & permissions'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...config.roleDefinitions.map(
                  (role) => Card(
                    child: ListTile(
                      title: Text(role.name),
                      subtitle: Text(role.permissions.join(', ')),
                      trailing: IconButton(
                        onPressed: () async {
                          await _showEditRoleDialog(context, role);
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'New role name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: permissionsController,
                  decoration: const InputDecoration(
                    labelText: 'Permissions',
                    hintText: 'users:manage, reports:view, commission:manage',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              await ProviderScope.containerOf(context)
                  .read(adminDashboardControllerProvider.notifier)
                  .createRole(
                    name: nameController.text.trim(),
                    permissions: permissionsController.text
                        .split(',')
                        .map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .toList(growable: false),
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Create role'),
          ),
        ],
      );
    },
  );
}

Future<void> _showEditRoleDialog(
  BuildContext context,
  AdminRoleDefinition role,
) async {
  final nameController = TextEditingController(text: role.name);
  final permissionsController = TextEditingController(
    text: role.permissions.join(', '),
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: Text('Edit ${role.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Role name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: permissionsController,
              decoration: const InputDecoration(labelText: 'Permissions'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ProviderScope.containerOf(context)
                  .read(adminDashboardControllerProvider.notifier)
                  .updateRole(
                    key: role.key,
                    name: nameController.text.trim(),
                    permissions: permissionsController.text
                        .split(',')
                        .map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .toList(growable: false),
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<void> _showCategoriesDialog(
  BuildContext context,
  AdminPlatformConfig config,
) async {
  final controller = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: const Text('Manage categories'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...config.managedCategories.map(
                  (category) => SwitchListTile(
                    value: category.isActive,
                    title: Text(category.name),
                    onChanged: (value) async {
                      await ProviderScope.containerOf(context)
                          .read(adminDashboardControllerProvider.notifier)
                          .updateCategory(
                            categoryId: category.id,
                            name: category.name,
                            isActive: value,
                          );
                    },
                  ),
                ),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'New category'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              await ProviderScope.containerOf(context)
                  .read(adminDashboardControllerProvider.notifier)
                  .createCategory(controller.text.trim());
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}

Future<void> _showBannersDialog(
  BuildContext context,
  AdminPlatformConfig config,
) async {
  final titleController = TextEditingController();
  final subtitleController = TextEditingController();
  final ctaController = TextEditingController(text: 'Order now');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: const Text('Manage banners'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...config.marketingBanners.map(
                  (banner) => SwitchListTile(
                    value: banner.isActive,
                    title: Text(banner.title),
                    subtitle: Text('${banner.subtitle} • ${banner.ctaText}'),
                    onChanged: (value) async {
                      await ProviderScope.containerOf(context)
                          .read(adminDashboardControllerProvider.notifier)
                          .updateBanner(
                            bannerId: banner.id,
                            title: banner.title,
                            subtitle: banner.subtitle,
                            ctaText: banner.ctaText,
                            isActive: value,
                          );
                    },
                  ),
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Banner title'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: subtitleController,
                  decoration: const InputDecoration(labelText: 'Subtitle'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: ctaController,
                  decoration: const InputDecoration(labelText: 'CTA text'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              await ProviderScope.containerOf(context)
                  .read(adminDashboardControllerProvider.notifier)
                  .createBanner(
                    title: titleController.text.trim(),
                    subtitle: subtitleController.text.trim(),
                    ctaText: ctaController.text.trim(),
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Create banner'),
          ),
        ],
      );
    },
  );
}

Future<void> _showWebsiteSettingsDialog(
  BuildContext context,
  AdminWebsiteSettings settings,
) async {
  final headlineController = TextEditingController(text: settings.headline);
  final subtitleController = TextEditingController(text: settings.subtitle);
  final links = settings.qrLinks
      .map(
        (item) => _EditableWebsiteQrLink(
          id: item.id,
          titleController: TextEditingController(text: item.title),
          descriptionController: TextEditingController(text: item.description),
          urlController: TextEditingController(text: item.url),
          isActive: item.isActive,
        ),
      )
      .toList(growable: false);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            title: const Text('Website & QR access'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: headlineController,
                      decoration: const InputDecoration(
                        labelText: 'Website headline',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: subtitleController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Website subtitle',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...links.map(
                      (entry) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: entry.isActive,
                                title: Text(entry.titleController.text),
                                subtitle: Text('QR card visibility'),
                                onChanged: (value) =>
                                    setState(() => entry.isActive = value),
                              ),
                              TextField(
                                controller: entry.titleController,
                                decoration: const InputDecoration(
                                  labelText: 'QR title',
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: entry.descriptionController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'QR description',
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: entry.urlController,
                                decoration: const InputDecoration(
                                  labelText: 'QR destination URL',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final updated = AdminWebsiteSettings(
                    headline: headlineController.text.trim(),
                    subtitle: subtitleController.text.trim(),
                    qrLinks: links
                        .map(
                          (entry) => AdminWebsiteQrLink(
                            id: entry.id,
                            title: entry.titleController.text.trim(),
                            description: entry.descriptionController.text
                                .trim(),
                            url: entry.urlController.text.trim(),
                            isActive: entry.isActive,
                          ),
                        )
                        .toList(growable: false),
                  );
                  await ProviderScope.containerOf(context)
                      .read(adminDashboardControllerProvider.notifier)
                      .updateWebsiteSettings(updated);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Save website settings'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _EditableWebsiteQrLink {
  _EditableWebsiteQrLink({
    required this.id,
    required this.titleController,
    required this.descriptionController,
    required this.urlController,
    required this.isActive,
  });

  final String id;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController urlController;
  bool isActive;
}

Future<void> _showBroadcastDialog(BuildContext context) async {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final selectedRoles = <String>{
    'CUSTOMER',
    'VENDOR',
    'DELIVERY_PARTNER',
    'SUPER_ADMIN',
    'ADMIN',
    'MANAGER',
  };

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            title: const Text('Broadcast notification'),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: bodyController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final role in const [
                          'CUSTOMER',
                          'VENDOR',
                          'DELIVERY_PARTNER',
                          'SUPER_ADMIN',
                          'ADMIN',
                          'MANAGER',
                        ])
                          FilterChip(
                            label: Text(role),
                            selected: selectedRoles.contains(role),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  selectedRoles.add(role);
                                } else {
                                  selectedRoles.remove(role);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ProviderScope.containerOf(context)
                      .read(adminDashboardControllerProvider.notifier)
                      .broadcastNotification(
                        title: titleController.text.trim(),
                        body: bodyController.text.trim(),
                        targetRoles: selectedRoles.toList(growable: false),
                      );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Send'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showReportPeriodDialog(
  BuildContext context,
  ValueChanged<int> onReportRequested,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: const Text('Generate reports'),
        content: const Text(
          'Select a reporting window to refresh the admin report section.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              onReportRequested(7);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('7 days'),
          ),
          TextButton(
            onPressed: () {
              onReportRequested(30);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('30 days'),
          ),
          FilledButton(
            onPressed: () {
              onReportRequested(90);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('90 days'),
          ),
        ],
      );
    },
  );
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
