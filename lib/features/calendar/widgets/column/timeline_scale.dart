import 'dart:math' as math;

class TimelineScale {
  TimelineScale({
    required this.startHour,
    required this.endHour,
    required Set<int> activeHours,
    required double availableHeight,
    required double activePxPerHour,
    this.zoom = 1,
  }) {
    final n = endHour - startHour;
    if (n <= 0) {
      _perHour = const [];
      _top = const [0];
      return;
    }

    // Altura estándar fija y proporcional para que no se deformen los cards
    final base = <double>[];
    for (var h = startHour; h < endHour; h++) {
      final active = activeHours.contains(h);
      final desired = active ? activePxPerHour : _inactiveBasePx;
      base.add(math.max(desired, active ? _activeFloorPx : _inactiveFloorPx));
    }

    _perHour = List<double>.generate(
      n,
      (i) => base[i] * zoom,
      growable: false,
    );

    _top = List<double>.generate(n + 1, (i) {
      var y = 0.0;
      for (var j = 0; j < i; j++) {
        y += _perHour[j];
      }
      return y;
    });
  }

  final int startHour;
  final int endHour;
  final double zoom;

  static const double _inactiveBasePx = 28;
  static const double _activeFloorPx = 45;
  static const double _inactiveFloorPx = 20;

  late final List<double> _perHour;
  late final List<double> _top;

  int get totalHours => endHour - startHour;
  double get totalHeight => _top.isEmpty ? 0 : _top.last;

  double topAt(int hour) => _top[hour - startHour];

  double pxPerHourAt(int hour) => _perHour[hour - startHour];

  double yForHourFraction(double hour) {
    final local = hour - startHour;
    if (local <= 0) return 0;
    if (local >= totalHours) return totalHeight;
    final idx = local.floor();
    final frac = local - idx;
    return _top[idx] + _perHour[idx] * frac;
  }

  double yForMinutes(int minutes) => yForHourFraction(minutes / 60);
}