import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ── Time group labels ─────────────────────────────────────────────────────────

enum _Group { today, yesterday, thisWeek, thisMonth, older }

_Group _groupFor(TimeEntry e) {
  final now = DateTime.now();
  final d = e.startedAt;
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);

  if (d.isAfter(today)) return _Group.today;
  if (d.isAfter(yesterday)) return _Group.yesterday;
  if (d.isAfter(weekStart)) return _Group.thisWeek;
  if (d.isAfter(monthStart)) return _Group.thisMonth;
  return _Group.older;
}

String _groupLabel(_Group g) => switch (g) {
      _Group.today => 'Today',
      _Group.yesterday => 'Yesterday',
      _Group.thisWeek => 'Earlier This Week',
      _Group.thisMonth => 'Earlier This Month',
      _Group.older => 'Older',
    };

// ═════════════════════════════════════════════════════════════════════════════
// Session History Page
// ═════════════════════════════════════════════════════════════════════════════

class SessionHistoryPage extends ConsumerStatefulWidget {
  const SessionHistoryPage({super.key});

  @override
  ConsumerState<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends ConsumerState<SessionHistoryPage> {
  final Set<_Group> _collapsed = {};
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      ref.read(sessionSearchQueryProvider.notifier).state = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allEntries = ref.watch(filteredSessionsProvider).value ?? [];
    final completed =
        allEntries.where((e) => !e.isOngoing).toList();

    // Group
    final Map<_Group, List<TimeEntry>> grouped = {};
    for (final e in completed) {
      final g = _groupFor(e);
      grouped.putIfAbsent(g, () => []).add(e);
    }
    final groups = _Group.values.where((g) => grouped.containsKey(g)).toList();

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search sessions…',
                hintStyle: GoogleFonts.inter(
                    color: scheme.onSurface.withOpacity(0.3), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: scheme.onSurface.withOpacity(0.35), size: 20),
                isDense: true,
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          ref
                              .read(sessionSearchQueryProvider.notifier)
                              .state = '';
                        },
                        child: Icon(Icons.close_rounded,
                            size: 18,
                            color: scheme.onSurface.withOpacity(0.35)),
                      )
                    : null,
              ),
            ),
          ),
        ),

        // ── List ─────────────────────────────────────────────────────────────
        Expanded(
          child: completed.isEmpty
              ? _EmptyHistory()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  itemCount: _countItems(groups, grouped),
                  itemBuilder: (ctx, i) {
                    return _resolveItem(ctx, i, groups, grouped, scheme);
                  },
                ),
        ),
      ],
    );
  }

  int _countItems(
    List<_Group> groups,
    Map<_Group, List<TimeEntry>> grouped,
  ) {
    int count = 0;
    for (final g in groups) {
      count += 1; // header
      if (!_collapsed.contains(g)) {
        count += grouped[g]!.length;
      }
    }
    return count;
  }

  Widget _resolveItem(
    BuildContext ctx,
    int index,
    List<_Group> groups,
    Map<_Group, List<TimeEntry>> grouped,
    ColorScheme scheme,
  ) {
    int cursor = 0;
    for (final g in groups) {
      if (cursor == index) {
        // group header
        return _GroupHeader(
          label: _groupLabel(g),
          count: grouped[g]!.length,
          isCollapsed: _collapsed.contains(g),
          onToggle: () => setState(() {
            if (_collapsed.contains(g)) {
              _collapsed.remove(g);
            } else {
              _collapsed.add(g);
            }
          }),
          totalMinutes: grouped[g]!
              .fold(0, (sum, e) => sum + e.durationMinutes),
        );
      }
      cursor++;
      if (!_collapsed.contains(g)) {
        final items = grouped[g]!;
        if (index < cursor + items.length) {
          return _HistoryCard(entry: items[index - cursor]);
        }
        cursor += items.length;
      }
    }
    return const SizedBox.shrink();
  }
}

