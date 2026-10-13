import '../../presets/domain/plan_summary.dart';
import '../../themes/domain/theme_package.dart';
import '../../timer/domain/timer_phase.dart';
import '../../timer/domain/timer_plan.dart';
import 'sound_ref.dart';

/// Loại sự kiện hết giờ, quyết định âm thanh mặc định.
enum AlertKind {
  focusEnd(SoundKeys.chime),
  restEnd(SoundKeys.bell),
  complete(SoundKeys.complete);

  const AlertKind(this.defaultSound);
  final String defaultSound;
}

/// Nội dung một thông báo hết giờ.
class AlertMessage {
  const AlertMessage({
    required this.title,
    required this.body,
    required this.kind,
    this.stepSound,
  });

  final String title;
  final String body;
  final AlertKind kind;

  /// Âm thanh riêng của bước (chỉ nhận key có sẵn trong [SoundKeys]).
  final String? stepSound;

  /// Chọn âm thanh: của bước → của theme → mặc định theo [kind].
  SoundRef resolveSound(ThemePackage theme) {
    if (stepSound case final key? when SoundKeys.all.contains(key)) {
      return SoundKeys.ref(key);
    }
    final themeSpec = switch (kind) {
      AlertKind.focusEnd => theme.sounds.focusEnd,
      AlertKind.restEnd => theme.sounds.restEnd,
      AlertKind.complete => theme.sounds.complete,
    };
    return theme.resolveSound(themeSpec) ?? SoundKeys.ref(kind.defaultSound);
  }
}

/// Dựng thông báo khi bước [ended] kết thúc; [next] = null nghĩa là hết chuỗi.
AlertMessage alertForStepEnd({
  required TimerStep ended,
  required TimerStep? next,
  required String planName,
}) {
  if (next == null) {
    return AlertMessage(
      title: 'All done!',
      body: 'You finished "$planName".',
      kind: AlertKind.complete,
      stepSound: ended.sound,
    );
  }
  // Bước kế vô hạn: không có thời lượng để nói.
  final forNext = next.infinite
      ? 'with no time limit'
      : 'for ${formatDuration(next.duration)}';
  // Bước có tên riêng: báo theo tên đó ("Reading is over · Next: Walk …").
  if (ended.label != null || next.label != null) {
    return AlertMessage(
      title: '${ended.displayName} is over',
      body: 'Next: ${next.displayName} $forNext.',
      kind: ended.phase == TimerPhase.focus
          ? AlertKind.focusEnd
          : AlertKind.restEnd,
      stepSound: ended.sound,
    );
  }
  return switch (ended.phase) {
    TimerPhase.focus => AlertMessage(
      title: 'Focus time is up',
      body: next.phase == TimerPhase.rest
          ? 'Take a break $forNext.'
          : 'Keep focusing $forNext.',
      kind: AlertKind.focusEnd,
      stepSound: ended.sound,
    ),
    TimerPhase.rest => AlertMessage(
      title: 'Break is over',
      body: next.phase == TimerPhase.focus
          ? 'Time to focus $forNext.'
          : 'Keep resting $forNext.',
      kind: AlertKind.restEnd,
      stepSound: ended.sound,
    ),
  };
}
