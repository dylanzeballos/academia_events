// lib/data/models/seat_model.dart
import 'dart:ui' show Color, Rect;

enum SeatStatus { available, mine, held, sold, blocked }

class SeatModel {
  final String id;
  final String row;
  final String label;
  final String section;
  final int number;
  final double x;
  final double y;
  final double rotation; // grados
  final double price;
  final SeatStatus status;

  const SeatModel({
    required this.id,
    required this.row,
    required this.label,
    required this.section,
    required this.number,
    required this.x,
    required this.y,
    required this.rotation,
    required this.price,
    required this.status,
  });

  /// Se puede tocar: libre o ya reservada temporalmente por mí
  bool get isSelectable =>
      status == SeatStatus.available || status == SeatStatus.mine;

  String get displayName => '$section $row-$label';

  factory SeatModel.fromJson(Map<String, dynamic> j) {
    // Acepta tanto seat_row / seat_number (PostgreSQL) como row / number
    final rowStr = (j['seat_row'] ?? j['row'] ?? '').toString();
    final seatNum = (j['seat_number'] as num?)?.toInt() ??
        (j['number'] as num?)?.toInt() ??
        0;

    final seatLabel = (j['seat_label'] ?? j['label'])?.toString();

    return SeatModel(
      id: (j['id'] ?? '').toString(),
      row: rowStr,
      number: seatNum,
      label: (seatLabel != null && seatLabel.isNotEmpty) ? seatLabel : '$seatNum',
      section: (j['section'] ?? 'General').toString(),
      x: (j['x'] as num?)?.toDouble() ?? 0.0,
      y: (j['y'] as num?)?.toDouble() ?? 0.0,
      rotation: (j['rotation'] as num?)?.toDouble() ?? 0.0,
      price: (j['price'] as num?)?.toDouble() ?? 50.0,
      status: SeatStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => SeatStatus.available,
      ),
    );
  }
}

class LayoutLabel {
  final String text;
  final double x;
  final double y;
  const LayoutLabel(this.text, this.x, this.y);
}

class VenueLayout {
  final Rect? stage;
  final String stageLabel;
  final List<LayoutLabel> labels;
  final Map<String, Color> sectionColors;

  const VenueLayout({
    this.stage,
    this.stageLabel = 'ESCENARIO',
    this.labels = const [],
    this.sectionColors = const {},
  });

  factory VenueLayout.fromJson(Map<String, dynamic>? j) {
    if (j == null || j.isEmpty) return const VenueLayout();

    Rect? stage;
    String stageLabel = (j['stageLabel'] ?? j['stage_label'] ?? 'ESCENARIO').toString();
    final st = j['stage'];

    if (st is Map) {
      // 1. Si viene con formato left, top, right, bottom (usado en PostgreSQL)
      if (st.containsKey('left') && st.containsKey('top')) {
        final l = (st['left'] as num?)?.toDouble() ?? 0.0;
        final t = (st['top'] as num?)?.toDouble() ?? 0.0;
        final r = (st['right'] as num?)?.toDouble() ?? (l + 10.0);
        final b = (st['bottom'] as num?)?.toDouble() ?? (t + 2.0);
        stage = Rect.fromLTRB(l, t, r, b);
      }
      // 2. Si viene con formato x, y, w, h
      else if (st.containsKey('x') && st.containsKey('y')) {
        final x = (st['x'] as num?)?.toDouble() ?? 0.0;
        final y = (st['y'] as num?)?.toDouble() ?? 0.0;
        final w = (st['w'] as num?)?.toDouble() ?? 10.0;
        final h = (st['h'] as num?)?.toDouble() ?? 2.0;
        stage = Rect.fromLTWH(x, y, w, h);
      }

      if (st['label'] != null) {
        stageLabel = st['label'].toString();
      }
    }

    final labels = <LayoutLabel>[
      for (final l in (j['labels'] as List? ?? const []))
        if (l is Map)
          LayoutLabel(
            (l['text'] ?? '').toString(),
            (l['x'] as num?)?.toDouble() ?? 0.0,
            (l['y'] as num?)?.toDouble() ?? 0.0,
          ),
    ];

    final colors = <String, Color>{};
    final rawColors = j['sectionColors'] ?? j['section_colors'];

    if (rawColors is Map) {
      rawColors.forEach((k, v) {
        if (v is String && v.isNotEmpty) {
          try {
            final hex = v.replaceFirst('#', '').padLeft(8, 'F');
            colors[k.toString()] = Color(int.parse(hex, radix: 16));
          } catch (_) {}
        }
      });
    }

    return VenueLayout(
      stage: stage,
      stageLabel: stageLabel,
      labels: labels,
      sectionColors: colors,
    );
  }
}

class SeatMapModel {
  final VenueLayout layout;
  final List<SeatModel> seats;

  /// Segundos que le quedan al usuario para comprar (null si no tiene butacas bloqueadas)
  final int? holdSecondsLeft;

  const SeatMapModel({
    required this.layout,
    required this.seats,
    this.holdSecondsLeft,
  });

  factory SeatMapModel.fromJson(Map<String, dynamic> j) => SeatMapModel(
        layout: VenueLayout.fromJson(
          j['layout'] == null
              ? null
              : Map<String, dynamic>.from(j['layout'] as Map),
        ),
        holdSecondsLeft: (j['hold_seconds_left'] as num?)?.toInt(),
        seats: [
          for (final s in (j['seats'] as List? ?? const []))
            if (s is Map)
              SeatModel.fromJson(Map<String, dynamic>.from(s)),
        ],
      );
}