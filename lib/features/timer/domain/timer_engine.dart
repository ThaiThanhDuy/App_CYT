import 'dart:async';

import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'time_format.dart';
import 'timer_phase.dart';
import 'timer_plan.dart';

enum TimerStatus { idle, running, paused, finished }

/// Sự kiện engine phát ra (đồng bộ, ngay khi phát hiện).
sealed class TimerEvent {
  const TimerEvent();
}

/// Một bước kết thúc trọn vẹn: bước có giờ chạy hết giờ, hoặc bước vô hạn
/// được người dùng bấm "Xong". Chỉ sự kiện này (với pha focus) mới được
/// tính là một phiên hoàn thành.
class StepCompleted extends TimerEvent {
  const StepCompleted({
    required this.index,
    required this.step,
    required this.startedAt,
    required this.endedAt,
    required this.elapsed,
  });

  final int index;
  final TimerStep step;
  final DateTime startedAt;

  /// Bước có giờ: thời điểm hết giờ theo lịch (endAt), không phải lúc engine
  /// phát hiện. Bước vô hạn: lúc bấm Xong.
  final DateTime endedAt;

  /// Thời gian thực sự chạy (không tính lúc tạm dừng). Bước có giờ thì bằng
  /// thời lượng của bước.
  final Duration elapsed;
}

/// Một bước bị người dùng bỏ qua — không tính là hoàn thành.
class StepSkipped extends TimerEvent {
  const StepSkipped({required this.index, required this.step});

  final int index;
  final TimerStep step;
}

/// Đã chạy xong bước cuối cùng của chuỗi.
class PlanFinished extends TimerEvent {
  const PlanFinished({required this.at});

  final DateTime at;
}

/// Một mốc hết giờ dự kiến (dùng để hẹn thông báo khi app chạy nền).
@immutable
class UpcomingStepEnd {
  const UpcomingStepEnd({
    required this.index,
    required this.step,
    required this.at,
    required this.next,
  });

  final int index;
  final TimerStep step;
  final DateTime at;

  /// Bước kế tiếp; null nếu đây là bước cuối của chuỗi.
  final TimerStep? next;
}

/// Ảnh chụp trạng thái để UI hiển thị.
@immutable
class TimerSnapshot {
  const TimerSnapshot({
    required this.status,
    required this.index,
    required this.step,
    required this.round,
    required this.totalRounds,
    required this.remaining,
    required this.elapsed,
  });

  final TimerStatus status;
  final int index;
  final TimerStep step;
  final int round;
  final int totalRounds;

  /// Thời gian còn lại; bước vô hạn luôn là 0.
  final Duration remaining;

  /// Thời gian bước hiện tại đã chạy (không tính lúc tạm dừng).
  final Duration elapsed;

  TimerPhase get phase => step.phase;

  /// Bước hiện tại không giới hạn thời gian (và chuỗi chưa xong).
  bool get isInfinite => step.infinite && status != TimerStatus.finished;

  /// Tỉ lệ cuối bước được coi là "sắp đổi pha" (đèn vàng).
  static const double endingFraction = 0.1;

  /// Đang ở 10% thời gian cuối của một bước có giờ (đang chạy hoặc tạm dừng)
  /// → hiển thị màu vàng báo sắp chuyển pha, giống đèn giao thông.
  bool get isEnding =>
      !isInfinite &&
      (status == TimerStatus.running || status == TimerStatus.paused) &&
      step.duration > Duration.zero &&
      remaining > Duration.zero &&
      remaining.inMicroseconds <= step.duration.inMicroseconds * endingFraction;

  /// Chuỗi thời gian đang hiển thị: đếm ngược, hoặc đếm lên nếu vô hạn.
  String get display =>
      isInfinite ? formatElapsed(elapsed) : formatMmSs(remaining);
}

