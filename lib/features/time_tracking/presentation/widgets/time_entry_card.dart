import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter/material.dart';

class TimeEntryCard extends StatefulWidget {
  const TimeEntryCard({
    required this.entry,
    required this.onStopSession,
    this.onResumeSession,
    this.onEditSession,
    this.onDeleteSession,
    super.key,
  });

  final TimeEntry entry;
  final VoidCallback? onStopSession;
  final VoidCallback? onResumeSession;
  final VoidCallback? onEditSession;
  final VoidCallback? onDeleteSession;

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
    if (!widget.entry.isActive) return;
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
    final dotColor = widget.entry.isActive
        ? accent
        : _colorForCategory(widget.entry.category);

    final subtitle = widget.entry.isActive
        ? '${widget.entry.category.label} · ${AppStrings.inProgress}'
        : '${widget.entry.category.label} · ${_formatDuration(widget.entry.duration)}';

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: widget.entry.isActive
              ? Border.all(
                  color: _expanded
                      ? accent.withValues(alpha: 0.65)
                      : accent.withValues(alpha: 0.35),
                  width: _expanded ? 1.5 : 1.0,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Row: always visible ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status dot
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: widget.entry.isActive
                        ? _PulsingDot(color: dotColor)
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
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
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Clock + live badge / chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _clock(widget.entry.duration),
                        style: textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.entry.isActive)
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LIVE',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 13,
                                  color: accent,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      switch (value) {
                        case 'resume':
                          widget.onResumeSession?.call();
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
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'resume',
                        enabled: !widget.entry.isActive,
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow_rounded, color: scheme.onSurface, size: 20),
                            const SizedBox(width: 8),
                            const Text('Resume'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'stop',
                        enabled: widget.entry.isActive,
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
                            const Text('Edit'),
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
            ),

            // ── Expandable controls ──────────────────────────────────────
            if (widget.entry.isActive)
              SizeTransition(
                sizeFactor: _expandAnim,
                // ignore: deprecated_member_use
                axisAlignment: -1.0,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _SessionControls(
                    accent: accent,
                    onStop: () {
                      // Collapse first, then trigger stop
                      setState(() => _expanded = false);
                      _expandCtrl.reverse();
                      widget.onStopSession?.call();
                    },
                  ),
                ),
              ),
          ],
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

  String _formatDuration(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable controls panel — stop button
// ─────────────────────────────────────────────────────────────────────────────

class _SessionControls extends StatelessWidget {
  const _SessionControls({required this.accent, required this.onStop});

  final Color accent;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accent.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Stop button — full-width glowing pill
          _StopButton(accent: accent, onStop: onStop, textTheme: textTheme),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stop button — pulsing glow ring + icon + label
// ─────────────────────────────────────────────────────────────────────────────

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
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4D6D), Color(0xFFD6194A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _stopRed.withValues(alpha: _glow.value),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Square stop icon with rounded corners
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'STOP SESSION',
                    style: widget.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      fontSize: 13,
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

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot for active sessions
// ─────────────────────────────────────────────────────────────────────────────

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
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
