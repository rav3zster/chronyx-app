import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/routing/app_router.dart';
import 'package:chronyx/core/theme/theme_provider.dart';
import 'package:chronyx/core/widgets/biometric_gate.dart';
import 'package:chronyx/core/services/inactivity_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChronyxApp extends ConsumerWidget {
  const ChronyxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeData = ref.watch(resolvedThemeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: themeData,
      routerConfig: router,
      builder: (context, child) {
        return Listener(
          onPointerDown: (_) {
            ref.read(inactivityLockProvider).notifyActivity();
          },
          child: BiometricGate(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
