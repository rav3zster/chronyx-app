import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pending session handoff from a project's Today's Focus to the time
/// tracking screen. The tracking page consumes this once to pre-fill the
/// task name + category (and link the session to a project/task).
class SessionPrefill {
  const SessionPrefill({
    required this.taskName,
    required this.category,
    this.projectId,
    this.projectTaskId,
  });

  final String taskName;
  final TaskCategory category;
  final String? projectId;
  final String? projectTaskId;
}

/// Null when there's nothing to pre-fill. Set by the project dashboard,
/// read + cleared by the time tracking screen.
final sessionPrefillProvider = StateProvider<SessionPrefill?>((_) => null);
