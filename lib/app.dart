import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/routing/app_router.dart';
import 'package:chronyx/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChronyxApp extends ConsumerWidget {
  const ChronyxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      // Dark is the premium default; light is available for system preference
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
