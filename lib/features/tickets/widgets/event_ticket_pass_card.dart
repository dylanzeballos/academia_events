// lib/features/tickets/widgets/event_ticket_pass_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';

class EventTicketPassCard extends StatelessWidget {
  const EventTicketPassCard({
    super.key,
    required this.eventTitle,
    required this.ticketTypeName,
    required this.ticketNumber,
    required this.qrToken,
    required this.eventStartAt,
    required this.purchaseDate,
    this.attendeeName,
  });

  final String eventTitle;
  final String ticketTypeName;
  final String ticketNumber;
  final String qrToken;
  final DateTime? eventStartAt;
  final DateTime purchaseDate;
  final String? attendeeName;

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
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(color: context.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
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
                    Icon(Icons.confirmation_number_outlined, color: context.textMuted, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  eventTitle,
                  style: TextStyle(
                    color: context.textOnBg,
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
                        style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (attendeeName != null && attendeeName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          attendeeName!,
                          style: TextStyle(
                            color: context.textOnBg,
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

          Row(
            children: [
              SizedBox(
                height: 16,
                width: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.scaffoldBg,
                    borderRadius: const BorderRadius.only(
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
                        (_) => SizedBox(
                          width: 4,
                          height: 1,
                          child: DecoratedBox(decoration: BoxDecoration(color: context.divider)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                height: 16,
                width: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.scaffoldBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    border: Border.all(color: context.divider),
                  ),
                  child: QrImageView(
                    key: ValueKey(qrToken),
                    data: qrToken.isNotEmpty ? qrToken : ticketNumber,
                    size: 145,
                    version: QrVersions.auto,
                    gapless: true,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ticketNumber,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comprado el ${_formatPurchase(purchaseDate)}',
                  style: TextStyle(color: context.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}