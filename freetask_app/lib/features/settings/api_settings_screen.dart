import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../services/http_client.dart';
import '../../theme/app_theme.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;
  String? _activeBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final current = await HttpClient().currentBaseUrl();
    if (!mounted) return;
    setState(() {
      _activeBaseUrl = current;
      _controller.text = current;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final value = _controller.text.trim();
    await HttpClient().updateBaseUrl(value);
    if (!mounted) return;
    final resolved = value.isEmpty ? Env.defaultApiBaseUrl : value;
    setState(() {
      _activeBaseUrl = resolved;
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value.isEmpty
              ? 'URL dikosongkan. Menggunakan default: $resolved'
              : 'URL disimpan. Mulakan semula sesi jika perlu.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Server URL'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tetapan ini membenarkan QA menukar host API tanpa rebuild.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'API Base URL',
                      hintText: Env.defaultApiBaseUrl,
                      helperText:
                          'Contoh: http://localhost:4000 (web), http://10.0.2.2:4000 (Android emulator) atau http://your-lan-ip:4000',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'URL aktif: ${_activeBaseUrl ?? Env.defaultApiBaseUrl}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan & Guna'),
                  ),
                ],
              ),
            ),
    );
  }
}
