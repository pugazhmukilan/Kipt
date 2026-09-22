import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/attachment.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';

/// Grid display of item attachments with share, delete, and tap-to-view actions.
class AttachmentGrid extends StatelessWidget {
  final List<Attachment> attachments;
  final void Function(Attachment)? onDelete;
  final bool showDelete;

  const AttachmentGrid({
    super.key,
    required this.attachments,
    this.onDelete,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final att = attachments[index];
        return _AttachmentTile(
          attachment: att,
          onDelete: showDelete && onDelete != null
              ? () => onDelete!(att)
              : null,
        );
      },
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onDelete;

  const _AttachmentTile({required this.attachment, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _viewAttachment(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: attachment.isPhoto
                ? _PhotoThumbnail(path: attachment.path)
                : _PdfThumbnail(cs: cs),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TileAction(
                  icon: Icons.share_rounded,
                  onTap: () => _shareAttachment(context),
                  cs: cs,
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  _TileAction(
                    icon: Icons.delete_rounded,
                    onTap: onDelete!,
                    cs: cs,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewAttachment(BuildContext context) {
    if (attachment.isPhoto) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(
            path: attachment.path,
            attachmentId: attachment.id,
            itemId: attachment.itemId,
          ),
        ),
      );
    } else {
      _openPdf(context);
    }
  }

  Future<void> _openPdf(BuildContext context) async {
    final result = await OpenFile.open(attachment.path);
    if (!context.mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _shareAttachment(BuildContext context) async {
    await Share.shareXFiles([XFile(attachment.path)]);
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String path;
  const _PhotoThumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return file.existsSync()
        ? Image.file(file, fit: BoxFit.cover)
        : Container(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: const Icon(Icons.broken_image_outlined),
          );
  }
}

class _PdfThumbnail extends StatelessWidget {
  final ColorScheme cs;
  const _PdfThumbnail({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.errorContainer,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            color: cs.onErrorContainer,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            'PDF',
            style: TextStyle(
              fontSize: 11,
              color: cs.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _TileAction({
    required this.icon,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: cs.onSurface),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String path;
  final int? attachmentId;
  final int? itemId;

  const FullScreenImageViewer({
    super.key,
    required this.path,
    this.attachmentId,
    this.itemId,
  });

  Future<void> _share(BuildContext context) async {
    await Share.shareXFiles([XFile(path)], subject: 'Item photo');
  }

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = File(path);
    final name = file.uri.pathSegments.last;
    messenger.showSnackBar(const SnackBar(content: Text('Saving photo…')));
    try {
      final result = await ImageGallerySaverPlus.saveFile(path, name: name);
      final isSuccess = result is Map && result['isSuccess'] == true;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isSuccess ? 'Photo saved to gallery' : 'Could not save photo',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save photo')),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    if (attachmentId == null || itemId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This photo will be removed from the item.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<ItemBloc>().add(
      DeleteAttachment(
        attachmentId: attachmentId!,
        path: path,
        itemId: itemId!,
      ),
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download',
            onPressed: () => _download(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: () => _share(context),
          ),
          if (attachmentId != null && itemId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete photo',
              onPressed: () => _delete(context),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(160),
          clipBehavior: Clip.none,
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}
