import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_model.dart';

class OrganizationShareSection extends StatelessWidget {
  const OrganizationShareSection({
    super.key,
    required this.organization,
    this.compact = false,
  });

  final OrganizationModel organization;
  final bool compact;

  String get _publicUrl {
    final publicPath =
        '${AppRoutes.organizationPublicDetailBase}/${organization.id}';
    final baseUri = Uri.base;
    if (baseUri.scheme == 'http' || baseUri.scheme == 'https') {
      return baseUri.replace(path: publicPath, query: '').toString();
    }
    return 'academiaevents://$publicPath';
  }

  String get _qrValue =>
      '$_publicUrl?qr=${organization.qrCodeHash ?? organization.id}';

  String get _shareText =>
      'Conoce ${organization.name} en Academia Events:\n$_publicUrl';

  Future<void> _share(BuildContext context) async {
    await SharePlus.instance.share(ShareParams(text: _shareText));
  }

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    final uri = Uri.https('wa.me', '/', {'text': _shareText});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      await _share(context);
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _publicUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace copiado')),
      );
    }
  }

  Future<void> _showQrDialog(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'QR de la academia',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close, color: Color(0xFF111827)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: QrImageView(
                    data: _qrValue,
                    size: 250,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _publicUrl,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _copyLink(sheetContext),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar enlace'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF29344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: Color(0xFF38BDF8), size: 17),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ENLACE ÚNICO DE LA ACADEMIA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A3F2D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PERFIL OFICIAL',
                  style: TextStyle(
                    color: Color(0xFFFFC09D),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1421),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF29344A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.public, color: Colors.white70, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _publicUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar enlace',
                  onPressed: () => _copyLink(context),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  color: const Color(0xFF38BDF8),
                ),
                IconButton(
                  tooltip: 'Mostrar QR',
                  onPressed: () => _showQrDialog(context),
                  icon: const Icon(Icons.qr_code_2, size: 20),
                  color: Colors.white70,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Compartir vía:',
                style: TextStyle(color: Color(0xFFE5B9A4), fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _sharePill(
                  context,
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  onTap: () => _shareOnWhatsApp(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _sharePill(
                  context,
                  icon: Icons.share_outlined,
                  label: 'Más',
                  onTap: () => _share(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sharePill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white70),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF1B2334),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);

    return Card(
      color: context.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Compartir academia',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${organization.viewsCount} vistas',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: QrImageView(
                  data: _qrValue,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Identificador QR: $_qrValue',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _share(context),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir enlace'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _shareOnWhatsApp(context),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
