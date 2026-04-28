import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/breakpoints.dart';
import '../../../../models/vendor_models.dart';
import '../../../../services/media/image_compression_service.dart';
import '../../../../shared/widgets/app_async_state.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_paginated_column.dart';
import '../controllers/vendor_dashboard_controller.dart';

class VendorDashboardPage extends ConsumerStatefulWidget {
  const VendorDashboardPage({super.key});

  @override
  ConsumerState<VendorDashboardPage> createState() =>
      _VendorDashboardPageState();
}

class _VendorDashboardPageState extends ConsumerState<VendorDashboardPage> {
  late final ProviderSubscription<AsyncValue<VendorDashboardState>>
  _subscription;
  _VendorSection _selectedSection = _VendorSection.overview;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(vendorDashboardControllerProvider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }

      final previousData = previous?.valueOrNull;
      final nextData = next.valueOrNull;
      if (previousData == null || nextData == null) {
        return;
      }

      final previousPlacedIds = previousData.orders
          .where((order) => order.status == 'PLACED')
          .map((order) => order.id)
          .toSet();
      final incomingOrders = nextData.orders.where(
        (order) =>
            order.status == 'PLACED' && !previousPlacedIds.contains(order.id),
      );

      for (final order in incomingOrders) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'New order received: ${order.id.substring(0, 8)} for Rs ${order.total}',
              ),
            ),
          );
      }
    });
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorDashboardControllerProvider);

    return state.when(
      data: (data) => _VendorDashboardBody(
        data: data,
        selectedSection: _selectedSection,
        onSectionSelected: (section) =>
            setState(() => _selectedSection = section),
      ),
      loading: () =>
          const AppLoadingState(message: 'Loading your vendor dashboard...'),
      error: (error, stackTrace) => AppErrorState(
        message: error.toString(),
        onRetry: () =>
            ref.read(vendorDashboardControllerProvider.notifier).refresh(),
      ),
    );
  }
}

class _VendorDashboardBody extends ConsumerWidget {
  const _VendorDashboardBody({
    required this.data,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final VendorDashboardState data;
  final _VendorSection selectedSection;
  final ValueChanged<_VendorSection> onSectionSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= Breakpoints.desktop;
    final showSidebar = width >= 1180;
    final restaurant = data.restaurant;

    if (restaurant == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final overviewCards = _buildOverviewCards(data);
    final groupedSections = _buildVendorSidebarGroups();

    final content = ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        _VendorTopbar(
          section: selectedSection,
          storeStatus: restaurant.storeStatus,
          onStoreStatusChanged: (isOpen) => ref
              .read(vendorDashboardControllerProvider.notifier)
              .updateStoreStatus(isOpen ? 'OPEN' : 'CLOSED'),
          notificationCount: data.orders
              .where((o) => o.status == 'PLACED')
              .length,
        ),
        const SizedBox(height: AppSpacing.md),
        if (!showSidebar) ...[
          _VendorSectionTabs(
            selectedSection: selectedSection,
            onSelected: onSectionSelected,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _PartnerHeader(restaurant: restaurant, today: data.today),
        const SizedBox(height: AppSpacing.lg),
        ..._buildSectionContent(
          context,
          ref,
          data,
          restaurant,
          selectedSection,
          overviewCards,
          isWide,
          onSectionSelected,
        ),
      ],
    );

    if (!showSidebar) {
      return content;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 292,
          child: _VendorSidebar(
            groups: groupedSections,
            selectedSection: selectedSection,
            onSelected: onSectionSelected,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: content),
      ],
    );
  }
}

enum _VendorSection {
  overview,
  todaySummary,
  newOrders,
  preparingOrders,
  readyForPickup,
  completedOrders,
  cancelledOrders,
  allProducts,
  addProduct,
  categories,
  addCategory,
  stockManagement,
  dailySales,
  weeklySales,
  monthlySales,
  totalEarnings,
  commissionDeduction,
  settlementHistory,
  tableReservations,
  bookingStatus,
  restaurantDetails,
  bankDetails,
  workingHours,
  uploadDocuments,
  notificationSettings,
}

extension on _VendorSection {
  String get label => switch (this) {
    _VendorSection.overview => 'Overview',
    _VendorSection.todaySummary => 'Today\'s Summary',
    _VendorSection.newOrders => 'New Orders',
    _VendorSection.preparingOrders => 'Preparing Orders',
    _VendorSection.readyForPickup => 'Ready for Pickup',
    _VendorSection.completedOrders => 'Completed Orders',
    _VendorSection.cancelledOrders => 'Cancelled Orders',
    _VendorSection.allProducts => 'All Products',
    _VendorSection.addProduct => 'Add Product',
    _VendorSection.categories => 'Categories',
    _VendorSection.addCategory => 'Add Category',
    _VendorSection.stockManagement => 'Stock Management',
    _VendorSection.dailySales => 'Daily Sales',
    _VendorSection.weeklySales => 'Weekly Sales',
    _VendorSection.monthlySales => 'Monthly Sales',
    _VendorSection.totalEarnings => 'Total Earnings',
    _VendorSection.commissionDeduction => 'Commission Deduction',
    _VendorSection.settlementHistory => 'Settlement History',
    _VendorSection.tableReservations => 'Table Reservations',
    _VendorSection.bookingStatus => 'Booking Status',
    _VendorSection.restaurantDetails => 'Restaurant Details',
    _VendorSection.bankDetails => 'Bank Details',
    _VendorSection.workingHours => 'Working Hours',
    _VendorSection.uploadDocuments => 'Upload Documents',
    _VendorSection.notificationSettings => 'Notification Settings',
  };

