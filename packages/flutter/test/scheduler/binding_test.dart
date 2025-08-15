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
    setUp(() {
      WidgetsBinding.instance.attachRootWidget(const SizedBox.shrink());
      SchedulerBinding.instance.resetInternalState();
    });

    tearDown(() {
      SchedulerBinding.instance.resetInternalState();
    });

    test('defaults to false and uses normal lifecycle behavior', () {
      expect(SchedulerBinding.instance.forceFramesEnabled, isFalse);
      expect(SchedulerBinding.instance.framesEnabled, isTrue);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(SchedulerBinding.instance.framesEnabled, isFalse);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(SchedulerBinding.instance.framesEnabled, isTrue);
    });

    test('when set to true, keeps frames enabled when hidden or paused but not when detached', () {
      SchedulerBinding.instance.forceFramesEnabled = true;
      expect(SchedulerBinding.instance.framesEnabled, isTrue);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(SchedulerBinding.instance.framesEnabled, isTrue);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(SchedulerBinding.instance.framesEnabled, isTrue);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      expect(SchedulerBinding.instance.framesEnabled, isFalse);
    });

    test('does not disable frames when app is active', () {
      SchedulerBinding.instance.forceFramesEnabled = false;
      expect(SchedulerBinding.instance.framesEnabled, isTrue);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(SchedulerBinding.instance.framesEnabled, isTrue);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(SchedulerBinding.instance.framesEnabled, isTrue);
    });

    test('can be toggled on and off', () {
      expect(SchedulerBinding.instance.forceFramesEnabled, isFalse);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(SchedulerBinding.instance.framesEnabled, isFalse);

      SchedulerBinding.instance.forceFramesEnabled = true;
      expect(SchedulerBinding.instance.framesEnabled, isTrue);

      SchedulerBinding.instance.forceFramesEnabled = false;
      expect(SchedulerBinding.instance.framesEnabled, isFalse);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(SchedulerBinding.instance.framesEnabled, isTrue);
    });

    test('schedules frame when changed from false to true while app is hidden', () {
      SchedulerBinding.instance.handleBeginFrame(null);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(SchedulerBinding.instance.framesEnabled, isFalse);
      expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);

      SchedulerBinding.instance.forceFramesEnabled = true;
      expect(SchedulerBinding.instance.framesEnabled, isTrue);
      expect(SchedulerBinding.instance.hasScheduledFrame, isTrue);
    });

    test('never enables frames when detached, even when forced', () {
      SchedulerBinding.instance.forceFramesEnabled = true;
      expect(SchedulerBinding.instance.framesEnabled, isTrue);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      expect(SchedulerBinding.instance.framesEnabled, isFalse);

      expect(SchedulerBinding.instance.forceFramesEnabled, isTrue);
    });

    test('resetInternalState clears force flag', () {
      SchedulerBinding.instance.forceFramesEnabled = true;
      expect(SchedulerBinding.instance.forceFramesEnabled, isTrue);

      SchedulerBinding.instance.resetInternalState();
      expect(SchedulerBinding.instance.forceFramesEnabled, isFalse);
    });
  });
}
