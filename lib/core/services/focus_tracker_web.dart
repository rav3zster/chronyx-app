// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';
import 'package:chronyx/core/services/focus_tracker.dart';

class FocusTrackerImpl implements FocusTracker {
  FocusTrackerImpl() {
    _controller = StreamController<bool>.broadcast();
    _isFocused = html.document.visibilityState == 'visible';

    html.document.addEventListener('visibilitychange', (html.Event _) {
      final visible = html.document.visibilityState == 'visible';
      _isFocused = visible;
      _controller.add(visible);
    });
  }

  late final StreamController<bool> _controller;
  bool _isFocused = true;

  @override
  Stream<bool> get focusStream => _controller.stream;

  @override
  bool get isFocused => _isFocused;

  @override
  void dispose() {
    _controller.close();
  }
}

FocusTracker createFocusTracker() => FocusTrackerImpl();
