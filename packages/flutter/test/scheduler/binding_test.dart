// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  test('scheduleForcedFrame sets up frame callbacks', () async {
    SchedulerBinding.instance.scheduleForcedFrame();
    expect(SchedulerBinding.instance.platformDispatcher.onBeginFrame, isNotNull);
  });

  test('debugAssertNoTimeDilation does not throw if time dilate already reset', () async {
    timeDilation = 2.0;
    timeDilation = 1.0;
    SchedulerBinding.instance.debugAssertNoTimeDilation('reason'); // no error
  });

  test('debugAssertNoTimeDilation throw if time dilate not reset', () async {
    timeDilation = 3.0;
    expect(
      () => SchedulerBinding.instance.debugAssertNoTimeDilation('reason'),
      throwsA(isA<FlutterError>().having((FlutterError e) => e.message, 'message', 'reason')),
    );
    timeDilation = 1.0;
  });

  test('Adding a persistent frame callback during a persistent frame callback', () {
    bool calledBack = false;
    SchedulerBinding.instance.addPersistentFrameCallback((Duration timeStamp) {
      if (!calledBack) {
        SchedulerBinding.instance.addPersistentFrameCallback((Duration timeStamp) {
          calledBack = true;
        });
      }
    });
    SchedulerBinding.instance.handleBeginFrame(null);
    SchedulerBinding.instance.handleDrawFrame();
    expect(calledBack, false);
    SchedulerBinding.instance.handleBeginFrame(null);
    SchedulerBinding.instance.handleDrawFrame();
    expect(calledBack, true);
  });

  group('forceFramesEnabled', () {
    late TestSchedulerBinding testBinding;

    setUp(() {
      testBinding = TestSchedulerBinding();
    });

    test('defaults to false and uses normal lifecycle behavior', () {
      expect(testBinding.forceFramesEnabled, isFalse);
      expect(testBinding.framesEnabled, isTrue);

      // Simulate app going to hidden state
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(testBinding.framesEnabled, isFalse);

      // Simulate app going to resumed state
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(testBinding.framesEnabled, isTrue);
    });

    test('when set to true, keeps frames enabled when hidden or paused but not when detached', () {
      testBinding.forceFramesEnabled = true;
      expect(testBinding.framesEnabled, isTrue);

      // Simulate app going to hidden state
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(testBinding.framesEnabled, isTrue); // Should remain true due to force

      // Simulate app going to paused state
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(testBinding.framesEnabled, isTrue); // Should remain true due to force

      // Simulate app going to detached state
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      expect(
        testBinding.framesEnabled,
        isFalse,
      ); // Should be false even when forced, no point in rendering when detached
    });

    test('does not disable frames when app is active', () {
      testBinding.forceFramesEnabled = false;
      expect(testBinding.framesEnabled, isTrue); // Should remain true when app is active

      // Simulate app going to resumed state
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(testBinding.framesEnabled, isTrue); // Should remain true

      // Simulate app going to inactive state
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(testBinding.framesEnabled, isTrue); // Should remain true
    });

    test('can be toggled on and off', () {
      // Start with default behavior
      expect(testBinding.forceFramesEnabled, isFalse);
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(testBinding.framesEnabled, isFalse);

      testBinding.forceFramesEnabled = true;
      expect(testBinding.framesEnabled, isTrue);

      testBinding.forceFramesEnabled = false;
      expect(testBinding.framesEnabled, isFalse);

      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(testBinding.framesEnabled, isTrue);
    });

    test('schedules frame when changed from false to true while app is hidden', () {
      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(testBinding.framesEnabled, isFalse);
      expect(testBinding.frameScheduledCount, 0);

      testBinding.forceFramesEnabled = true;
      expect(testBinding.framesEnabled, isTrue);
      expect(testBinding.frameScheduledCount, 1);

      testBinding.forceFramesEnabled = true;
      expect(testBinding.frameScheduledCount, 1);
    });

    test('never enables frames when detached, even when forced', () {
      testBinding.forceFramesEnabled = true;
      expect(testBinding.framesEnabled, isTrue);

      testBinding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      expect(testBinding.framesEnabled, isFalse);

      expect(testBinding.forceFramesEnabled, isTrue);
    });

    test('resetInternalState clears force flag', () {
      testBinding.forceFramesEnabled = true;
      expect(testBinding.forceFramesEnabled, isTrue);

      testBinding.resetInternalState();
      expect(testBinding.forceFramesEnabled, isFalse);
    });
  });
}

class TestSchedulerBinding extends WidgetsFlutterBinding {
  int frameScheduledCount = 0;

  @override
  void scheduleFrame() {
    frameScheduledCount++;
    // Don't call super to avoid actual frame scheduling in tests
  }
}
