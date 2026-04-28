import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/breakpoints.dart';
import '../widgets/app_logo.dart';

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= Breakpoints.tablet;
    final isCompact = width < 380;
    final horizontalPadding = width >= Breakpoints.desktop
        ? AppSpacing.xl
        : width >= Breakpoints.tablet
        ? AppSpacing.lg
        : AppSpacing.md;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompact ? 64 : 72,
        title: Row(
          children: [
            const AppLogo(size: 34),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                maxLines: isCompact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: actions,
      ),
      body: Row(
        children: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                extended: width >= Breakpoints.desktop,
                indicatorColor: AppColors.saffron,
                destinations: destinations
                    .map(
                      (item) => NavigationRailDestination(
                        icon: item.icon,
                        selectedIcon: item.selectedIcon ?? item.icon,
                        label: Text(item.label),
                      ),
                    )
                    .toList(),
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
                    child: body,
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
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            ),
    );
  }
}
