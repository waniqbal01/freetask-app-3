import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/utils/error_utils.dart';
import 'reviews_repository.dart';

class ReviewDialog extends StatefulWidget {
  const ReviewDialog({
    super.key,
    required this.jobId,
    required this.revieweeId,
    required this.serviceTitle,
  });

  final String jobId;
  final String revieweeId;
  final String serviceTitle;

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Review untuk ${widget.serviceTitle}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Penilaian'),
              const SizedBox(height: 8),
              Row(
                children: List<Widget>.generate(5, (int index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= _rating;
                  return IconButton(
                    icon: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _rating = starIndex;
                            });
                          },
                  );
                }),
              ),
              const SizedBox(height: 12),
              const Text('Komen (pilihan)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Kongsi pengalaman anda...',
                ),
                validator: (String? value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      value.trim().length < 10) {
                    return 'Komen mesti sekurang-kurangnya 10 aksara.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hantar'),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    final parsedJobId = int.tryParse(widget.jobId);
    final parsedRevieweeId = int.tryParse(widget.revieweeId);

    if (parsedJobId == null || parsedRevieweeId == null) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        Navigator.of(context).pop(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data tidak sah. Sila cuba lagi.')),
        );
      }
      return;
    }

    try {
      await reviewsRepository.createReview(
        jobId: parsedJobId,
        revieweeId: parsedRevieweeId,
        rating: _rating,
        comment: _commentController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      Navigator.of(context).pop(true);
    } on AuthRequiredException catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Provide specific error messaging for common review validation failures
        final message = error.response?.statusCode == 403
            ? (error.response?.data?['message']?.toString() ??
                'Tidak dapat menghantar review. Pastikan anda adalah sebahagian daripada job ini.')
            : error.response?.statusCode == 400
                ? (error.response?.data?['message']?.toString() ??
                    'Data review tidak sah. Sila cuba lagi.')
                : resolveDioErrorMessage(error);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghantar review: $error')),
        );
      }
    }
  }
}