  IconData get icon => switch (this) {
    _VendorSection.overview => Icons.dashboard_outlined,
    _VendorSection.todaySummary => Icons.today_outlined,
    _VendorSection.newOrders => Icons.notifications_active_outlined,
    _VendorSection.preparingOrders => Icons.soup_kitchen_outlined,
    _VendorSection.readyForPickup => Icons.shopping_bag_outlined,
    _VendorSection.completedOrders => Icons.task_alt_outlined,
    _VendorSection.cancelledOrders => Icons.cancel_outlined,
    _VendorSection.allProducts => Icons.restaurant_menu_outlined,
    _VendorSection.addProduct => Icons.add_box_outlined,
    _VendorSection.categories => Icons.category_outlined,
    _VendorSection.addCategory => Icons.playlist_add_outlined,
    _VendorSection.stockManagement => Icons.inventory_2_outlined,
    _VendorSection.dailySales => Icons.bar_chart_outlined,
    _VendorSection.weeklySales => Icons.query_stats_outlined,
    _VendorSection.monthlySales => Icons.show_chart_outlined,
    _VendorSection.totalEarnings => Icons.account_balance_wallet_outlined,
    _VendorSection.commissionDeduction => Icons.percent_outlined,
    _VendorSection.settlementHistory => Icons.receipt_long_outlined,
    _VendorSection.tableReservations => Icons.event_seat_outlined,
    _VendorSection.bookingStatus => Icons.calendar_today_outlined,
    _VendorSection.restaurantDetails => Icons.storefront_outlined,
    _VendorSection.bankDetails => Icons.account_balance_outlined,
    _VendorSection.workingHours => Icons.schedule_outlined,
    _VendorSection.uploadDocuments => Icons.upload_file_outlined,
    _VendorSection.notificationSettings => Icons.settings_outlined,
  };
}

class _VendorSidebarGroup {
  const _VendorSidebarGroup({required this.title, required this.items});

