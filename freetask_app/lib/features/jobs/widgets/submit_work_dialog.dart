import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../../../core/utils/error_utils.dart';
import '../../../services/upload_service.dart';
import '../jobs_repository.dart';

/// Dialog for submitting work with optional file attachments
class SubmitWorkDialog extends StatefulWidget {
  final String jobId;

  const SubmitWorkDialog({
    super.key,
    required this.jobId,
  });

  @override
  State<SubmitWorkDialog> createState() => _SubmitWorkDialogState();
}

class _SubmitWorkDialogState extends State<SubmitWorkDialog> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _uploadedFileUrls = [];
  final List<String> _fileNames = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    setState(() => _isUploading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'zip'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Upload using bytes for web, path for mobile
        late UploadResult uploadResult;
        if (file.bytes != null) {
          // Web platform
          uploadResult = await uploadService.uploadData(
            file.name,
            file.bytes!,
            lookupMimeType(file.name),
          );
        } else if (file.path != null) {
          // Mobile/Desktop platform
          uploadResult = await uploadService.uploadFile(file.path!);
        } else {
          throw StateError('File data not available');
        }

        setState(() {
          _uploadedFileUrls.add(uploadResult.url);
          _fileNames.add(file.name);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fail berjaya dimuat naik!')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Gagal memuat naik fail: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _submitWork() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesej wajib diisi')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await jobsRepository.submitJob(
        widget.jobId,
        message,
        attachments: _uploadedFileUrls.isEmpty ? null : _uploadedFileUrls,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, 'Gagal menghantar: $error');
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hantar Kerja'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sila beritahu pelanggan bahawa kerja telah siap:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Mesej (Wajib)',
                hintText: 'Contoh: Kerja siap, sila semakkan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 16),

            // File Upload Section
            ElevatedButton.icon(
              onPressed:
                  (_isUploading || _isSubmitting) ? null : _pickAndUploadFile,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
              label: Text(_isUploading ? 'Uploading...' : 'Lampirkan Fail'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.black87,
              ),
            ),

            // Display uploaded files
            if (_fileNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(_fileNames.length, (index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fileNames[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isSubmitting)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _uploadedFileUrls.removeAt(index);
                              _fileNames.removeAt(index);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pelanggan ada 48 jam untuk semak. Jika tiada respon, kerja auto-selesai.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submitWork,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hantar'),
        ),
      ],
    );
  }
}
