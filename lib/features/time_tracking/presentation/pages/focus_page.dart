import 'dart:async';
import 'dart:math' as math;
import 'package:chronyx/core/services/ambient_sound_service.dart';
import 'package:chronyx/core/services/sound_service.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/session_prefill_provider.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/life_insights/presentation/pages/session_celebration_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pomodoro presets
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Premium Focus Page
// ─────────────────────────────────────────────────────────────────────────────

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with TickerProviderStateMixin {
  // ── Form state ────────────────────────────────────────────────────────────
  final _taskController = TextEditingController();
  final _taskFocus = FocusNode();
  final _tagController = TextEditingController();
  TaskCategory _selectedCategory = TaskCategory.productive;
  SessionMode _selectedMode = SessionMode.stopwatch;
  EnergyLevel _energyLevel = EnergyLevel.medium;
  int? _targetDurationMinutes;
  int? _breakDurationMinutes;
  String? _pendingProjectTaskId;
  List<String> _tags = [];
  int _pomodoroPresetIndex = 0;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefill = ref.read(sessionPrefillProvider);
      if (prefill != null) {
        _taskController.text = prefill.taskName;
        _pendingProjectTaskId = prefill.projectTaskId;
        setState(() {
          _selectedCategory = prefill.category;
        });
        ref.read(sessionPrefillProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _taskController.dispose();
    _taskFocus.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  TimeEntry? get _activeSession {
    final entries = ref.watch(timeEntriesProvider).value ?? [];
    return entries.where((e) => e.isOngoing).firstOrNull;
  }

  double _sessionProgress(TimeEntry entry) {
    if (entry.targetDurationMinutes == null ||
        entry.targetDurationMinutes! <= 0) {
      return 0.0;
    }
    final target = entry.targetDurationMinutes! * 60;
    return (entry.elapsedSeconds / target).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    HapticFeedback.mediumImpact();
    ref.read(soundServiceProvider).buttonPress();

    final notifier = ref.read(timeEntriesProvider.notifier);
    final taskName = _taskController.text.trim();
    final entries = ref.read(timeEntriesProvider).value ?? [];
    final activeSession = entries.where((e) => e.isActive || e.isPaused).firstOrNull;

    if (activeSession != null) {
      final choice = await _showActiveSessionDialog(activeSession);
      if (choice == null || choice == 'resume') return;
      if (choice == 'stop') {
        await _stopSession(activeSession.id);
      } else if (choice == 'delete') {
        await notifier.deleteSession(sessionId: activeSession.id);
      }
    }

    int? targetMins;
    int? breakMins;

    if (_selectedMode == SessionMode.pomodoro) {
      final preset = _pomodoroPresets[_pomodoroPresetIndex];
      targetMins = preset.workMinutes;
      breakMins = preset.breakMinutes;
    } else if (_selectedMode == SessionMode.timer ||
        _selectedMode == SessionMode.custom) {
      targetMins = _targetDurationMinutes;
      breakMins = _breakDurationMinutes;
    }

    try {
      await notifier.startSession(
        taskName: taskName.isEmpty ? 'Focus Session' : taskName,
        category: _selectedCategory,
        projectTaskId: _pendingProjectTaskId,
        sessionMode: _selectedMode,
        targetDurationMinutes: targetMins,
        tags: _tags.isEmpty ? null : _tags,
        energyLevel: _energyLevel,
        breakDurationMinutes: breakMins,
        ignoreActiveCheck: true,
      );
      _taskController.clear();
      _taskFocus.unfocus();
      _pendingProjectTaskId = null;
    } catch (error) {
      if (!mounted) return;
      _showError(ErrorMessageMapper.fromError(error));
    }
  }

  Future<void> _stopSession(String id) async {
    HapticFeedback.mediumImpact();
    ref.read(soundServiceProvider).buttonPress();
    final finished =
        await ref.read(timeEntriesProvider.notifier).stopSession(sessionId: id);
    if (!mounted || finished == null) return;

    final linkedTaskId = finished.projectTaskId;
    if (linkedTaskId != null) {
      final minutes = finished.duration.inMinutes;
      if (minutes > 0) {
        try {
          await ref
              .read(projectRepositoryProvider)
              .attributeSessionMinutes(
                projectTaskId: linkedTaskId,
                minutes: minutes,
              );
          ref.read(projectsProvider.notifier).refresh();
          ref.read(analyticsProvider.notifier).refresh();
        } catch (_) {}
      }
    }

    if (!mounted) return;
    await showSessionCelebration(context, justFinished: finished);
  }

  Future<void> _pauseSession(String id) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(timeEntriesProvider.notifier).pauseSession(sessionId: id);
    } catch (error) {
      if (!mounted) return;
      _showError(ErrorMessageMapper.fromError(error));
    }
  }

  Future<void> _resumeSession(String id) async {
    HapticFeedback.lightImpact();
    try {
      await ref
          .read(timeEntriesProvider.notifier)
          .resumeSession(sessionId: id);
    } catch (error) {
      if (!mounted) return;
      _showError(ErrorMessageMapper.fromError(error));
    }
  }

  Future<void> _trackInterruption(String sessionId) async {
    HapticFeedback.heavyImpact();
    await ref
        .read(timeEntriesProvider.notifier)
        .incrementInterruption(sessionId: sessionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Interruption tracked'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<String?> _showActiveSessionDialog(TimeEntry session) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Session Active',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text(
            '"${session.taskName}" is still running. What would you like to do?',
            style: GoogleFonts.inter(color: scheme.onSurface.withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'resume'),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'stop'),
              child:
                  Text('Stop it', style: TextStyle(color: scheme.error)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, 'startAnyway'),
              child: const Text('Start new'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = _activeSession;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: session != null
            ? _ActiveFocusView(
                session: session,
                formatDuration: _formatDuration,
                sessionProgress: _sessionProgress(session),
                pulseAnim: _pulseAnim,
                onPause: () => _pauseSession(session.id),
                onResume: () => _resumeSession(session.id),
                onStop: () => _stopSession(session.id),
                onInterrupt: () => _trackInterruption(session.id),
              )
            : _SetupFocusView(
                taskController: _taskController,
                taskFocus: _taskFocus,
                tagController: _tagController,
                selectedMode: _selectedMode,
                selectedCategory: _selectedCategory,
                energyLevel: _energyLevel,
                targetDurationMinutes: _targetDurationMinutes,
                breakDurationMinutes: _breakDurationMinutes,
                pomodoroPresetIndex: _pomodoroPresetIndex,
                tags: _tags,
                onModeChanged: (m) => setState(() => _selectedMode = m),
                onCategoryChanged: (c) =>
                    setState(() => _selectedCategory = c),
                onEnergyChanged: (e) => setState(() => _energyLevel = e),
                onTargetDurationChanged: (v) =>
                    setState(() => _targetDurationMinutes = v),
                onBreakDurationChanged: (v) =>
                    setState(() => _breakDurationMinutes = v),
                onPomodoroPresetChanged: (i) =>
                    setState(() => _pomodoroPresetIndex = i),
                onTagsChanged: (t) => setState(() => _tags = t),
                onStart: _startSession,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Focus View
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveFocusView extends ConsumerWidget {
  const _ActiveFocusView({
    required this.session,
    required this.formatDuration,
    required this.sessionProgress,
    required this.pulseAnim,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onInterrupt,
  });

  final TimeEntry session;
  final String Function(Duration) formatDuration;
  final double sessionProgress;
  final Animation<double> pulseAnim;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onInterrupt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isTimer = session.sessionMode == SessionMode.timer ||
        session.sessionMode == SessionMode.pomodoro ||
        session.sessionMode == SessionMode.custom;
    final elapsed = session.duration;
    final remaining = session.remainingTime;
    final displayDuration = isTimer ? remaining : elapsed;
    final ambientState = ref.watch(ambientSoundServiceProvider).valueOrNull;

    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle,
                        size: 8,
                        color: session.isActive
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF9800)),
                    const SizedBox(width: 6),
                    Text(
                      session.isActive ? 'Active' : 'Paused',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${session.sessionMode.icon} ${session.sessionMode.label}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),

        // ── Timer Ring ────────────────────────────────────────────────────
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: session.isActive ? pulseAnim : const AlwaysStoppedAnimation(1.0),
                  child: _TimerRing(
                    progress: isTimer ? sessionProgress : 0.0,
                    isTimer: isTimer,
                    isPaused: session.isPaused,
                    displayDuration: displayDuration,
                    formatDuration: formatDuration,
                    taskName: session.taskName,
                    category: session.category,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Controls ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Interrupt
                    _IconControl(
                      icon: Icons.phone_in_talk_rounded,
                      label: '${session.interruptions}',
                      tooltip: 'Track interruption',
                      onTap: onInterrupt,
                      color: scheme.error.withOpacity(0.8),
                      size: 48,
                    ),
                    const SizedBox(width: 16),

                    // Pause / Resume
                    _BigControl(
                      icon: session.isActive
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onTap: session.isActive ? onPause : onResume,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 16),

                    // Stop
                    _IconControl(
                      icon: Icons.stop_rounded,
                      label: 'Stop',
                      tooltip: 'End session',
                      onTap: onStop,
                      color: scheme.error,
                      size: 48,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Session meta ─────────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _MetaChip(
                      icon: session.category.emoji,
                      label: session.category.label,
                      scheme: scheme,
                    ),
                    _MetaChip(
                      icon: session.energyLevel.emoji,
                      label: session.energyLevel.label,
                      scheme: scheme,
                    ),
                    if (isTimer)
                      _MetaChip(
                        icon: '⏱️',
                        label: formatDuration(elapsed) + ' elapsed',
                        scheme: scheme,
                      ),
                    ...session.tags.take(3).map((t) => _MetaChip(
                          icon: '#',
                          label: t,
                          scheme: scheme,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Ambient Sound Strip ───────────────────────────────────────────
        _AmbientSoundStrip(ambientState: ambientState),

        // ── Daily progress ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: _DailyGoalBar(),
        ),
      ],
    );
  }
}

// ── Timer Ring ────────────────────────────────────────────────────────────────

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.progress,
    required this.isTimer,
    required this.isPaused,
    required this.displayDuration,
    required this.formatDuration,
    required this.taskName,
    required this.category,
  });

  final double progress;
  final bool isTimer;
  final bool isPaused;
  final Duration displayDuration;
  final String Function(Duration) formatDuration;
  final String taskName;
  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size.width * 0.72;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: isTimer ? progress : 0.0,
              trackColor: scheme.outlineVariant.withOpacity(0.3),
              progressColor: isPaused
                  ? scheme.tertiary
                  : scheme.primary,
              strokeWidth: 10,
            ),
          ),
          // Content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                formatDuration(displayDuration),
                style: GoogleFonts.inter(
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.w300,
                  color: scheme.onSurface,
                  letterSpacing: -2,
                ),
              ),
              if (isTimer)
                Text(
                  'remaining',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.4),
                    letterSpacing: 1.2,
                  ),
                ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: size * 0.7),
                child: Text(
                  taskName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
}

