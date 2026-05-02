import 'package:chronyx/core/constants/app_colors.dart';
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter/material.dart';
import 'package:chronyx/core/widgets/app_card.dart';
import 'package:intl/intl.dart';

class TimeEntryCard extends StatelessWidget {
  const TimeEntryCard({
    required this.entry,
    required this.onStopSession,
    super.key,
  });

  final TimeEntry entry;
  final VoidCallback? onStopSession;

  @override
  Widget build(BuildContext context) {
    final String startedAt = DateFormat.Hm().format(entry.startedAt.toLocal());
    final String duration = _formatDuration(entry.duration);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.taskName.isEmpty ? AppStrings.unknownTask : entry.taskName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('$startedAt • $duration'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            entry.isActive ? AppStrings.inProgress : duration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: entry.isActive ? AppColors.success : null,
            ),
          ),
          if (entry.isActive) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onStopSession,
                child: const Text(AppStrings.stopSession),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    final String hh = hours.toString().padLeft(2, '0');
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}
