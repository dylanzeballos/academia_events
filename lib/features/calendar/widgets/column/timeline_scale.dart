import 'dart:math' as math;

class TimelineScale {
  TimelineScale({
    required this.startHour,
    required this.endHour,
    required Set<int> activeHours,
    Set<int> compressedHours = const {},
    required double activePxPerHour,
    this.availableHeight = double.infinity,
    this.zoom = 1,
    this.collapseInactiveHours = false,
    this.centerContentIfShort = false,
  }) {
    _activeHours = Set<int>.unmodifiable(activeHours);
    _compressedHours = Set<int>.unmodifiable(compressedHours);
    final n = endHour - startHour;
    if (n <= 0) {
      _verticalOffset = 0;
      _perHour = const [];
      _top = const [0];
      return;
    }

    // Altura estándar fija y proporcional para que no se deformen los cards
    final base = <double>[];
    for (var h = startHour; h < endHour; h++) {
      final active = _activeHours.contains(h);
      base.add(
        active
            ? _compressedHours.contains(h)
                  ? _compressedActivePx
                  : math.max(activePxPerHour, _activeFloorPx)
            : collapseInactiveHours
            ? _collapsedGapPx
            : _inactiveBasePx,
      );
    }

    _perHour = List<double>.generate(n, (i) => base[i] * zoom, growable: false);

    _top = List<double>.generate(n + 1, (i) {
      var y = 0.0;
      for (var j = 0; j < i; j++) {
        y += _perHour[j];
      }
      return y;
    });
    _verticalOffset = centerContentIfShort && availableHeight.isFinite
        ? math.max(0, (availableHeight - _top.last) / 2)
        : 0;
  }

  final int startHour;
  final int endHour;
  final double availableHeight;
  final double zoom;
  final bool collapseInactiveHours;
  final bool centerContentIfShort;

  static const double _inactiveBasePx = 28;
  static const double _activeFloorPx = 45;
  static const double _collapsedGapPx = 2;
  // Agrupa visualmente horas consecutivas de eventos largos. Una jornada de
  // 21 h ocupa ~210 px en vez de más de una pantalla.
  static const double _compressedActivePx = 10;

  late final Set<int> _activeHours;
  late final Set<int> _compressedHours;
  late final List<double> _perHour;
  late final List<double> _top;
  late final double _verticalOffset;

  int get totalHours => endHour - startHour;
  double get totalHeight => _top.isEmpty ? 0 : _top.last + 2 * _verticalOffset;
  bool isActiveHour(int hour) => _activeHours.contains(hour);
  bool isCompressedHour(int hour) => _compressedHours.contains(hour);

  bool shouldDrawHourBoundary(int hour) {
    if (!collapseInactiveHours || hour <= startHour || hour >= endHour) {
      return true;
    }
    if (isCompressedHour(hour) || isCompressedHour(hour - 1)) {
      return false;
    }
    return isActiveHour(hour - 1) || isActiveHour(hour);
  }

  double topAt(int hour) => _top[hour - startHour] + _verticalOffset;

  double pxPerHourAt(int hour) => _perHour[hour - startHour];

  double yForHourFraction(double hour) {
    final local = hour - startHour;
    if (local <= 0) return _verticalOffset;
    if (local >= totalHours) return _top.last + _verticalOffset;
    final idx = local.floor();
    final frac = local - idx;
    return _top[idx] + _perHour[idx] * frac + _verticalOffset;
  }

  double yForMinutes(int minutes) => yForHourFraction(minutes / 60);
}
