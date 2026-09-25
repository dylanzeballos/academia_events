import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/organization_model.dart';

class OrganizationShareSection extends StatelessWidget {
  const OrganizationShareSection({super.key, required this.organization});

  final OrganizationModel organization;

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

  @override
  Widget build(BuildContext context) {
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