/// Engine đếm giờ.
///
/// Không bao giờ đếm bằng cách cộng dồn từng tick: bước có giờ chỉ lưu
/// [_endAt] và tính `remaining = endAt - now`; bước vô hạn lưu mốc bắt đầu
/// chạy [_runningSince] và tính `elapsed = now - runningSince`. Vì vậy app bị
/// OS tạm dừng bao lâu thì lần gọi kế tiếp vẫn đúng; [_catchUp] sẽ hoàn thành
/// bù mọi bước có giờ đã qua (và dừng lại ở bước vô hạn đầu tiên gặp).
class TimerEngine {
  TimerEngine({required this.plan, required this.clock}) {
    if (plan.steps.isEmpty || plan.repeat < 1) {
      throw ArgumentError.value(plan, 'plan', 'must have at least 1 step');
    }
    _remaining = plan.stepAt(0).duration;
  }

  final TimerPlan plan;
  final Clock clock;
  final _events = StreamController<TimerEvent>.broadcast(sync: true);

  TimerStatus _status = TimerStatus.idle;
  int _index = 0;

  /// Thời điểm hết giờ của bước có giờ; chỉ khác null khi đang chạy.
  DateTime? _endAt;

  /// Thời điểm bước hiện tại bắt đầu chạy lần đầu.
  DateTime? _stepStartedAt;

  /// Thời gian còn lại của bước có giờ khi không chạy (idle / paused).
  late Duration _remaining;

  /// Bước vô hạn: thời gian đã chạy trước lần chạy hiện tại.
  Duration _elapsedBefore = Duration.zero;

  /// Bước vô hạn: mốc bắt đầu lần chạy hiện tại; null khi không chạy.
  DateTime? _runningSince;

  Stream<TimerEvent> get events => _events.stream;

  bool get _currentInfinite => plan.stepAt(_index).infinite;

  TimerStatus get status {
    _catchUp();
    return _status;
  }

  TimerSnapshot get snapshot {
    _catchUp();
    final step = plan.stepAt(_index);
    final remaining = switch (_status) {
      _ when step.infinite => Duration.zero,
      TimerStatus.running => _nonNegative(_endAt!.difference(clock.now())),
      TimerStatus.finished => Duration.zero,
      TimerStatus.idle || TimerStatus.paused => _remaining,
    };
    return TimerSnapshot(
      status: _status,
      index: _index,
      step: step,
      round: plan.roundOf(_index),
      totalRounds: plan.repeat,
      remaining: remaining,
      elapsed: step.infinite ? _infiniteElapsed() : step.duration - remaining,
    );
  }

  /// Bắt đầu (idle), chạy tiếp (paused) hoặc chạy lại từ đầu (finished).
  void start() {
    _catchUp();
    switch (_status) {
      case TimerStatus.running:
        return;
      case TimerStatus.finished:
        reset();
      case TimerStatus.idle || TimerStatus.paused:
        break;
    }
    final now = clock.now();
    _stepStartedAt ??= now;
    if (_currentInfinite) {
      _runningSince = now;
      _endAt = null;
    } else {
      _endAt = now.add(_remaining);
    }
    _status = TimerStatus.running;
  }

  void pause() {
    _catchUp();
    if (_status != TimerStatus.running) return;
    if (_currentInfinite) {
      _elapsedBefore = _infiniteElapsed();
      _runningSince = null;
    } else {
      _remaining = _nonNegative(_endAt!.difference(clock.now()));
      _endAt = null;
    }
    _status = TimerStatus.paused;
  }

  void toggle() => status == TimerStatus.running ? pause() : start();

  /// Bỏ qua bước hiện tại, giữ nguyên trạng thái chạy/dừng.
  void skip() {
    _catchUp();
    if (_status == TimerStatus.finished) return;
    _emit(StepSkipped(index: _index, step: plan.stepAt(_index)));
    _advance(clock.now());
  }

