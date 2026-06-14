import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter/material.dart';

class TimeEntryCard extends StatefulWidget {
  const TimeEntryCard({
    required this.entry,
    required this.onStopSession,
    this.onPauseSession,
    this.onResumeSession,
    this.onEditSession,
    this.onDeleteSession,
    this.onMergeWithPrevious,
    super.key,
  });

  final TimeEntry entry;
  final VoidCallback? onStopSession;
  final VoidCallback? onPauseSession;
  final VoidCallback? onResumeSession;
  final VoidCallback? onEditSession;
  final VoidCallback? onDeleteSession;
  final VoidCallback? onMergeWithPrevious;

  @override
  State<TimeEntryCard> createState() => _TimeEntryCardState();
}

class _TimeEntryCardState extends State<TimeEntryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;
  late Animation<double> _fadeAnim;

  static Color _colorForCategory(TaskCategory cat) => switch (cat) {
    TaskCategory.productive => const Color(0xFF22D3A6),
    TaskCategory.learning => const Color(0xFF818CF8),
    TaskCategory.break_ => const Color(0xFFFBBC05),
    TaskCategory.meeting => const Color(0xFFFB923C),
    TaskCategory.exercise => const Color(0xFF4ADE80),
    TaskCategory.entertainment => const Color(0xFFF472B6),
    TaskCategory.distraction => const Color(0xFFEA4335),
    TaskCategory.other => const Color(0xFF94A3B8),
  };

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: const Interval(0.4, 1.0),
    );
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = scheme.primary;

    // Status styling
    final Color statusColor;
    final String statusText;
    if (widget.entry.isActive) {
      statusColor = const Color(0xFF22D3A6); // active neon green
      statusText = 'ACTIVE';
    } else if (widget.entry.isPaused) {
      statusColor = const Color(0xFFFBBC05); // gold/amber
      statusText = 'PAUSED';
    } else if (widget.entry.status == SessionStatus.cancelled) {
      statusColor = scheme.error;
      statusText = 'CANCELLED';
    } else {
      statusColor = _colorForCategory(widget.entry.category);
      statusText = 'COMPLETED';
    }

    final durationToShow = (widget.entry.sessionMode == SessionMode.timer || widget.entry.sessionMode == SessionMode.pomodoro) && widget.entry.isOngoing
        ? widget.entry.remainingTime
        : widget.entry.duration;

    final hasNotes = widget.entry.notes != null && widget.entry.notes!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: widget.entry.isOngoing
            ? Border.all(
                color: _expanded
                    ? accent.withValues(alpha: 0.6)
                    : accent.withValues(alpha: 0.3),
                width: _expanded ? 1.5 : 1.0,
              )
            : Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
                width: 1.0,
              ),
        boxShadow: _expanded && widget.entry.isOngoing
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row: Core Session Details ─────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Accent category emoji
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _colorForCategory(widget.entry.category).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.entry.category.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Task + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.entry.taskName.isEmpty
                                  ? AppStrings.unknownTask
                                  : widget.entry.taskName,
                              style: textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  widget.entry.category.label,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Clock / Duration text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _clock(durationToShow),
                            style: textTheme.titleLarge?.copyWith(
                              color: widget.entry.isOngoing ? accent : scheme.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (widget.entry.isActive) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PulsingDot(color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (value) {
                          switch (value) {
                            case 'resume':
                              widget.onResumeSession?.call();
                              break;
                            case 'pause':
                              widget.onPauseSession?.call();
                              break;
                            case 'stop':
                              widget.onStopSession?.call();
                              break;
                            case 'edit':
                              widget.onEditSession?.call();
                              break;
                            case 'delete':
                              widget.onDeleteSession?.call();
                              break;
                            case 'merge':
                              widget.onMergeWithPrevious?.call();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'resume',
                            enabled: widget.entry.isPaused || !widget.entry.isOngoing,
                            child: Row(
                              children: [
                                Icon(Icons.play_arrow_rounded, color: scheme.onSurface, size: 20),
                                const SizedBox(width: 8),
                                const Text('Resume'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'pause',
                            enabled: widget.entry.isActive,
                            child: Row(
                              children: [
                                Icon(Icons.pause_rounded, color: scheme.onSurface, size: 20),
                                const SizedBox(width: 8),
                                const Text('Pause'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'stop',
                            enabled: widget.entry.isOngoing,
                            child: Row(
                              children: [
                                Icon(Icons.stop_rounded, color: scheme.onSurface, size: 20),
                                const SizedBox(width: 8),
                                const Text('Stop'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, color: scheme.onSurface, size: 20),
                                const SizedBox(width: 8),
                                const Text('Edit Details'),
                              ],
                            ),
                          ),
                          if (widget.onMergeWithPrevious != null)
                            PopupMenuItem(
                              value: 'merge',
                              child: Row(
                                children: [
                                  Icon(Icons.merge_type, color: scheme.onSurface, size: 20),
                                  const SizedBox(width: 8),
                                  const Text('Merge with Previous'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, color: scheme.error, size: 20),
                                const SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: scheme.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Expandable Details Panel ──────────────────────────────
                  SizeTransition(
                    sizeFactor: _expandAnim,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          Container(
                            height: 1,
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 14),

                          // Start and End times
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _DetailItem(
                                label: 'STARTED AT',
                                value: _formatDateTime(widget.entry.startedAt),
                                textTheme: textTheme,
                                scheme: scheme,
                              ),
                              if (widget.entry.endedAt != null)
                                _DetailItem(
                                  label: 'ENDED AT',
                                  value: _formatDateTime(widget.entry.endedAt!),
                                  textTheme: textTheme,
                                  scheme: scheme,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Mode and Completion Rate
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _DetailItem(
                                label: 'SESSION MODE',
                                value: widget.entry.sessionMode.label,
                                textTheme: textTheme,
                                scheme: scheme,
                              ),
                              if (widget.entry.sessionMode != SessionMode.stopwatch && widget.entry.targetDurationMinutes != null)
                                _DetailItem(
                                  label: 'COMPLETION',
                                  value: '${widget.entry.completionPercentage.toStringAsFixed(0)}% of ${widget.entry.targetDurationMinutes}m',
                                  textTheme: textTheme,
                                  scheme: scheme,
                                ),
                            ],
                          ),

                          // Completion progress bar (only for timed focus sessions)
                          if (widget.entry.sessionMode != SessionMode.stopwatch && widget.entry.targetDurationMinutes != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (widget.entry.completionPercentage / 100.0).clamp(0.0, 1.0),
                                backgroundColor: scheme.surfaceContainer,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  widget.entry.completionPercentage >= 100.0 ? const Color(0xFF4ADE80) : scheme.primary,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],

                          // Notes Section
                          if (hasNotes) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.sticky_note_2_outlined, size: 14, color: scheme.onSurfaceVariant),
                                      const SizedBox(width: 6),
                                      Text(
                                        'NOTES',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.entry.notes!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Controls (Play/Pause/Stop) if ongoing
                          if (widget.entry.isOngoing) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (widget.entry.isActive)
                                  Expanded(
                                    child: _SessionControls(
                                      accent: accent,
                                      onStop: () {
                                        _toggle();
                                        widget.onStopSession?.call();
                                      },
                                      onPause: () {
                                        _toggle();
                                        widget.onPauseSession?.call();
                                      },
                                    ),
                                  ),
                                if (widget.entry.isPaused)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            onPressed: () {
                                              _toggle();
                                              widget.onResumeSession?.call();
                                            },
                                            icon: const Icon(Icons.play_arrow_rounded),
                                            label: const Text('RESUME'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: scheme.error,
                                              foregroundColor: scheme.onError,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            onPressed: () {
                                              _toggle();
                                              widget.onStopSession?.call();
                                            },
                                            icon: const Icon(Icons.stop_rounded),
                                            label: const Text('STOP'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
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

  String _clock(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60);
    final s = value.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = local.minute.toString().padLeft(2, '0');
    
    // E.g., "14 Jun, 2:30 PM"
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${local.day} ${months[local.month - 1]}, $hour:$minuteStr $period';
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    required this.textTheme,
    required this.scheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SessionControls extends StatelessWidget {
  const _SessionControls({
    required this.accent,
    required this.onStop,
    required this.onPause,
  });

  final Color accent;
  final VoidCallback onStop;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: _PauseButton(
            onPause: onPause,
            textTheme: textTheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StopButton(
            accent: accent,
            onStop: onStop,
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }
}

class _PauseButton extends StatefulWidget {
  const _PauseButton({
    required this.onPause,
    required this.textTheme,
  });

  final VoidCallback onPause;
  final TextTheme textTheme;

  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;
  bool _pressed = false;

  static const _pauseAmber = Color(0xFFFBBC05);

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPause();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, _) {
            return Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFCA28), Color(0xFFF57F17)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _pauseAmber.withValues(alpha: _glow.value),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 3.5,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 3.5,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PAUSE',
                    style: widget.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StopButton extends StatefulWidget {
  const _StopButton({
    required this.accent,
    required this.onStop,
    required this.textTheme,
  });

  final Color accent;
  final VoidCallback onStop;
  final TextTheme textTheme;

  @override
  State<_StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<_StopButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;
  bool _pressed = false;

  static const _stopRed = Color(0xFFFF4D6D);

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onStop();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, _) {
            return Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4D6D), Color(0xFFD6194A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _stopRed.withValues(alpha: _glow.value),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'STOP',
                    style: widget.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
