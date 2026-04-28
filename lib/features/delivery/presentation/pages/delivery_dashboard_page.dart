import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/breakpoints.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../../models/app_user.dart';
import '../../../../models/delivery_models.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/location/location_service.dart';
import '../../../../shared/widgets/app_async_state.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_paginated_column.dart';
import '../controllers/delivery_dashboard_controller.dart';

enum _DeliveryTab { home, orders, earnings, profile }

class DeliveryDashboardPage extends ConsumerStatefulWidget {
  const DeliveryDashboardPage({super.key});

  @override
  ConsumerState<DeliveryDashboardPage> createState() =>
      _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends ConsumerState<DeliveryDashboardPage> {
  late final ProviderSubscription<AsyncValue<DeliveryDashboardState>>
  _subscription;
  _DeliveryTab _currentTab = _DeliveryTab.home;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(deliveryDashboardControllerProvider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }

      final previousData = previous?.valueOrNull;
      final nextData = next.valueOrNull;
      if (previousData != null && nextData != null) {
        final previousAvailableIds = previousData.availableOrders
            .map((order) => order.id)
            .toSet();
        final incomingAvailableOrders = nextData.availableOrders.where(
          (order) => !previousAvailableIds.contains(order.id),
        );

        for (final order in incomingAvailableOrders) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'New pickup order: ${order.restaurantName} • ${_shortOrderId(order.id)}',
                ),
              ),
            );
        }
      }

      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });
    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pushLiveLocation(),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _subscription.close();
    super.dispose();
  }

  Future<void> _pushLiveLocation() async {
    final data = ref.read(deliveryDashboardControllerProvider).valueOrNull;
    if (data == null || !(data.partner.deliveryProfile?.isOnline ?? false)) {
      return;
    }

    DeliveryOrderModel? activeOrder;
    for (final order in data.assignedOrders) {
      if (order.status != 'DELIVERED' && order.status != 'CANCELLED') {
        activeOrder = order;
        break;
      }
    }
    if (activeOrder == null) {
      return;
    }

    final point = await getCurrentGeoPoint();
    if (point == null) {
      return;
    }

    try {
      await ref
          .read(deliveryDashboardControllerProvider.notifier)
          .updateOrderLocation(
            orderId: activeOrder.id,
            latitude: point.latitude,
            longitude: point.longitude,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryDashboardControllerProvider);
    final user = ref.watch(authControllerProvider).valueOrNull?.user;

    return state.when(
      data: (data) => _DeliveryShell(
        currentTab: _currentTab,
        alertCount: _buildNotifications(data).length,
        onTabSelected: (tab) => setState(() => _currentTab = tab),
        onOpenNotifications: () => _showNotificationsSheet(context, data),
        onSignOut: () async {
          await ref.read(authControllerProvider.notifier).signOut();
          if (context.mounted) {
            context.go(RouteNames.login);
          }
        },
        child: _DeliveryScreenBody(
          currentTab: _currentTab,
          data: data,
          user: user,
          onOpenNotifications: () => _showNotificationsSheet(context, data),
        ),
      ),
      loading: () => const Scaffold(
        body: AppLoadingState(
          message: 'Loading your delivery partner panel...',
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: AppErrorState(
          message: error.toString(),
          onRetry: () =>
              ref.read(deliveryDashboardControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }

  Future<void> _showNotificationsSheet(
    BuildContext context,
    DeliveryDashboardState data,
  ) {
    final notifications = _buildNotifications(data);

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (notifications.isEmpty)
                const _EmptyCard(
                  title: 'No notifications right now',
                  subtitle:
                      'New order requests, cancellations, payouts, and bonus alerts will appear here.',
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(AppSpacing.md),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0x14FF6B00),
                            foregroundColor: AppColors.saffron,
                            child: Icon(item.icon),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(item.subtitle),
                          trailing: Text(item.meta),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryShell extends StatelessWidget {
  const _DeliveryShell({
    required this.currentTab,
    required this.alertCount,
    required this.onTabSelected,
    required this.onOpenNotifications,
    required this.onSignOut,
    required this.child,
  });

  final _DeliveryTab currentTab;
  final int alertCount;
  final ValueChanged<_DeliveryTab> onTabSelected;
  final VoidCallback onOpenNotifications;
  final VoidCallback onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= Breakpoints.tablet;
    final isCompact = width < 390;
    final horizontalPadding = width >= Breakpoints.desktop
        ? AppSpacing.xl
        : width >= Breakpoints.tablet
        ? AppSpacing.lg
        : AppSpacing.md;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompact ? 68 : 76,
        titleSpacing: horizontalPadding,
        title: Row(
          children: [
            const AppLogo(size: 34),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IndoFeast Delivery',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isCompact)
                    Text(
                      'Accept, pickup, deliver, track earnings',
                      style: Theme.of(context).textTheme.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: onOpenNotifications,
            icon: Badge(
              isLabelVisible: alertCount > 0,
              label: Text('$alertCount'),
              child: const Icon(Icons.notifications_active_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
          SizedBox(width: horizontalPadding),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: NavigationRail(
                selectedIndex: currentTab.index,
                onDestinationSelected: (index) =>
                    onTabSelected(_DeliveryTab.values[index]),
                extended: width >= Breakpoints.desktop,
                indicatorColor: AppColors.saffron,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: Text('Orders'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.currency_rupee_outlined),
                    selectedIcon: Icon(Icons.currency_rupee),
                    label: Text('Earnings'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Profile'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              height: isCompact ? 64 : 72,
              labelBehavior: width < 340
                  ? NavigationDestinationLabelBehavior.alwaysHide
                  : NavigationDestinationLabelBehavior.onlyShowSelected,
              selectedIndex: currentTab.index,
              onDestinationSelected: (index) =>
                  onTabSelected(_DeliveryTab.values[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.currency_rupee_outlined),
                  selectedIcon: Icon(Icons.currency_rupee),
                  label: 'Earnings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }
}

class _DeliveryScreenBody extends StatelessWidget {
  const _DeliveryScreenBody({
    required this.currentTab,
    required this.data,
    required this.user,
    required this.onOpenNotifications,
  });

  final _DeliveryTab currentTab;
  final DeliveryDashboardState data;
  final AppUser? user;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: switch (currentTab) {
        _DeliveryTab.home => _DeliveryHomeTab(
          key: const ValueKey('delivery-home'),
          data: data,
          onOpenNotifications: onOpenNotifications,
        ),
        _DeliveryTab.orders => _DeliveryOrdersTab(
          key: const ValueKey('delivery-orders'),
          data: data,
        ),
        _DeliveryTab.earnings => _DeliveryEarningsTab(
          key: const ValueKey('delivery-earnings'),
          data: data,
        ),
        _DeliveryTab.profile => _DeliveryProfileTab(
          key: const ValueKey('delivery-profile'),
          data: data,
          user: user,
        ),
      },
    );
  }
}

class _DeliveryHomeTab extends ConsumerWidget {
  const _DeliveryHomeTab({
    super.key,
    required this.data,
    required this.onOpenNotifications,
  });

  final DeliveryDashboardState data;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = data.partner;
    final profile = partner.deliveryProfile;
    final todayCompleted = data.paymentHistory
        .where((payment) => _isToday(payment.createdAt))
        .where((payment) => payment.category == 'DELIVERY_EARNING')
        .length;
    final pendingOrders = data.assignedOrders
        .where((order) => order.status != 'DELIVERED')
        .length;

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(deliveryDashboardControllerProvider.notifier).refresh(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _RiderHeroCard(
            partner: partner,
            data: data,
            onOpenNotifications: onOpenNotifications,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _StatsCard(
                title: "Today's earnings",
                value: _rupees(data.earnings.today),
                subtitle: 'Live shift total',
              ),
              _StatsCard(
                title: 'Completed orders',
                value: '$todayCompleted',
                subtitle: 'Completed today',
              ),
              _StatsCard(
                title: 'Pending orders',
                value: '$pendingOrders',
                subtitle: 'In your active queue',
              ),
              _StatsCard(
                title: 'Weekly earnings',
                value: _rupees(data.earnings.weekly),
                subtitle: 'Last 7 days',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Availability',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: (profile?.isOnline ?? false)
                          ? AppColors.mist
                          : AppColors.sand,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: (profile?.isOnline ?? false)
                              ? AppColors.darkGreen
                              : AppColors.saffron,
                          foregroundColor: Colors.white,
                          child: Icon(
                            (profile?.isOnline ?? false)
                                ? Icons.wifi_tethering
                                : Icons.pause_circle_outline,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (profile?.isOnline ?? false)
                                    ? 'Status = AVAILABLE'
                                    : 'Status = OFFLINE',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (profile?.isOnline ?? false)
                                    ? 'New order notifications are enabled.'
                                    : 'Turn on to start receiving order requests.',
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: profile?.isOnline ?? false,
                          onChanged: (value) => ref
                              .read(
                                deliveryDashboardControllerProvider.notifier,
                              )
                              .updateAvailability(value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Quick queue'),
          const SizedBox(height: AppSpacing.sm),
          if (data.availableOrders.isEmpty && data.assignedOrders.isEmpty)
            const _EmptyCard(
              title: 'No delivery jobs right now',
              subtitle:
                  'Go online and keep the app active to receive nearby orders.',
            )
          else
            Column(
              children: [
                if (data.availableOrders.isNotEmpty)
                  _OrderSnapshotCard(
                    title: 'Assigned orders',
                    count: data.availableOrders.length,
                    accent: AppColors.saffron,
                    subtitle: 'New jobs you can accept now',
                  ),
                if (data.assignedOrders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _OrderSnapshotCard(
                      title: 'Ongoing orders',
                      count: data.assignedOrders.length,
                      accent: AppColors.darkGreen,
                      subtitle: 'Active pickups and deliveries on your queue',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DeliveryOrdersTab extends StatelessWidget {
  const _DeliveryOrdersTab({super.key, required this.data});

  final DeliveryDashboardState data;

  @override
  Widget build(BuildContext context) {
    final assigned = data.availableOrders;
    final ongoing = data.assignedOrders
        .where((order) => order.status != 'DELIVERED')
        .toList(growable: false);
    final completed = data.paymentHistory
        .where((payment) => payment.category == 'DELIVERY_EARNING')
        .map((payment) => payment.orderId)
        .whereType<String>()
        .toSet();
    final completedOrders = data.assignedOrders
        .where(
          (order) =>
              order.status == 'DELIVERED' || completed.contains(order.id),
        )
        .toList(growable: false);
    final cancelledOrders = data.paymentHistory
        .where((payment) => payment.category == 'ADJUSTMENT')
        .toList(growable: false);

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orders',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Assigned'),
              Tab(text: 'Ongoing'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TabBarView(
              children: [
                _OrdersTabList(
                  title: 'Assigned orders',
                  emptyTitle: 'No assigned orders',
                  emptySubtitle:
                      'Newly assigned delivery jobs will appear here with accept and route actions.',
                  orders: assigned,
                  listType: _OrderListType.assigned,
                ),
                _OrdersTabList(
                  title: 'Ongoing orders',
                  emptyTitle: 'No ongoing orders',
                  emptySubtitle:
                      'Accepted and picked-up deliveries will appear here.',
                  orders: ongoing,
                  listType: _OrderListType.ongoing,
                ),
                _OrdersTabList(
                  title: 'Completed orders',
                  emptyTitle: 'No completed orders',
                  emptySubtitle:
                      'Delivered jobs and credited earnings will show here.',
                  orders: completedOrders,
                  listType: _OrderListType.completed,
                ),
                _CancelledPlaceholder(payments: cancelledOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryEarningsTab extends StatelessWidget {
  const _DeliveryEarningsTab({super.key, required this.data});

  final DeliveryDashboardState data;

  @override
  Widget build(BuildContext context) {
    final earningsRows = _buildEarningsRows(data);
    final totalPayable = data.earnings.lifetime;
    final paidAmount = data.paymentHistory
        .where((payment) => payment.category == 'DELIVERY_PAYOUT')
        .fold<int>(0, (sum, payment) => sum + payment.amount);
    final pendingAmount = (totalPayable - paidAmount).clamp(0, 1 << 31);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Earnings'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _StatsCard(
                title: "Today's earnings",
                value: _rupees(data.earnings.today),
                subtitle: 'Current shift',
              ),
              _StatsCard(
                title: 'Weekly earnings',
                value: _rupees(data.earnings.weekly),
                subtitle: 'Last 7 days',
              ),
              _StatsCard(
                title: 'Monthly earnings',
                value: _rupees(data.earnings.monthly),
                subtitle: 'Last 30 days',
              ),
              _StatsCard(
                title: 'Total earnings',
                value: _rupees(data.earnings.lifetime),
                subtitle: 'Lifetime credited',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Earnings breakdown',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (earningsRows.isEmpty)
                    const _EmptyCard(
                      title: 'No delivery earnings yet',
                      subtitle:
                          'Completed deliveries will add earnings rows here.',
                    )
                  else
                    ...earningsRows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _EarningsBreakdownCard(row: row),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payout section',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PriceLine(label: 'Total payable', value: totalPayable),
                  _PriceLine(label: 'Paid amount', value: paidAmount),
                  _PriceLine(label: 'Pending amount', value: pendingAmount),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incentives & bonus',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BonusTile(
                    title: 'Peak hour bonus',
                    value: _rupees(_peakHourBonus(data)),
                    subtitle: 'Applied on lunch and dinner rush deliveries',
                  ),
                  _BonusTile(
                    title: 'Target completion bonus',
                    value: _rupees(_targetBonus(data)),
                    subtitle: 'Unlock after 15 completed deliveries this week',
                  ),
                  _BonusTile(
                    title: 'Weekly incentive target',
                    value:
                        '${data.earnings.completedTrips}/15 deliveries completed',
                    subtitle: 'Stay online to finish your incentive target',
                  ),
                  const _BonusTile(
                    title: 'Referral bonus',
                    value: '₹0',
                    subtitle: 'Referral payouts can plug into a future API',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settlement history',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (data.paymentHistory.isEmpty)
                    const _EmptyCard(
                      title: 'No settlements yet',
                      subtitle:
                          'Wallet payouts and delivery credits will appear here.',
                    )
                  else
                    AppPaginatedColumn<DeliveryPaymentModel>(
                      items: data.paymentHistory,
                      initialCount: 8,
                      step: 8,
                      itemBuilder: (context, payment, index) =>
                          _PaymentRow(payment: payment),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryProfileTab extends StatelessWidget {
  const _DeliveryProfileTab({
    super.key,
    required this.data,
    required this.user,
  });

  final DeliveryDashboardState data;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final partner = user ?? data.partner;
    final profile = partner.deliveryProfile;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0x14FF6B00),
                    foregroundColor: AppColors.saffron,
                    child: Text(
                      (partner.displayName.isNotEmpty
                              ? partner.displayName.characters.first
                              : 'D')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.displayName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(partner.phoneNumber),
                        Text(partner.email),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Vehicle details'),
          const SizedBox(height: AppSpacing.sm),
          _ProfileCard(
            title: 'Vehicle information',
            subtitle:
                'Vehicle type: ${profile?.vehicleLabel ?? 'Bike'}\nVehicle number: KA-01-DF-2048\nInsurance: Pending upload\nRC Book: Pending upload',
            actions: const [
              _InlineAction(label: 'Upload document'),
              _InlineAction(label: 'Update bank details'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Documents'),
          const SizedBox(height: AppSpacing.sm),
          _ProfileCard(
            title: 'Compliance',
            subtitle:
                'Driving License: ${partner.documentName ?? 'Not uploaded'}\nID Proof: Pending upload\nBank details: Future backend action',
            actions: const [
              _InlineAction(label: 'Upload document'),
              _InlineAction(label: 'Refresh status'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Safety & support'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: const [
                      _EmergencyButton(label: 'Emergency'),
                      _EmergencyButton(label: 'Call support'),
                      _EmergencyButton(label: 'SOS'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _FeatureLine(
                    text:
                        'Help Center and support chat can plug into future service endpoints.',
                  ),
                  const _FeatureLine(
                    text: 'Raise issue for order, payout, or route problems.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Security rules'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Delivery partner can view only assigned orders, access only own earnings, and modify only their own profile.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  SelectableText(
                    'if(order.deliveryPartnerId !== req.user.id) {\n  return res.status(403).json({ message: "Unauthorized" });\n}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            color: const Color(0xFFFFFAF4),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Production requirements',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: AppSpacing.md),
                  _FeatureLine(text: 'Background location tracking'),
                  _FeatureLine(text: 'Battery optimization'),
                  _FeatureLine(text: 'Offline sync'),
                  _FeatureLine(text: 'Auto logout after inactivity'),
                  _FeatureLine(text: 'Fraud detection logic'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OrderListType { assigned, ongoing, completed }

class _OrdersTabList extends StatelessWidget {
  const _OrdersTabList({
    required this.title,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.orders,
    required this.listType,
  });

  final String title;
  final String emptyTitle;
  final String emptySubtitle;
  final List<DeliveryOrderModel> orders;
  final _OrderListType listType;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (orders.isEmpty)
            _EmptyCard(title: emptyTitle, subtitle: emptySubtitle)
          else
            ...orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _OrderCard(order: order, listType: listType),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order, required this.listType});

  final DeliveryOrderModel order;
  final _OrderListType listType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(deliveryDashboardControllerProvider.notifier);
    final eta = _etaForOrder(order);
    final earnings = _earningsEstimate(order);
    final distance = _distanceEstimate(order);
    final primaryActions = <Widget>[
      if (listType == _OrderListType.assigned)
        FilledButton.icon(
          onPressed: () => notifier.acceptOrder(order.id),
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Accept delivery'),
        ),
      if (listType == _OrderListType.ongoing)
        OutlinedButton.icon(
          onPressed: () => _openMaps(
            latitude: order.pickupConfirmedAt == null
                ? order.pickupLatitude
                : order.deliveryLatitude,
            longitude: order.pickupConfirmedAt == null
                ? order.pickupLongitude
                : order.deliveryLongitude,
            label: order.pickupConfirmedAt == null
                ? order.pickupAddress
                : order.deliveryAddress,
          ),
          icon: const Icon(Icons.navigation_outlined),
          label: Text(
            order.pickupConfirmedAt == null
                ? 'Navigate to store'
                : 'Navigate to customer',
          ),
        ),
      if (listType == _OrderListType.ongoing && order.canConfirmPickup)
        FilledButton.tonalIcon(
          onPressed: () => _showStoreOtpDialog(context, order),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Show store OTP'),
        ),
      if (listType == _OrderListType.ongoing && order.canVerifyOtp)
        FilledButton.tonalIcon(
          onPressed: () => _showOtpDialog(context, ref, order),
          icon: const Icon(Icons.password_outlined),
          label: const Text('Complete delivery'),
        ),
      if (listType != _OrderListType.completed)
        OutlinedButton.icon(
          onPressed: () => _showOrderDetailSheet(context, ref, order),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View details'),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                        'Order #${_shortOrderId(order.id)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _MiniBadge(
                  icon: Icons.storefront_outlined,
                  label: order.restaurantName,
                ),
                _MiniBadge(icon: Icons.location_on_outlined, label: distance),
                _MiniBadge(icon: Icons.currency_rupee, label: earnings),
                _MiniBadge(icon: Icons.timer_outlined, label: eta),
                if (order.deliveryOtp != null && order.deliveryOtp!.isNotEmpty)
                  _MiniBadge(
                    icon: Icons.password_outlined,
                    label: 'Store OTP ${order.deliveryOtp!}',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _AddressRow(
              icon: Icons.store_mall_directory_outlined,
              text: order.pickupAddress,
            ),
            const SizedBox(height: AppSpacing.xs),
            _AddressRow(icon: Icons.home_outlined, text: order.deliveryAddress),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.itemsSummary.isEmpty
                        ? 'No items listed'
                        : order.itemsSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: primaryActions,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOtpDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryOrderModel order,
  ) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Validate delivery OTP'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Customer OTP',
            hintText: 'Enter the OTP to confirm delivery',
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
                  .read(deliveryDashboardControllerProvider.notifier)
                  .verifyOtp(orderId: order.id, otp: controller.text.trim());
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Validate OTP'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStoreOtpDialog(
    BuildContext context,
    DeliveryOrderModel order,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Store verification OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.deliveryOtp == null || order.deliveryOtp!.isEmpty
                  ? 'OTP is not available yet.'
                  : 'Share this OTP with the store to confirm pickup:',
            ),
            const SizedBox(height: AppSpacing.md),
            if (order.deliveryOtp != null && order.deliveryOtp!.isNotEmpty)
              SelectableText(
                order.deliveryOtp!,
                style: Theme.of(dialogContext).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderDetailSheet(
    BuildContext context,
    WidgetRef ref,
    DeliveryOrderModel order,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.92,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order detail',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _DetailSection(
                title: 'Vendor info',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.restaurantName),
                    const SizedBox(height: AppSpacing.xs),
                    Text(order.pickupAddress),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _openMaps(
                        latitude: order.pickupLatitude,
                        longitude: order.pickupLongitude,
                        label: order.pickupAddress,
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open Google Maps'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                title: 'Customer info',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customerName),
                    Text(order.customerPhoneNumber),
                    const SizedBox(height: AppSpacing.xs),
                    Text(order.deliveryAddress),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                title: 'Order details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item count: ${_itemCount(order)}'),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Special instructions: Hand over carefully'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Status flow: AVAILABLE → ACCEPTED → OUT FOR DELIVERY → DELIVERED',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailSection(
                title: 'Delivery system',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery partner shares the order OTP at the store.',
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      order.deliveryOtp == null || order.deliveryOtp!.isEmpty
                          ? 'Store verifies the OTP before dispatch.'
                          : 'Store verification OTP: ${order.deliveryOtp!}',
                    ),
                    SizedBox(height: AppSpacing.xs),
                    const Text(
                      'After store verification, the order moves out for delivery and final delivery still needs OTP confirmation.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openMaps(
                      latitude: order.pickupConfirmedAt == null
                          ? order.pickupLatitude
                          : order.deliveryLatitude,
                      longitude: order.pickupConfirmedAt == null
                          ? order.pickupLongitude
                          : order.deliveryLongitude,
                      label: order.pickupConfirmedAt == null
                          ? order.pickupAddress
                          : order.deliveryAddress,
                    ),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Navigate'),
                  ),
                  if (order.canConfirmPickup)
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Waiting for store OTP check'),
                    ),
                  if (order.canVerifyOtp)
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _showOtpDialog(context, ref, order);
                      },
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Confirm delivery'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelledPlaceholder extends StatelessWidget {
  const _CancelledPlaceholder({required this.payments});

  final List<DeliveryPaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancelled orders',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (payments.isEmpty)
            const _EmptyCard(
              title: 'No cancelled orders',
              subtitle:
                  'Cancellation events can appear here when the backend exposes dedicated rider cancellation records.',
            )
          else
            ...payments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Card(
                  child: ListTile(
                    title: Text(
                      payment.description,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(payment.category),
                    trailing: Text(_formatDate(payment.createdAt)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RiderHeroCard extends ConsumerWidget {
  const _RiderHeroCard({
    required this.partner,
    required this.data,
    required this.onOpenNotifications,
  });

  final AppUser partner;
  final DeliveryDashboardState data;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = partner.deliveryProfile;
    final rating = _ratingForPartner(data);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFFA15B), Color(0xFFFFF4EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.24),
                foregroundColor: Colors.white,
                child: Text(
                  (partner.displayName.isNotEmpty
                          ? partner.displayName.characters.first
                          : 'D')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.displayName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rating $rating ★',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpenNotifications,
                icon: const Icon(Icons.notifications_active_outlined),
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _HeroPill(
                label: profile?.isOnline ?? false ? 'Online' : 'Offline',
              ),
              _HeroPill(label: profile?.currentZone ?? 'Central Zone'),
              _HeroPill(label: profile?.vehicleLabel ?? 'Bike'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Stay visible, move fast, and keep delivery confirmations clean with OTP-based handoff.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSnapshotCard extends StatelessWidget {
  const _OrderSnapshotCard({
    required this.title,
    required this.count,
    required this.accent,
    required this.subtitle,
  });

  final String title;
  final int count;
  final Color accent;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.14),
          foregroundColor: accent,
          child: const Icon(Icons.delivery_dining_outlined),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: Text(
          '$count',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0x0D1D1B16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.ink),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.saffron),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _EarningsBreakdownCard extends StatelessWidget {
  const _EarningsBreakdownCard({required this.row});

  final _EarningBreakdownRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFAF4),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.orderLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(_formatDate(row.date)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _PriceLine(label: 'Base pay', value: row.basePay),
            _PriceLine(label: 'Distance pay', value: row.distancePay),
            _PriceLine(label: 'Bonus', value: row.bonus),
            _PriceLine(
              label: 'Total earned',
              value: row.totalEarned,
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BonusTile extends StatelessWidget {
  const _BonusTile({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0x14FF6B00),
            foregroundColor: AppColors.saffron,
            child: const Icon(Icons.local_fire_department_outlined),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(subtitle),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: _noop);
  }
}

class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _noop,
      icon: const Icon(Icons.warning_amber_rounded),
      label: Text(label),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle,
              size: 16,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final int value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_rupees(value), style: style),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final DeliveryPaymentModel payment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: payment.type == 'CREDIT'
                ? AppColors.mist
                : const Color(0x1AF44336),
            foregroundColor: payment.type == 'CREDIT'
                ? AppColors.darkGreen
                : Colors.redAccent,
            child: Icon(
              payment.type == 'CREDIT'
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.description,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${payment.category} • ${_formatDateTime(payment.createdAt)}',
                ),
              ],
            ),
          ),
          Text(
            '${payment.type == 'CREDIT' ? '+' : '-'}${_rupees(payment.amount)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: payment.type == 'CREDIT'
                  ? AppColors.darkGreen
                  : Colors.redAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _DeliveryNotification {
  const _DeliveryNotification({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
}

class _EarningBreakdownRow {
  const _EarningBreakdownRow({
    required this.date,
    required this.orderLabel,
    required this.basePay,
    required this.distancePay,
    required this.bonus,
    required this.totalEarned,
  });

  final DateTime date;
  final String orderLabel;
  final int basePay;
  final int distancePay;
  final int bonus;
  final int totalEarned;
}

List<_DeliveryNotification> _buildNotifications(DeliveryDashboardState data) {
  return [
    ...data.availableOrders
        .take(3)
        .map(
          (order) => _DeliveryNotification(
            title: 'New order request',
            subtitle: '${order.restaurantName} is ready for assignment.',
            meta: _shortOrderId(order.id),
            icon: Icons.assignment_ind_outlined,
          ),
        ),
    ...data.assignedOrders
        .take(3)
        .map(
          (order) => _DeliveryNotification(
            title: 'Active order update',
            subtitle:
                '${order.status.replaceAll('_', ' ')} for ${order.customerName}.',
            meta: _shortOrderId(order.id),
            icon: Icons.local_shipping_outlined,
          ),
        ),
    ...data.paymentHistory
        .where((payment) => payment.category == 'DELIVERY_PAYOUT')
        .take(2)
        .map(
          (payment) => _DeliveryNotification(
            title: 'Payment processed',
            subtitle: payment.description,
            meta: _rupees(payment.amount),
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
    _DeliveryNotification(
      title: 'Incentive update',
      subtitle: 'Complete 15 deliveries this week to unlock target bonus.',
      meta: '${data.earnings.completedTrips}/15',
      icon: Icons.local_fire_department_outlined,
    ),
  ];
}

List<_EarningBreakdownRow> _buildEarningsRows(DeliveryDashboardState data) {
  return data.paymentHistory
      .where((payment) => payment.category == 'DELIVERY_EARNING')
      .take(12)
      .map((payment) {
        final basePay = 30;
        final distanceKm = _distanceKmFromAmount(payment.amount);
        final distancePay = distanceKm * 8;
        final bonus = payment.amount - basePay - distancePay;

        return _EarningBreakdownRow(
          date: payment.createdAt,
          orderLabel: payment.orderId == null
              ? 'Order earning'
              : 'Order #${_shortOrderId(payment.orderId!)}',
          basePay: basePay,
          distancePay: distancePay,
          bonus: bonus < 0 ? 0 : bonus,
          totalEarned: payment.amount,
        );
      })
      .toList(growable: false);
}

int _distanceKmFromAmount(int amount) {
  final remainder = amount - 30;
  if (remainder <= 0) {
    return 0;
  }
  return (remainder / 8).round();
}

String _distanceEstimate(DeliveryOrderModel order) {
  final latA = order.pickupLatitude;
  final lonA = order.pickupLongitude;
  final latB = order.deliveryLatitude;
  final lonB = order.deliveryLongitude;

  if (latA == null || lonA == null || latB == null || lonB == null) {
    return '5 km';
  }

  final rough = ((latA - latB).abs() + (lonA - lonB).abs()) * 55;
  final km = rough < 1 ? 1 : rough.round();
  return '$km km';
}

String _earningsEstimate(DeliveryOrderModel order) {
  final distanceText = _distanceEstimate(order);
  final km = int.tryParse(distanceText.split(' ').first) ?? 5;
  final peakBonus = _isPeakHour(order.createdAt) ? 20 : 0;
  final total = 30 + (8 * km) + peakBonus;
  return _rupees(total);
}

String _etaForOrder(DeliveryOrderModel order) {
  if (order.status == 'OUT_FOR_DELIVERY') {
    return 'ETA 12 min';
  }
  if (order.pickupConfirmedAt != null) {
    return 'Drop run';
  }
  if (order.deliveryAcceptedAt != null) {
    return 'Pickup in 8 min';
  }
  return 'Respond fast';
}

double _ratingForPartner(DeliveryDashboardState data) {
  final completed = data.earnings.completedTrips;
  if (completed == 0) {
    return 4.7;
  }
  final value = 4.5 + ((completed % 5) * 0.1);
  return value > 5 ? 5 : value;
}

int _peakHourBonus(DeliveryDashboardState data) {
  return data.paymentHistory
          .where((payment) => payment.category == 'DELIVERY_EARNING')
          .where((payment) => _isPeakHour(payment.createdAt))
          .length *
      20;
}

int _targetBonus(DeliveryDashboardState data) {
  return data.earnings.completedTrips >= 15 ? 300 : 0;
}

bool _isPeakHour(DateTime time) {
  final hour = time.hour;
  return (hour >= 12 && hour <= 14) || (hour >= 19 && hour <= 22);
}

bool _isToday(DateTime time) {
  final now = DateTime.now();
  return now.year == time.year &&
      now.month == time.month &&
      now.day == time.day;
}

int _itemCount(DeliveryOrderModel order) {
  if (order.itemsSummary.isEmpty) {
    return 0;
  }
  return order.itemsSummary.split(',').length;
}

String _shortOrderId(String id) {
  return id.length > 6
      ? id.substring(id.length - 6).toUpperCase()
      : id.toUpperCase();
}

String _rupees(int amount) => '₹$amount';

String _formatDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';

String _formatDateTime(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minutes = value.minute.toString().padLeft(2, '0');
  final meridiem = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.day}/${value.month}/${value.year} • $hour:$minutes $meridiem';
}

Future<void> _openMaps({
  required double? latitude,
  required double? longitude,
  required String label,
}) async {
  final uri = latitude != null && longitude != null
      ? Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
        )
      : Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}',
        );

  await launchUrl(uri, mode: LaunchMode.platformDefault);
}

void _noop() {}
