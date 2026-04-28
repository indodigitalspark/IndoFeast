import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'shared/widgets/app_async_state.dart';
import 'routes/app_router.dart';

class IndoFeastApp extends ConsumerWidget {
  const IndoFeastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    ErrorWidget.builder = (details) =>
        Material(child: AppErrorState(message: details.exceptionAsString()));

    return MaterialApp.router(
      title: 'IndoFeast',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
