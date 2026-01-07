import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/ft_button.dart';
import '../../theme/app_theme.dart';

/// Screen for requesting a quote when service price is unavailable
/// UX-C-09: "Minta sebut harga" proper flow
class QuoteRequestScreen extends StatefulWidget {
  const QuoteRequestScreen({
    super.key,
    required this.serviceId,
    required this.serviceTitle,
  });

  final String serviceId;
  final String serviceTitle;

  @override
  State<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _deadlineController = TextEditingController();

  bool _isSubmitting = false;
  String _contactPreference = 'chat';

  @override
  void dispose() {
    _budgetController.dispose();
    _requirementsController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate API call - in real implementation, this would create a job request
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    // Show success dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permintaan Dihantar'),
          content: const Text(
            'Permintaan sebut harga dihantar kepada penyedia. Anda akan dimaklumkan melalui chat atau notifikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
              child: const Text('Kembali ke Home'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minta Sebut Harga'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Isi borang di bawah untuk mendapatkan sebut harga daripada penyedia servis.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Servis: ${widget.serviceTitle}',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bajet Anggaran (RM)',
                  prefixIcon: Icon(Icons.attach_money),
                  helperText: 'Masukkan bajet anggaran anda',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Sila masukkan bajet anggaran';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Sila masukkan nombor yang sah';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deadlineController,
                decoration: const InputDecoration(
                  labelText: 'Tarikh Akhir (pilihan)',
                  prefixIcon: Icon(Icons.calendar_today),
                  helperText: 'Contoh: 15 Disember 2025',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _requirementsController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Keperluan & Butiran',
                  prefixIcon: Icon(Icons.description_outlined),
                  helperText: 'Terangkan keperluan anda dengan jelas',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sila terangkan keperluan anda';
                  }
                  if (value.trim().length < 20) {
                    return 'Sila berikan butiran lebih lanjut (minimum 20 aksara)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Cara Dihubungi',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // ignore: deprecated_member_use
              RadioListTile<String>(
                title: const Text('Chat dalam aplikasi'),
                value: 'chat',
                // ignore: deprecated_member_use
                groupValue: _contactPreference,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _contactPreference = value);
                  }
                },
              ),
              // ignore: deprecated_member_use
              RadioListTile<String>(
                title: const Text('Notifikasi'),
                value: 'notification',
                // ignore: deprecated_member_use
                groupValue: _contactPreference,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _contactPreference = value);
                  }
                },
              ),
              const SizedBox(height: 32),
              FTButton(
                label: 'Hantar Permintaan',
                onPressed: _handleSubmit,
                isLoading: _isSubmitting,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
