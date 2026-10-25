import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/event_model.dart';
import '../../../data/models/seat_model.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/seat_selection_provider.dart';
import '../../events/widgets/armchair/seat_picker_widget.dart';
import 'purchase_tickets_screen.dart';

class SeatSelectionTicketScreen extends ConsumerWidget {
  final String eventId;
  final EventModel? event;

  const SeatSelectionTicketScreen({
    super.key,
    required this.eventId,
    this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = event != null
        ? AsyncValue.data(event!)
        : ref.watch(eventDetailProvider(eventId));

    final seatState = ref.watch(seatSelectionProvider(eventId));
    final notifier = ref.read(seatSelectionProvider(eventId).notifier);

    ref.listen(seatSelectionProvider(eventId).select((s) => s.errorMessage), (
      prev,
      next,
    ) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), backgroundColor: Colors.redAccent),
        );
      }
    });

    return eventAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF030A1A),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFF030A1A),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text(
            'Error al cargar el evento: $e',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
      data: (eventData) {
        final dateFormatted =
            DateFormat('dd/MM/yyyy').format(eventData.startTime);
        final timeFormatted = DateFormat('HH:mm').format(eventData.startTime);

        final resolvedCity = eventData.location?.addressLine1 ??
            eventData.location?.postalCode ??
            'Por confirmar';

        if (seatState.isLoading && seatState.seatMap == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF030A1A),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final seatMap = seatState.seatMap;
        if (seatMap == null || seatMap.seats.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF030A1A),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const BackButton(color: Colors.white),
            ),
            body: const Center(
              child: Text(
                'No hay butacas disponibles para este evento',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF030A1A),
          body: SafeArea(
            child: SeatPickerWidget(
              seats: seatMap.seats,
              layout: seatMap.layout,
              selectedSeats: seatState.selectedSeats,
              timeLeft: seatState.timeLeft,
              onSeatToggle: (seat) => notifier.toggleSeat(seat),
              eventTitle: eventData.title,
              eventDate: dateFormatted,
              eventTime: '$timeFormatted hrs',
              cityName: resolvedCity,
              onConfirmPurchase: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PurchaseTicketsScreen(
                      eventId: eventId,
                      preselectedSeats: seatState.selectedSeats,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}