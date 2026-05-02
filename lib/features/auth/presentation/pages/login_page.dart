import 'dart:math' as math;
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

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  bool _oauthLaunchBusy = false;

  late final AnimationController _bgCtrl;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _oauthLaunchBusy = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;
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
      if (mounted) setState(() => _oauthLaunchBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bool buttonBusy =
        _oauthLaunchBusy || (authState.isLoading && !authState.hasValue);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated background ────────────────────────────────────────
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _BackgroundPainter(
                  t: _bgCtrl.value,
                  primaryColor: scheme.primary,
                  secondaryColor: scheme.secondary,
                  scaffoldBg: Theme.of(context).scaffoldBackgroundColor,
                ),
              );
            },
          ),

          // ── Content ────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      FadeTransition(
                        opacity: _logoFade,
                        child: _ChronyxLogo(color: scheme.primary),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Card
                      FadeTransition(
                        opacity: _fadeIn,
                        child: SlideTransition(
                          position: _slideUp,
                          child: _LoginCard(
                            scheme: scheme,
                            textTheme: textTheme,
                            buttonBusy: buttonBusy,
                            onSignIn: _signIn,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Login Card ────────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.scheme,
    required this.textTheme,
    required this.buttonBusy,
    required this.onSignIn,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool buttonBusy;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surface.withValues(alpha: 0.70)
            : scheme.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.loginTitle,
            style: textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.loginSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: AppStrings.continueWithGoogle,
            isLoading: buttonBusy,
            onPressed: onSignIn,
            icon: _GoogleIcon(size: AppSpacing.iconMd),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: AppSpacing.iconSm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Secured with OAuth 2.0',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────

class _ChronyxLogo extends StatelessWidget {
  const _ChronyxLogo({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        CustomPaint(
          size: const Size(64, 64),
          painter: _ClockLogoPainter(primaryColor: color),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Chronyx',
          style: textTheme.headlineMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Your time, mastered.',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter({
    required this.t,
    required this.primaryColor,
    required this.secondaryColor,
    required this.scaffoldBg,
  });

  final double t;
  final Color primaryColor;
  final Color secondaryColor;
  final Color scaffoldBg;

  @override
  void paint(Canvas canvas, Size size) {
    // Background fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = scaffoldBg,
    );

    // Orb 1 — primary color, floats up/down
    final orb1 = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.25),
          primaryColor.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.25,
            size.height * (0.25 + 0.08 * math.sin(t * math.pi)),
          ),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(
        size.width * 0.25,
        size.height * (0.25 + 0.08 * math.sin(t * math.pi)),
      ),
      size.width * 0.55,
      orb1,
    );

    // Orb 2 — secondary color, floats opposite phase
    final orb2 = Paint()
      ..shader = RadialGradient(
        colors: [
          secondaryColor.withValues(alpha: 0.20),
          secondaryColor.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.8,
            size.height *
                (0.65 + 0.07 * math.cos(t * math.pi + math.pi / 2)),
          ),
          radius: size.width * 0.50,
        ),
      );
    canvas.drawCircle(
      Offset(
        size.width * 0.8,
        size.height * (0.65 + 0.07 * math.cos(t * math.pi + math.pi / 2)),
      ),
      size.width * 0.50,
      orb2,
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.t != t ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor ||
      old.scaffoldBg != scaffoldBg;
}



class _ClockLogoPainter extends CustomPainter {
  const _ClockLogoPainter({required this.primaryColor});
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Outer ring
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Hour hand (10 o'clock)
    final hourPaint = Paint()
      ..color = primaryColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;
    canvas.drawLine(
      c,
      c +
          Offset(
            -r * 0.4 * math.sin(math.pi / 6),
            -r * 0.4 * math.cos(math.pi / 6),
          ),
      hourPaint,
    );

    // Minute hand (12 o'clock)
    final minPaint = Paint()
      ..color = primaryColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
    canvas.drawLine(c, c + Offset(0, -r * 0.58), minPaint);

    // Center dot
    canvas.drawCircle(c, 3.5, Paint()..color = primaryColor);
  }

  @override
  bool shouldRepaint(_ClockLogoPainter old) =>
      old.primaryColor != primaryColor;
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Simplified G — blue arc + red, green, yellow quadrants
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(c, r, bgPaint);

    // Blue section
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi,
      true,
      Paint()..color = const Color(0xFF4285F4),
    );
    // Red section
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi / 2,
      math.pi / 2,
      true,
      Paint()..color = const Color(0xFFEA4335),
    );
    // Green section
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      0,
      math.pi / 2,
      true,
      Paint()..color = const Color(0xFF34A853),
    );
    // Yellow + cutout
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      -math.pi / 2,
      true,
      Paint()..color = const Color(0xFFFBBC05),
    );
    // Inner white circle (donut)
    canvas.drawCircle(c, r * 0.55, Paint()..color = Colors.white);
    // G bar
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - r * 0.18, r * 0.92, r * 0.36),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleIconPainter _) => false;
}
