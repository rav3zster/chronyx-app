import 'package:chronyx/core/errors/app_exception.dart';

/// Maps exceptions to user-friendly, actionable messages.
///
/// NEVER show raw exception text, class names, or stack traces to users.
class ErrorMessageMapper {
  const ErrorMessageMapper._();

  /// Convert any error into a human-readable message.
  static String fromError(Object error) {
    if (error is ValidationException) {
      return error.message;
    }
    if (error is NetworkException) {
      return 'Unable to connect. Check your internet and try again.';
    }
    if (error is ServerException) {
      return 'Our servers are having a moment. Please try again shortly.';
    }
    if (error is UnknownException) {
      return _mapUnknownMessage(error.message);
    }
    if (error is AppException) {
      return error.message;
    }

    // Catch raw Supabase/platform exceptions
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused')) {
      return 'Unable to connect. Check your internet and try again.';
    }
    if (msg.contains('not authenticated') || msg.contains('jwt')) {
      return 'Session expired. Please sign in again.';
    }
    if (msg.contains('permission denied') || msg.contains('rls')) {
      return 'Access denied. Please sign in again.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// Context-aware empty state messages for specific features.
  static String emptyState(EmptyStateContext context) {
    return switch (context) {
      EmptyStateContext.timeTracking =>
        'No sessions yet. Start tracking your first focus session.',
      EmptyStateContext.goals =>
        'No goals yet. Create your first goal to build momentum.',
      EmptyStateContext.analytics =>
        'Track a few sessions to unlock your insights.',
      EmptyStateContext.projects =>
        'No roadmaps yet. Create a Blueprint to get started.',
      EmptyStateContext.todaysRoadmap => 'No tasks scheduled for today.',
    };
  }

  static String _mapUnknownMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('not authenticated') || lower.contains('auth')) {
      return 'Session expired. Please sign in again.';
    }
    if (lower.contains('fetch')) {
      return 'Could not load data. Pull to refresh or try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Contexts for feature-specific empty state messages.
enum EmptyStateContext {
  timeTracking,
  goals,
  analytics,
  projects,
  todaysRoadmap,
}