  /// "Xong": kết thúc bước vô hạn hiện tại và tính là hoàn thành.
  /// Không có tác dụng với bước có giờ hoặc khi chưa bắt đầu.
  void finishInfinite() {
    _catchUp();
    if (!_currentInfinite ||
        (_status != TimerStatus.running && _status != TimerStatus.paused)) {
      return;
    }
    final now = clock.now();
    _emit(
      StepCompleted(
        index: _index,
        step: plan.stepAt(_index),
        startedAt: _stepStartedAt ?? now,
        endedAt: now,
        elapsed: _infiniteElapsed(),
      ),
    );
    _advance(now);
  }

  /// Huỷ và quay về bước đầu tiên. Bước đang dở không được tính.
  void reset() {
    _status = TimerStatus.idle;
    _index = 0;
    _endAt = null;
    _stepStartedAt = null;
    _remaining = plan.stepAt(0).duration;
    _elapsedBefore = Duration.zero;
    _runningSince = null;
  }

  /// Các mốc hết giờ sắp tới, giả sử chạy liên tục không tạm dừng.
  /// Rỗng nếu không đang chạy. Dừng trước bước vô hạn đầu tiên (không đoán
  /// được lúc nào kết thúc). Tối đa [limit] mốc (iOS giới hạn 64 thông báo
  /// hẹn trước).
  List<UpcomingStepEnd> upcomingStepEnds({int limit = 32}) {
    _catchUp();
    if (_status != TimerStatus.running || _currentInfinite) return const [];
    final result = <UpcomingStepEnd>[];
    var at = _endAt!;
    for (var i = _index; i < plan.length && result.length < limit; i++) {
      final step = plan.stepAt(i);
      if (i > _index) {
        if (step.infinite) break;
        at = at.add(step.duration);
      }
      result.add(
        UpcomingStepEnd(
          index: i,
          step: step,
          at: at,
          next: i + 1 < plan.length ? plan.stepAt(i + 1) : null,
        ),
      );
    }
    return result;
  }

  /// Gọi định kỳ để phát hiện hết giờ (UI ticker gọi qua [snapshot]).
  void tick() => _catchUp();

  void dispose() => _events.close();

  Duration _infiniteElapsed() {
    final since = _runningSince;
    return since == null
        ? _elapsedBefore
        : _elapsedBefore + _nonNegative(clock.now().difference(since));
  }

  void _catchUp() {
    while (_status == TimerStatus.running &&
        !_currentInfinite &&
        !clock.now().isBefore(_endAt!)) {
      final endedAt = _endAt!;
      final step = plan.stepAt(_index);
      _emit(
        StepCompleted(
          index: _index,
          step: step,
          startedAt: _stepStartedAt!,
          endedAt: endedAt,
          elapsed: step.duration,
        ),
      );
      // Bước kế bắt đầu đúng lúc bước trước hết giờ, không phải "bây giờ".
      _advance(endedAt);
    }
  }

  /// Chuyển sang bước kế tiếp, bắt đầu tại [at]; giữ trạng thái chạy/dừng.
  void _advance(DateTime at) {
    _elapsedBefore = Duration.zero;
    _runningSince = null;
    if (_index + 1 >= plan.length) {
      _status = TimerStatus.finished;
      _endAt = null;
      _stepStartedAt = null;
      _remaining = Duration.zero;
      _emit(PlanFinished(at: at));
      return;
    }
    _index++;
    final step = plan.stepAt(_index);
    if (_status == TimerStatus.running) {
      _stepStartedAt = at;
      if (step.infinite) {
        _endAt = null;
        _runningSince = at;
      } else {
        _endAt = at.add(step.duration);
      }
    } else {
      // Đang dừng/idle: bước mới chỉ thực sự bắt đầu khi bấm chạy.
      _stepStartedAt = null;
      _remaining = step.duration;
    }
  }

  void _emit(TimerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  static Duration _nonNegative(Duration d) => d.isNegative ? Duration.zero : d;
}
