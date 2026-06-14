import 'dart:math' as math;
import 'package:chronyx/core/services/ambient_sound_service.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:chronyx/core/services/session_recovery_service.dart';
import 'package:chronyx/core/services/sound_service.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/life_insights/presentation/pages/session_celebration_sheet.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/session_prefill_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Pomodoro Presets ──────────────────────────────────────────────────────────

class _PomodoroPreset {
  const _PomodoroPreset(this.label, this.workMinutes, this.breakMinutes);
  final String label;
  final int workMinutes;
  final int breakMinutes;
}

const _pomodoroPresets = [
  _PomodoroPreset('25 / 5', 25, 5),
  _PomodoroPreset('50 / 10', 50, 10),
  _PomodoroPreset('90 / 20', 90, 20),
];

// ── Color scheme per state ────────────────────────────────────────────────────

Color _ringColor(BuildContext ctx, TimeEntry? session) {
  if (session == null) return Theme.of(ctx).colorScheme.primary;
  if (session.isPaused) return const Color(0xFFF59E0B); // amber
  if (session.category == TaskCategory.break_) return const Color(0xFF34D399); // emerald
  return switch (session.sessionMode) {
    SessionMode.pomodoro => const Color(0xFFEF4444), // tomato red
    SessionMode.timer => const Color(0xFF6366F1),    // indigo
    SessionMode.custom => const Color(0xFF8B5CF6),   // violet
    SessionMode.stopwatch => const Color(0xFF22D3A6), // teal
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// Focus Page
// ═════════════════════════════════════════════════════════════════════════════

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with TickerProviderStateMixin {

  // ── Setup form state ───────────────────────────────────────────────────────
  final _taskCtrl = TextEditingController();
  final _taskFocus = FocusNode();
  final _tagCtrl = TextEditingController();
  TaskCategory _cat = TaskCategory.productive;
  SessionMode _mode = SessionMode.stopwatch;
  EnergyLevel _energy = EnergyLevel.medium;
  int? _targetMins;
  int? _breakMins;
  String? _linkedTaskId;
  List<String> _tags = [];
  int _pomodoroIdx = 0;

  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _breatheCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _completionCtrl;
  late Animation<double> _breathe;
  late Animation<double> _completionRing;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _immersive = false; // hides setup, shows only timer

  @override
  void initState() {
    super.initState();

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _completionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _breathe = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );

    _completionRing = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _completionCtrl, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkPrefill();
    });
  }

  void _checkPrefill() {
    final prefill = ref.read(sessionPrefillProvider);
    if (prefill != null) {
      _taskCtrl.text = prefill.taskName;
      _linkedTaskId = prefill.projectTaskId;
      setState(() => _cat = prefill.category);
      ref.read(sessionPrefillProvider.notifier).state = null;
    }
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _pulseCtrl.dispose();
    _completionCtrl.dispose();
    _taskCtrl.dispose();
    _taskFocus.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // ── Computed ───────────────────────────────────────────────────────────────

  TimeEntry? get _active {
    final entries = ref.watch(timeEntriesProvider).value ?? [];
    return entries.where((e) => e.isOngoing).firstOrNull;
  }

  double _progress(TimeEntry e) {
    if (e.targetDurationMinutes == null || e.targetDurationMinutes! <= 0) {
      return 0.0;
    }
    return (e.elapsedSeconds / (e.targetDurationMinutes! * 60)).clamp(0.0, 1.0);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    ref.read(soundServiceProvider).buttonPress();

    final entries = ref.read(timeEntriesProvider).value ?? [];
    final existing = entries.where((e) => e.isOngoing).firstOrNull;

    if (existing != null) {
      final choice = await _showConflict(existing);
      if (choice == null || choice == 'keep') return;
      if (choice == 'stop') await _stop(existing.id);
    }

    int? tMins;
    int? bMins;
    if (_mode == SessionMode.pomodoro) {
      tMins = _pomodoroPresets[_pomodoroIdx].workMinutes;
      bMins = _pomodoroPresets[_pomodoroIdx].breakMinutes;
    } else if (_mode == SessionMode.timer || _mode == SessionMode.custom) {
      tMins = _targetMins;
      bMins = _breakMins;
    }

    final taskName = _taskCtrl.text.trim();
    try {
      await ref.read(timeEntriesProvider.notifier).startSession(
        taskName: taskName.isEmpty ? 'Focus Session' : taskName,
        category: _cat,
        projectTaskId: _linkedTaskId,
        sessionMode: _mode,
        targetDurationMinutes: tMins,
        tags: _tags.isEmpty ? null : List.from(_tags),
        energyLevel: _energy,
        breakDurationMinutes: bMins,
        ignoreActiveCheck: true,
      );

      // Persist for recovery
      final active = ref.read(timeEntriesProvider).value?.where((e) => e.isActive).firstOrNull;
      if (active != null) {
        await SessionRecoveryService.persist(
          sessionId: active.id,
          taskName: active.taskName,
          sessionMode: active.sessionMode.jsonKey,
          startedAt: active.startedAt,
        );
      }

      _taskCtrl.clear();
      _taskFocus.unfocus();
      _linkedTaskId = null;
      setState(() => _immersive = true);
    } catch (e) {
      if (!mounted) return;
      _err(ErrorMessageMapper.fromError(e));
    }
  }

  Future<void> _stop(String id) async {
    HapticFeedback.mediumImpact();
    ref.read(soundServiceProvider).buttonPress();
    setState(() => _immersive = false);

    final finished =
        await ref.read(timeEntriesProvider.notifier).stopSession(sessionId: id);

    await SessionRecoveryService.clear();

    if (!mounted || finished == null) return;

    final linkedId = finished.projectTaskId;
    if (linkedId != null && finished.duration.inMinutes > 0) {
      try {
        await ref.read(projectRepositoryProvider).attributeSessionMinutes(
          projectTaskId: linkedId,
          minutes: finished.duration.inMinutes,
        );
        ref.read(projectsProvider.notifier).refresh();
        ref.read(analyticsProvider.notifier).refresh();
      } catch (_) {}
    }

    if (!mounted) return;
    await showSessionCelebration(context, justFinished: finished);
  }

  Future<void> _pause(String id) async {
    HapticFeedback.lightImpact();
    ref.read(ambientSoundServiceProvider.notifier).pauseAmbient();
    try {
      await ref.read(timeEntriesProvider.notifier).pauseSession(sessionId: id);
    } catch (e) {
      if (!mounted) return;
      _err(ErrorMessageMapper.fromError(e));
    }
  }

  Future<void> _resume(String id) async {
    HapticFeedback.lightImpact();
    ref.read(ambientSoundServiceProvider.notifier).resumeAmbient();
    try {
      await ref.read(timeEntriesProvider.notifier).resumeSession(sessionId: id);
    } catch (e) {
      if (!mounted) return;
      _err(ErrorMessageMapper.fromError(e));
    }
  }

  Future<void> _interrupt(String id) async {
    HapticFeedback.heavyImpact();
    await ref.read(timeEntriesProvider.notifier).incrementInterruption(sessionId: id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Interruption tracked'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }

  Future<String?> _showConflict(TimeEntry s) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final sc = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Session Running',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Text(
            '"${s.taskName}" is active. Stop it first?',
            style: GoogleFonts.inter(color: sc.onSurface.withOpacity(0.65)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Keep going'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'stop'),
              child: const Text('Stop & start new'),
            ),
          ],
        );
      },
    );
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = _active;

    // Ensure immersive syncs with active session
    if (session != null && !_immersive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _immersive = true);
      });
    } else if (session == null && _immersive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _immersive = false);
      });
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: session != null
            ? _ImmersiveView(
                key: const ValueKey('immersive'),
                session: session,
                breathe: _breathe,
                progress: _progress(session),
                ringColor: _ringColor(context, session),
                fmt: _fmt,
                onPause: () => _pause(session.id),
                onResume: () => _resume(session.id),
                onStop: () => _stop(session.id),
                onInterrupt: () => _interrupt(session.id),
                onExitImmersive: () => setState(() => _immersive = false),
              )
            : _SetupView(
                key: const ValueKey('setup'),
                taskCtrl: _taskCtrl,
                taskFocus: _taskFocus,
                tagCtrl: _tagCtrl,
                mode: _mode,
                cat: _cat,
                energy: _energy,
                targetMins: _targetMins,
                breakMins: _breakMins,
                pomodoroIdx: _pomodoroIdx,
                tags: _tags,
                onModeChanged: (m) => setState(() => _mode = m),
                onCatChanged: (c) => setState(() => _cat = c),
                onEnergyChanged: (e) => setState(() => _energy = e),
                onTargetChanged: (v) => setState(() => _targetMins = v),
                onBreakChanged: (v) => setState(() => _breakMins = v),
                onPomodoroChanged: (i) => setState(() => _pomodoroIdx = i),
                onTagsChanged: (t) => setState(() => _tags = t),
                onStart: _start,
              ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Immersive Active View
// ═════════════════════════════════════════════════════════════════════════════

class _ImmersiveView extends ConsumerWidget {
  const _ImmersiveView({
    super.key,
    required this.session,
    required this.breathe,
    required this.progress,
    required this.ringColor,
    required this.fmt,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onInterrupt,
    required this.onExitImmersive,
  });

  final TimeEntry session;
  final Animation<double> breathe;
  final double progress;
  final Color ringColor;
  final String Function(Duration) fmt;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onInterrupt;
  final VoidCallback onExitImmersive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isTimer = session.sessionMode != SessionMode.stopwatch;
    final elapsed = session.duration;
    final remaining = session.remainingTime;
    final displayTime = isTimer ? remaining : elapsed;
    final ambientState = ref.watch(ambientSoundServiceProvider).valueOrNull;
    final stats = ref.watch(timeTrackingStatsProvider);
    final goalProgress = ref.watch(dailyFocusProgressProvider);
    final goalAsync = ref.watch(dailyFocusGoalProvider);
    final goalMins = goalAsync.valueOrNull?.targetMinutes ?? 120;

    final screenH = MediaQuery.of(context).size.height;
    final ringSize = math.min(MediaQuery.of(context).size.width * 0.74, 320.0);

    return SafeArea(
      child: Column(
        children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                _StatusPill(session: session, ringColor: ringColor),
                const Spacer(),
                Text(
                  '${session.sessionMode.icon} ${session.sessionMode.label}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface.withOpacity(0.45),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onExitImmersive,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.expand_more_rounded,
                        size: 20,
                        color: scheme.onSurface.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),

          // ── Timer ring ────────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Center(
              child: ScaleTransition(
                scale: session.isActive ? breathe : const AlwaysStoppedAnimation(1.0),
                child: _FitnessRing(
                  size: ringSize,
                  progress: isTimer ? progress : 0,
                  ringColor: ringColor,
                  isPaused: session.isPaused,
                  displayTime: displayTime,
                  isTimer: isTimer,
                  elapsed: elapsed,
                  taskName: session.taskName,
                  category: session.category,
                  fmt: fmt,
                ),
              ),
            ),
          ),

          // ── Controls ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Interrupt button
                _CircleButton(
                  icon: Icons.phone_in_talk_rounded,
                  color: scheme.error,
                  size: 52,
                  badge: session.interruptions > 0
                      ? '${session.interruptions}'
                      : null,
                  onTap: onInterrupt,
                ),

                // Main pause/play
                _MainButton(
                  isActive: session.isActive,
                  color: ringColor,
                  onPause: onPause,
                  onResume: onResume,
                ),

                // Stop button
                _CircleButton(
                  icon: Icons.stop_rounded,
                  color: scheme.onSurface.withOpacity(0.7),
                  size: 52,
                  onTap: onStop,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Session chips ─────────────────────────────────────────────────
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _Chip('${session.category.emoji} ${session.category.label}', scheme),
                const SizedBox(width: 6),
                _Chip('${session.energyLevel.emoji} ${session.energyLevel.label}', scheme),
                if (isTimer && remaining > Duration.zero) ...[
                  const SizedBox(width: 6),
                  _Chip('⏱ ${fmt(elapsed)} elapsed', scheme),
                ],
                ...session.tags.take(3).map((t) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Chip('#$t', scheme),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Ambient strip ─────────────────────────────────────────────────
          _AmbientStrip(ambientState: ambientState),
          const SizedBox(height: 12),

          // ── Daily goal ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _DailyBar(
              progress: goalProgress,
              todayMins: stats.todayFocusMinutes,
              goalMins: goalMins,
              streak: stats.weeklyStreak,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatefulWidget {
  const _StatusPill({required this.session, required this.ringColor});
  final TimeEntry session;
  final Color ringColor;

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = widget.session.isActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.ringColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.ringColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _blink,
            builder: (ctx, _) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? widget.ringColor.withOpacity(0.5 + _blink.value * 0.5)
                    : const Color(0xFFF59E0B),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Paused',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.ringColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Apple Fitness Ring ────────────────────────────────────────────────────────

class _FitnessRing extends StatelessWidget {
  const _FitnessRing({
    required this.size,
    required this.progress,
    required this.ringColor,
    required this.isPaused,
    required this.displayTime,
    required this.isTimer,
    required this.elapsed,
    required this.taskName,
    required this.category,
    required this.fmt,
  });

  final double size;
  final double progress;
  final Color ringColor;
  final bool isPaused;
  final Duration displayTime;
  final bool isTimer;
  final Duration elapsed;
  final String taskName;
  final TaskCategory category;
  final String Function(Duration) fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring (decorative)
          CustomPaint(
            size: Size(size, size),
            painter: _GlowRingPainter(
              progress: progress,
              color: ringColor,
              isDark: isDark,
            ),
          ),
          // Inner content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                fmt(displayTime),
                style: GoogleFonts.inter(
                  fontSize: size * 0.165,
                  fontWeight: FontWeight.w200,
                  color: scheme.onSurface,
                  letterSpacing: -2,
                  height: 1.1,
                ),
              ),
              if (isTimer)
                Text(
                  isPaused ? 'paused' : 'remaining',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: scheme.onSurface.withOpacity(0.35),
                  ),
                )
              else
                Text(
                  isPaused ? 'paused' : 'elapsed',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: scheme.onSurface.withOpacity(0.35),
                  ),
                ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: size * 0.65),
                child: Text(
                  taskName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
              if (isTimer && progress > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: ringColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowRingPainter extends CustomPainter {
  const _GlowRingPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  final double progress;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeW = size.width * 0.065;
    final radius = (size.width - strokeW) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(isDark ? 0.12 : 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    if (progress <= 0) return;

    // Glow shadow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW + 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Main arc — gradient-like by drawing two arcs
    final halfProgress = progress * 0.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Main control button ───────────────────────────────────────────────────────

class _MainButton extends StatelessWidget {
  const _MainButton({
    required this.isActive,
    required this.color,
    required this.onPause,
    required this.onResume,
  });
  final bool isActive;
  final Color color;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? onPause : onResume,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color.withOpacity(0.85), color],
            radius: 0.7,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.45),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isActive),
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: size * 0.42),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.scheme);
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface.withOpacity(0.65),
        ),
      ),
    );
  }
}