// ── Group Header ──────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.isCollapsed,
    required this.onToggle,
    required this.totalMinutes,
  });
  final String label;
  final int count;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withOpacity(0.55),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const Spacer(),
            Text(
              timeStr,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: scheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: isCollapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: scheme.onSurface.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.entry});
  final TimeEntry entry;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  static Color _catColor(TaskCategory c) => switch (c) {
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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _anim = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final scheme = Theme.of(context).colorScheme;
    final accent = _catColor(e.category);
    final isFmt = DateFormat('HH:mm');
    final dFmt = DateFormat('MMM d');

    final hh = e.durationMinutes ~/ 60;
    final mm = e.durationMinutes % 60;
    final dur = hh > 0 ? '${hh}h ${mm}m' : '${mm}m';
    final pct = e.targetDurationMinutes != null &&
            e.targetDurationMinutes! > 0
        ? (e.durationMinutes / e.targetDurationMinutes! * 100)
            .clamp(0, 100)
            .round()
        : null;

    // Status
    final Color statusColor;
    final String statusLabel;
    if (e.isActive) {
      statusColor = const Color(0xFF22D3A6);
      statusLabel = 'Active';
    } else if (e.isPaused) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Paused';
    } else if (e.status == SessionStatus.cancelled) {
      statusColor = scheme.error;
      statusLabel = 'Cancelled';
    } else {
      statusColor = accent;
      statusLabel = 'Done';
    }

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _expanded
                ? accent.withOpacity(0.3)
                : scheme.outlineVariant.withOpacity(0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category dot
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.taskName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface.withOpacity(0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dur,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Meta row
                        Row(
                          children: [
                            Text(
                              '${e.category.emoji} ${e.category.label}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    scheme.onSurface.withOpacity(0.45),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${e.sessionMode.icon} ${e.sessionMode.label}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    scheme.onSurface.withOpacity(0.45),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Time row
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 12,
                                color:
                                    scheme.onSurface.withOpacity(0.3)),
                            const SizedBox(width: 4),
                            Text(
                              '${isFmt.format(e.startedAt)}${e.endedAt != null ? ' – ${isFmt.format(e.endedAt!)}' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    scheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                            if (pct != null) ...[
                              const SizedBox(width: 10),
                              Text(
                                '$pct%',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Completion bar (only if has target)
            if (pct != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 0, 14, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0, 1),
                    minHeight: 3,
                    backgroundColor:
                        scheme.outlineVariant.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),

            // Tags strip
            if (e.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 0, 14, 10),
                child: Wrap(
                  spacing: 5,
                  children: e.tags
                      .take(5)
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer
                                  .withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$t',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: scheme.primary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),

            // ── Expanded detail ───────────────────────────────────────────
            SizeTransition(
              sizeFactor: _anim,
              child: FadeTransition(
                opacity: _anim,
                child: _ExpandedDetail(entry: e, scheme: scheme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanded Detail ───────────────────────────────────────────────────────────

class _ExpandedDetail extends StatelessWidget {
  const _ExpandedDetail({required this.entry, required this.scheme});
  final TimeEntry entry;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final rows = <_DetailRow>[
      _DetailRow('Energy', '${e.energyLevel.emoji} ${e.energyLevel.label}'),
      if (e.interruptions > 0)
        _DetailRow('Interruptions', '${e.interruptions} ⚡'),
      if (e.targetDurationMinutes != null)
        _DetailRow('Target', '${e.targetDurationMinutes}m'),
      if (e.breakDurationMinutes != null)
        _DetailRow('Break', '${e.breakDurationMinutes}m'),
      if (e.notes != null && e.notes!.isNotEmpty)
        _DetailRow('Notes', e.notes!),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(r.label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withOpacity(0.4),
                            )),
                      ),
                      Expanded(
                        child: Text(r.value,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withOpacity(0.75),
                            )),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 40,
              color: scheme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No sessions yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your first focus session\nto see it appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.35),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
