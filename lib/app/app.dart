import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/time/today_provider.dart';
import 'router.dart';

class DeepListApp extends ConsumerStatefulWidget {
  const DeepListApp({super.key});

  @override
  ConsumerState<DeepListApp> createState() => _DeepListAppState();
}

class _DeepListAppState extends ConsumerState<DeepListApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(todayProvider);
    return MaterialApp.router(
      title: 'DeepList',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeControllerProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
