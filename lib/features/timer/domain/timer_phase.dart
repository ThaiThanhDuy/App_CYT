/// Pha của bộ hẹn giờ.
enum TimerPhase {
  focus,
  rest;

  String get label => switch (this) {
    TimerPhase.focus => 'Focus',
    TimerPhase.rest => 'Break',
  };
}
