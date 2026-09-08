import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final localClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final todayProvider = NotifierProvider.autoDispose<TodayController, DateTime>(
  TodayController.new,
);

class TodayController extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(localClockProvider);
    ref.onDispose(() {
      _timer?.cancel();
    });
    final now = clock();
    _schedule(now);
    return DateTime(now.year, now.month, now.day);
  }

  void refresh() {
    final now = ref.read(localClockProvider)();
    final date = DateTime(now.year, now.month, now.day);
    if (date != state) state = date;
    _schedule(now);
  }

  void _schedule(DateTime now) {
    _timer?.cancel();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    // Recheck the wall clock while foregrounded to catch clock/time-zone edits.
    final delay = remaining < const Duration(minutes: 1)
        ? remaining
        : const Duration(minutes: 1);
    _timer = Timer(delay, refresh);
  }
}
