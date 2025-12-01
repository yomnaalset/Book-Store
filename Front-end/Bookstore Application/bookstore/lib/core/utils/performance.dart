import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Utility class for performance optimization in the app
class Performance {
  /// Debounces a function call to avoid excessive execution
  ///
  /// This is useful for search inputs, scrolling events, etc.
  static Function debounce(
    Function function, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    DateTime? lastExecution;
    Timer? timer;

    return () {
      if (timer != null) {
        timer!.cancel();
      }

      timer = Timer(duration, () {
        if (lastExecution == null ||
            DateTime.now().difference(lastExecution!) > duration) {
          function();
          lastExecution = DateTime.now();
        }
      });
    };
  }

  /// Throttles a function call to execute at most once per specified duration
  ///
  /// This is useful for button taps, API calls, etc.
  static Function throttle(
    Function function, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    DateTime? lastExecution;

    return () {
      if (lastExecution == null ||
          DateTime.now().difference(lastExecution!) > duration) {
        function();
        lastExecution = DateTime.now();
      }
    };
  }

  /// Optimizes image loading by pre-caching important images
  static Future<void> precacheAppImages(BuildContext context) async {
    // List of important app images to precache
    final List<String> imagePaths = [
      'assets/images/welcome/welcome_bg.jpg',
      'assets/images/welcome/welcome_1.jpg',
      'assets/images/welcome/welcome_2.jpg',
      'assets/images/welcome/welcome_3.jpg',
    ];

    // Precache images to avoid jank when they're first displayed
    for (String path in imagePaths) {
      await precacheImage(AssetImage(path), context);
    }
  }

  /// Schedules a callback for the next frame when the UI is idle
  static void scheduleForNextFrame(VoidCallback callback) {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      callback();
    });
  }

  /// Logs performance metrics in debug mode
  static void logPerformance(String tag, Function() function) {
    if (kDebugMode) {
      final stopwatch = Stopwatch()..start();
      function();
      stopwatch.stop();
      debugPrint('$tag completed in ${stopwatch.elapsedMilliseconds}ms');
    } else {
      function();
    }
  }
}

/// Extension on Widget to add performance optimizations
extension PerformanceOptimizedWidget on Widget {
  /// Wraps widget with RepaintBoundary to optimize repaints
  Widget withRepaintBoundary() => RepaintBoundary(child: this);

  /// Wraps widget with LayoutBuilder to defer expensive layout operations
  Widget withDeferredLayout(
    Widget Function(BuildContext, BoxConstraints) builder,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(context, constraints),
    );
  }
}

/// Timer class used by the debounce method
class Timer {
  final Duration duration;
  final Function callback;
  DateTime startTime;
  bool _cancelled = false;

  Timer(this.duration, this.callback) : startTime = DateTime.now() {
    Future.delayed(duration).then((_) {
      if (!_cancelled) {
        callback();
      }
    });
  }

  void cancel() {
    _cancelled = true;
  }
}
