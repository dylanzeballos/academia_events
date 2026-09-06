import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/check_in_result_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/dance_class_session_model.dart';
import '../../../data/models/event_model.dart';
import '../../../data/services/checkin_service.dart';
import '../../../providers/checkin_provider.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/events_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/checkin_result_card.dart';
import '../widgets/scanner_page.dart';

enum _CheckinMode { event, class_ }

/// Pantalla para el staff: selecciona el evento (o clase + sesión) y escanea
/// el QR del asistente. El servidor valida todo y devuelve el resultado.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  _CheckinMode _mode = _CheckinMode.event;
  String? _eventId;
  String? _classId;
  String? _sessionId;

  bool _busy = false;
  CheckInResultModel? _result;

  @override
  void initState() {
    super.initState();
    _listenForDefaults();
  }

  void _listenForDefaults() {
    // Seleccionar automáticamente el primer evento disponible.
    ref.listenManual(orgEventsProvider, (prev, next) {
      next.maybeWhen(
        data: (events) {
          if (_eventId == null && events.isNotEmpty) {
            _eventId = events.first.id;
          } else if (_eventId != null && !events.any((e) => e.id == _eventId)) {
            _eventId = null;
          }
        },
        orElse: () {},
      );
    });
    // Seleccionar automáticamente la primera clase/sesión disponible.
    ref.listenManual(orgClassesProvider, (prev, next) {
      next.maybeWhen(
        data: (classes) {
          if (_classId == null && classes.isNotEmpty) {
            _classId = classes.first.id;
            _sessionId = null;
          } else if (_classId != null &&
              !classes.any((c) => c.id == _classId)) {
            _classId = null;
            _sessionId = null;
          }
        },
        orElse: () {},
      );
    });
  }

  void _selectMode(_CheckinMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _result = null;
      _eventId = null;
      _classId = null;
      _sessionId = null;
    });
  }

  void _resetResult() => setState(() => _result = null);

  Future<void> _openScanner() async {
    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (token == null || token.trim().isEmpty || !mounted) return;
    await _processToken(token.trim());
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final controller = MobileScannerController();
      try {
        final capture = await controller.analyzeImage(picked.path);
        final token = capture?.raw is String
            ? capture!.raw as String
            : (capture?.barcodes.isNotEmpty ?? false)
                ? capture!.barcodes.first.rawValue
                : null;

        if (token == null || token.trim().isEmpty) {
          _showSnack('No se encontró un código QR válido en la imagen.');
          return;
        }
        await _processToken(token.trim());
      } finally {
        controller.dispose();
      }
    } catch (e) {
      if (mounted) _showSnack('No se pudo leer la imagen: $e');
    }
  }

  Future<void> _processToken(String token) async {
    if (_busy) return;

    final eventId = _eventId;
    final sessionId = _sessionId;

    if (_mode == _CheckinMode.event && eventId == null) {
      _showSnack('Selecciona un evento.');
      return;
    }
    if (_mode == _CheckinMode.class_ && sessionId == null) {
      _showSnack('Selecciona la sesión a escanear.');
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
    });

    try {
      final repo = ref.read(checkInRepositoryProvider);
      final result = _mode == _CheckinMode.event
          ? await repo.registerEventCheckIn(tokenHash: token, eventId: eventId!)
          : await repo.registerClassCheckIn(tokenHash: token, sessionId: sessionId!);
      if (!mounted) return;
      setState(() => _result = result);
    } on CheckInException catch (e) {
      if (!mounted) return;
      setState(() =>
          _result = CheckInResultModel(success: false, reason: e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _result = CheckInResultModel(success: false, reason: e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in')),
      body: Column(
        children: [
          if (_busy)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox.shrink(),
          Expanded(
            child: _result != null
                ? _buildResultView()
                : _buildSetupView(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CheckInResultCard(result: _result!, onContinue: _resetResult),
      ],
    );
  }

  Widget _buildSetupView() {
    final eventsAsync = ref.watch(orgEventsProvider);
    final classesAsync = ref.watch(orgClassesProvider);
    final sessionsAsync = _mode == _CheckinMode.class_ && _classId != null
        ? ref.watch(checkinClassSessionsProvider(_classId!))
        : null;

    final canScan = _busy ||
        (_mode == _CheckinMode.event
            ? _eventId == null
            : _sessionId == null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Selecciona dónde vas a registrar la entrada:',
          style: TextStyle(color: context.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_CheckinMode>(
          segments: const [
            ButtonSegment(
              value: _CheckinMode.event,
              icon: Icon(Icons.event_outlined),
              label: Text('Evento'),
            ),
            ButtonSegment(
              value: _CheckinMode.class_,
              icon: Icon(Icons.school_outlined),
              label: Text('Clase'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) => _selectMode(selection.first),
        ),
        const SizedBox(height: 20),

        if (_mode == _CheckinMode.event) ...[
          eventsAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => Text('Error cargando eventos: $e'),
            data: (events) => _EventDropdown(
              events: events,
              value: _eventId,
              onChanged: (id) {
                setState(() {
                  _eventId = id;
                  _result = null;
                });
              },
            ),
          ),
        ] else ...[
          classesAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => Text('Error cargando clases: $e'),
            data: (classes) => _ClassDropdown(
              classes: classes,
              value: _classId,
              onChanged: (id) {
                setState(() {
                  _classId = id;
                  _sessionId = null;
                  _result = null;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          if (sessionsAsync == null)
            const SizedBox.shrink()
          else
            sessionsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => Text('Error cargando sesiones: $e'),
              data: (sessions) => _SessionDropdown(
                sessions: sessions,
                value: _sessionId,
                onChanged: (id) {
                  setState(() {
                    _sessionId = id;
                    _result = null;
                  });
                },
              ),
            ),
        ],

        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: canScan ? null : _openScanner,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear con cámara'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: canScan ? null : _pickFromGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Importar de galería'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'El sistema valida automáticamente el QR, el pago y tu autorización.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventDropdown extends StatelessWidget {
  const _EventDropdown({
    required this.events,
    required this.value,
    required this.onChanged,
  });

  final List<EventModel> events;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptySelection(
        icon: Icons.event_busy,
        message: 'Esta organización no tiene eventos.',
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Evento',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final event in events)
          DropdownMenuItem(
            value: event.id,
            child: Text(event.title, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ClassDropdown extends StatelessWidget {
  const _ClassDropdown({
    required this.classes,
    required this.value,
    required this.onChanged,
  });

  final List<ClassModel> classes;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const _EmptySelection(
        icon: Icons.school_outlined,
        message: 'Esta organización no tiene clases.',
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Clase',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final c in classes)
          DropdownMenuItem(
            value: c.id,
            child: Text(c.title, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _SessionDropdown extends StatelessWidget {
  const _SessionDropdown({
    required this.sessions,
    required this.value,
    required this.onChanged,
  });

  final List<DanceClassSessionModel> sessions;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _EmptySelection(
        icon: Icons.event_note,
        message: 'Esta clase no tiene sesiones programadas.',
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Sesión',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final s in sessions)
          DropdownMenuItem(
            value: s.id,
            child: Text(
              '${_formatDate(s.sessionDate)} · ${_formatTime(s.startAt)} - ${_formatTime(s.endAt)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  static String _formatTime(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[500]),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}