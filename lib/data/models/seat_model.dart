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

  /// Se puede tocar: libre o ya bloqueada por mí
  bool get isSelectable =>
      status == SeatStatus.available || status == SeatStatus.mine;

  String get displayName => '$section $row-$label';

  factory SeatModel.fromJson(Map<String, dynamic> j) => SeatModel(
        id: j['id'] as String,
        row: j['row'] as String,
        number: (j['number'] as num).toInt(),
        label: (j['label'] as String?) ?? '${j['number']}',
        section: (j['section'] as String?) ?? 'General',
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        status: SeatStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => SeatStatus.blocked,
        ),
      );
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
    String stageLabel = 'ESCENARIO';
    final st = j['stage'];
    if (st is Map) {
      stage = Rect.fromLTWH(
        (st['x'] as num).toDouble(),
        (st['y'] as num).toDouble(),
        (st['w'] as num).toDouble(),
        (st['h'] as num).toDouble(),
      );
      stageLabel = (st['label'] as String?) ?? stageLabel;
    }

    final labels = <LayoutLabel>[
      for (final l in (j['labels'] as List? ?? const []))
        LayoutLabel(
          l['text'] as String,
          (l['x'] as num).toDouble(),
          (l['y'] as num).toDouble(),
        ),
    ];

    final colors = <String, Color>{};
    (j['section_colors'] as Map? ?? const {}).forEach((k, v) {
      colors[k as String] =
          Color(int.parse((v as String).replaceFirst('#', 'FF'), radix: 16));
    });

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
            SeatModel.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}