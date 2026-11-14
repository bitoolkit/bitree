import '../core/json.dart';
import '../core/time.dart';

/// A daily, inclusive campus wall-clock window. The real deadline is never
/// stored here or changed: [apply] only derives an earlier presentation time.
class DeadlineCutoffWindow {
  const DeadlineCutoffWindow({
    this.enabled = false,
    this.startMinute = 22 * 60,
    this.endMinute = 8 * 60,
  }) : assert(startMinute >= 0 && startMinute < 24 * 60),
       assert(endMinute >= 0 && endMinute < 24 * 60);

  final bool enabled;
  final int startMinute;
  final int endMinute;

  bool get crossesMidnight => endMinute < startMinute;
  bool get isSinglePoint => endMinute == startMinute;

  bool contains(DateTime actual) {
    if (!enabled) return false;
    final day = calendarDate(actual);
    final start = day.add(Duration(minutes: startMinute));
    final end = day.add(Duration(minutes: endMinute));
    return crossesMidnight
        ? !actual.isBefore(start) || !actual.isAfter(end)
        : !actual.isBefore(start) && !actual.isAfter(end);
  }

  DateTime apply(DateTime actual) {
    if (!contains(actual)) return actual;
    final start = calendarDate(actual).add(Duration(minutes: startMinute));
    return crossesMidnight && actual.isBefore(start)
        ? start.subtract(const Duration(days: 1))
        : start;
  }

  DeadlineCutoffWindow copyWith({
    bool? enabled,
    int? startMinute,
    int? endMinute,
  }) => DeadlineCutoffWindow(
    enabled: enabled ?? this.enabled,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'startMinute': startMinute,
    'endMinute': endMinute,
  };

  factory DeadlineCutoffWindow.fromJson(Map<String, dynamic> json) {
    final start = jsonIntField(json, 'startMinute');
    final end = jsonIntField(json, 'endMinute');
    if (start < 0 || start >= 24 * 60 || end < 0 || end >= 24 * 60) {
      throw const FormatException('DDL 时间段必须在 00:00–23:59 内');
    }
    return DeadlineCutoffWindow(
      enabled: jsonBoolField(json, 'enabled'),
      startMinute: start,
      endMinute: end,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeadlineCutoffWindow &&
      enabled == other.enabled &&
      startMinute == other.startMinute &&
      endMinute == other.endMinute;

  @override
  int get hashCode => Object.hash(enabled, startMinute, endMinute);
}
