import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _oauthLaunchBusy = false;

  Future<void> _signIn() async {
    setState(() {
      _oauthLaunchBusy = true;
    });
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) {
        return;
      }
      final authState = ref.read(authProvider);
      authState.whenOrNull(
        error: (error, _) {
          final message = ErrorMessageMapper.fromError(error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _oauthLaunchBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bool buttonBusy =
        _oauthLaunchBusy || (authState.isLoading && !authState.hasValue);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  AppStrings.loginTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.loginSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: AppStrings.continueWithGoogle,
                  isLoading: buttonBusy,
                  onPressed: _signIn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
