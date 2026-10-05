import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Visor de imágenes a pantalla completa estilo WhatsApp:
/// zoom con pinza, paneo, doble toque para acercar y deslizamiento entre
/// varias imágenes.
///
/// Usa [tag]/[tags] en un [Hero] para una transición suave desde la miniatura.
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.tags,
  });

  final List<String> urls;
  final int initialIndex;
  final List<String?>? tags;

  /// Abre una sola imagen.
  static void show(BuildContext context, String url, {String? tag}) {
    showGallery(context, [url], tags: [tag]);
  }

  /// Abre una galería de imágenes, empezando por [initialIndex].
  static void showGallery(
    BuildContext context,
    List<String> urls, {
    int initialIndex = 0,
    List<String?>? tags,
  }) {
    final clean = urls.where((u) => u.trim().isNotEmpty).toList();
    if (clean.isEmpty) return;
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => FullscreenImageViewer(
          urls: clean,
          initialIndex: initialIndex.clamp(0, clean.length - 1),
          tags: tags,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.urls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: multiple
            ? Text(
                '${_current + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: PhotoViewGallery.builder(
        pageController: _controller,
        itemCount: widget.urls.length,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        onPageChanged: (index) => setState(() => _current = index),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        builder: (context, index) {
          final tag = (widget.tags != null && index < widget.tags!.length)
              ? widget.tags![index]
              : null;
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(widget.urls[index]),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: tag != null
                ? PhotoViewHeroAttributes(tag: tag)
                : null,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          );
        },
      ),
    );
  }
}
