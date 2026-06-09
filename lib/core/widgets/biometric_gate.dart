import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronyx/core/services/biometric_service.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';

final biometricGateNotifierProvider =
    StateNotifierProvider<BiometricGateNotifier, BiometricGateState>((ref) {
  return BiometricGateNotifier(ref);
});

class BiometricGateState {
  final bool isLocked;
  final bool isAuthenticating;
  final String? error;

  const BiometricGateState({
    this.isLocked = true,
    this.isAuthenticating = false,
    this.error,
  });

  BiometricGateState copyWith({
    bool? isLocked,
    bool? isAuthenticating,
    String? error,
  }) {
    return BiometricGateState(
      isLocked: isLocked ?? this.isLocked,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      error: error,
    );
  }
}

class BiometricGateNotifier extends StateNotifier<BiometricGateState> {
  final Ref _ref;

  BiometricGateNotifier(this._ref) : super(const BiometricGateState()) {
    final settings = _ref.read(settingsProvider);
    state = BiometricGateState(isLocked: settings.requireBiometrics);
  }

  Future<void> authenticate() async {
    final settings = _ref.read(settingsProvider);
    if (!settings.requireBiometrics) {
      state = state.copyWith(isLocked: false);
      return;
    }

    state = state.copyWith(isAuthenticating: true, error: null);

    final biometricService = _ref.read(biometricServiceProvider);
    final available = await biometricService.isAvailable();

    if (!available) {
      state = state.copyWith(
        isLocked: false,
        isAuthenticating: false,
        error: 'Biometrics not available on this device',
      );
      return;
    }

    final authenticated = await biometricService.authenticate(
      reason: 'Authenticate to unlock Chronyx',
    );

    if (authenticated) {
      state = state.copyWith(isLocked: false, isAuthenticating: false);
    } else {
      state = state.copyWith(
        isAuthenticating: false,
        error: 'Authentication failed',
      );
    }
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
  }

  void lock() {
    state = state.copyWith(isLocked: true, error: null);
  }

  void retry() {
    state = state.copyWith(error: null);
    authenticate();
  }
}

class BiometricGate extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricGate({super.key, required this.child});

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

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
    if (mounted) {
      setState(() {
        _lifecycleState = state;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateState = ref.watch(biometricGateNotifierProvider);
    final settings = ref.watch(settingsProvider);

    final showBlur = settings.requireBiometrics &&
        (_lifecycleState == AppLifecycleState.inactive ||
            _lifecycleState == AppLifecycleState.paused);

    if (settings.requireBiometrics && gateState.isLocked) {
      return _LockScreen(
        isAuthenticating: gateState.isAuthenticating,
        error: gateState.error,
        onAuthenticate: () =>
            ref.read(biometricGateNotifierProvider.notifier).authenticate(),
      );
    }

    if (showBlur) {
      return Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      );
    }

    return widget.child;
  }
}

class _LockScreen extends StatelessWidget {
  final bool isAuthenticating;
  final String? error;
  final VoidCallback onAuthenticate;

  const _LockScreen({
    required this.isAuthenticating,
    required this.onAuthenticate,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.surfaceContainerLow,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 80,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chronyx',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your focus companion',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: isAuthenticating ? null : onAuthenticate,
                      icon: isAuthenticating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: Text(
                        isAuthenticating
                            ? 'Authenticating...'
                            : 'Unlock with Biometrics',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
