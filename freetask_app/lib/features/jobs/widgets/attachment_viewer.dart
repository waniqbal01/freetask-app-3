import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

import '../../../core/utils/url_utils.dart';
import '../../../services/upload_service.dart';

/// Widget to display file attachments with preview and download capability
class AttachmentViewer extends StatefulWidget {
  final List<String> attachments;
  final String label;

  const AttachmentViewer({
    super.key,
    required this.attachments,
    this.label = 'Fail',
  });

  @override
  State<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> {
  // Track download progress if needed, or simply loading state per file
  final Map<String, bool> _loadingStates = {};

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
    if (_isImageUrl(url)) return Icons.image;
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) {
      return Icons.folder_zip;
    }
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
    if (_isImageUrl(url)) return Colors.blue;
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf')) return Colors.red;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Colors.indigo;
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return Colors.amber;
    return Colors.grey;
  }

  Future<void> _viewFile(String url) async {
    if (_loadingStates[url] == true) return;

    setState(() {
      _loadingStates[url] = true;
    });

    try {
      // 1. Download file bytes securely (with auth)
      final response = await uploadService.downloadWithAuth(url);
      final bytes = response.data;

      if (bytes == null) throw Exception('Tiada data fail diterima');

      if (kIsWeb) {
        // Web: Create Blob and open in new tab
        final blob = html.Blob([bytes]);
        final objectUrl = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(objectUrl, '_blank');
        // Clean up objectUrl after a delay or let it persist for the session?
        // Usually safe to revoke after short delay if just opening, but window.open might need it briefly.
        Future.delayed(const Duration(seconds: 5), () {
          html.Url.revokeObjectUrl(objectUrl);
        });
      } else {
        // Mobile: Save to temp and open
        final tempDir = await getTemporaryDirectory();
        final fileName = _getFileName(url);
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          throw Exception(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka fail: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates[url] = false;
        });
      }
    }
  }

  Future<void> _downloadFile(String url) async {
    if (_loadingStates[url] == true) return;

    // Check storage permission on Android (simplified)
    // Note: On Android 13+ strict storage permissions apply,
    // but managing external storage often requires explicit intent or manage_external_storage
    // For simplicity we try to get a public directory.

    /* 
    // Basic permission check - usually not needed for getExternalStorageDirectory on modern Android for app-specific files,
    // but for public Downloads folder it might differ.
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Perlu kebenaran akses storan untuk muat turun.')),
          );
        }
        return;
      }
    }
    */

    setState(() {
      _loadingStates[url] = true;
    });

    try {
      // 1. Download
      final response = await uploadService.downloadWithAuth(url);
      final bytes = response.data;
      if (bytes == null) throw Exception('Tiada data fail');

      final fileName = _getFileName(url).replaceAll(RegExp(r'[^\w\s\.-]'), '_');

      if (kIsWeb) {
        // Web: Trigger browser download
        final blob = html.Blob([bytes]);
        final objectUrl = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: objectUrl)
          ..setAttribute('download', fileName)
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();

        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(objectUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Muat turun bermula...')),
          );
        }
      } else {
        // Mobile: Save to downloads
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        } else {
          directory = await getDownloadsDirectory();
        }

        if (directory == null)
          throw Exception('Folder muat turun tidak ditemui');

        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final saveFile = File('${directory.path}/$fileName');
        await saveFile.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Fail berjaya dimuat turun ke: ${saveFile.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal muat turun: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates[url] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.attachments.map((url) {
            final isImage = _isImageUrl(url);
            final fileName = _getFileName(url);
            final fileColor = _getFileColor(url);
            final fileIcon = _getFileIcon(url);
            final isLoading = _loadingStates[url] == true;

            return Container(
              width:
                  isImage ? 140 : 300, // Slightly wider to accommodate buttons
              decoration: BoxDecoration(
                color: fileColor.withValues(alpha: 0.1),
                border: Border.all(color: fileColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Threat preview area as "View" button
                  InkWell(
                    onTap: isLoading ? null : () => _viewFile(url),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isImage)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: Image.network(
                                  UrlUtils.resolveImageUrl(url),
                                  width: 140,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 140,
                                      height: 120,
                                      color: fileColor.withValues(alpha: 0.2),
                                      child: Icon(
                                        Icons.broken_image,
                                        color: fileColor,
                                        size: 40,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (isLoading)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black12,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Icon(fileIcon, size: 16, color: fileColor),
                              const SizedBox(width: 4),
                              Expanded(
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons (View & Download)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: fileColor.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isLoading ? null : () => _viewFile(url),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Icon(
                                Icons.visibility,
                                size: 18,
                                color: fileColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: fileColor.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: isLoading ? null : () => _downloadFile(url),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Icon(
                                Icons.download,
                                size: 18,
                                color: fileColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
