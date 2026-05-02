import 'dart:async';

// Conditional import — uses web impl on web, stub everywhere else
import 'focus_tracker_stub.dart'
    if (dart.library.html) 'focus_tracker_web.dart';

/// Service that tracks whether the Chronyx browser tab is active.
///
/// On web: listens to `document.visibilitychange`.
/// On native: always reports focused (no-op).
abstract class FocusTracker {
  factory FocusTracker() => createFocusTracker();

  /// Emits [true] when the tab gains focus, [false] when it loses it.
  Stream<bool> get focusStream;

  /// Current focus state (synchronous read).
  bool get isFocused;

  void dispose();
}
