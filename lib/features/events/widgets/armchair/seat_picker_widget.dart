import 'dart:math' as math;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import '../../../../data/models/seat_model.dart';

class SeatPickerWidget extends StatefulWidget {
  final List<SeatModel> seats;
  final VenueLayout layout;
  final List<SeatModel> selectedSeats;
  final ValueChanged<SeatModel> onSeatToggle;
  final VoidCallback? onConfirmPurchase;
  final Duration? timeLeft;
  final String eventTitle;
  final String eventDate;
  final String eventTime;
  final String cityName;

  const SeatPickerWidget({
    super.key,
    required this.seats,
    this.layout = const VenueLayout(),
    required this.selectedSeats,
    required this.onSeatToggle,
    this.onConfirmPurchase,
    this.timeLeft,
    this.eventTitle = 'Evento',
    this.eventDate = 'Fecha del evento',
    this.eventTime = 'Horario',
    this.cityName = 'Cochabamba',
  });

  @override
  State<SeatPickerWidget> createState() => _SeatPickerWidgetState();
}

class _SeatPickerWidgetState extends State<SeatPickerWidget> {
  static const double _unit = 22.0;
  static const double _pad = 3.0;

  final TransformationController _ctrl = TransformationController();
  late _Geometry _geo;
  Size? _fittedViewport;

  @override
  void initState() {
    super.initState();
    _geo = _Geometry.of(widget.seats, widget.layout, _pad);
  }

  @override
  void didUpdateWidget(covariant SeatPickerWidget old) {
    super.didUpdateWidget(old);
    if (widget.seats.isNotEmpty && !identical(old.seats, widget.seats)) {
      _geo = _Geometry.of(widget.seats, widget.layout, _pad);
    }
    if (old.seats.length != widget.seats.length) {
      _fittedViewport = null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _scheduleFit(Size viewport, Size content) {
    if (_fittedViewport == viewport) return;
    _fittedViewport = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = math
          .min(viewport.width / content.width, viewport.height / content.height)
          .clamp(0.2, 1.8)
          .toDouble();
      final dx = (viewport.width - content.width * s) / 2;
      final dy = (viewport.height - content.height * s) / 2;
      _ctrl.value = Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(dx, dy, 0);
    });
  }