// ── Controls ──────────────────────────────────────────────────────────────────

class _BigControl extends StatelessWidget {
  const _BigControl({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color.withOpacity(0.9), color],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2)
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }
}

class _IconControl extends StatelessWidget {
  const _IconControl({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: size * 0.45),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: scheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(
      {required this.icon, required this.label, required this.scheme});
  final String icon;
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
        '$icon $label',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: scheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }
}

// ── Ambient Sound Strip ───────────────────────────────────────────────────────

class _AmbientSoundStrip extends ConsumerWidget {
  const _AmbientSoundStrip({required this.ambientState});
  final AmbientState? ambientState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sounds = AmbientSound.values;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
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
                  size: 16, color: scheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                'Ambient Sound',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              if (ambientState?.isPlaying == true) ...[
                Icon(Icons.volume_up_rounded,
                    size: 14, color: scheme.primary),
                const SizedBox(width: 4),
                SizedBox(
                  width: 80,
                  child: SliderTheme(
                    data: SliderThemeData(
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 10),
                      trackHeight: 2,
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
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sounds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final sound = sounds[i];
                final isActive = ambientState?.activeSound == sound &&
                    ambientState?.isPlaying == true;
                return GestureDetector(
                  onTap: () {
                    ref
                        .read(ambientSoundServiceProvider.notifier)
                        .play(sound);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? scheme.primary.withOpacity(0.15)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? scheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(sound.emoji,
                            style: const TextStyle(fontSize: 16)),
                        Text(
                          sound.label,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: isActive
                                ? scheme.primary
                                : scheme.onSurface.withOpacity(0.5),
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
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

// ── Daily Goal Bar ────────────────────────────────────────────────────────────

class _DailyGoalBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(dailyFocusProgressProvider);
    final stats = ref.watch(timeTrackingStatsProvider);
    final goalAsync = ref.watch(dailyFocusGoalProvider);
    final goalMins = goalAsync.valueOrNull?.targetMinutes ?? 120;
    final todayH = stats.todayFocusMinutes ~/ 60;
    final todayM = stats.todayFocusMinutes % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Daily Goal',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withOpacity(0.5),
              ),
            ),
            const Spacer(),
            Text(
              '${todayH}h ${todayM}m / ${goalMins ~/ 60}h ${goalMins % 60}m',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: scheme.outlineVariant.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? const Color(0xFF4CAF50) : scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup Focus View (when no active session)
// ─────────────────────────────────────────────────────────────────────────────

class _SetupFocusView extends ConsumerWidget {
  const _SetupFocusView({
    required this.taskController,
    required this.taskFocus,
    required this.tagController,
    required this.selectedMode,
    required this.selectedCategory,
    required this.energyLevel,
    required this.targetDurationMinutes,
    required this.breakDurationMinutes,
    required this.pomodoroPresetIndex,
    required this.tags,
    required this.onModeChanged,
    required this.onCategoryChanged,
    required this.onEnergyChanged,
    required this.onTargetDurationChanged,
    required this.onBreakDurationChanged,
    required this.onPomodoroPresetChanged,
    required this.onTagsChanged,
    required this.onStart,
  });

  final TextEditingController taskController;
  final FocusNode taskFocus;
  final TextEditingController tagController;
  final SessionMode selectedMode;
  final TaskCategory selectedCategory;
  final EnergyLevel energyLevel;
  final int? targetDurationMinutes;
  final int? breakDurationMinutes;
  final int pomodoroPresetIndex;
  final List<String> tags;
  final ValueChanged<SessionMode> onModeChanged;
  final ValueChanged<TaskCategory> onCategoryChanged;
  final ValueChanged<EnergyLevel> onEnergyChanged;
  final ValueChanged<int?> onTargetDurationChanged;
  final ValueChanged<int?> onBreakDurationChanged;
  final ValueChanged<int> onPomodoroPresetChanged;
  final ValueChanged<List<String>> onTagsChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(timeTrackingStatsProvider);
    final progress = ref.watch(dailyFocusProgressProvider);
    final goalAsync = ref.watch(dailyFocusGoalProvider);
    final goalMins = goalAsync.valueOrNull?.targetMinutes ?? 120;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'Enter deep work',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: scheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Focus score badge
                    _FocusScoreBadge(score: stats.focusScore),
                  ],
                ),
                const SizedBox(height: 20),

                // Daily goal progress
                _DailyGoalCard(
                  progress: progress,
                  todayMinutes: stats.todayFocusMinutes,
                  goalMinutes: goalMins,
                  streak: stats.weeklyStreak,
                  scheme: scheme,
                  onSetGoal: (mins) {
                    ref
                        .read(dailyFocusGoalProvider.notifier)
                        .setGoal(mins);
                  },
                ),
                const SizedBox(height: 20),

                // Task name input
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: scheme.outline.withOpacity(0.2)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 4),
                  child: TextField(
                    controller: taskController,
                    focusNode: taskFocus,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'What are you working on?',
                      hintStyle: GoogleFonts.inter(
                        color: scheme.onSurface.withOpacity(0.3),
                      ),
                      prefixIcon: Icon(
                        Icons.edit_note_rounded,
                        color: scheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => onStart(),
                  ),
                ),
                const SizedBox(height: 16),

                // Mode selector
                _ModeSelector(
                    selectedMode: selectedMode, onChanged: onModeChanged),
                const SizedBox(height: 16),

                // Pomodoro presets
                if (selectedMode == SessionMode.pomodoro) ...[
                  _PomodoroPresetSelector(
                    selectedIndex: pomodoroPresetIndex,
                    onChanged: onPomodoroPresetChanged,
                  ),
                  const SizedBox(height: 16),
                ],

                // Timer / Custom duration
                if (selectedMode == SessionMode.timer ||
                    selectedMode == SessionMode.custom) ...[
                  _DurationPicker(
                    label: 'Work Duration',
                    value: targetDurationMinutes,
                    onChanged: onTargetDurationChanged,
                    options: const [15, 25, 30, 45, 60, 90, 120],
                  ),
                  const SizedBox(height: 12),
                  if (selectedMode == SessionMode.custom) ...[
                    _DurationPicker(
                      label: 'Break Duration',
                      value: breakDurationMinutes,
                      onChanged: onBreakDurationChanged,
                      options: const [5, 10, 15, 20],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                // Category chips
                _CategoryChips(
                    selected: selectedCategory,
                    onChanged: onCategoryChanged),
                const SizedBox(height: 16),

                // Energy level
                _EnergySelector(
                    selected: energyLevel, onChanged: onEnergyChanged),
                const SizedBox(height: 16),

                // Tags
                _TagInput(
                  tags: tags,
                  controller: tagController,
                  onTagsChanged: onTagsChanged,
                ),
                const SizedBox(height: 24),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary,
                          scheme.primary.withBlue(
                              (scheme.primary.blue + 40).clamp(0, 255)),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: MaterialButton(
                      onPressed: onStart,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'Start Focus',
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
                ),
                const SizedBox(height: 24),

                // Quick stats
                _QuickStatsRow(stats: stats),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Focus Score Badge ─────────────────────────────────────────────────────────

class _FocusScoreBadge extends StatelessWidget {
  const _FocusScoreBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = score >= 80
        ? const Color(0xFF4CAF50)
        : score >= 50
            ? scheme.primary
            : scheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: GoogleFonts.inter(
              fontSize: 22,
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
              color: color.withOpacity(0.8),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily Goal Card ───────────────────────────────────────────────────────────

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({
    required this.progress,
    required this.todayMinutes,
    required this.goalMinutes,
    required this.streak,
    required this.scheme,
    required this.onSetGoal,
  });

  final double progress;
  final int todayMinutes;
  final int goalMinutes;
  final int streak;
  final ColorScheme scheme;
  final ValueChanged<int> onSetGoal;

  @override
  Widget build(BuildContext context) {
    final completed = progress >= 1.0;
    final color = completed ? const Color(0xFF4CAF50) : scheme.primary;
    final h = todayMinutes ~/ 60;
    final m = todayMinutes % 60;
    final goalH = goalMinutes ~/ 60;
    final goalM = goalMinutes % 60;

    return GestureDetector(
      onLongPress: () => _showGoalPicker(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.08),
              color.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  completed ? '🎯 Goal Achieved!' : '🎯 Daily Goal',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (streak > 0) ...[
                  Text('🔥 $streak day streak',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(0.5))),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor:
                          scheme.outlineVariant.withOpacity(0.2),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${h}h ${m}m / ${goalH}h ${goalM}m',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Long-press to change goal',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: scheme.onSurface.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalPicker(BuildContext context) {
    final options = [60, 90, 120, 180, 240, 300, 360];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Set Daily Focus Goal',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...options.map((mins) {
              final h = mins ~/ 60;
              final m = mins % 60;
              final label = h > 0
                  ? (m > 0 ? '${h}h ${m}m' : '${h}h')
                  : '${m}m';
              return ListTile(
                title: Text(label, style: GoogleFonts.inter()),
                trailing: mins == goalMinutes
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () {
                  onSetGoal(mins);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// ── Mode Selector ─────────────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selectedMode, required this.onChanged});
  final SessionMode selectedMode;
  final ValueChanged<SessionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mode',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: SessionMode.values.map((mode) {
            final isSelected = mode == selectedMode;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(mode.icon,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 3),
                      Text(
                        mode.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : scheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Pomodoro Preset Selector ──────────────────────────────────────────────────

class _PomodoroPresetSelector extends StatelessWidget {
  const _PomodoroPresetSelector(
      {required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pomodoro Preset',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _pomodoroPresets.asMap().entries.map((e) {
            final i = e.key;
            final preset = e.value;
            final isSelected = i == selectedIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.tertiary.withOpacity(0.15)
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? scheme.tertiary
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('🍅', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        preset.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? scheme.tertiary
                              : scheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        '${preset.breakMinutes}m break',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: scheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Duration Picker ───────────────────────────────────────────────────────────

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final List<int> options;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final mins = options[i];
              final isSelected = value == mins;
              final label =
                  mins >= 60 ? '${mins ~/ 60}h' : '${mins}m';
              return GestureDetector(
                onTap: () => onChanged(isSelected ? null : mins),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Category Chips ────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips(
      {required this.selected, required this.onChanged});
  final TaskCategory selected;
  final ValueChanged<TaskCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TaskCategory.selectable.map((cat) {
            final isSelected = cat == selected;
            return GestureDetector(
              onTap: () => onChanged(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withOpacity(0.15)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${cat.emoji} ${cat.label}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? scheme.primary
                        : scheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Energy Selector ───────────────────────────────────────────────────────────

class _EnergySelector extends StatelessWidget {
  const _EnergySelector({required this.selected, required this.onChanged});
  final EnergyLevel selected;
  final ValueChanged<EnergyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Energy Level',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: EnergyLevel.values.map((level) {
            final isSelected = level == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.secondary.withOpacity(0.15)
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? scheme.secondary
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(level.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 3),
                      Text(
                        level.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
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
      ],
    );
  }
}

// ── Tag Input ─────────────────────────────────────────────────────────────────

class _TagInput extends StatelessWidget {
  const _TagInput({
    required this.tags,
    required this.controller,
    required this.onTagsChanged,
  });

  final List<String> tags;
  final TextEditingController controller;
  final ValueChanged<List<String>> onTagsChanged;

  void _addTag(String raw) {
    final tag = raw.trim().replaceAll('#', '').toLowerCase();
    if (tag.isNotEmpty && !tags.contains(tag) && tags.length < 8) {
      onTagsChanged([...tags, tag]);
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: controller,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '#deepwork   #flutter   #revision',
              hintStyle: GoogleFonts.inter(
                color: scheme.onSurface.withOpacity(0.3),
                fontSize: 13,
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.add_circle_outline,
                    color: scheme.primary),
                onPressed: () => _addTag(controller.text),
              ),
            ),
            onSubmitted: _addTag,
          ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((tag) {
              return Chip(
                label: Text('#$tag',
                    style: GoogleFonts.inter(fontSize: 12)),
                backgroundColor:
                    scheme.primaryContainer.withOpacity(0.5),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  onTagsChanged(
                      tags.where((t) => t != tag).toList());
                },
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Quick Stats Row ───────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.stats});
  final DerivedStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _StatTile(
          label: 'Sessions',
          value: '${stats.sessionsCompleted}',
          icon: '✅',
          scheme: scheme,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Deep Work',
          value:
              '${stats.deepWorkHours.toStringAsFixed(1)}h',
          icon: '🧠',
          scheme: scheme,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Avg Session',
          value:
              '${stats.averageSessionLengthMinutes.toStringAsFixed(0)}m',
          icon: '⏱️',
          scheme: scheme,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.scheme,
  });

  final String label;
  final String value;
  final String icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                color: scheme.onSurface,
                height: 1.0,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: scheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
