import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/seat_model.dart';
import '../data/services/events_service.dart';
import 'events_provider.dart';

// ─── ESTADO INMUTABLE ───────────────────────────────────────────────
class SeatSelectionState {
  final SeatMapModel? seatMap;
  final List<SeatModel> selectedSeats;
  final Duration? timeLeft;
  final bool isLoading;
  final String? errorMessage;

  const SeatSelectionState({
    this.seatMap,
    this.selectedSeats = const [],
    this.timeLeft,
    this.isLoading = false,
    this.errorMessage,
  });

  SeatSelectionState copyWith({
    SeatMapModel? seatMap,
    List<SeatModel>? selectedSeats,
    Duration? timeLeft,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SeatSelectionState(
      seatMap: seatMap ?? this.seatMap,
      selectedSeats: selectedSeats ?? this.selectedSeats,
      timeLeft: timeLeft,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// ─── NOTIFIER DE CONTROL Y RELOJ ────────────────────────────────────
class SeatSelectionNotifier extends Notifier<SeatSelectionState> {
  final String eventId;
  SeatSelectionNotifier(this.eventId);

  Timer? _timer;
  DateTime? _deadline;

  EventsService get _service => ref.read(eventsServiceProvider);

  @override
  SeatSelectionState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _service.releaseAllMyHolds().catchError((_) {});
    });

    Future.microtask(() => loadMap());

    return const SeatSelectionState(isLoading: true);
  }

  Future<void> loadMap() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final map = await _service.fetchSeatMap(eventId);
      final mine =
          map.seats.where((s) => s.status == SeatStatus.mine).toList();

      state = state.copyWith(
        seatMap: map,
        selectedSeats: mine,
        isLoading: false,
      );

      if (mine.isNotEmpty && map.holdSecondsLeft != null) {
        _startTimer(map.holdSecondsLeft!);
      } else {
        _stopTimer();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void _startTimer(int secondsLeft) {
    _timer?.cancel();
    _deadline = DateTime.now().add(Duration(seconds: secondsLeft));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_deadline == null) return;
      final diff = _deadline!.difference(DateTime.now());
      if (diff <= Duration.zero) {
        _timer?.cancel();
        _timer = null;
        state = state.copyWith(selectedSeats: [], timeLeft: null);
        loadMap();
      } else {
        state = state.copyWith(timeLeft: diff);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    state = state.copyWith(timeLeft: null);
  }

  Future<void> toggleSeat(SeatModel seat) async {
    final isSelected = state.selectedSeats.any((s) => s.id == seat.id);

    if (!isSelected && state.selectedSeats.length >= 10) {
      state = state.copyWith(errorMessage: 'Máximo 10 butacas por compra');
      return;
    }

    try {
      if (isSelected) {
        await _service.releaseSeat(seat.id);
        final updated =
            state.selectedSeats.where((s) => s.id != seat.id).toList();
        state = state.copyWith(selectedSeats: updated);
        if (updated.isEmpty) _stopTimer();
      } else {
        final secs = await _service.holdSeat(seat.id);
        final updated = [...state.selectedSeats, seat];
        state = state.copyWith(selectedSeats: updated);
        _startTimer(secs);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      loadMap();
    }
  }
}

// ─── PROVIDER FAMILY ────────────────────────────────────────────────
final seatSelectionProvider = NotifierProvider.autoDispose
    .family<SeatSelectionNotifier, SeatSelectionState, String>(
  SeatSelectionNotifier.new,
);