  final String title;
  final List<_VendorSection> items;
}

List<_VendorSidebarGroup> _buildVendorSidebarGroups() {
  return const [
    _VendorSidebarGroup(
      title: 'Dashboard',
      items: [_VendorSection.overview, _VendorSection.todaySummary],
    ),
    _VendorSidebarGroup(
      title: 'Orders',
      items: [
        _VendorSection.newOrders,
        _VendorSection.preparingOrders,
        _VendorSection.readyForPickup,
        _VendorSection.completedOrders,
        _VendorSection.cancelledOrders,
      ],
    ),
    _VendorSidebarGroup(
      title: 'Menu Management',
      items: [
        _VendorSection.allProducts,
        _VendorSection.addProduct,
        _VendorSection.categories,
        _VendorSection.addCategory,
        _VendorSection.stockManagement,
      ],
    ),
    _VendorSidebarGroup(
      title: 'Reports',
      items: [
        _VendorSection.dailySales,
        _VendorSection.weeklySales,
        _VendorSection.monthlySales,
      ],
    ),
    _VendorSidebarGroup(
      title: 'Earnings',
      items: [
        _VendorSection.totalEarnings,
        _VendorSection.commissionDeduction,
        _VendorSection.settlementHistory,
      ],
    ),
    _VendorSidebarGroup(
      title: 'Dine-in Booking',
      items: [_VendorSection.tableReservations, _VendorSection.bookingStatus],
    ),
    _VendorSidebarGroup(
      title: 'Profile',
      items: [
        _VendorSection.restaurantDetails,
        _VendorSection.bankDetails,
        _VendorSection.workingHours,
        _VendorSection.uploadDocuments,
      ],
    ),
    _VendorSidebarGroup(
      title: 'Settings',
      items: [_VendorSection.notificationSettings],
    ),
  ];
}

List<_VendorQuickCard> _buildOverviewCards(VendorDashboardState data) {
  final openOrders = data.orders
      .where((order) => !{'DELIVERED', 'CANCELLED'}.contains(order.status))
      .length;
  final deliveredOrders = data.orders
      .where((order) => order.status == 'DELIVERED')
      .length;

  return [
    _VendorQuickCard(
      title: 'Today\'s Orders',
      value: '${data.today.orderCount}',
      subtitle: 'New and active orders for today',
      icon: Icons.receipt_long_outlined,
      trend:
          '+${data.weekly.orderCount == 0 ? 0 : ((data.today.orderCount / data.weekly.orderCount) * 100).round()}%',
      section: _VendorSection.newOrders,
    ),
    _VendorQuickCard(
      title: 'Today\'s Revenue',
      value: 'Rs ${data.today.grossSales}',
      subtitle: 'Gross sales before commission',
      icon: Icons.currency_rupee_outlined,
      trend:
          '+${data.monthly.grossSales == 0 ? 0 : ((data.today.grossSales / data.monthly.grossSales) * 100).round()}%',
      section: _VendorSection.totalEarnings,
    ),
    _VendorQuickCard(
      title: 'Pending Orders',
      value: '$openOrders',
      subtitle: 'Orders still in progress',
      icon: Icons.timelapse_outlined,
      trend: openOrders > 0 ? 'Action needed' : 'Queue clear',
      section: _VendorSection.preparingOrders,
    ),
    _VendorQuickCard(
      title: 'Commission Deducted',
      value: 'Rs ${data.today.commissionDeduction}',
      subtitle: 'Today\'s platform fee',
      icon: Icons.percent_outlined,
      trend: '$deliveredOrders completed',
      section: _VendorSection.commissionDeduction,
    ),
  ];
}

List<Widget> _buildSectionContent(
  BuildContext context,
  WidgetRef ref,
  VendorDashboardState data,
  VendorRestaurantModel restaurant,
  _VendorSection section,
  List<_VendorQuickCard> overviewCards,
  bool isWide,
  ValueChanged<_VendorSection> onSectionSelected,
) {
  switch (section) {
    case _VendorSection.overview:
      return [
        _VendorQuickStatsGrid(
          cards: overviewCards,
          onSelected: onSectionSelected,
        ),
        const SizedBox(height: AppSpacing.lg),
        _VendorChartsBand(data: data),
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(title: 'Recent Orders Table'),
        const SizedBox(height: AppSpacing.sm),
        _OrderListSection(orders: data.orders.take(6).toList(growable: false)),
      ];
    case _VendorSection.todaySummary:
      return [
        _VendorQuickStatsGrid(
          cards: overviewCards,
          onSelected: onSectionSelected,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ReportCard(
          title: 'Today',
          subtitle: 'Today\'s earnings and commission',
          report: data.today,
        ),
      ];
    case _VendorSection.newOrders:
      return [
        _OrderModuleSection(
          title: 'New Orders',
          subtitle:
              'Placed orders waiting for accept or reject action from the kitchen.',
          orders: data.orders
              .where((o) => o.status == 'PLACED')
              .toList(growable: false),
        ),
      ];
    case _VendorSection.preparingOrders:
      return [
        _OrderModuleSection(
          title: 'Preparing Orders',
          subtitle:
              'Accepted and preparing orders that still need kitchen work.',
          orders: data.orders
              .where((o) => {'ACCEPTED', 'PREPARING'}.contains(o.status))
              .toList(growable: false),
        ),
      ];
    case _VendorSection.readyForPickup:
      return [
        _OrderModuleSection(
          title: 'Ready for Pickup',
          subtitle:
              'This build does not yet expose a separate READY status in the vendor API, so handoff-ready orders will appear here once that backend step is added.',
          orders: data.orders
              .where((o) => o.status == 'OUT_FOR_DELIVERY')
              .toList(growable: false),
        ),
      ];
    case _VendorSection.completedOrders:
      return [
        _OrderModuleSection(
          title: 'Completed Orders',
          subtitle: 'Delivered orders with settlement values attached.',
          orders: data.orders
              .where((o) => o.status == 'DELIVERED')
              .toList(growable: false),
        ),
      ];
    case _VendorSection.cancelledOrders:
      return [
        _OrderModuleSection(
          title: 'Cancelled Orders',
          subtitle: 'Vendor or system cancelled orders for review and support.',
          orders: data.orders
              .where((o) => o.status == 'CANCELLED')
              .toList(growable: false),
        ),
      ];
    case _VendorSection.allProducts:
      return [
        _SectionTitle(
          title: 'All Products',
          action: FilledButton.icon(
            onPressed: () => _showProductDialog(context, ref),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add Product'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ProductsGrid(products: restaurant.products),
      ];
    case _VendorSection.addProduct:
      return [
        _ActionPromptCard(
          title: 'Add Product',
          description:
              'Create a new product with pricing, stock, category, and image upload.',
          ctaLabel: 'Open Product Form',
          onTap: () => _showProductDialog(context, ref),
        ),
      ];
    case _VendorSection.categories:
      final categories = restaurant.products
          .map((product) => product.category)
          .toSet()
          .toList(growable: false);
      return [_CategoriesSection(categories: categories)];
    case _VendorSection.addCategory:
      return [
        const _StaticInfoCard(
          title: 'Add Category',
          body:
              'Category creation is currently driven from product editing. A dedicated category API can be added next without changing this panel structure.',
          icon: Icons.playlist_add_outlined,
        ),
      ];
    case _VendorSection.stockManagement:
      return [_StockManagementSection(products: restaurant.products)];
    case _VendorSection.dailySales:
      return [
        _ReportCard(
          title: 'Daily Sales',
          subtitle: 'Date range: today',
          report: data.today,
        ),
      ];
    case _VendorSection.weeklySales:
      return [
        _ReportCard(
          title: 'Weekly Sales',
          subtitle: 'Date range: last 7 days',
          report: data.weekly,
        ),
      ];
    case _VendorSection.monthlySales:
      return [
        _ReportCard(
          title: 'Monthly Sales',
          subtitle: 'Date range: last 30 days',
          report: data.monthly,
        ),
      ];
    case _VendorSection.totalEarnings:
      return [
        _EarningsSummarySection(
          restaurant: restaurant,
          today: data.today,
          weekly: data.weekly,
          monthly: data.monthly,
        ),
      ];
    case _VendorSection.commissionDeduction:
      return [
        _CommissionSection(
          commissionRate: restaurant.commissionRate,
          today: data.today,
          weekly: data.weekly,
          monthly: data.monthly,
        ),
      ];
    case _VendorSection.settlementHistory:
      return [_SettlementSection(orders: data.orders)];
    case _VendorSection.tableReservations:
    case _VendorSection.bookingStatus:
      return [
        const AppEmptyState(
          title: 'Dine-in booking module ready for integration',
          message:
              'The vendor panel now has a dedicated booking space. Wire reservation APIs here when dine-in bookings are enabled.',
          icon: Icons.event_seat_outlined,
        ),
      ];
    case _VendorSection.restaurantDetails:
      return [_ProfileSection(restaurant: restaurant)];
    case _VendorSection.bankDetails:
      return [
        const _StaticInfoCard(
          title: 'Bank Details',
          body:
              'Account holder name, account number, IFSC, and bank name are not yet exposed by the vendor API. This page is ready for those fields.',
          icon: Icons.account_balance_outlined,
        ),
      ];
    case _VendorSection.workingHours:
      return [
        const _StaticInfoCard(
          title: 'Working Hours',
          body:
              'Working-hours controls are not yet available in the backend, but the vendor panel now includes a dedicated surface for them.',
          icon: Icons.schedule_outlined,
        ),
      ];
    case _VendorSection.uploadDocuments:
      return [
        const _StaticInfoCard(
          title: 'Upload Documents',
          body:
              'FSSAI, GST, and compliance uploads belong here once the restaurant profile endpoint exposes document storage.',
          icon: Icons.upload_file_outlined,
        ),
      ];
    case _VendorSection.notificationSettings:
      return [
        const _StaticInfoCard(
          title: 'Notification Settings',
          body:
              'New order alerts are already shown live. Granular notification toggles can plug into this settings module next.',
          icon: Icons.settings_outlined,
        ),
      ];
  }
}

class _VendorTopbar extends StatelessWidget {
  const _VendorTopbar({
    required this.section,
    required this.notificationCount,
    required this.storeStatus,
    required this.onStoreStatusChanged,
  });

  final _VendorSection section;
  final int notificationCount;
  final String storeStatus;
  final ValueChanged<bool> onStoreStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isCompact ? constraints.maxWidth : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.label,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Vendor Panel',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Icon(Icons.chevron_right, size: 16),
                            Text(
                              section.label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.saffron,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFF8F5EF),
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        storeStatus == 'OPEN' ? 'Store Open' : 'Store Closed',
                        style: TextStyle(
                          color: storeStatus == 'OPEN'
                              ? AppColors.darkGreen
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Switch(
                        value: storeStatus == 'OPEN',
                        onChanged: onStoreStatusChanged,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {},
                  tooltip: 'Notifications',
                  icon: Badge.count(
                    count: notificationCount,
                    isLabelVisible: notificationCount > 0,
                    child: const Icon(Icons.notifications_none),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VendorSidebar extends StatelessWidget {
  const _VendorSidebar({
    required this.groups,
    required this.selectedSection,
    required this.onSelected,
  });

  final List<_VendorSidebarGroup> groups;
  final _VendorSection selectedSection;
  final ValueChanged<_VendorSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Text(
                      group.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ...group.items.map(
                    (item) => _VendorSidebarTile(
                      section: item,
                      selected: item == selectedSection,
                      onTap: () => onSelected(item),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _VendorSidebarTile extends StatelessWidget {
  const _VendorSidebarTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _VendorSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? AppColors.saffron : Colors.transparent,
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
                Icon(
                  section.icon,
                  color: selected ? Colors.white : AppColors.ink,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
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

class _VendorSectionTabs extends StatelessWidget {
  const _VendorSectionTabs({
    required this.selectedSection,
    required this.onSelected,
  });

  final _VendorSection selectedSection;
  final ValueChanged<_VendorSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      _VendorSection.overview,
      _VendorSection.newOrders,
      _VendorSection.allProducts,
      _VendorSection.dailySales,
      _VendorSection.totalEarnings,
      _VendorSection.restaurantDetails,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: AppSpacing.sm,
        children: tabs
            .map(
              (section) => ChoiceChip(
                label: Text(section.label),
                selected: selectedSection == section,
                onSelected: (_) => onSelected(section),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _VendorQuickCard {
  const _VendorQuickCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.trend,
    required this.section,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String trend;
  final _VendorSection section;
}

class _VendorQuickStatsGrid extends StatelessWidget {
  const _VendorQuickStatsGrid({required this.cards, required this.onSelected});

  final List<_VendorQuickCard> cards;
  final ValueChanged<_VendorSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : 2;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected(card.section),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.sand,
                                  child: Icon(
                                    card.icon,
                                    color: AppColors.saffron,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  card.trend,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.darkGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(card.title),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              card.value,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(card.subtitle),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _VendorChartsBand extends StatelessWidget {
  const _VendorChartsBand({required this.data});

  final VendorDashboardState data;

  @override
  Widget build(BuildContext context) {
    final deliveryCount = data.orders
        .where((order) => order.orderMode == 'DELIVERY')
        .length;
    final pickupCount = data.orders
        .where((order) => order.orderMode == 'PICKUP')
        .length;
    final dineInCount = data.orders
        .where((order) => order.orderMode == 'DINE_IN')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSplit = constraints.maxWidth >= 980;
        final revenueCard = _SimpleGraphCard(
          title: 'Revenue Graph (Last 7 Days)',
          values: [
            data.today.grossSales,
            (data.weekly.grossSales / 2).round(),
            data.weekly.grossSales,
            (data.monthly.grossSales / 4).round(),
          ],
          labels: const ['Today', 'Midweek', '7D', '30D'],
        );
        final mixCard = _BreakdownCard(
          title: 'Orders Breakdown',
          rows: [
            _BreakdownRowData(label: 'Delivery', value: deliveryCount),
            _BreakdownRowData(label: 'Pickup', value: pickupCount),
            _BreakdownRowData(label: 'Dine-in', value: dineInCount),
          ],
        );

        if (showSplit) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: revenueCard),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: mixCard),
            ],
          );
        }

        return Column(
          children: [
            revenueCard,
            const SizedBox(height: AppSpacing.md),
            mixCard,
          ],
        );
      },
    );
  }
}

class _SimpleGraphCard extends StatelessWidget {
  const _SimpleGraphCard({
    required this.title,
    required this.values,
    required this.labels,
  });

  final String title;
  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(
      1,
      (prev, value) => value > prev ? value : prev,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (index) {
                  final heightFactor = values[index] / maxValue;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Rs ${values[index]}'),
                          const SizedBox(height: AppSpacing.xs),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: heightFactor.clamp(0.08, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.saffron,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(labels[index]),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRowData {
  const _BreakdownRowData({required this.label, required this.value});

  final String label;
  final int value;
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.rows});

  final String title;
  final List<_BreakdownRowData> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...rows.map((row) {
              final fraction = total == 0 ? 0.0 : row.value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(row.label)),
                        Text('${row.value}'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    LinearProgressIndicator(
                      value: fraction,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: AppColors.sand,
                      color: AppColors.saffron,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OrderModuleSection extends StatelessWidget {
  const _OrderModuleSection({
    required this.title,
    required this.subtitle,
    required this.orders,
  });

  final String title;
  final String subtitle;
  final List<VendorOrderModel> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: title),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle),
        const SizedBox(height: AppSpacing.md),
        _OrderListSection(orders: orders),
      ],
    );
  }
}

class _OrderListSection extends StatelessWidget {
  const _OrderListSection({required this.orders});

  final List<VendorOrderModel> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyCard(
        title: 'No orders in this queue',
        subtitle: 'Orders matching this workflow state will appear here.',
      );
    }

    return AppPaginatedColumn<VendorOrderModel>(
      items: orders,
      initialCount: 6,
      step: 6,
      itemBuilder: (context, order, index) => _VendorOrderCard(order: order),
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  const _ProductsGrid({required this.products});

  final List<VendorProductModel> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyCard(
        title: 'No products yet',
        subtitle: 'Add your first product to start receiving customer orders.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 2
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: products
              .map(
                (product) => SizedBox(
                  width: width,
                  child: _VendorProductCard(product: product),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.categories});

  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categories',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: categories
                  .map((category) => Chip(label: Text(category)))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockManagementSection extends StatelessWidget {
  const _StockManagementSection({required this.products});

  final List<VendorProductModel> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyCard(
        title: 'No stock to manage',
        subtitle:
            'Create products first and their stock controls will appear here.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: products
              .map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(product.name),
                  subtitle: Text(product.category),
                  trailing: Text(
                    '${product.stock} ${product.isAvailable ? 'In Stock' : 'Out of Stock'}',
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _EarningsSummarySection extends StatelessWidget {
  const _EarningsSummarySection({
    required this.restaurant,
    required this.today,
    required this.weekly,
    required this.monthly,
  });

  final VendorRestaurantModel restaurant;
  final VendorReportModel today;
  final VendorReportModel weekly;
  final VendorReportModel monthly;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _MetricCard(
                title: 'Gross Sales',
                value: 'Rs ${monthly.grossSales}',
                subtitle: 'Last 30 days',
              ),
              _MetricCard(
                title: 'Platform Commission',
                value: 'Rs ${monthly.commissionDeduction}',
                subtitle: 'Last 30 days',
              ),
              _MetricCard(
                title: 'Net Payable',
                value: 'Rs ${monthly.netPayout}',
                subtitle: 'After commission deductions',
              ),
              _MetricCard(
                title: 'Pending Settlement',
                value: 'Rs ${restaurant.pendingSettlementAmount}',
                subtitle: 'Awaiting settlement',
              ),
            ];
            final columns = constraints.maxWidth >= 1000 ? 4 : 2;
            final width =
                (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) /
                columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _ReportCard(
          title: 'Today',
          subtitle: 'Today\'s settled performance snapshot',
          report: today,
        ),
        const SizedBox(height: AppSpacing.md),
        _ReportCard(title: 'Weekly', subtitle: '7-day view', report: weekly),
      ],
    );
  }
}

class _CommissionSection extends StatelessWidget {
  const _CommissionSection({
    required this.commissionRate,
    required this.today,
    required this.weekly,
    required this.monthly,
  });

  final double commissionRate;
  final VendorReportModel today;
  final VendorReportModel weekly;
  final VendorReportModel monthly;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commission Settings',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${(commissionRate * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.saffron,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ReportRow(
              label: 'Today commission',
              value: today.commissionDeduction,
            ),
            _ReportRow(
              label: 'Weekly commission',
              value: weekly.commissionDeduction,
            ),
            _ReportRow(
              label: 'Monthly commission',
              value: monthly.commissionDeduction,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementSection extends StatelessWidget {
  const _SettlementSection({required this.orders});

  final List<VendorOrderModel> orders;

  @override
  Widget build(BuildContext context) {
    final settled = orders
        .where((order) => order.vendorSettlementAmount > 0)
        .toList(growable: false);

    if (settled.isEmpty) {
      return const _EmptyCard(
        title: 'No settlement history yet',
        subtitle: 'Completed orders with settlement values will appear here.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: settled
              .map(
                (order) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Order ${order.id.substring(0, 8)}'),
                  subtitle: Text(
                    'Gross Rs ${order.total} • Commission Rs ${order.commissionAmount}',
                  ),
                  trailing: Text('Net Rs ${order.vendorSettlementAmount}'),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.restaurant});

  final VendorRestaurantModel restaurant;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restaurant Details',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            _ProfileRow(label: 'Restaurant Name', value: restaurant.name),
            _ProfileRow(label: 'Offer Highlight', value: restaurant.offerText),
            _ProfileRow(label: 'Description', value: restaurant.description),
            _ProfileRow(
              label: 'Commission Rate',
              value: '${(restaurant.commissionRate * 100).toStringAsFixed(0)}%',
            ),
            _ProfileRow(
              label: 'Pending Settlement',
              value: 'Rs ${restaurant.pendingSettlementAmount}',
            ),
            _ProfileRow(
              label: 'Lifetime Settlement',
              value: 'Rs ${restaurant.lifetimeSettlementAmount}',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticInfoCard extends StatelessWidget {
  const _StaticInfoCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.saffron),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ActionPromptCard extends StatelessWidget {
  const _ActionPromptCard({
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(description),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_box_outlined),
              label: Text(ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader({required this.restaurant, required this.today});

  final VendorRestaurantModel restaurant;
  final VendorReportModel today;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, Color(0xFF124D39), AppColors.saffron],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'IndoFeast Partner Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  restaurant.offerText,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            restaurant.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            restaurant.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _HeaderChip(label: '${restaurant.products.length} products'),
              _HeaderChip(label: '${today.orderCount} orders today'),
              _HeaderChip(label: 'Net payout Rs ${today.netPayout}'),
              _HeaderChip(
                label:
                    'Pending settlement Rs ${restaurant.pendingSettlementAmount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VendorOrderCard extends ConsumerWidget {
  const _VendorOrderCard({required this.order});

  final VendorOrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(vendorDashboardControllerProvider.notifier);
    final canDecide = order.status == 'PLACED';
    final canStartPreparing = order.status == 'ACCEPTED';
    final canCancel = ['ACCEPTED', 'PREPARING'].contains(order.status);
    final canVerifyOtp =
        order.deliveryOtp != null &&
        order.deliveryOtp!.isNotEmpty &&
        ['ACCEPTED', 'PREPARING'].contains(order.status);
    final canVerifyDeliveryHandoff =
        canVerifyOtp &&
        order.orderMode == 'DELIVERY' &&
        order.deliveryPartnerName != null &&
        order.deliveryPartnerName!.isNotEmpty;
    final canVerifyGuestHandoff = canVerifyOtp && order.orderMode != 'DELIVERY';
    final actionButtons = <Widget>[
      if (canDecide)
        FilledButton.icon(
          onPressed: () =>
              controller.decideOrder(orderId: order.id, decision: 'ACCEPT'),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Accept order'),
        ),
      if (canStartPreparing)
        FilledButton.icon(
          onPressed: () => controller.updateOrderStatus(
            orderId: order.id,
            status: 'PREPARING',
          ),
          icon: const Icon(Icons.soup_kitchen_outlined),
          label: const Text('Start preparing'),
        ),
      if (canVerifyGuestHandoff)
        FilledButton.tonalIcon(
          onPressed: () => _showVendorOtpDialog(context, ref, order),
          icon: const Icon(Icons.password_outlined),
          label: Text(
            order.orderMode == 'PICKUP'
                ? 'Verify pickup OTP'
                : 'Verify dine-in OTP',
          ),
        ),
      if (canVerifyDeliveryHandoff)
        FilledButton.tonalIcon(
          onPressed: () => _showVendorOtpDialog(context, ref, order),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Verify rider handoff'),
        ),
      if (canCancel)
        OutlinedButton.icon(
          onPressed: () => controller.updateOrderStatus(
            orderId: order.id,
            status: 'CANCELLED',
          ),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel order'),
        ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${order.id.substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Chip(
                      label: Text(
                        order.status.replaceAll('_', ' '),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${order.orderMode.replaceAll('_', ' ')} • ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Customer: ${order.customerName} • ${order.paymentMethod} • ${order.paymentStatus}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.name} x${item.quantity}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Rs ${item.price * item.quantity}'),
                  ],
                ),
              ),
            ),
            const Divider(height: AppSpacing.xl),
            Row(
              children: [
                Text('Discount: Rs ${order.discount}'),
                const Spacer(),
                Text(
                  'Total: Rs ${order.total}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (order.deliveryPartnerName != null &&
                order.deliveryPartnerName!.isNotEmpty) ...[
              Text(
                'Delivery partner: ${order.deliveryPartnerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _OrderStatusFlow(status: order.status),
            const SizedBox(height: AppSpacing.md),
            if (canVerifyDeliveryHandoff)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x140F9D58),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x220F9D58)),
                ),
                child: Text(
                  'Ask ${order.deliveryPartnerName} for the order OTP, then verify the handoff here.',
                  style: const TextStyle(
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ...actionButtons,
                if (order.status == 'DELIVERED')
                  Chip(
                    label: Text(
                      'Settlement Rs ${order.vendorSettlementAmount}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showVendorOtpDialog(
  BuildContext context,
  WidgetRef ref,
  VendorOrderModel order,
) async {
  final controller = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(
        order.orderMode == 'DELIVERY'
            ? 'Verify rider OTP'
            : order.orderMode == 'PICKUP'
            ? 'Verify pickup OTP'
            : 'Verify dine-in OTP',
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Verification OTP',
          hintText: order.orderMode == 'DELIVERY'
              ? 'Enter the OTP shared by the rider'
              : 'Enter the OTP shared by the customer',
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
            await ref
                .read(vendorDashboardControllerProvider.notifier)
                .verifyOrderOtp(orderId: order.id, otp: controller.text.trim());
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          child: const Text('Verify OTP'),
        ),
      ],
    ),
  );
}

class _OrderStatusFlow extends StatelessWidget {
  const _OrderStatusFlow({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    const flow = ['PLACED', 'ACCEPTED', 'PREPARING', 'OUT_FOR_DELIVERY'];
    final currentIndex = flow.indexOf(status);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var index = 0; index < flow.length; index++)
          _OrderStatusStep(
            label: flow[index].replaceAll('_', ' '),
            isComplete:
                currentIndex > index ||
                (status == 'DELIVERED' && index == flow.length - 1),
            isCurrent: currentIndex == index,
          ),
        if (status == 'CANCELLED')
          const _OrderStatusStep(
            label: 'CANCELLED',
            isComplete: true,
            isCurrent: true,
            isDanger: true,
          ),
        if (status == 'DELIVERED')
          const _OrderStatusStep(
            label: 'DELIVERED',
            isComplete: true,
            isCurrent: true,
          ),
      ],
    );
  }
}

class _OrderStatusStep extends StatelessWidget {
  const _OrderStatusStep({
    required this.label,
    required this.isComplete,
    required this.isCurrent,
    this.isDanger = false,
  });

  final String label;
  final bool isComplete;
  final bool isCurrent;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDanger
        ? const Color(0x14D93025)
        : isCurrent
        ? const Color(0x1AFF6B00)
        : isComplete
        ? const Color(0x140F9D58)
        : const Color(0xFFF5F3EF);
    final foregroundColor = isDanger
        ? Colors.red.shade700
        : isCurrent
        ? AppColors.saffron
        : isComplete
        ? AppColors.darkGreen
        : AppColors.ink;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isCurrent
              ? const Color(0x33FF6B00)
              : isDanger
              ? const Color(0x33D93025)
              : const Color(0x150F5132),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _VendorProductCard extends ConsumerWidget {
  const _VendorProductCard({required this.product});

  final VendorProductModel product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(vendorDashboardControllerProvider.notifier);
    final imageUrl = AppConfig.buildAssetUrl(product.imagePath);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: const Color(0xFFF4F4F4),
              alignment: Alignment.center,
              child: imageUrl.isEmpty
                  ? const Icon(Icons.image_outlined, size: 42)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined, size: 42),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Switch(
                      value: product.isAvailable,
                      onChanged: (value) => controller.updateStock(
                        itemId: product.itemId,
                        stock: product.stock,
                        isAvailable: value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _TinyTag(label: product.category),
                    _TinyTag(label: 'Rs ${product.price}'),
                    _TinyTag(label: 'Stock ${product.stock}'),
                    _TinyTag(label: product.isVeg ? 'Veg' : 'Non-veg'),
                    if (product.discountPercent > 0)
                      _TinyTag(label: '${product.discountPercent}% OFF'),
                    _TinyTag(
                      label:
                          '${product.preparationTimeMin}-${product.preparationTimeMax} min',
                    ),
                    _TinyTag(
                      label: product.isAvailable ? 'Available' : 'Out of stock',
                    ),
                  ],
                ),
                if (product.addOns.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Add-ons: ${product.addOns.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (product.customizationOptions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Customizations: ${product.customizationOptions.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => controller.updateStock(
                        itemId: product.itemId,
                        stock: product.stock > 0 ? product.stock - 1 : 0,
                        isAvailable: product.stock > 1 && product.isAvailable,
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Reduce stock'),
                    ),
                    Chip(label: Text('Stock ${product.stock}')),
                    FilledButton.tonalIcon(
                      onPressed: () => controller.updateStock(
                        itemId: product.itemId,
                        stock: product.stock + 1,
                        isAvailable: true,
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add stock'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showProductDialog(context, ref, existing: product),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit product'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => controller.deleteProduct(product.itemId),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete product'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.report,
  });

  final String title;
  final String subtitle;
  final VendorReportModel report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle),
            const SizedBox(height: AppSpacing.md),
            _ReportRow(label: 'Gross sales', value: report.grossSales),
            _ReportRow(
              label: 'Commission deduction',
              value: report.commissionDeduction,
            ),
            _ReportRow(label: 'Net payout', value: report.netPayout),
            _ReportRow(label: 'Orders', value: report.orderCount),
            _ReportRow(
              label: 'Completed orders',
              value: report.completedOrders,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            label.contains('Orders') ? '$value' : 'Rs $value',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        action ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0x120F5132),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.store_mall_directory_outlined, size: 36),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<void> _showProductDialog(
  BuildContext context,
  WidgetRef ref, {
  VendorProductModel? existing,
}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final descriptionController = TextEditingController(
    text: existing?.description ?? '',
  );
  final categoryController = TextEditingController(
    text: existing?.category ?? 'Main Course',
  );
  final priceController = TextEditingController(
    text: existing?.price.toString() ?? '199',
  );
  final stockController = TextEditingController(
    text: existing?.stock.toString() ?? '20',
  );
  final discountController = TextEditingController(
    text: existing?.discountPercent.toString() ?? '0',
  );
  final prepMinController = TextEditingController(
    text: existing?.preparationTimeMin.toString() ?? '20',
  );
  final prepMaxController = TextEditingController(
    text: existing?.preparationTimeMax.toString() ?? '25',
  );
  final addOnsController = TextEditingController(
    text: existing?.addOns.join(', ') ?? '',
  );
  final customizationController = TextEditingController(
    text: existing?.customizationOptions.join(', ') ?? '',
  );
  bool isVeg = existing?.isVeg ?? true;
  bool bestseller = existing?.bestseller ?? false;
  bool isAvailable = existing?.isAvailable ?? true;
  Uint8List? imageBytes;
  String? imageName;

  Future<void> pickImage(StateSetter setState) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    if (file.bytes == null) {
      return;
    }

    final compressed = await ImageCompressionService.compress(
      bytes: file.bytes!,
      fileName: file.name,
    );

    setState(() {
      imageBytes = compressed.bytes;
      imageName = compressed.fileName;
    });
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            title: Text(existing == null ? 'Add product' : 'Edit product'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Discount %',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: prepMinController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prep min',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: prepMaxController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prep max',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: addOnsController,
                      decoration: const InputDecoration(
                        labelText: 'Add-ons',
                        hintText: 'Extra cheese, Raita, Coke',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: customizationController,
                      decoration: const InputDecoration(
                        labelText: 'Customizations',
                        hintText: 'Spice level, Less oil, No onion',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilterChip(
                          label: const Text('Veg'),
                          selected: isVeg,
                          onSelected: (value) => setState(() => isVeg = value),
                        ),
                        FilterChip(
                          label: const Text('Bestseller'),
                          selected: bestseller,
                          onSelected: (value) =>
                              setState(() => bestseller = value),
                        ),
                        FilterChip(
                          label: const Text('Available'),
                          selected: isAvailable,
                          onSelected: (value) =>
                              setState(() => isAvailable = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            imageName ??
                                existing?.imagePath ??
                                'No image selected',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => pickImage(setState),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload image'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final controller = ref.read(
                    vendorDashboardControllerProvider.notifier,
                  );

                  if (existing == null) {
                    await controller.createProduct(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      category: categoryController.text.trim(),
                      price: int.tryParse(priceController.text.trim()) ?? 0,
                      stock: int.tryParse(stockController.text.trim()) ?? 0,
                      isVeg: isVeg,
                      bestseller: bestseller,
                      isAvailable: isAvailable,
                      discountPercent:
                          int.tryParse(discountController.text.trim()) ?? 0,
                      preparationTimeMin:
                          int.tryParse(prepMinController.text.trim()) ?? 20,
                      preparationTimeMax:
                          int.tryParse(prepMaxController.text.trim()) ?? 25,
                      addOns: addOnsController.text.trim(),
                      customizationOptions: customizationController.text.trim(),
                      imageBytes: imageBytes,
                      imageName: imageName,
                    );
                  } else {
                    await controller.updateProduct(
                      itemId: existing.itemId,
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim(),
                      category: categoryController.text.trim(),
                      price: int.tryParse(priceController.text.trim()) ?? 0,
                      stock: int.tryParse(stockController.text.trim()) ?? 0,
                      isVeg: isVeg,
                      bestseller: bestseller,
                      isAvailable: isAvailable,
                      discountPercent:
                          int.tryParse(discountController.text.trim()) ?? 0,
                      preparationTimeMin:
                          int.tryParse(prepMinController.text.trim()) ?? 20,
                      preparationTimeMax:
                          int.tryParse(prepMaxController.text.trim()) ?? 25,
                      addOns: addOnsController.text.trim(),
                      customizationOptions: customizationController.text.trim(),
                      imageBytes: imageBytes,
                      imageName: imageName,
                    );
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
