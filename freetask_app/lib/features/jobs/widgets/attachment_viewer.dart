import 'package:flutter/material.dart';
import 'dart:html' as html;

import '../../../services/upload_service.dart';

/// Widget to display file attachments with preview and download capability
class AttachmentViewer extends StatelessWidget {
  final List<String> attachments;
  final String label;

  const AttachmentViewer({
    super.key,
    required this.attachments,
    this.label = 'Fail',
  });

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.contains('/uploads/') &&
            (lower.contains('jpg') ||
                lower.contains('png') ||
                lower.contains('jpeg'));
  }

  IconData _getFileIcon(String url) {
    final lower = url.toLowerCase();
    if (_isImageUrl(url)) return Icons.image;
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx'))
      return Icons.description;
    if (lower.endsWith('.zip') || lower.endsWith('.rar'))
      return Icons.folder_zip;
    return Icons.attachment;
  }

  String _getFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
    } catch (_) {}
    return url.split('/').last;
  }

  Color _getFileColor(String url) {
    final lower = url.toLowerCase();
    if (_isImageUrl(url)) return Colors.blue;
    if (lower.endsWith('.pdf')) return Colors.red;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Colors.indigo;
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return Colors.amber;
    return Colors.grey;
  }

  Future<void> _openFile(BuildContext context, String url) async {
    try {
      final fullUrl = await uploadService.resolveAuthorizedUrl(url);
      html.window.open(fullUrl, '_blank');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka fail: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: attachments.map((url) {
            final isImage = _isImageUrl(url);
            final fileName = _getFileName(url);
            final fileColor = _getFileColor(url);
            final fileIcon = _getFileIcon(url);

            return InkWell(
              onTap: () => _openFile(context, url),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: isImage ? 120 : null,
                constraints: BoxConstraints(
                  maxWidth: isImage ? 120 : 300,
                ),
                decoration: BoxDecoration(
                  color: fileColor.withOpacity(0.1),
                  border: Border.all(color: fileColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isImage)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: FutureBuilder<String>(
                          future: uploadService.resolveAuthorizedUrl(url),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.network(
                                snapshot.data!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 120,
                                    height: 120,
                                    color: fileColor.withOpacity(0.2),
                                    child: Icon(
                                      Icons.broken_image,
                                      color: fileColor,
                                      size: 40,
                                    ),
                                  );
                                },
                              );
                            }
                            return Container(
                              width: 120,
                              height: 120,
                              color: fileColor.withOpacity(0.2),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(fileIcon, size: 16, color: fileColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 12,
                                color: fileColor,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: fileColor.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
