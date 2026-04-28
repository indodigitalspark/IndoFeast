import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/breakpoints.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../../models/app_user.dart';
import '../../../../models/customer_models.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/app_async_state.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_paginated_column.dart';
import '../controllers/customer_dashboard_controller.dart';

enum _CustomerTab { home, search, orders, wallet, profile }

class CustomerDashboardPage extends ConsumerStatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  ConsumerState<CustomerDashboardPage> createState() =>
      _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends ConsumerState<CustomerDashboardPage> {
  late final TextEditingController _searchController;
  late final TextEditingController _couponController;
  _CustomerTab _currentTab = _CustomerTab.home;
  RestaurantModelView? _selectedRestaurant;
  String _vendorTab = 'MENU';
  bool _pureVegOnly = false;
  bool _nearbyOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _couponController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerDashboardControllerProvider);
    final user = ref.watch(authControllerProvider).valueOrNull?.user;

    return customerState.when(
      data: (data) {
        if (_couponController.text != (data.cart.couponCode ?? '')) {
          _couponController.value = _couponController.value.copyWith(
            text: data.cart.couponCode ?? '',
            selection: TextSelection.collapsed(
              offset: (data.cart.couponCode ?? '').length,
            ),
          );
        }

        return _CustomerShell(
          currentTab: _currentTab,
          cartItemCount: data.cart.items.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          ),
          activeOrderCount: data.activeOrders.length,
          couponCount: data.coupons.length,
          onTabSelected: (tab) => setState(() {
            _currentTab = tab;
            if (tab != _CustomerTab.home && tab != _CustomerTab.search) {
              _selectedRestaurant = null;
            }
          }),
          onOpenNotifications: () => _showNotificationsSheet(context, data),
          onOpenSearch: () => setState(() => _currentTab = _CustomerTab.search),
          onOpenOrders: () => setState(() => _currentTab = _CustomerTab.orders),
          onOpenWallet: () => setState(() => _currentTab = _CustomerTab.wallet),
          onOpenProfile: () =>
              setState(() => _currentTab = _CustomerTab.profile),
          onOpenCart: () => _showCartSheet(context, ref, data, user: user),
          onSignOut: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) {
              context.go(RouteNames.login);
            }
          },
          floatingActionButton: data.cart.items.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () =>
                      _showCartSheet(context, ref, data, user: user),
                  backgroundColor: AppColors.saffron,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                    'Cart • ${_cartCount(data.cart)} item${_cartCount(data.cart) == 1 ? '' : 's'}',
                  ),
                ),
          child: _CustomerScreenBody(
            currentTab: _currentTab,
            data: data,
            user: user,
            searchController: _searchController,
            selectedRestaurant: _selectedRestaurant,
            vendorTab: _vendorTab,
            onRestaurantSelected: (restaurant) => setState(() {
              _selectedRestaurant = restaurant;
              _vendorTab = 'MENU';
            }),
            onExitRestaurant: () => setState(() => _selectedRestaurant = null),
            onVendorTabChanged: (value) => setState(() => _vendorTab = value),
            onOpenHome: () => setState(() {
              _currentTab = _CustomerTab.home;
              _selectedRestaurant = null;
            }),
            onOpenCart: () => _showCartSheet(context, ref, data, user: user),
            onOpenCheckout: () =>
                _showCheckoutSheet(context, ref, data, user: user),
            onOpenNotifications: () => _showNotificationsSheet(context, data),
            couponController: _couponController,
            onOpenSearch: () =>
                setState(() => _currentTab = _CustomerTab.search),
            onOpenOrders: () =>
                setState(() => _currentTab = _CustomerTab.orders),
            onOpenWallet: () =>
                setState(() => _currentTab = _CustomerTab.wallet),
            onOpenProfile: () =>
                setState(() => _currentTab = _CustomerTab.profile),
            pureVegOnly: _pureVegOnly,
            nearbyOnly: _nearbyOnly,
            onPureVegChanged: (value) => setState(() => _pureVegOnly = value),
            onNearbyChanged: (value) => setState(() => _nearbyOnly = value),
          ),
        );
      },
      loading: () => const Scaffold(
        body: AppLoadingState(message: 'Loading your customer panel...'),
      ),
      error: (error, stackTrace) => Scaffold(
        body: AppErrorState(
          message: error.toString(),
          onRetry: () =>
              ref.read(customerDashboardControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }

  Future<void> _showCartSheet(
    BuildContext context,
    WidgetRef ref,
    CustomerDashboardState data, {
    AppUser? user,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _CartSheet(
          data: data,
          couponController: _couponController,
          onCheckout: () async {
            Navigator.of(sheetContext).pop();
            await _showCheckoutSheet(context, ref, data, user: user);
          },
        ),
      ),
    );
  }

  Future<void> _showCheckoutSheet(
    BuildContext context,
    WidgetRef ref,
    CustomerDashboardState data, {
    AppUser? user,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _CheckoutSheet(
          data: data,
          user: user,
          onPlaceOrder: () async {
            Navigator.of(sheetContext).pop();
            await _handleCheckout(context, ref, data);
          },
        ),
      ),
    );
  }

  Future<void> _showNotificationsSheet(
    BuildContext context,
    CustomerDashboardState data,
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
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (notifications.isEmpty)
                const _EmptyCard(
                  title: 'No notifications yet',
                  subtitle:
                      'Order updates, offers, and refunds will appear here.',
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
                            backgroundColor: const Color(0x1AFF6B00),
                            foregroundColor: AppColors.saffron,
                            child: Icon(item.icon),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(item.subtitle),
                          trailing: Text(
                            item.meta,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
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

class _CustomerShell extends StatelessWidget {
  const _CustomerShell({
    required this.currentTab,
    required this.cartItemCount,
    required this.activeOrderCount,
    required this.couponCount,
    required this.onTabSelected,
    required this.onOpenNotifications,
    required this.onOpenSearch,
    required this.onOpenOrders,
    required this.onOpenWallet,
    required this.onOpenProfile,
    required this.onOpenCart,
    required this.onSignOut,
    required this.child,
    this.floatingActionButton,
  });

  final _CustomerTab currentTab;
  final int cartItemCount;
  final int activeOrderCount;
  final int couponCount;
  final ValueChanged<_CustomerTab> onTabSelected;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenCart;
  final VoidCallback onSignOut;
  final Widget child;
  final Widget? floatingActionButton;

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
      extendBody: !isDesktop,
      appBar: AppBar(
        toolbarHeight: isCompact ? 68 : 76,
        titleSpacing: horizontalPadding,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFCF8), Color(0xFFFFF3E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            const AppLogo(size: 34),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IndoFeast',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isCompact)
                    Text(
                      'Browse, order, track, pay, review',
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
          _QuickActionsMenu(
            activeOrderCount: activeOrderCount,
            couponCount: couponCount,
            onLocationTap: onOpenProfile,
            onSearchTap: onOpenSearch,
            onFilterTap: onOpenSearch,
            onCartTap: onOpenCart,
            onOffersTap: onOpenSearch,
            onProfileTap: onOpenProfile,
            onTrackingTap: onOpenOrders,
          ),
          _AppBarActionButton(
            tooltip: 'Notifications',
            onPressed: onOpenNotifications,
            child: Badge(
              isLabelVisible: cartItemCount > 0,
              label: Text('$cartItemCount'),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          _AppBarActionButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            child: const Icon(Icons.logout),
          ),
          SizedBox(width: horizontalPadding),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          const Positioned(
            top: -80,
            right: -40,
            child: _AmbientGlow(size: 220, color: Color(0x33FF6B00)),
          ),
          const Positioned(
            top: 220,
            left: -70,
            child: _AmbientGlow(size: 180, color: Color(0x220F5132)),
          ),
          Row(
            children: [
              if (isDesktop)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: NavigationRail(
                    selectedIndex: currentTab.index,
                    onDestinationSelected: (index) =>
                        onTabSelected(_CustomerTab.values[index]),
                    extended: width >= Breakpoints.desktop,
                    indicatorColor: AppColors.saffron,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search_outlined),
                        selectedIcon: Icon(Icons.search),
                        label: Text('Search'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: Text('Orders'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet),
                        label: Text('Wallet'),
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
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: NavigationBar(
                height: isCompact ? 64 : 72,
                labelBehavior: width < 340
                    ? NavigationDestinationLabelBehavior.alwaysHide
                    : NavigationDestinationLabelBehavior.onlyShowSelected,
                selectedIndex: currentTab.index,
                onDestinationSelected: (index) =>
                    onTabSelected(_CustomerTab.values[index]),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet),
                    label: 'Wallet',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
    );
  }
}

class _CustomerScreenBody extends ConsumerWidget {
  const _CustomerScreenBody({
    required this.currentTab,
    required this.data,
    required this.user,
    required this.searchController,
    required this.selectedRestaurant,
    required this.vendorTab,
    required this.onRestaurantSelected,
    required this.onExitRestaurant,
    required this.onVendorTabChanged,
    required this.onOpenHome,
    required this.onOpenCart,
    required this.onOpenCheckout,
    required this.onOpenNotifications,
    required this.couponController,
    required this.onOpenSearch,
    required this.onOpenOrders,
    required this.onOpenWallet,
    required this.onOpenProfile,
    required this.pureVegOnly,
    required this.nearbyOnly,
    required this.onPureVegChanged,
    required this.onNearbyChanged,
  });

  final _CustomerTab currentTab;
  final CustomerDashboardState data;
  final AppUser? user;
  final TextEditingController searchController;
  final RestaurantModelView? selectedRestaurant;
  final String vendorTab;
  final ValueChanged<RestaurantModelView> onRestaurantSelected;
  final VoidCallback onExitRestaurant;
  final ValueChanged<String> onVendorTabChanged;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenCheckout;
  final VoidCallback onOpenNotifications;
  final TextEditingController couponController;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenProfile;
  final bool pureVegOnly;
  final bool nearbyOnly;
  final ValueChanged<bool> onPureVegChanged;
  final ValueChanged<bool> onNearbyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    searchController.value = searchController.value.copyWith(
      text: data.search,
      selection: TextSelection.collapsed(offset: data.search.length),
    );
    final visibleRestaurants = _applyRestaurantFilters(
      data.restaurants,
      pureVegOnly: pureVegOnly,
      nearbyOnly: nearbyOnly,
      priceFilter: data.priceFilter,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: switch (currentTab) {
        _CustomerTab.home =>
          selectedRestaurant == null
              ? _CustomerHomeTab(
                  key: const ValueKey('home'),
                  data: data,
                  visibleRestaurants: visibleRestaurants,
                  searchController: searchController,
                  onRestaurantSelected: onRestaurantSelected,
                  onOpenNotifications: onOpenNotifications,
                  onOpenSearch: onOpenSearch,
                  onOpenOrders: onOpenOrders,
                  onOpenCart: onOpenCart,
                  onOpenWallet: onOpenWallet,
                  onOpenProfile: onOpenProfile,
                  pureVegOnly: pureVegOnly,
                  nearbyOnly: nearbyOnly,
                  onPureVegChanged: onPureVegChanged,
                  onNearbyChanged: onNearbyChanged,
                )
              : _VendorDetailView(
                  key: ValueKey('vendor-${selectedRestaurant!.id}'),
                  restaurant: selectedRestaurant!,
                  cart: data.cart,
                  vendorTab: vendorTab,
                  onBack: onExitRestaurant,
                  onVendorTabChanged: onVendorTabChanged,
                ),
        _CustomerTab.search => _CustomerSearchTab(
          key: const ValueKey('search'),
          data: data,
          visibleRestaurants: visibleRestaurants,
          searchController: searchController,
          onRestaurantSelected: onRestaurantSelected,
          onOpenHome: onOpenHome,
          onOpenOrders: onOpenOrders,
          pureVegOnly: pureVegOnly,
          nearbyOnly: nearbyOnly,
          onPureVegChanged: onPureVegChanged,
          onNearbyChanged: onNearbyChanged,
        ),
        _CustomerTab.orders => _CustomerOrdersTab(
          key: const ValueKey('orders'),
          data: data,
          onOpenHome: onOpenHome,
          onOpenSearch: onOpenSearch,
        ),
        _CustomerTab.wallet => _CustomerWalletTab(
          key: const ValueKey('wallet'),
          wallet: data.wallet,
          onOpenCheckout: onOpenCheckout,
          onOpenHome: onOpenHome,
          onOpenOrders: onOpenOrders,
        ),
        _CustomerTab.profile => _CustomerProfileTab(
          key: const ValueKey('profile'),
          user: user,
          data: data,
          couponController: couponController,
          onOpenCart: onOpenCart,
          onOpenHome: onOpenHome,
          onOpenWallet: onOpenWallet,
        ),
      },
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _QuickActionsMenu extends StatelessWidget {
  const _QuickActionsMenu({
    required this.activeOrderCount,
    required this.couponCount,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.onFilterTap,
    required this.onCartTap,
    required this.onOffersTap,
    required this.onProfileTap,
    required this.onTrackingTap,
  });

  final int activeOrderCount;
  final int couponCount;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onFilterTap;
  final VoidCallback onCartTap;
  final VoidCallback onOffersTap;
  final VoidCallback onProfileTap;
  final VoidCallback onTrackingTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Location', 'Change address', Icons.location_on_outlined, onLocationTap),
      (
        'Offers',
        '$couponCount deals live',
        Icons.local_offer_outlined,
        onOffersTap,
      ),
      ('Search', 'Restaurants & dishes', Icons.search, onSearchTap),
      ('Profile', 'Account & settings', Icons.person_outline, onProfileTap),
      ('Filter', 'Rating, time, price', Icons.tune, onFilterTap),
      (
        'Tracking',
        '$activeOrderCount active',
        Icons.delivery_dining_outlined,
        onTrackingTap,
      ),
      ('Cart', 'Review added items', Icons.shopping_cart_outlined, onCartTap),
    ];

    return PopupMenuButton<int>(
      tooltip: 'Quick actions',
      offset: const Offset(0, 12),
      onSelected: (index) => items[index].$4(),
      itemBuilder: (context) => List.generate(
        items.length,
        (index) => PopupMenuItem<int>(
          value: index,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(items[index].$3, color: AppColors.saffron),
            title: Text(
              items[index].$1,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(items[index].$2),
          ),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.only(right: AppSpacing.sm),
        child: _ActionButtonSurface(
          tooltip: 'Quick actions',
          icon: Icons.grid_view_rounded,
        ),
      ),
    );
  }
}

class _AppBarActionButton extends StatelessWidget {
  const _AppBarActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: child,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.82),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ActionButtonSurface extends StatelessWidget {
  const _ActionButtonSurface({required this.tooltip, required this.icon});

  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.82),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Icon(icon)),
        ),
      ),
    );
  }
}

class _SurfaceSection extends StatelessWidget {
  const _SurfaceSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFAF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x120F5132)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _PageLinksBar extends StatelessWidget {
  const _PageLinksBar({required this.actions});

  final List<(String, IconData, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions
          .map(
            (item) => OutlinedButton.icon(
              onPressed: item.$3,
              icon: Icon(item.$2),
              label: Text(item.$1),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CustomerHomeTab extends ConsumerWidget {
  const _CustomerHomeTab({
    super.key,
    required this.data,
    required this.visibleRestaurants,
    required this.searchController,
    required this.onRestaurantSelected,
    required this.onOpenNotifications,
    required this.onOpenSearch,
    required this.onOpenOrders,
    required this.onOpenCart,
    required this.onOpenWallet,
    required this.onOpenProfile,
    required this.pureVegOnly,
    required this.nearbyOnly,
    required this.onPureVegChanged,
    required this.onNearbyChanged,
  });

  final CustomerDashboardState data;
  final List<RestaurantModelView> visibleRestaurants;
  final TextEditingController searchController;
  final ValueChanged<RestaurantModelView> onRestaurantSelected;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenProfile;
  final bool pureVegOnly;
  final bool nearbyOnly;
  final ValueChanged<bool> onPureVegChanged;
  final ValueChanged<bool> onNearbyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeHeroHeader(
            restaurants: data.restaurants,
            searchController: searchController,
            onOpenNotifications: onOpenNotifications,
            onOpenSearch: onOpenSearch,
            onOpenOrders: onOpenOrders,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SurfaceSection(
            title: 'Food categories',
            subtitle: 'Tap an icon to instantly search a cuisine or dish type.',
            child: _FoodTypeScroller(searchController: searchController),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Categories'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final category = data.categories[index];
                final selected = category == data.selectedCategory;
                return _CategoryCard(
                  category: category,
                  selected: selected,
                  onTap: () => ref
                      .read(customerDashboardControllerProvider.notifier)
                      .updateCategory(category),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Live offers'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.banners.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _OfferBannerCard(banner: data.banners[index]),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              const Expanded(child: _SectionTitle(title: 'Vendors near you')),
              TextButton(
                onPressed: () => ref
                    .read(customerDashboardControllerProvider.notifier)
                    .refresh(),
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _FilterStrip(
            data: data,
            pureVegOnly: pureVegOnly,
            nearbyOnly: nearbyOnly,
            onPureVegChanged: onPureVegChanged,
            onNearbyChanged: onNearbyChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          _VendorGrid(
            restaurants: visibleRestaurants,
            cart: data.cart,
            onRestaurantSelected: onRestaurantSelected,
          ),
        ],
      ),
    );
  }
}

class _CustomerSearchTab extends ConsumerWidget {
  const _CustomerSearchTab({
    super.key,
    required this.data,
    required this.visibleRestaurants,
    required this.searchController,
    required this.onRestaurantSelected,
    required this.onOpenHome,
    required this.onOpenOrders,
    required this.pureVegOnly,
    required this.nearbyOnly,
    required this.onPureVegChanged,
    required this.onNearbyChanged,
  });

  final CustomerDashboardState data;
  final List<RestaurantModelView> visibleRestaurants;
  final TextEditingController searchController;
  final ValueChanged<RestaurantModelView> onRestaurantSelected;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenOrders;
  final bool pureVegOnly;
  final bool nearbyOnly;
  final ValueChanged<bool> onPureVegChanged;
  final ValueChanged<bool> onNearbyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageLinksBar(
            actions: [
              ('Home', Icons.home_outlined, onOpenHome),
              ('Orders', Icons.receipt_long_outlined, onOpenOrders),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8F1), Color(0xFFFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x120F5132)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search vendors, products, and categories',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Find restaurants, dishes, cuisines, and jump into results fast.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: searchController,
                    onSubmitted: (value) => ref
                        .read(customerDashboardControllerProvider.notifier)
                        .updateSearch(value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Vendor name, product name, or category',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () => ref
                            .read(customerDashboardControllerProvider.notifier)
                            .updateSearch(searchController.text.trim()),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FilterStrip(
                    data: data,
                    pureVegOnly: pureVegOnly,
                    nearbyOnly: nearbyOnly,
                    onPureVegChanged: onPureVegChanged,
                    onNearbyChanged: onNearbyChanged,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Results'),
          const SizedBox(height: AppSpacing.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              final results = _searchResults(
                data,
                visibleRestaurants,
                queryOverride: value.text,
              );

              if (results.isEmpty) {
                return const _EmptyCard(
                  title: 'No results found',
                  subtitle: 'Try a vendor, menu item, or category keyword.',
                );
              }

              return Column(
                children: results
                    .map(
                      (result) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(AppSpacing.md),
                            leading: CircleAvatar(
                              backgroundColor: _parseColor(
                                result.restaurant.accentColor,
                              ),
                              child: Text(
                                result.restaurant.name.characters.first,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            title: Text(
                              result.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(result.subtitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                onRestaurantSelected(result.restaurant),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CustomerOrdersTab extends StatelessWidget {
  const _CustomerOrdersTab({
    super.key,
    required this.data,
    required this.onOpenHome,
    required this.onOpenSearch,
  });

  final CustomerDashboardState data;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageLinksBar(
            actions: [
              ('Home', Icons.home_outlined, onOpenHome),
              ('Search', Icons.search_outlined, onOpenSearch),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _MetricTile(
                    label: 'Active orders',
                    value: '${data.activeOrders.length}',
                    icon: Icons.local_shipping_outlined,
                  ),
                  _MetricTile(
                    label: 'Completed',
                    value:
                        '${data.orderHistory.where((item) => item.status == 'DELIVERED').length}',
                    icon: Icons.check_circle_outline,
                  ),
                  _MetricTile(
                    label: 'Cancellations',
                    value:
                        '${data.orderHistory.where((item) => item.status == 'CANCELLED').length}',
                    icon: Icons.cancel_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Track orders'),
          const SizedBox(height: AppSpacing.sm),
          if (data.activeOrders.isEmpty)
            const _EmptyCard(
              title: 'No active orders',
              subtitle:
                  'Placed, accepted, preparing, and rider updates appear here.',
            )
          else
            AppPaginatedColumn<CustomerOrderModel>(
              items: data.activeOrders,
              initialCount: 4,
              step: 4,
              itemBuilder: (context, order, index) =>
                  _ActiveOrderCard(order: order),
            ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Order history'),
          const SizedBox(height: AppSpacing.sm),
          if (data.orderHistory.isEmpty)
            const _EmptyCard(
              title: 'No past orders yet',
              subtitle:
                  'Your completed, cancelled, and refunded orders will show here.',
            )
          else
            AppPaginatedColumn<CustomerOrderModel>(
              items: data.orderHistory,
              initialCount: 6,
              step: 6,
              itemBuilder: (context, order, index) =>
                  _OrderHistoryCard(order: order),
            ),
        ],
      ),
    );
  }
}

class _CustomerWalletTab extends StatelessWidget {
  const _CustomerWalletTab({
    super.key,
    required this.wallet,
    required this.onOpenCheckout,
    required this.onOpenHome,
    required this.onOpenOrders,
  });

  final CustomerWalletModel wallet;
  final VoidCallback onOpenCheckout;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageLinksBar(
            actions: [
              ('Home', Icons.home_outlined, onOpenHome),
              ('Orders', Icons.receipt_long_outlined, onOpenOrders),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionTitle(title: 'Wallet summary'),
          const SizedBox(height: AppSpacing.sm),
          _WalletCard(wallet: wallet),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet uses',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _FeatureBullet(
                    text: 'Partial payment for mixed wallet + gateway checkout',
                  ),
                  const _FeatureBullet(
                    text: 'Full payment for quick repeat orders',
                  ),
                  const _FeatureBullet(
                    text:
                        'Refund credits after cancellations or failed deliveries',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: onOpenCheckout,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Use wallet in checkout'),
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

class _CustomerProfileTab extends StatelessWidget {
  const _CustomerProfileTab({
    super.key,
    required this.user,
    required this.data,
    required this.couponController,
    required this.onOpenCart,
    required this.onOpenHome,
    required this.onOpenWallet,
  });

  final AppUser? user;
  final CustomerDashboardState data;
  final TextEditingController couponController;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenWallet;

  @override
  Widget build(BuildContext context) {
    final memberSince = user == null
        ? 'Not available'
        : '${user!.createdAt.day}/${user!.createdAt.month}/${user!.createdAt.year}';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageLinksBar(
            actions: [
              ('Home', Icons.home_outlined, onOpenHome),
              ('Wallet', Icons.account_balance_wallet_outlined, onOpenWallet),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0x1AFF6B00),
                    foregroundColor: AppColors.saffron,
                    child: Text(
                      (user?.displayName.isNotEmpty ?? false)
                          ? user!.displayName.characters.first.toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
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
                          user?.displayName ?? 'Customer',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(user?.email ?? 'No email'),
                        Text(user?.phoneNumber ?? 'No phone number'),
                        Text('Member since $memberSince'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Manage addresses'),
          const SizedBox(height: AppSpacing.sm),
          _ProfileActionCard(
            title: 'Primary delivery address',
            subtitle:
                data.activeOrders.firstOrNull?.deliveryAddress.isNotEmpty ==
                    true
                ? data.activeOrders.first.deliveryAddress
                : '221B MG Road, Bengaluru, Karnataka',
            trailing: Wrap(
              spacing: AppSpacing.xs,
              children: const [
                ActionChip(label: Text('Add'), onPressed: _noop),
                ActionChip(label: Text('Edit'), onPressed: _noop),
                ActionChip(label: Text('Delete'), onPressed: _noop),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Saved cards'),
          const SizedBox(height: AppSpacing.sm),
          const _ProfileActionCard(
            title: 'Payments',
            subtitle:
                'Stripe, Razorpay, wallet, and Cash on Delivery supported.',
            trailing: ActionChip(label: Text('Checkout'), onPressed: _noop),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Complaints'),
          const SizedBox(height: AppSpacing.sm),
          const _ProfileActionCard(
            title: 'Raise ticket',
            subtitle:
                'Track complaint status for order, payment, or delivery issues.',
            trailing: ActionChip(label: Text('Open'), onPressed: _noop),
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
                    'Customer can access only their own orders, wallet, and profile.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  SelectableText(
                    'if(order.userId !== req.user.id){\n  return res.status(403).json({ message: "Unauthorized" });\n}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onOpenCart,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Open cart'),
          ),
        ],
      ),
    );
  }
}

class _HomeHeroHeader extends ConsumerWidget {
  const _HomeHeroHeader({
    required this.restaurants,
    required this.searchController,
    required this.onOpenNotifications,
    required this.onOpenSearch,
    required this.onOpenOrders,
  });

  final List<RestaurantModelView> restaurants;
  final TextEditingController searchController;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0E1), Color(0xFFFFD6B3), Color(0xFFFFF7EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            runSpacing: AppSpacing.md,
            spacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _InfoPill(
                icon: Icons.location_on_outlined,
                label: 'Deliver to Green Residency',
              ),
              const _InfoPill(icon: Icons.search, label: 'Search dishes'),
              const _InfoPill(icon: Icons.tune, label: 'Filter & sort'),
              OutlinedButton.icon(
                onPressed: onOpenNotifications,
                icon: const Icon(Icons.notifications_none),
                label: const Text('Alerts'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Discover food faster with clean categories, search, filters, offers, and live order tracking.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Everything important stays visible: location selector, food icons, restaurant cards, cart access, and profile actions.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onOpenSearch,
                icon: const Icon(Icons.search),
                label: const Text('Start searching'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenOrders,
                icon: const Icon(Icons.delivery_dining_outlined),
                label: const Text('Track orders'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: searchController,
            onSubmitted: (value) => ref
                .read(customerDashboardControllerProvider.notifier)
                .updateSearch(value.trim()),
            decoration: InputDecoration(
              hintText: 'Search by vendor, dish, product, or category',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: () => ref
                    .read(customerDashboardControllerProvider.notifier)
                    .updateSearch(searchController.text.trim()),
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              final query = value.text.trim().toLowerCase();
              if (query.isEmpty) {
                return const SizedBox.shrink();
              }

              final suggestions = restaurants
                  .expand(
                    (restaurant) => restaurant.menuItems
                        .where(
                          (item) =>
                              restaurant.isOpen &&
                              (item.name.toLowerCase().contains(query) ||
                                  item.category.toLowerCase().contains(query)),
                        )
                        .map((item) => '${item.name} • ${restaurant.name}'),
                  )
                  .take(4)
                  .toList(growable: false);

              if (suggestions.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: suggestions
                      .map(
                        (suggestion) => ActionChip(
                          label: Text(suggestion),
                          onPressed: () => ref
                              .read(
                                customerDashboardControllerProvider.notifier,
                              )
                              .updateSearch(suggestion.split(' • ').first),
                        ),
                      )
                      .toList(growable: false),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (category.toLowerCase()) {
      'food' || 'all' => Icons.lunch_dining_outlined,
      'grocery' => Icons.local_grocery_store_outlined,
      'medicine' => Icons.medication_outlined,
      'dine-in' => Icons.table_restaurant_outlined,
      _ => Icons.store_mall_directory_outlined,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 112,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.saffron : AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.saffron : const Color(0x1A0F5132),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.saffron,
              size: 28,
            ),
            const Spacer(),
            Text(
              category,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodTypeScroller extends ConsumerWidget {
  const _FoodTypeScroller({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(customerDashboardControllerProvider.notifier);
    final items = [
      ('Burgers', 'Fast food', Icons.lunch_dining_outlined),
      ('Pizza', 'Pizza places', Icons.local_pizza_outlined),
      ('Chicken', 'Non-veg dishes', Icons.egg_alt_outlined),
      ('Noodles', 'Chinese & Asian', Icons.ramen_dining_outlined),
      ('Salad', 'Healthy food', Icons.eco_outlined),
      ('Dessert', 'Cakes & sweets', Icons.cake_outlined),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = items[index];
          return _FoodTypeCard(
            title: item.$1,
            subtitle: item.$2,
            icon: item.$3,
            onTap: () {
              searchController.value = searchController.value.copyWith(
                text: item.$1,
                selection: TextSelection.collapsed(offset: item.$1.length),
              );
              controller.updateSearch(item.$1);
            },
          );
        },
      ),
    );
  }
}

class _FoodTypeCard extends StatelessWidget {
  const _FoodTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        width: 144,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBF7), Color(0xFFFFF1E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x1AFF6B00)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0x14FF6B00),
              foregroundColor: AppColors.saffron,
              child: Icon(icon, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FilterStrip extends ConsumerWidget {
  const _FilterStrip({
    required this.data,
    required this.pureVegOnly,
    required this.nearbyOnly,
    required this.onPureVegChanged,
    required this.onNearbyChanged,
  });

  final CustomerDashboardState data;
  final bool pureVegOnly;
  final bool nearbyOnly;
  final ValueChanged<bool> onPureVegChanged;
  final ValueChanged<bool> onNearbyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(customerDashboardControllerProvider.notifier);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilterChip(
          avatar: const Icon(Icons.star, size: 16),
          label: Text(data.minRating == null ? 'Rating 4.3+' : 'Clear rating'),
          selected: data.minRating != null,
          onSelected: (_) =>
              controller.updateRating(data.minRating == null ? 4.3 : null),
        ),
        FilterChip(
          avatar: const Icon(Icons.timer_outlined, size: 16),
          label: Text(
            data.maxDeliveryTime == null ? 'Delivery < 25 min' : 'Clear time',
          ),
          selected: data.maxDeliveryTime != null,
          onSelected: (_) => controller.updateDeliveryTime(
            data.maxDeliveryTime == null ? 25 : null,
          ),
        ),
        FilterChip(
          avatar: const Icon(Icons.sort, size: 16),
          label: Text(
            data.priceFilter == null ? 'Price low to high' : 'Clear price',
          ),
          selected: data.priceFilter != null,
          onSelected: (_) => controller.updatePriceFilter(
            data.priceFilter == null ? '180' : null,
          ),
        ),
        FilterChip(
          avatar: Icon(Icons.eco_outlined, size: 16),
          label: Text('Pure veg'),
          selected: pureVegOnly,
          onSelected: onPureVegChanged,
        ),
        FilterChip(
          avatar: Icon(Icons.near_me_outlined, size: 16),
          label: Text('Distance'),
          selected: nearbyOnly,
          onSelected: onNearbyChanged,
        ),
      ],
    );
  }
}

class _VendorGrid extends StatelessWidget {
  const _VendorGrid({
    required this.restaurants,
    required this.cart,
    required this.onRestaurantSelected,
  });

  final List<RestaurantModelView> restaurants;
  final CustomerCartModel cart;
  final ValueChanged<RestaurantModelView> onRestaurantSelected;

  @override
  Widget build(BuildContext context) {
    if (restaurants.isEmpty) {
      return const _EmptyCard(
        title: 'No vendors match the current filters',
        subtitle: 'Try clearing search or switching category filters.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: restaurants
              .map(
                (restaurant) => SizedBox(
                  width: itemWidth,
                  child: _VendorCard(
                    restaurant: restaurant,
                    cart: cart,
                    onTap: () => onRestaurantSelected(restaurant),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.restaurant,
    required this.cart,
    required this.onTap,
  });

  final RestaurantModelView restaurant;
  final CustomerCartModel cart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cartCount = cart.items
        .where((item) => item.restaurantId == restaurant.id)
        .fold<int>(0, (sum, item) => sum + item.quantity);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _parseColor(restaurant.accentColor),
                    _parseColor(restaurant.accentColor).withValues(alpha: 0.76),
                  ],
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
                          color: AppColors.darkGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          restaurant.heroTag.isEmpty
                              ? 'Featured'
                              : restaurant.heroTag,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const Spacer(),
                      if (cartCount > 0)
                        Badge(
                          label: Text('$cartCount'),
                          child: const Icon(Icons.shopping_bag_outlined),
                        )
                      else
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.favorite_border, size: 18),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      restaurant.category,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    restaurant.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.cuisine.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _TinyInfoChip(
                        icon: Icons.star,
                        label: restaurant.rating.toStringAsFixed(1),
                        foregroundColor: AppColors.saffron,
                      ),
                      _TinyInfoChip(
                        icon: Icons.timer_outlined,
                        label: '${restaurant.deliveryTime} min',
                      ),
                      _TinyInfoChip(
                        icon: Icons.currency_rupee,
                        label: _deliveryFee(restaurant),
                      ),
                      _TinyInfoChip(
                        icon: restaurant.cuisine.any(_isVegCuisine)
                            ? Icons.eco_outlined
                            : Icons.restaurant_outlined,
                        label: restaurant.cuisine.any(_isVegCuisine)
                            ? 'Veg'
                            : 'Non-veg',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    restaurant.offerText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.saffron,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    restaurant.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recommended',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.darkGreen,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: onTap,
                        child: const Text('View menu'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorDetailView extends StatelessWidget {
  const _VendorDetailView({
    super.key,
    required this.restaurant,
    required this.cart,
    required this.vendorTab,
    required this.onBack,
    required this.onVendorTabChanged,
  });

  final RestaurantModelView restaurant;
  final CustomerCartModel cart;
  final String vendorTab;
  final VoidCallback onBack;
  final ValueChanged<String> onVendorTabChanged;

  @override
  Widget build(BuildContext context) {
    if (!restaurant.isOpen) {
      return Column(children: [_StoreClosedCard(restaurant: restaurant)]);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _parseColor(restaurant.accentColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to listing'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: onBack,
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('Home'),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        restaurant.name,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _TinyInfoChip(
                            icon: Icons.star,
                            label: restaurant.rating.toStringAsFixed(1),
                            foregroundColor: AppColors.saffron,
                          ),
                          _TinyInfoChip(
                            icon: Icons.location_on_outlined,
                            label: 'Koramangala, Bengaluru',
                          ),
                          _TinyInfoChip(
                            icon: Icons.timer_outlined,
                            label: '${restaurant.deliveryTime} min',
                          ),
                          _TinyInfoChip(
                            icon: Icons.local_offer_outlined,
                            label: restaurant.offerText,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'MENU', label: Text('Menu')),
                          ButtonSegment(
                            value: 'REVIEWS',
                            label: Text('Reviews'),
                          ),
                          ButtonSegment(value: 'INFO', label: Text('Info')),
                        ],
                        selected: {vendorTab},
                        onSelectionChanged: (value) =>
                            onVendorTabChanged(value.first),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (vendorTab == 'MENU')
                        ...restaurant.menuItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _VendorMenuItemCard(
                              restaurant: restaurant,
                              item: item,
                              quantity: _itemQuantity(
                                cart,
                                restaurant.id,
                                item.itemId,
                              ),
                            ),
                          ),
                        )
                      else if (vendorTab == 'REVIEWS')
                        restaurant.reviews.isEmpty
                            ? const _EmptyCard(
                                title: 'No reviews yet',
                                subtitle:
                                    'Customer reviews will appear after delivery.',
                              )
                            : Column(
                                children: restaurant.reviews
                                    .map(
                                      (review) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.md,
                                        ),
                                        child: Card(
                                          child: ListTile(
                                            title: Text(
                                              review.userName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(review.review),
                                            trailing: Text(
                                              review.rating.toStringAsFixed(1),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurant.description,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                const _FeatureBullet(
                                  text:
                                      'Delivery, pickup, and dine-in order types',
                                ),
                                _FeatureBullet(
                                  text:
                                      'Cuisine types: ${restaurant.cuisine.join(', ')}',
                                ),
                                _FeatureBullet(
                                  text:
                                      'Estimated delivery fee: ${_deliveryFee(restaurant)}',
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorMenuItemCard extends ConsumerWidget {
  const _VendorMenuItemCard({
    required this.restaurant,
    required this.item,
    required this.quantity,
  });

  final RestaurantModelView restaurant;
  final MenuItemModel item;
  final int quantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(customerDashboardControllerProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _MenuItemImage(item: item),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (item.bestseller)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1AFF6B00),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Bestseller',
                            style: TextStyle(
                              color: AppColors.saffron,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _TinyInfoChip(
                        icon: item.isVeg
                            ? Icons.eco_outlined
                            : Icons.set_meal_outlined,
                        label: item.isVeg ? 'Veg' : 'Non-Veg',
                        foregroundColor: item.isVeg
                            ? AppColors.darkGreen
                            : AppColors.saffron,
                      ),
                      _TinyInfoChip(
                        icon: Icons.category_outlined,
                        label: item.category,
                      ),
                      _TinyInfoChip(
                        icon: Icons.storefront_outlined,
                        label: restaurant.name,
                      ),
                      _TinyInfoChip(
                        icon: Icons.timer_outlined,
                        label:
                            '${item.preparationTimeMin}-${item.preparationTimeMax} min',
                      ),
                      _TinyInfoChip(
                        icon: Icons.star,
                        label:
                            '${restaurant.rating.toStringAsFixed(1)} (${restaurant.reviews.length})',
                        foregroundColor: AppColors.saffron,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(item.description),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text(
                        _rupees(item.price),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (item.discountPercent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1AFF6B00),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${item.discountPercent}% OFF',
                            style: const TextStyle(
                              color: AppColors.saffron,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.isAvailable
                              ? const Color(0x140F9D58)
                              : const Color(0x14D93025),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.isAvailable ? 'Available' : 'Out of Stock',
                          style: TextStyle(
                            color: item.isAvailable
                                ? AppColors.darkGreen
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.addOns.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Add-ons: ${item.addOns.join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (item.customizationOptions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Customize: ${item.customizationOptions.join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (!item.isAvailable || item.stock <= 0)
                    OutlinedButton(
                      onPressed: null,
                      child: const Text('Out of stock'),
                    )
                  else if (quantity == 0)
                    FilledButton(
                      onPressed: () => controller.addToCart(
                        restaurantId: restaurant.id,
                        menuItemId: item.itemId,
                      ),
                      child: const Text('Add to cart'),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x220F5132)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => controller.removeFromCart(
                              restaurantId: restaurant.id,
                              menuItemId: item.itemId,
                            ),
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            onPressed: () => controller.addToCart(
                              restaurantId: restaurant.id,
                              menuItemId: item.itemId,
                            ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSheet extends ConsumerWidget {
  const _CartSheet({
    required this.data,
    required this.couponController,
    required this.onCheckout,
  });

  final CustomerDashboardState data;
  final TextEditingController couponController;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(customerDashboardControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cart',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Review items, update quantities, apply coupons, and choose your order type.',
            ),
            const SizedBox(height: AppSpacing.md),
            _PageLinksBar(
              actions: [
                (
                  'Continue shopping',
                  Icons.storefront_outlined,
                  () {
                    Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'DELIVERY', label: Text('Delivery')),
                ButtonSegment(value: 'PICKUP', label: Text('Pickup')),
                ButtonSegment(value: 'DINE_IN', label: Text('Dine-in')),
              ],
              selected: {data.cart.orderMode},
              onSelectionChanged: (selection) =>
                  controller.updateOrderMode(selection.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (data.cart.items.isEmpty)
              const _EmptyCard(
                title: 'Your cart is empty',
                subtitle: 'Add items from a vendor menu to continue.',
              )
            else ...[
              ...data.cart.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.restaurantName} • ${_rupees(item.price)}',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => controller.removeFromCart(
                              restaurantId: item.restaurantId,
                              menuItemId: item.menuItemId,
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            onPressed: () => controller.addToCart(
                              restaurantId: item.restaurantId,
                              menuItemId: item.menuItemId,
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          IconButton(
                            onPressed: () => controller.removeFromCart(
                              restaurantId: item.restaurantId,
                              menuItemId: item.menuItemId,
                              removeCompletely: true,
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: couponController,
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  prefixIcon: const Icon(Icons.sell_outlined),
                  suffixIcon: IconButton(
                    onPressed: () => controller.applyCoupon(
                      couponController.text.trim().isEmpty
                          ? null
                          : couponController.text.trim().toUpperCase(),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  TextButton(
                    onPressed: () => controller.applyCoupon(null),
                    child: const Text('Remove coupon'),
                  ),
                  const Spacer(),
                  if (data.cart.couponCode != null)
                    Text(
                      data.cart.couponCode!,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                color: const Color(0xFFFFFAF4),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill breakdown',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PriceRow(
                        label: 'Items total',
                        value: data.cart.subtotal,
                      ),
                      _PriceRow(label: 'Discount', value: -data.cart.discount),
                      _PriceRow(
                        label: 'Delivery fee',
                        value: _deliveryChargeForMode(data.cart.orderMode),
                      ),
                      const _PriceRow(label: 'Platform fee', value: 10),
                      _PriceRow(
                        label: 'GST',
                        value: _gstForAmount(
                          data.cart.subtotal -
                              data.cart.discount +
                              _deliveryChargeForMode(data.cart.orderMode) +
                              10,
                        ),
                      ),
                      const Divider(height: AppSpacing.xl),
                      _PriceRow(
                        label: 'Grand total',
                        value: _grandTotal(data.cart),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCheckout,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Proceed to checkout'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckoutSheet extends ConsumerWidget {
  const _CheckoutSheet({
    required this.data,
    required this.user,
    required this.onPlaceOrder,
  });

  final CustomerDashboardState data;
  final AppUser? user;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(customerDashboardControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checkout',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.md),
            _PageLinksBar(
              actions: [
                (
                  'Back to cart',
                  Icons.shopping_bag_outlined,
                  () {
                    Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _CheckoutSection(
              title: 'Delivery address',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.displayName ?? 'Customer'),
                  Text(user?.phoneNumber ?? ''),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    data.activeOrders.firstOrNull?.deliveryAddress.isNotEmpty ==
                            true
                        ? data.activeOrders.first.deliveryAddress
                        : '221B MG Road, Bengaluru, Karnataka',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: const [
                      ActionChip(label: Text('Add address'), onPressed: _noop),
                      ActionChip(label: Text('Edit address'), onPressed: _noop),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CheckoutSection(
              title: 'Payment methods',
              child: Column(
                children: [
                  ...[
                    ('RAZORPAY', 'Razorpay', Icons.bolt_outlined),
                    ('STRIPE', 'Stripe', Icons.credit_card_outlined),
                    ('WALLET', 'Wallet', Icons.account_balance_wallet_outlined),
                    ('COD', 'Cash on Delivery', Icons.payments_outlined),
                  ].map(
                    (method) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _PaymentMethodTile(
                        value: method.$1,
                        label: method.$2,
                        icon: method.$3,
                        selected: data.cart.paymentMethod == method.$1,
                        onTap: () => controller.updatePaymentMethod(method.$1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CheckoutSection(
              title: 'Order summary',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...data.cart.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${item.quantity}x ${item.name}'),
                          ),
                          Text(_rupees(item.price * item.quantity)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: AppSpacing.xl),
                  _PriceRow(label: 'Items total', value: data.cart.subtotal),
                  _PriceRow(label: 'Discount', value: -data.cart.discount),
                  _PriceRow(
                    label: 'Delivery fee',
                    value: _deliveryChargeForMode(data.cart.orderMode),
                  ),
                  const _PriceRow(label: 'Platform fee', value: 10),
                  _PriceRow(
                    label: 'Taxes',
                    value: _gstForAmount(
                      data.cart.subtotal -
                          data.cart.discount +
                          _deliveryChargeForMode(data.cart.orderMode) +
                          10,
                    ),
                  ),
                  const Divider(height: AppSpacing.xl),
                  _PriceRow(
                    label: 'Grand total',
                    value: _grandTotal(data.cart),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              color: const Color(0xFFFFFAF4),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Flow', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: AppSpacing.sm),
                    _FeatureBullet(text: 'Validate payment'),
                    _FeatureBullet(text: 'Create order'),
                    _FeatureBullet(text: 'Notify vendor'),
                    _FeatureBullet(text: 'Notify delivery partner'),
                    _FeatureBullet(text: 'Redirect to tracking page'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: data.cart.items.isEmpty ? null : onPlaceOrder,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Place order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({required this.title, required this.child});

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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.saffron : const Color(0x220F5132),
            width: selected ? 1.4 : 1,
          ),
          color: selected ? const Color(0x14FF6B00) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.saffron : AppColors.ink),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.saffron)
            else
              const Icon(Icons.circle_outlined),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final CustomerOrderModel order;

  @override
  Widget build(BuildContext context) {
    final stages = order.orderMode == 'DELIVERY'
        ? const [
            'PLACED',
            'ACCEPTED',
            'PREPARING',
            'OUT_FOR_DELIVERY',
            'DELIVERED',
          ]
        : const ['PLACED', 'ACCEPTED', 'PREPARING', 'DELIVERED'];
    final currentIndex = stages.indexOf(order.status);
    final eta = order.tracking.etaMinutes <= 0
        ? 'Arrived'
        : '${order.tracking.etaMinutes} min';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OrderTopDetails(order: order),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurantName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Order ID ${order.id}'),
                    ],
                  ),
                ),
                Chip(label: Text(order.orderMode.replaceAll('_', ' '))),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Current status: ${order.status.replaceAll('_', ' ')}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              order.orderMode == 'DELIVERY'
                  ? 'Live tracking ETA: $eta'
                  : 'Pickup ready estimate: $eta',
            ),
            const SizedBox(height: AppSpacing.sm),
            _TrackingSurface(order: order),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: List.generate(stages.length, (index) {
                final complete = index <= currentIndex;
                return Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: complete
                            ? AppColors.darkGreen
                            : const Color(0x140F5132),
                        child: Icon(
                          complete ? Icons.check : Icons.more_horiz,
                          size: 16,
                          color: complete ? Colors.white : AppColors.darkGreen,
                        ),
                      ),
                      if (index < stages.length - 1)
                        Expanded(
                          child: Container(
                            height: 3,
                            color: index < currentIndex
                                ? AppColors.darkGreen
                                : const Color(0x140F5132),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _TinyInfoChip(
                  icon: Icons.storefront_outlined,
                  label: order.restaurantName,
                ),
                _TinyInfoChip(
                  icon: Icons.person_pin_circle_outlined,
                  label: order.deliveryPartnerName ?? 'Rider assigning',
                ),
                _TinyInfoChip(
                  icon: Icons.map_outlined,
                  label: order.tracking.canTrackLive
                      ? 'Map tracking live'
                      : 'Tracking preparing',
                ),
                if (order.deliveryOtp != null && order.deliveryOtp!.isNotEmpty)
                  _TinyInfoChip(
                    icon: Icons.password_outlined,
                    label:
                        '${_otpLabelForMode(order.orderMode)} ${order.deliveryOtp!}',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.start,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _noop,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call vendor'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openCustomerTracking(order),
                  icon: const Icon(Icons.support_agent_outlined),
                  label: const Text('Track order'),
                ),
                if (['PLACED', 'ACCEPTED', 'PREPARING'].contains(order.status))
                  Consumer(
                    builder: (context, ref, _) => FilledButton.tonalIcon(
                      onPressed: () => ref
                          .read(customerDashboardControllerProvider.notifier)
                          .cancelOrder(order.id),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel order'),
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

class _TrackingSurface extends StatelessWidget {
  const _TrackingSurface({required this.order});

  final CustomerOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7FBF8), Color(0xFFFFF8F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x160F5132)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _TinyInfoChip(
                icon: Icons.location_on_outlined,
                label: '${order.tracking.distanceKm.toStringAsFixed(1)} km',
              ),
              _TinyInfoChip(
                icon: Icons.timer_outlined,
                label: '${order.tracking.etaMinutes} min ETA',
              ),
              _TinyInfoChip(
                icon: Icons.traffic_outlined,
                label: order.tracking.trafficLabel,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: const [
              Icon(Icons.storefront_outlined, color: AppColors.darkGreen),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Divider()),
              SizedBox(width: AppSpacing.sm),
              Icon(Icons.delivery_dining_outlined, color: AppColors.saffron),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Divider()),
              SizedBox(width: AppSpacing.sm),
              Icon(Icons.home_outlined, color: AppColors.ink),
            ],
          ),
          if (order.tracking.delayReason != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your order is slightly delayed due to ${order.tracking.delayReason!.toLowerCase()}.',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoreClosedCard extends StatelessWidget {
  const _StoreClosedCard({required this.restaurant});

  final RestaurantModelView restaurant;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              restaurant.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This store is currently closed. Please check back later.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.order});

  final CustomerOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OrderTopDetails(order: order),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurantName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text('Order ${order.id}'),
                    ],
                  ),
                ),
                Chip(label: Text(order.status.replaceAll('_', ' '))),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${order.items.length} items • ${_rupees(order.total)} • ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Payment: ${order.paymentMethod} • ${order.paymentStatus}'),
            if (order.deliveryOtp != null && order.deliveryOtp!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${_otpLabelForMode(order.orderMode)}: ${order.deliveryOtp!}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.saffron,
                ),
              ),
            ],
            if (order.review != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Review: ${order.review!.rating}/5 • ${order.review!.comment}',
              ),
            ],
            if (order.canReview) ...[
              const SizedBox(height: AppSpacing.md),
              _ReviewButton(order: order),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderTopDetails extends StatelessWidget {
  const _OrderTopDetails({required this.order});

  final CustomerOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _TinyInfoChip(
            icon: Icons.confirmation_number_outlined,
            label: 'Order ${_shortOrderCode(order.id)}',
          ),
          _TinyInfoChip(
            icon: Icons.currency_rupee,
            label: _rupees(order.total),
          ),
          _TinyInfoChip(
            icon: Icons.calendar_today_outlined,
            label:
                '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
          ),
          _TinyInfoChip(
            icon: Icons.info_outline,
            label: order.status.replaceAll('_', ' '),
          ),
          if (order.deliveryOtp != null && order.deliveryOtp!.isNotEmpty)
            _TinyInfoChip(
              icon: Icons.password_outlined,
              label:
                  '${_otpShortLabelForMode(order.orderMode)} ${order.deliveryOtp!}',
            ),
        ],
      ),
    );
  }
}

class _ReviewButton extends ConsumerWidget {
  const _ReviewButton({required this.order});

  final CustomerOrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _showReviewDialog(context, ref, order),
      icon: const Icon(Icons.reviews_outlined),
      label: const Text('Rate & review'),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  const _WalletCard({required this.wallet});

  final CustomerWalletModel wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current balance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _rupees(wallet.walletBalance),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [200, 500, 1000]
                  .map(
                    (amount) => FilledButton.tonal(
                      onPressed: () => ref
                          .read(customerDashboardControllerProvider.notifier)
                          .addFunds(amount),
                      child: Text('Add ${_rupees(amount)}'),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Transaction history',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (wallet.transactions.isEmpty)
              const _EmptyCard(
                title: 'No wallet activity yet',
                subtitle: 'Top-ups, refunds, and order debits will show here.',
              )
            else
              ...wallet.transactions
                  .take(6)
                  .map(
                    (transaction) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Card(
                        color: const Color(0xFFFFFAF4),
                        child: ListTile(
                          title: Text(
                            transaction.description,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(transaction.category),
                          trailing: Text(
                            '${transaction.type == 'CREDIT' ? '+' : '-'}${_rupees(transaction.amount)}',
                            style: TextStyle(
                              color: transaction.type == 'CREDIT'
                                  ? AppColors.darkGreen
                                  : AppColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _OfferBannerCard extends StatelessWidget {
  const _OfferBannerCard({required this.banner});

  final OfferBannerModel banner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFF9F5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Offer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Text(
            banner.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            banner.subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        color: const Color(0xFFFFFAF4),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.saffron),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
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
          Text(
            value < 0 ? '-${_rupees(value.abs())}' : _rupees(value),
            style: style,
          ),
        ],
      ),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

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
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle),
            const SizedBox(height: AppSpacing.md),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.text});

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

class _TinyInfoChip extends StatelessWidget {
  const _TinyInfoChip({
    required this.icon,
    required this.label,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color? foregroundColor;

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
          Icon(icon, size: 16, color: foregroundColor ?? AppColors.ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor ?? AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.saffron),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
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
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.restaurant,
    required this.title,
    required this.subtitle,
  });

  final RestaurantModelView restaurant;
  final String title;
  final String subtitle;
}

class _NotificationItem {
  const _NotificationItem({
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

List<_SearchResult> _searchResults(
  CustomerDashboardState data,
  List<RestaurantModelView> restaurants, {
  String? queryOverride,
}) {
  final query = (queryOverride ?? data.search).trim().toLowerCase();
  final results = <_SearchResult>[];

  for (final restaurant in restaurants) {
    if (query.isEmpty ||
        restaurant.name.toLowerCase().contains(query) ||
        restaurant.category.toLowerCase().contains(query) ||
        restaurant.offerText.toLowerCase().contains(query) ||
        restaurant.cuisine.any((item) => item.toLowerCase().contains(query))) {
      results.add(
        _SearchResult(
          restaurant: restaurant,
          title: restaurant.name,
          subtitle:
              '${restaurant.category} • ${restaurant.cuisine.join(', ')} • ${restaurant.deliveryTime} min',
        ),
      );
    }

    for (final item in restaurant.menuItems) {
      if (query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          (item.isVeg ? 'veg' : 'non-veg').contains(query) ||
          item.addOns.any((option) => option.toLowerCase().contains(query)) ||
          item.customizationOptions.any(
            (option) => option.toLowerCase().contains(query),
          )) {
        results.add(
          _SearchResult(
            restaurant: restaurant,
            title: item.name,
            subtitle:
                '${restaurant.name} • ${item.category} • ${_rupees(item.price)}${item.discountPercent > 0 ? ' • ${item.discountPercent}% OFF' : ''}',
          ),
        );
      }
    }
  }

  return results.take(20).toList(growable: false);
}

class _MenuItemImage extends StatelessWidget {
  const _MenuItemImage({required this.item});

  final MenuItemModel item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.buildAssetUrl(item.imagePath);
    if (imageUrl.isEmpty) {
      return Icon(
        item.isVeg ? Icons.eco_outlined : Icons.set_meal_outlined,
        color: item.isVeg ? AppColors.darkGreen : AppColors.saffron,
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Icon(
        item.isVeg ? Icons.eco_outlined : Icons.set_meal_outlined,
        color: item.isVeg ? AppColors.darkGreen : AppColors.saffron,
      ),
    );
  }
}

List<RestaurantModelView> _applyRestaurantFilters(
  List<RestaurantModelView> restaurants, {
  required bool pureVegOnly,
  required bool nearbyOnly,
  required String? priceFilter,
}) {
  final filtered = restaurants
      .where((restaurant) {
        final vegPass =
            !pureVegOnly ||
            restaurant.menuItems.isNotEmpty &&
                restaurant.menuItems.every((item) => item.isVeg);
        final nearbyPass = !nearbyOnly || restaurant.deliveryTime <= 25;
        return vegPass && nearbyPass;
      })
      .toList(growable: false);

  if (priceFilter != null) {
    final sorted = [...filtered];
    sorted.sort(
      (a, b) =>
          _priceWeight(a.priceLevel).compareTo(_priceWeight(b.priceLevel)),
    );
    return sorted;
  }

  return filtered;
}

List<_NotificationItem> _buildNotifications(CustomerDashboardState data) {
  final items = <_NotificationItem>[
    ...data.activeOrders.map(
      (order) => _NotificationItem(
        title: 'Order ${order.status.replaceAll('_', ' ')}',
        subtitle: '${order.restaurantName} is updating your order.',
        meta: order.orderMode == 'DELIVERY' ? 'Tracking' : 'Pickup',
        icon: Icons.delivery_dining_outlined,
      ),
    ),
    ...data.orderHistory
        .where((order) => order.refundedAmount > 0)
        .map(
          (order) => _NotificationItem(
            title: 'Refund processed',
            subtitle:
                '${_rupees(order.refundedAmount)} returned for order ${order.id}.',
            meta: 'Refund',
            icon: Icons.currency_rupee,
          ),
        ),
    ...data.coupons
        .take(2)
        .map(
          (coupon) => _NotificationItem(
            title: 'Offer available',
            subtitle: '${coupon.code} gives extra savings on your next order.',
            meta: 'Offer',
            icon: Icons.local_offer_outlined,
          ),
        ),
  ];

  return items;
}

String _otpLabelForMode(String orderMode) {
  return switch (orderMode) {
    'PICKUP' => 'Pickup OTP',
    'DINE_IN' => 'Dine-in OTP',
    _ => 'Verification OTP',
  };
}

String _otpShortLabelForMode(String orderMode) {
  return switch (orderMode) {
    'PICKUP' => 'Pickup OTP',
    'DINE_IN' => 'Dine-in OTP',
    _ => 'OTP',
  };
}

Future<void> _handleCheckout(
  BuildContext context,
  WidgetRef ref,
  CustomerDashboardState data,
) async {
  final checkout = await ref
      .read(customerDashboardControllerProvider.notifier)
      .placeOrder();

  if (!context.mounted) {
    return;
  }

  if (data.cart.paymentMethod == 'COD' || data.cart.paymentMethod == 'WALLET') {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${data.cart.paymentMethod} order placed successfully. Tracking is now available in Orders.',
          ),
        ),
      );
    return;
  }

  await _showPaymentVerificationDialog(context, ref, checkout);
}

Future<void> _showPaymentVerificationDialog(
  BuildContext context,
  WidgetRef ref,
  CustomerCheckoutModel checkout,
) async {
  final paymentIdController = TextEditingController();
  final signatureController = TextEditingController();
  final order = checkout.order;
  final provider = order.paymentMethod;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: Text('Verify $provider payment'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ${order.id} created. Complete the provider checkout, then verify it here.',
                ),
                const SizedBox(height: AppSpacing.sm),
                if (checkout.checkout != null)
                  SelectableText(checkout.checkout.toString()),
                if (provider == 'RAZORPAY') ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: paymentIdController,
                    decoration: const InputDecoration(
                      labelText: 'Razorpay payment id',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: signatureController,
                    decoration: const InputDecoration(
                      labelText: 'Razorpay signature',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              final payload = <String, dynamic>{};
              if (provider == 'RAZORPAY') {
                payload['razorpay_payment_id'] = paymentIdController.text
                    .trim();
                payload['razorpay_signature'] = signatureController.text.trim();
              }

              await ref
                  .read(customerDashboardControllerProvider.notifier)
                  .verifyPayment(orderId: order.id, payload: payload);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Verify payment'),
          ),
        ],
      );
    },
  );
}

Future<void> _showReviewDialog(
  BuildContext context,
  WidgetRef ref,
  CustomerOrderModel order,
) async {
  final commentController = TextEditingController();
  int rating = 5;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text('Review ${order.restaurantName}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rate vendor and delivery partner experience'),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: () => setState(() => rating = index + 1),
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: AppColors.saffron,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Add a review comment',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Photo upload can be added when media upload is wired.',
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
              await ref
                  .read(customerDashboardControllerProvider.notifier)
                  .submitReview(
                    orderId: order.id,
                    rating: rating,
                    comment: commentController.text.trim(),
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
}

int _itemQuantity(CustomerCartModel cart, String restaurantId, String itemId) {
  for (final item in cart.items) {
    if (item.restaurantId == restaurantId && item.menuItemId == itemId) {
      return item.quantity;
    }
  }
  return 0;
}

int _cartCount(CustomerCartModel cart) {
  return cart.items.fold<int>(0, (sum, item) => sum + item.quantity);
}

String _rupees(int amount) => '₹$amount';

String _shortOrderCode(String id) {
  return id.length > 4
      ? id.substring(id.length - 4).toUpperCase()
      : id.toUpperCase();
}

String _deliveryFee(RestaurantModelView restaurant) {
  final fee = 18 + ((restaurant.deliveryTime / 5).round() * 2);
  return '₹$fee fee';
}

int _priceWeight(String value) {
  return switch (value.trim()) {
    '₹' => 1,
    '₹₹' => 2,
    '₹₹₹' => 3,
    '₹₹₹₹' => 4,
    _ => 99,
  };
}

int _deliveryChargeForMode(String orderMode) {
  return switch (orderMode) {
    'PICKUP' || 'DINE_IN' => 0,
    _ => 30,
  };
}

int _gstForAmount(int amount) {
  final safeAmount = amount < 0 ? 0 : amount;
  return (safeAmount * 0.05).round();
}

int _grandTotal(CustomerCartModel cart) {
  final delivery = _deliveryChargeForMode(cart.orderMode);
  final platformFee = 10;
  final preTax = cart.subtotal - cart.discount + delivery + platformFee;
  return preTax + _gstForAmount(preTax);
}

bool _isVegCuisine(String value) {
  final lower = value.toLowerCase();
  return lower.contains('veg') ||
      lower.contains('salad') ||
      lower.contains('paneer');
}

Color _parseColor(String value) {
  final buffer = StringBuffer();
  if (value.length == 6 || value.length == 7) {
    buffer.write('ff');
  }
  buffer.write(value.replaceFirst('#', ''));
  return Color(int.tryParse(buffer.toString(), radix: 16) ?? 0xFFFFF4EA);
}

void _noop() {}

Future<void> _openCustomerTracking(CustomerOrderModel order) async {
  final destinationLabel = order.deliveryAddress.isNotEmpty
      ? order.deliveryAddress
      : order.restaurantName;
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(destinationLabel)}',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
