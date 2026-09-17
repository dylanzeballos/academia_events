import '../../../../data/models/event_model.dart';

class WeekTimelineSlot {
  const WeekTimelineSlot({
    required this.event,
    required this.column,
    required this.totalColumns,
    required this.clusterStart,
    required this.clusterEnd,
    required this.clusterIndex,
  });

  final EventModel event;
  final int column;
  final int totalColumns;
  final DateTime clusterStart;
  final DateTime clusterEnd;
  final int clusterIndex;
}

class WeekTimelineLayout {
  static List<WeekTimelineSlot> layout(List<EventModel> events) {
    final sorted = [...events]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final slots = <WeekTimelineSlot>[];
    if (sorted.isEmpty) return slots;

    var cluster = <EventModel>[];
    var clusterEnd = sorted.first.endTime;

    void flushCluster() {
      if (cluster.isEmpty) return;
      final columnEnds = <DateTime>[];
      final columns = <String, int>{};
      final clusterStart = cluster.first.startTime;
      var clusterEndFinal = cluster.first.endTime;
      for (final e in cluster) {
        if (e.endTime.isAfter(clusterEndFinal)) clusterEndFinal = e.endTime;
      }

      for (final e in cluster) {
        var col = 0;
        while (col < columnEnds.length &&
            columnEnds[col].isAfter(e.startTime)) {
          col++;
        }
        if (col == columnEnds.length) {
          columnEnds.add(e.endTime);
        } else {
          columnEnds[col] = e.endTime;
        }
        columns[e.id] = col;
      }

      for (var i = 0; i < cluster.length; i++) {
        final e = cluster[i];
        slots.add(
          WeekTimelineSlot(
            event: e,
            column: columns[e.id]!,
            totalColumns: columnEnds.length,
            clusterStart: clusterStart,
            clusterEnd: clusterEndFinal,
            clusterIndex: i,
          ),
        );
      }
      cluster = [];
    }

    for (final e in sorted) {
      if (cluster.isNotEmpty && !e.startTime.isBefore(clusterEnd)) {
        flushCluster();
      }
      if (e.endTime.isAfter(clusterEnd)) clusterEnd = e.endTime;
      cluster.add(e);
    }
    flushCluster();

    return slots;
  }
}