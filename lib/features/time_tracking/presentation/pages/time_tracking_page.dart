import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/widgets/input_field.dart';
import 'package:chronyx/core/widgets/primary_button.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/time_tracking/presentation/widgets/time_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronyx/core/widgets/app_error_view.dart';

class TimeTrackingPage extends ConsumerStatefulWidget {
  const TimeTrackingPage({super.key});

  @override
  ConsumerState<TimeTrackingPage> createState() => _TimeTrackingPageState();
}

class _TimeTrackingPageState extends ConsumerState<TimeTrackingPage> {
  final TextEditingController _taskController = TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    final notifier = ref.read(timeEntriesProvider.notifier);
    final taskName = _taskController.text.trim();
    try {
      await notifier.startSession(taskName: taskName);
      _taskController.clear();
    } catch (error) {
      if (!mounted) return;
      final message = ErrorMessageMapper.fromError(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _stopSession(String id) async {
    final notifier = ref.read(timeEntriesProvider.notifier);
    await notifier.stopSession(sessionId: id);
  }

  @override
  Widget build(BuildContext context) {
    final timeEntriesState = ref.watch(timeEntriesProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.timeTrackingTitle),
        actions: const [
          SettingsIconButton(),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InputField(
              controller: _taskController,
              label: 'Task Name',
              hint: AppStrings.taskHint,
              prefixIcon: Icon(
                Icons.label_outline_rounded,
                color: scheme.onSurfaceVariant,
                size: AppSpacing.iconMd,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _startSession(),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: AppStrings.startSession,
              onPressed: _startSession,
              isLoading: timeEntriesState.isLoading,
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: AppSpacing.iconMd,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.sessionsHeader,
              style: textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: timeEntriesState.when(
                data: (entries) => _SessionList(
                  entries: entries,
                  onStopSession: _stopSession,
                ),
                error: (error, _) => AppErrorView(
                  message: ErrorMessageMapper.fromError(error),
                  onRetry: () =>
                      ref.read(timeEntriesProvider.notifier).refreshEntries(),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.entries,
    required this.onStopSession,
  });

  final List<TimeEntry> entries;
  final Future<void> Function(String id) onStopSession;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: AppSpacing.iconXl * 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.noSessionsYet,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(bottom: AppSpacing.xxxl + AppSpacing.lg),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return TimeEntryCard(
          entry: entry,
          onStopSession: entry.isActive ? () => onStopSession(entry.id) : null,
        );
      },
    );
  }
}
