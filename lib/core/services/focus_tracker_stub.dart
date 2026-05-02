import 'dart:async';
import 'package:chronyx/core/services/focus_tracker.dart';

// Stub implementation for non-web platforms (desktop, mobile)
class FocusTrackerImpl implements FocusTracker {
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get focusStream => _controller.stream;

  @override
  bool get isFocused => true; // Always focused on native

  @override
  void dispose() {
    _controller.close();
  }
}

FocusTracker createFocusTracker() => FocusTrackerImpl();
