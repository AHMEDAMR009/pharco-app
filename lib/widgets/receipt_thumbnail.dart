import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

/// A small tappable thumbnail for a receipt/invoice image, opening a
/// full-screen viewer on tap. Renders nothing if there's no attachment;
/// shows a broken-image placeholder (and disables the tap) if the file is
/// missing or fails to load, instead of crashing the full-screen viewer.
class ReceiptThumbnail extends ConsumerStatefulWidget {
  final String? path;
  const ReceiptThumbnail({super.key, required this.path});

  @override
  ConsumerState<ReceiptThumbnail> createState() => _ReceiptThumbnailState();
}

class _ReceiptThumbnailState extends ConsumerState<ReceiptThumbnail> {
  bool _failedToLoad = false;

  @override
  Widget build(BuildContext context) {
    if (widget.path == null) return const SizedBox.shrink();
    final url = ref.read(storageServiceProvider).publicUrl(widget.path!);

    return GestureDetector(
      onTap: _failedToLoad ? null : () => _openViewer(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (context, _) => Container(
            width: 44,
            height: 44,
            color: const Color(0xFFF0F0F0),
            child: const Center(
              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          errorWidget: (context, _, __) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_failedToLoad) setState(() => _failedToLoad = true);
            });
            return Container(
              width: 44,
              height: 44,
              color: const Color(0xFFF0F0F0),
              child: const Icon(Icons.broken_image_outlined, size: 20, color: Colors.black38),
            );
          },
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                errorWidget: (context, _, __) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'This receipt image could not be loaded.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
