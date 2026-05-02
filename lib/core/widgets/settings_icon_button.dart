import 'package:chronyx/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A reusable settings icon button for use in AppBar actions.
class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.tune_rounded),
      tooltip: 'Settings',
      onPressed: () => context.push(AppRoutes.settings),
    );
  }
}
