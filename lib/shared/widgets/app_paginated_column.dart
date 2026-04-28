import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

class AppPaginatedColumn<T> extends StatefulWidget {
  const AppPaginatedColumn({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.initialCount = 6,
    this.step = 6,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int initialCount;
  final int step;

  @override
  State<AppPaginatedColumn<T>> createState() => _AppPaginatedColumnState<T>();
}

class _AppPaginatedColumnState<T> extends State<AppPaginatedColumn<T>> {
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.initialCount;
  }

  @override
  void didUpdateWidget(covariant AppPaginatedColumn<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _visibleCount = widget.initialCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = widget.items
        .take(_visibleCount)
        .toList(growable: false);
    final hasMore = widget.items.length > visibleItems.length;

    return Column(
      children: [
        ...visibleItems.asMap().entries.map(
          (entry) => widget.itemBuilder(context, entry.value, entry.key),
        ),
        if (hasMore) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: () {
              setState(() {
                _visibleCount = (_visibleCount + widget.step).clamp(
                  0,
                  widget.items.length,
                );
              });
            },
            child: Text(
              'Load more (${widget.items.length - visibleItems.length} left)',
            ),
          ),
        ],
      ],
    );
  }
}
