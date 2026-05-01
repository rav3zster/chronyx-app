import 'dart:math' as math;
import 'dart:ui';
import 'package:chronyx/core/constants/app_colors.dart';
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/core/widgets/secondary_button.dart';
import 'package:flutter/material.dart';

/// The login / welcome screen for Chronyx.
///
/// Pure UI — no business logic, no API calls, no state management.
/// All interactive callbacks are exposed via constructor parameters so
/// the caller can wire them to whatever auth logic they prefer.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.onGoogleSignIn,
    this.onContinueWithEmail,
  });

  /// Called when the user taps the Google Sign-In button.
  final VoidCallback? onGoogleSignIn;

  /// Called when the user taps "Continue with email".
  final VoidCallback? onContinueWithEmail;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  // Individual staggered animations
  late final Animation<double> _bgGlowAnim;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _bgGlowAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.1, 0.55, curve: Curves.easeOutCubic),
    ));

    _logoFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
    ));

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOutCubic),
    ));

    _cardFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    ));

    _footerFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    ));

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // ── Animated ambient glow background ───────────────────────────────
          _AmbientBackground(progress: _bgGlowAnim),

          // ── Content ────────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingH,
                  vertical: AppSpacing.pagePaddingV,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Logo ────────────────────────────────────────────
                      SlideTransition(
                        position: _logoSlide,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: const _LogoSection(),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // ── Auth card ───────────────────────────────────────
                      SlideTransition(
                        position: _cardSlide,
                        child: FadeTransition(
                          opacity: _cardFade,
                          child: _AuthCard(
                            onGoogleSignIn: widget.onGoogleSignIn,
                            onContinueWithEmail: widget.onContinueWithEmail,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Footer ──────────────────────────────────────────
                      FadeTransition(
                        opacity: _footerFade,
                        child: const _FooterSection(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Ambient Background
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground({required this.progress});
  final Animation<double> progress;

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheCtrl;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.progress, _breatheCtrl]),
      builder: (context, _) {
        final breathe = _breatheCtrl.value;
        final entered = widget.progress.value;
        final size = MediaQuery.of(context).size;

        return SizedBox.expand(
          child: CustomPaint(
            painter: _GlowPainter(
              breathe: breathe,
              entered: entered,
              size: size,
            ),
          ),
        );
      },
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.breathe,
    required this.entered,
    required this.size,
  });

  final double breathe;
  final double entered;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Dark base
    canvas.drawRect(
      Offset.zero & canvasSize,
      Paint()..color = AppColors.darkBackground,
    );

    // Top-left indigo glow
    final indigoRadius = (canvasSize.width * 0.75) * entered *
        (0.85 + breathe * 0.15);
    final indigoPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.indigo.withOpacity(0.18 * entered),
          AppColors.indigo.withOpacity(0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(canvasSize.width * 0.15, canvasSize.height * 0.15),
          radius: indigoRadius,
        ),
      );
    canvas.drawCircle(
      Offset(canvasSize.width * 0.15, canvasSize.height * 0.15),
      indigoRadius,
      indigoPaint,
    );

    // Bottom-right violet glow
    final violetRadius = (canvasSize.width * 0.7) * entered *
        (0.9 + (1 - breathe) * 0.1);
    final violetPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.violet.withOpacity(0.14 * entered),
          AppColors.violet.withOpacity(0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(canvasSize.width * 0.85, canvasSize.height * 0.8),
          radius: violetRadius,
        ),
      );
    canvas.drawCircle(
      Offset(canvasSize.width * 0.85, canvasSize.height * 0.8),
      violetRadius,
      violetPaint,
    );

    // Centre subtle grid overlay
    _drawGrid(canvas, canvasSize, entered);
  }

  void _drawGrid(Canvas canvas, Size size, double opacity) {
    if (opacity < 0.3) return;
    final paint = Paint()
      ..color = AppColors.darkBorderSubtle.withOpacity(0.25 * opacity)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.breathe != breathe || old.entered != entered;
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo Section
// ─────────────────────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── App icon ──────────────────────────────────────────────────────
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            boxShadow: [
              BoxShadow(
                color: AppColors.indigo.withOpacity(0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const _ChronyxLogoIcon(),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── App name ───────────────────────────────────────────────────────
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppColors.textPrimaryDark,
              Color(0xFFBFC8FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'Chronyx',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white, // masked by ShaderMask
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Tagline ───────────────────────────────────────────────────────
        Text(
          'Time, mastered.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 0.3,
              ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Pill badge ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.indigo.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: AppColors.indigo.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'v1.0 · Early Access',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Custom logo icon ──────────────────────────────────────────────────────────

class _ChronyxLogoIcon extends StatelessWidget {
  const _ChronyxLogoIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LogoPainter(),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer ring
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.36, ringPaint);

    // Clock hands
    final handPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Hour hand — pointing to ~10
    final hourAngle = (-math.pi / 2) + (10 / 12) * 2 * math.pi;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + math.cos(hourAngle) * size.width * 0.2,
          cy + math.sin(hourAngle) * size.width * 0.2),
      handPaint,
    );

    // Minute hand — pointing to ~12
    final minAngle = -math.pi / 2;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + math.cos(minAngle) * size.width * 0.3,
          cy + math.sin(minAngle) * size.width * 0.3),
      handPaint..strokeWidth = 1.5,
    );

    // Centre dot
    canvas.drawCircle(
      Offset(cx, cy),
      3,
      Paint()..color = Colors.white,
    );

    // Accent arc (progress indicator feel)
    final arcPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.36),
      -math.pi / 2,
      (2 * math.pi) * 0.72,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth Card
// ─────────────────────────────────────────────────────────────────────────────

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    this.onGoogleSignIn,
    this.onContinueWithEmail,
  });

  final VoidCallback? onGoogleSignIn;
  final VoidCallback? onContinueWithEmail;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderRadius: AppSpacing.radiusXxl,
      backgroundColor: AppColors.darkSurface2.withOpacity(0.65),
      borderColor: AppColors.darkBorder,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: AppColors.indigo.withOpacity(0.08),
          blurRadius: 40,
          offset: const Offset(0, 0),
          spreadRadius: 1,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ─────────────────────────────────────────────────────
          Text(
            'Get started',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sign in to your workspace and take control\nof your time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.6,
                ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Google Sign-In ───────────────────────────────────────────────
          PrimaryButton(
            label: 'Continue with Google',
            onPressed: onGoogleSignIn,
            icon: const _GoogleIcon(),
            gradient: const [AppColors.indigo, AppColors.violet],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Email option ─────────────────────────────────────────────────
          SecondaryButton(
            label: 'Continue with email',
            onPressed: onContinueWithEmail,
            icon: Icon(
              Icons.mail_outline_rounded,
              size: AppSpacing.iconMd,
              color: AppColors.textSecondaryDark,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Divider + social proof ───────────────────────────────────────
          const _SocialProofRow(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Icon (vector, no external asset needed)
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // White circle background
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    // G letter segments (simplified but recognisable)
    final paints = [
      Paint()..color = const Color(0xFF4285F4), // blue
      Paint()..color = const Color(0xFF34A853), // green
      Paint()..color = const Color(0xFFFBBC05), // yellow
      Paint()..color = const Color(0xFFEA4335), // red
    ];

    // Blue: top-right arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      -math.pi / 6,
      -math.pi * 0.9,
      false,
      paints[0]..style = PaintingStyle.stroke..strokeWidth = r * 0.28,
    );

    // Green: bottom-right arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      math.pi / 6,
      math.pi * 0.35,
      false,
      paints[1]..style = PaintingStyle.stroke..strokeWidth = r * 0.28,
    );

    // Yellow: bottom-left arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      math.pi * 0.55,
      math.pi * 0.4,
      false,
      paints[2]..style = PaintingStyle.stroke..strokeWidth = r * 0.28,
    );

    // Red: top-left arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      math.pi * 0.95,
      math.pi * 0.4,
      false,
      paints[3]..style = PaintingStyle.stroke..strokeWidth = r * 0.28,
    );

    // Horizontal bar for the G
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.1, r * 0.72, r * 0.22),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleIconPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Social Proof Row
// ─────────────────────────────────────────────────────────────────────────────

class _SocialProofRow extends StatelessWidget {
  const _SocialProofRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Stacked avatar indicators
        SizedBox(
          width: 72,
          height: 28,
          child: Stack(
            children: List.generate(4, (i) {
              const colors = [
                Color(0xFF5B6EF5),
                Color(0xFF8B5CF6),
                Color(0xFF06B6D4),
                Color(0xFF22D3A6),
              ];
              return Positioned(
                left: i * 16.0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.darkSurface2,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ['A', 'B', 'C', '+'][i],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Join 2,400+ professionals\nwho track smarter.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark.withOpacity(0.7),
                  height: 1.5,
                ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Feature pills
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: const [
            _FeaturePill(icon: Icons.bolt_rounded, label: 'Instant sync'),
            _FeaturePill(icon: Icons.lock_outline_rounded, label: 'End-to-end encrypted'),
            _FeaturePill(icon: Icons.devices_rounded, label: 'All platforms'),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Legal
        Text(
          'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textDisabledDark,
                height: 1.6,
              ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurface2.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.darkBorderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.indigo),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}
