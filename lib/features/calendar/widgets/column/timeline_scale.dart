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

    final base = <double>[];
    final floor = <double>[];
    for (var h = startHour; h < endHour; h++) {
      final active = activeHours.contains(h);
      final desired = active ? activePxPerHour : _inactiveBasePx;
      final f = active ? _activeFloorPx : _inactiveFloorPx;
      base.add(math.max(desired, f));
      floor.add(f);
    }

    final totalFloor = floor.fold(0.0, (sum, f) => sum + f);
    final peak = base.fold(0.0, (sum, b) => sum + b);
    final extraWeight = peak - totalFloor;

    double pxFor(int i) {
      if (availableHeight >= totalFloor) {
        if (extraWeight <= 0) return base[i];
        final leftover = availableHeight - totalFloor;
        return floor[i] + leftover * (base[i] - floor[i]) / extraWeight;
      }
      return floor[i] * availableHeight / totalFloor;
    }

    _perHour = List<double>.generate(
      n,
      (i) => pxFor(i) * zoom,
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

  static const double _inactiveBasePx = 13;
  static const double _activeFloorPx = 24;
  static const double _inactiveFloorPx = 9;

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