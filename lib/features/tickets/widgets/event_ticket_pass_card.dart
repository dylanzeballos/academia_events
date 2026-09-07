import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';

class EventTicketPassCard extends StatelessWidget {
  const EventTicketPassCard({
    super.key,
    required this.eventTitle,
    required this.ticketTypeName,
    required this.ticketNumber,
    required this.qrToken,
    required this.eventStartAt,
    required this.purchaseDate,
    this.attendeeName, // <-- Nuevo parámetro
  });

  final String eventTitle;
  final String ticketTypeName;
  final String ticketNumber;
  final String qrToken;
  final DateTime? eventStartAt;
  final DateTime purchaseDate;
  final String? attendeeName; // <-- Almacena el titular

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Por confirmar';
    return DateFormat("EEE d 'de' MMM, y · HH:mm", 'es').format(dt);
  }

  String _formatPurchase(DateTime dt) {
    return DateFormat("d MMM y, HH:mm", 'es').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabecera compacta
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ticketTypeName.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.confirmation_number_outlined, color: Colors.grey, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  eventTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatDateTime(eventStartAt),
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Muestra el nombre del asistente si existe
                if (attendeeName != null && attendeeName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          attendeeName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Troquelado central
          Row(
            children: [
              const SizedBox(
                height: 16,
                width: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Flex(
                      direction: Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        (constraints.constrainWidth() / 8).floor(),
                        (_) => const SizedBox(
                          width: 4,
                          height: 1,
                          child: DecoratedBox(decoration: BoxDecoration(color: Colors.white24)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(
                height: 16,
                width: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Contenedor del QR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    key: ValueKey(qrToken),
                    data: qrToken.isNotEmpty ? qrToken : ticketNumber,
                    size: 145,
                    version: QrVersions.auto,
                    gapless: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ticketNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comprado el ${_formatPurchase(purchaseDate)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}