  void _onTap(Offset local) {
    final p = _geo.toUnits(local, _unit);
    SeatModel? best;
    double bestD = 0.6 * 0.6;
    for (final s in widget.seats) {
      if (!s.isSelectable) continue;
      final dx = s.x - p.dx;
      final dy = s.y - p.dy;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    if (best != null) widget.onSeatToggle(best);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay butacas configuradas para este evento',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final selectedIds = widget.selectedSeats.map((s) => s.id).toSet();
    final total = widget.selectedSeats.fold<double>(0, (a, s) => a + s.price);
    final content = Size(
      math.max(300.0, _geo.w * _unit),
      math.max(200.0, _geo.h * _unit),
    );
    final left = widget.timeLeft;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF030A1A), Color(0xFF071938), Color(0xFF020712)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 80),
              const Expanded(
                child: Text(
                  'Elige tu butaca',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: left == null
                    ? null
                    : Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: left.inSeconds <= 60
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _fmt(left),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              _scheduleFit(Size(c.maxWidth, c.maxHeight), content);
              return InteractiveViewer(
                transformationController: _ctrl,
                constrained: false,
                minScale: 0.2,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(200),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onTap(d.localPosition),
                  child: CustomPaint(
                    size: content,
                    painter: _SeatMapPainter(
                      seats: widget.seats,
                      selectedIds: selectedIds,
                      layout: widget.layout,
                      geo: _geo,
                      unit: _unit,
                    ),
                  ),
                ),
              );
            }),
          ),
          _legend(),
          _summary(total),
        ],
      ),
    );
  }

  Widget _legend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [
          _legendItem(Colors.white, 'Disponible'),
          _legendItem(const Color(0xFF22C55E), 'Tu selección'),
          _legendItem(const Color(0xFFEF4444), 'Ocupado'),
          _legendItem(const Color(0xFFF59E0B), 'Reservado'),
          for (final e in widget.layout.sectionColors.entries)
            _legendItem(e.value, e.key),
        ],
      ),
    );
  }

  Widget _summary(double total) {
    final names = widget.selectedSeats.map((s) => s.displayName).join(', ');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1B38).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              'Resumen de compra',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _infoRow('Ciudad:', widget.cityName),
          _infoRow('Evento:', widget.eventTitle),
          _infoRow('Fecha:', widget.eventDate),
          _infoRow('Horario:', widget.eventTime),
          _infoRow('Butacas:', names.isEmpty ? '-' : names),
          _infoRow('Cantidad de entradas:', '${widget.selectedSeats.length}'),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Total Bs. ${total.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: widget.selectedSeats.isEmpty ? null : widget.onConfirmPurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Comprar entradas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Geometry {
  final double minX, minY, w, h;
  const _Geometry(this.minX, this.minY, this.w, this.h);

  factory _Geometry.of(List<SeatModel> seats, VenueLayout layout, double pad) {
    double x0 = double.infinity, y0 = double.infinity;
    double x1 = -double.infinity, y1 = -double.infinity;
    void add(double x, double y) {
      x0 = math.min(x0, x);
      y0 = math.min(y0, y);
      x1 = math.max(x1, x);
      y1 = math.max(y1, y);
    }

    for (final s in seats) {
      add(s.x - 0.5, s.y - 0.5);
      add(s.x + 0.5, s.y + 0.5);
    }
    final st = layout.stage;
    if (st != null) {
      add(st.left, st.top);
      add(st.right, st.bottom);
    }
    for (final l in layout.labels) {
      add(l.x, l.y);
    }
    if (x0.isInfinite) return const _Geometry(0, 0, 10, 10);
    return _Geometry(x0 - pad, y0 - pad, (x1 - x0) + pad * 2, (y1 - y0) + pad * 2);
  }

  Offset toPx(double x, double y, double unit) =>
      Offset((x - minX) * unit, (y - minY) * unit);

  Offset toUnits(Offset px, double unit) =>
      Offset(px.dx / unit + minX, px.dy / unit + minY);
}

class _SeatMapPainter extends CustomPainter {
  final List<SeatModel> seats;
  final Set<String> selectedIds;
  final VenueLayout layout;
  final _Geometry geo;
  final double unit;

  _SeatMapPainter({
    required this.seats,
    required this.selectedIds,
    required this.layout,
    required this.geo,
    required this.unit,
  });

  Color _color(SeatModel s) {
    if (s.status == SeatStatus.sold) return const Color(0xFFEF4444);
    if (s.status == SeatStatus.held) return const Color(0xFFF59E0B);
    if (selectedIds.contains(s.id)) return const Color(0xFF22C55E);
    return layout.sectionColors[s.section] ?? Colors.white;
  }

  void _text(Canvas canvas, String t, Offset center, double size, Color color,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final st = layout.stage;
    if (st != null) {
      final r = RRect.fromRectAndRadius(
        Rect.fromPoints(
          geo.toPx(st.left, st.top, unit),
          geo.toPx(st.right, st.bottom, unit),
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(r, Paint()..color = Colors.white.withValues(alpha: 0.10));
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white54,
      );
      _text(canvas, layout.stageLabel, r.center, 13, Colors.white70, bold: true);
    }

    for (final l in layout.labels) {
      _text(canvas, l.text, geo.toPx(l.x, l.y, unit), 12, Colors.white54, bold: true);
    }

    final ends = <String, List<SeatModel>>{};
    for (final s in seats) {
      if (s.status == SeatStatus.blocked) continue;
      final e = ends.putIfAbsent('${s.section}|${s.row}', () => [s, s]);
      if (s.x < e[0].x) e[0] = s;
      if (s.x > e[1].x) e[1] = s;
    }
    for (final e in ends.values) {
      _text(canvas, e[0].row, geo.toPx(e[0].x - 1.1, e[0].y, unit), 10, Colors.white60);
      if (!identical(e[0], e[1])) {
        _text(canvas, e[1].row, geo.toPx(e[1].x + 1.1, e[1].y, unit), 10, Colors.white60);
      }
    }

    final paint = Paint();
    final half = unit * 0.4;
    for (final s in seats) {
      if (s.status == SeatStatus.blocked) continue;
      final c = geo.toPx(s.x, s.y, unit);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
        const Radius.circular(3),
      );
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(s.rotation * math.pi / 180);
      if (selectedIds.contains(s.id)) {
        canvas.drawRRect(
          rect.inflate(2),
          Paint()..color = const Color(0xFF22C55E).withValues(alpha: 0.35),
        );
      }
      paint.color = _color(s);
      canvas.drawRRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SeatMapPainter old) =>
      !identical(old.seats, seats) ||
      !identical(old.layout, layout) ||
      !setEquals(old.selectedIds, selectedIds);
}