// ── Ambient Sound Strip ───────────────────────────────────────────────────────

class _AmbientStrip extends ConsumerWidget {
  const _AmbientStrip({required this.ambientState});
  final AmbientState? ambientState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sounds = AmbientSound.values.where((s) => s != AmbientSound.none).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.headphones_rounded,
                  size: 14, color: scheme.onSurface.withOpacity(0.4)),
              const SizedBox(width: 6),
              Text(
                'Ambient',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (ambientState?.isPlaying == true) ...[
                Icon(Icons.volume_up_rounded,
                    size: 13, color: scheme.primary),
                const SizedBox(width: 4),
                SizedBox(
                  width: 72,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: scheme.primary,
                      inactiveTrackColor: scheme.outlineVariant,
                      thumbColor: scheme.primary,
                      overlayColor: scheme.primary.withOpacity(0.15),
                    ),
                    child: Slider(
                      value: ambientState?.volume ?? 0.5,
                      onChanged: (v) {
                        ref
                            .read(ambientSoundServiceProvider.notifier)
                            .setVolume(v);
                      },
                    ),
                  ),
                ),
              ],
              if (ambientState?.isPlaying == true)
                GestureDetector(
                  onTap: () =>
                      ref.read(ambientSoundServiceProvider.notifier).fadeOut(),
                  child: Icon(Icons.close_rounded,
                      size: 16,
                      color: scheme.onSurface.withOpacity(0.4)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sounds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final s = sounds[i];
                final active = ambientState?.activeSound == s &&
                    ambientState?.isPlaying == true;
                return GestureDetector(
                  onTap: () =>
                      ref.read(ambientSoundServiceProvider.notifier).play(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 56,
                    decoration: BoxDecoration(
                      color: active
                          ? scheme.primary.withOpacity(0.15)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? scheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.emoji,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(
                          s.label,
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active
                                ? scheme.primary
                                : scheme.onSurface.withOpacity(0.45),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily Bar ─────────────────────────────────────────────────────────────────

class _DailyBar extends StatelessWidget {
  const _DailyBar({
    required this.progress,
    required this.todayMins,
    required this.goalMins,
    required this.streak,
  });
  final double progress;
  final int todayMins;
  final int goalMins;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = progress >= 1.0;
    final color = done ? const Color(0xFF22C55E) : scheme.primary;
    final h = todayMins ~/ 60;
    final m = todayMins % 60;
    final gh = goalMins ~/ 60;
    final gm = goalMins % 60;

    return Row(
      children: [
        Text(
          done ? '🎯' : '⏳',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    done ? 'Goal reached!' : 'Daily goal',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    '${h}h ${m}m / ${gh}h ${gm}m',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 5,
                  backgroundColor: scheme.outlineVariant.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
        if (streak > 0) ...[
          const SizedBox(width: 10),
          Text(
            '🔥 $streak',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Setup View (no active session)
// ═════════════════════════════════════════════════════════════════════════════

class _SetupView extends ConsumerWidget {
  const _SetupView({
    super.key,
    required this.taskCtrl,
    required this.taskFocus,
    required this.tagCtrl,
    required this.mode,
    required this.cat,
    required this.energy,
    required this.targetMins,
    required this.breakMins,
    required this.pomodoroIdx,
    required this.tags,
    required this.onModeChanged,
    required this.onCatChanged,
    required this.onEnergyChanged,
    required this.onTargetChanged,
    required this.onBreakChanged,
    required this.onPomodoroChanged,
    required this.onTagsChanged,
    required this.onStart,
  });

  final TextEditingController taskCtrl;
  final FocusNode taskFocus;
  final TextEditingController tagCtrl;
  final SessionMode mode;
  final TaskCategory cat;
  final EnergyLevel energy;
  final int? targetMins;
  final int? breakMins;
  final int pomodoroIdx;
  final List<String> tags;
  final ValueChanged<SessionMode> onModeChanged;
  final ValueChanged<TaskCategory> onCatChanged;
  final ValueChanged<EnergyLevel> onEnergyChanged;
  final ValueChanged<int?> onTargetChanged;
  final ValueChanged<int?> onBreakChanged;
  final ValueChanged<int> onPomodoroChanged;
  final ValueChanged<List<String>> onTagsChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(timeTrackingStatsProvider);
    final goalProgress = ref.watch(dailyFocusProgressProvider);
    final goalAsync = ref.watch(dailyFocusGoalProvider);
    final goalMins = goalAsync.valueOrNull?.targetMinutes ?? 120;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              // ── Header ───────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus',
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'Deep work starts here',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: scheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ScoreBadge(score: stats.focusScore),
                ],
              ),
              const SizedBox(height: 20),

              // ── Daily goal card ──────────────────────────────────────────
              _GoalCard(
                progress: goalProgress,
                todayMins: stats.todayFocusMinutes,
                goalMins: goalMins,
                streak: stats.weeklyStreak,
                onChangeGoal: (mins) =>
                    ref.read(dailyFocusGoalProvider.notifier).setGoal(mins),
              ),
              const SizedBox(height: 16),

              // ── Task input ───────────────────────────────────────────────
              _TaskInput(
                controller: taskCtrl,
                focusNode: taskFocus,
                onSubmit: onStart,
              ),
              const SizedBox(height: 14),

              // ── Mode selector ────────────────────────────────────────────
              _ModeRow(selected: mode, onChanged: onModeChanged),
              const SizedBox(height: 14),

              // ── Conditional options ──────────────────────────────────────
              if (mode == SessionMode.pomodoro) ...[
                _PomodoroRow(selected: pomodoroIdx, onChanged: onPomodoroChanged),
                const SizedBox(height: 14),
              ],
              if (mode == SessionMode.timer || mode == SessionMode.custom) ...[
                _DurationRow(
                  label: 'Work duration',
                  value: targetMins,
                  options: const [15, 25, 30, 45, 60, 90, 120],
                  onChanged: onTargetChanged,
                ),
                const SizedBox(height: 10),
                if (mode == SessionMode.custom) ...[
                  _DurationRow(
                    label: 'Break duration',
                    value: breakMins,
                    options: const [5, 10, 15, 20],
                    onChanged: onBreakChanged,
                  ),
                  const SizedBox(height: 14),
                ],
              ],

              // ── Category ─────────────────────────────────────────────────
              _CategoryGrid(selected: cat, onChanged: onCatChanged),
              const SizedBox(height: 14),

              // ── Energy ───────────────────────────────────────────────────
              _EnergyRow(selected: energy, onChanged: onEnergyChanged),
              const SizedBox(height: 14),

              // ── Tags ─────────────────────────────────────────────────────
              _TagsSection(
                tags: tags,
                controller: tagCtrl,
                onChanged: onTagsChanged,
              ),
              const SizedBox(height: 24),

              // ── Start button ─────────────────────────────────────────────
              _StartButton(onStart: onStart, mode: mode),
              const SizedBox(height: 24),

              // ── Quick stats ──────────────────────────────────────────────
              _QuickStats(stats: stats),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Score Badge ───────────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? const Color(0xFF22C55E)
        : score >= 50
            ? const Color(0xFF6366F1)
            : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          Text(
            'Focus\nScore',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: color.withOpacity(0.75),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Goal Card ─────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.progress,
    required this.todayMins,
    required this.goalMins,
    required this.streak,
    required this.onChangeGoal,
  });
  final double progress;
  final int todayMins;
  final int goalMins;
  final int streak;
  final ValueChanged<int> onChangeGoal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = progress >= 1.0;
    final color = done ? const Color(0xFF22C55E) : scheme.primary;
    final h = todayMins ~/ 60;
    final m = todayMins % 60;
    final gh = goalMins ~/ 60;
    final gm = goalMins % 60;

    return GestureDetector(
      onLongPress: () => _pickGoal(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  done ? '🎯 Goal reached!' : '🎯 Daily goal',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (streak > 0)
                  Text(
                    '🔥 $streak day streak',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 7,
                      backgroundColor: scheme.outlineVariant.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${h}h ${m}m / ${gh}h ${gm}m',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: scheme.onSurface.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Hold to change goal',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: scheme.onSurface.withOpacity(0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickGoal(BuildContext ctx) {
    final options = [60, 90, 120, 180, 240, 300, 360, 480];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bctx) {
        final sc = Theme.of(bctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: sc.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text('Daily Focus Goal',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...options.map((mins) {
                final h = mins ~/ 60;
                final m = mins % 60;
                final lbl = h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';
                return ListTile(
                  title:
                      Text(lbl, style: GoogleFonts.inter(fontSize: 15)),
                  trailing: mins == goalMins
                      ? Icon(Icons.check_rounded, color: sc.primary)
                      : null,
                  onTap: () {
                    onChangeGoal(mins);
                    Navigator.pop(bctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ── Task Input ────────────────────────────────────────────────────────────────

class _TaskInput extends StatelessWidget {
  const _TaskInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'What are you working on?',
          hintStyle: GoogleFonts.inter(
            color: scheme.onSurface.withOpacity(0.28),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.edit_note_rounded,
            color: scheme.onSurface.withOpacity(0.28),
          ),
        ),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => onSubmit(),
      ),
    );
  }
}

// ── Mode Row ──────────────────────────────────────────────────────────────────

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.selected, required this.onChanged});
  final SessionMode selected;
  final ValueChanged<SessionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      label: 'Mode',
      child: Row(
        children: SessionMode.values.map((m) {
          final active = m == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active ? scheme.primary : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(m.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      m.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : scheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Pomodoro presets ──────────────────────────────────────────────────────────

class _PomodoroRow extends StatelessWidget {
  const _PomodoroRow({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      label: 'Pomodoro Preset',
      child: Row(
        children: _pomodoroPresets.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFEF4444).withOpacity(0.12)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? const Color(0xFFEF4444)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Text('🍅', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      p.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? const Color(0xFFEF4444)
                            : scheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                    Text(
                      '${p.breakMinutes}m break',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: scheme.onSurface.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Duration picker ───────────────────────────────────────────────────────────

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final int? value;
  final List<int> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      label: label,
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (ctx, i) {
            final mins = options[i];
            final active = value == mins;
            final lbl = mins >= 60 ? '${mins ~/ 60}h' : '${mins}m';
            return GestureDetector(
              onTap: () => onChanged(active ? null : mins),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? scheme.primary : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  lbl,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.white
                        : scheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Category Grid ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onChanged});
  final TaskCategory selected;
  final ValueChanged<TaskCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      label: 'Category',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: TaskCategory.selectable.map((c) {
          final active = c == selected;
          return GestureDetector(
            onTap: () => onChanged(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? scheme.primary.withOpacity(0.12)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? scheme.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                '${c.emoji} ${c.label}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? scheme.primary
                      : scheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Energy Row ────────────────────────────────────────────────────────────────

class _EnergyRow extends StatelessWidget {
  const _EnergyRow({required this.selected, required this.onChanged});
  final EnergyLevel selected;
  final ValueChanged<EnergyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      label: 'Energy Level',
      child: Row(
        children: EnergyLevel.values.map((e) {
          final active = e == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? scheme.secondary.withOpacity(0.12)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? scheme.secondary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(e.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      e.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? scheme.secondary
                            : scheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tags Section ──────────────────────────────────────────────────────────────

class _TagsSection extends StatelessWidget {
  const _TagsSection({
    required this.tags,
    required this.controller,
    required this.onChanged,
  });
  final List<String> tags;
  final TextEditingController controller;
  final ValueChanged<List<String>> onChanged;

  void _add(String raw) {
    final t = raw.trim().replaceAll('#', '').toLowerCase();
    if (t.isNotEmpty && !tags.contains(t) && tags.length < 8) {
      onChanged([...tags, t]);
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      label: 'Tags',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '#deepwork  #flutter  #study',
                hintStyle: GoogleFonts.inter(
                  color: scheme.onSurface.withOpacity(0.28),
                  fontSize: 13,
                ),
                suffixIcon: GestureDetector(
                  onTap: () => _add(controller.text),
                  child:
                      Icon(Icons.add_rounded, color: scheme.primary, size: 20),
                ),
                isDense: true,
              ),
              onSubmitted: _add,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map((t) => Chip(
                        label: Text('#$t',
                            style: GoogleFonts.inter(fontSize: 11)),
                        deleteIcon: const Icon(Icons.close, size: 13),
                        onDeleted: () =>
                            onChanged(tags.where((x) => x != t).toList()),
                        backgroundColor:
                            scheme.primaryContainer.withOpacity(0.5),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Start Button ──────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onStart, required this.mode});
  final VoidCallback onStart;
  final SessionMode mode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _modeColor(mode, scheme);

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withBlue((color.blue + 30).clamp(0, 255))],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.38),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: MaterialButton(
          onPressed: onStart,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(mode.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                'Start ${mode.label}',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _modeColor(SessionMode m, ColorScheme sc) => switch (m) {
    SessionMode.stopwatch => const Color(0xFF22D3A6),
    SessionMode.timer => const Color(0xFF6366F1),
    SessionMode.pomodoro => const Color(0xFFEF4444),
    SessionMode.custom => const Color(0xFF8B5CF6),
  };
}

// ── Quick Stats ───────────────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.stats});
  final DerivedStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _StatCard('✅', '${stats.sessionsCompleted}', 'Sessions', scheme),
        const SizedBox(width: 10),
        _StatCard('🧠',
            '${stats.deepWorkHours.toStringAsFixed(1)}h', 'Deep Work', scheme),
        const SizedBox(width: 10),
        _StatCard('⚡', '${stats.averageSessionLengthMinutes.round()}m',
            'Avg', scheme),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.icon, this.value, this.label, this.scheme);
  final String icon, value, label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: scheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Section wrapper ────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withOpacity(0.4),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
