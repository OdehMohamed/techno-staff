import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Drives the per-screen adaptive countdown ticker. One instance per consuming
/// screen. NEVER instantiate at app-global level.
///
/// Architectural invariants (do not relax):
/// - Owns exactly one Timer.periodic.
/// - Period is 60s by default; switches to 1s only when at least one
///   `dueDates` entry has a remaining duration below `Duration(hours: 1)`
///   and still has time remaining.
/// - Pauses the timer on AppLifecycleState.paused/inactive/hidden;
///   resumes on resumed.
/// - Exposes `currentTime` as a ValueListenable of DateTime values.
/// - Subscribers rebuild via ValueListenableBuilder bound to the leaf chip.
class CountdownClockProvider extends StatefulWidget {
  final List<DateTime> dueDates;
  final Widget child;

  const CountdownClockProvider({
    super.key,
    required this.dueDates,
    required this.child,
  });

  static ValueListenable<DateTime> of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_CountdownClockScope>();
    assert(
      inherited != null,
      'No CountdownClockProvider found above CountdownChip in the tree.',
    );
    return inherited!.notifier;
  }

  @override
  State<CountdownClockProvider> createState() => _CountdownClockProviderState();
}

class _CountdownClockProviderState extends State<CountdownClockProvider>
    with WidgetsBindingObserver {
  late ValueNotifier<DateTime> _now;
  Timer? _timer;
  Duration _period = const Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    _now = ValueNotifier<DateTime>(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _restartTicker();
  }

  @override
  void didUpdateWidget(covariant CountdownClockProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // dueDates list identity changes when the parent re-emits a new list.
    // Recompute period in case the closest-deadline bucket changed.
    _restartTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _now.value = DateTime.now();
      _restartTicker();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _restartTicker() {
    _timer?.cancel();
    _period = _resolvePeriod();
    _timer = Timer.periodic(_period, (_) {
      _now.value = DateTime.now();
      // If we crossed the 1h-to-deadline threshold while running at 60s,
      // upgrade to 1s on the next tick.
      final newPeriod = _resolvePeriod();
      if (newPeriod != _period) {
        _restartTicker();
      }
    });
  }

  Duration _resolvePeriod() {
    final now = DateTime.now();
    for (final dueDate in widget.dueDates) {
      final endOfDay = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        23,
        59,
        59,
      );
      final diff = endOfDay.difference(now);
      if (diff > Duration.zero && diff < const Duration(hours: 1)) {
        return const Duration(seconds: 1);
      }
    }
    return const Duration(seconds: 60);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CountdownClockScope(notifier: _now, child: widget.child);
  }
}

class _CountdownClockScope extends InheritedWidget {
  final ValueNotifier<DateTime> notifier;

  const _CountdownClockScope({required this.notifier, required super.child});

  @override
  bool updateShouldNotify(_CountdownClockScope oldWidget) =>
      notifier != oldWidget.notifier;
}
