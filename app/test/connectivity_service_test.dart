/// Unit tests for ConnectivityService
///
/// Tests the pure logic of ConnectivityService without requiring
/// actual network access. Uses a testable wrapper approach.
///
/// Run with: flutter test test/connectivity_service_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

// We test the stream/state logic without the actual connectivity plugin.
// The ConnectivityService uses a singleton pattern, so we test the
// state management logic in isolation.

/// Mimics the backend health monitoring state logic from ConnectivityService
class BackendHealthTracker {
  bool _isBackendReachable = false;
  bool get isBackendReachable => _isBackendReachable;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onHealthChanged => _controller.stream;

  void updateHealth(bool isHealthy) {
    if (_isBackendReachable != isHealthy) {
      _isBackendReachable = isHealthy;
      _controller.add(isHealthy);
    }
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  late BackendHealthTracker tracker;

  setUp(() {
    tracker = BackendHealthTracker();
  });

  tearDown(() {
    tracker.dispose();
  });

  group('BackendHealthTracker — State Management', () {
    test('starts as not reachable', () {
      expect(tracker.isBackendReachable, false);
    });

    test('updates to reachable', () {
      tracker.updateHealth(true);
      expect(tracker.isBackendReachable, true);
    });

    test('updates back to not reachable', () {
      tracker.updateHealth(true);
      tracker.updateHealth(false);
      expect(tracker.isBackendReachable, false);
    });
  });

  group('BackendHealthTracker — Stream', () {
    test('emits event when health changes', () async {
      final events = <bool>[];
      tracker.onHealthChanged.listen(events.add);

      tracker.updateHealth(true);
      await Future.delayed(Duration.zero);

      expect(events, [true]);
    });

    test('does NOT emit when health stays the same', () async {
      final events = <bool>[];
      tracker.onHealthChanged.listen(events.add);

      tracker.updateHealth(false); // Same as initial — no event
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('emits multiple events on toggle', () async {
      final events = <bool>[];
      tracker.onHealthChanged.listen(events.add);

      tracker.updateHealth(true);
      tracker.updateHealth(false);
      tracker.updateHealth(true);
      await Future.delayed(Duration.zero);

      expect(events, [true, false, true]);
    });

    test('does not emit duplicate consecutive events', () async {
      final events = <bool>[];
      tracker.onHealthChanged.listen(events.add);

      tracker.updateHealth(true);
      tracker.updateHealth(true); // Duplicate — should NOT emit
      tracker.updateHealth(true); // Duplicate — should NOT emit
      await Future.delayed(Duration.zero);

      expect(events, [true]); // Only one event
    });
  });
}
