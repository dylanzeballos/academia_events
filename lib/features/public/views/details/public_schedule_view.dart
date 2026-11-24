// lib/features/public/views/details/public_schedule_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/theme_extensions.dart';
import '../../../../shared/widgets/schedule/weekly_schedule_grid.dart';

/// Horario semanal público de una academia.
///
/// La grilla vive en [WeeklyScheduleGrid] y se comparte con "Explorar clases".
class PublicScheduleView extends ConsumerStatefulWidget {
  const PublicScheduleView({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  final String organizationId;
  final String organizationName;

  @override
  ConsumerState<PublicScheduleView> createState() => _PublicScheduleViewState();
}

class _PublicScheduleViewState extends ConsumerState<PublicScheduleView> {
  bool _isLandscape = false;

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      SystemChrome.setPreferredOrientations(
        _isLandscape
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : [DeviceOrientation.portraitUp],
      );
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horario semanal',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: context.textOnBg,
              ),
            ),
            Text(
              widget.organizationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: context.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isLandscape ? 'Volver a vertical' : 'Ver en horizontal',
            icon: Icon(
              _isLandscape
                  ? Icons.screen_lock_portrait
                  : Icons.screen_rotation_outlined,
              color: context.textMuted,
            ),
            onPressed: _toggleOrientation,
          ),
          IconButton(
            tooltip: 'Actualizar horario',
            icon: Icon(Icons.refresh_rounded, color: context.textMuted),
            onPressed: () => ref.invalidate(
              orgScheduleEntriesProvider(widget.organizationId),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: WeeklyScheduleGrid(organizationId: widget.organizationId),
      ),
    );
  }
}
