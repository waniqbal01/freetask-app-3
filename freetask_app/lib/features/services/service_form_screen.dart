import 'package:flutter/material.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/service.dart';
import '../../theme/app_theme.dart';
import 'services_repository.dart';

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key, this.initialService, this.serviceId});

  final Service? initialService;
  final String? serviceId;

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = false;
  List<String> _categories = const <String>[];
  String? _errorMessage;

  bool get _isEdit => widget.initialService != null || widget.serviceId != null;

  @override
  void initState() {
    super.initState();
    _seedFromService(widget.initialService);
    _loadCategories();
    if (widget.initialService == null && widget.serviceId != null) {
      _fetchService(widget.serviceId!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _seedFromService(Service? service) {
    if (service == null) {
      return;
    }
    _titleController.text = service.title;
    _descriptionController.text = service.description;
    _priceController.text = service.price.toStringAsFixed(2);
    _categoryController.text = service.category;
  }

  Future<void> _fetchService(String id) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final service = await servicesRepository.getServiceById(id);
      if (!mounted) return;
      _seedFromService(service);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final data = await servicesRepository.getCategories();
      if (!mounted) return;
      setState(() => _categories = data);
    } catch (_) {
      // Ignore minor failures.
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final payload = ServiceRequestPayload(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      category: _categoryController.text.trim(),
    );

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_isEdit) {
        final id = widget.initialService?.id ?? widget.serviceId!;
        await servicesRepository.updateService(id, payload);
      } else {
        await servicesRepository.createService(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Servis dikemaskini.' : 'Servis baharu dicipta.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      showErrorSnackBar(context, error);
    } catch (error) {
      if (!mounted) return;
      final fallback = 'Gagal menyimpan servis: $error';
      setState(() => _errorMessage = fallback);
      showErrorSnackBar(context, fallback);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Kemaskini Servis' : 'Servis Baharu';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: AppRadius.mediumRadius,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tajuk Servis',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Tajuk wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      TextFormField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          prefixIcon: const Icon(Icons.category_outlined),
                          suffixIcon: _categories.isEmpty
                              ? null
                              : PopupMenuButton<String>(
                                  icon: const Icon(Icons.arrow_drop_down_circle),
                                  onSelected: (String value) {
                                    _categoryController.text = value;
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return _categories
                                        .map((String value) => PopupMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ))
                                        .toList();
                                  },
                                ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Kategori wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga (RM)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Masukkan harga yang sah';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi Servis',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 20) {
                            return 'Deskripsi sekurang-kurangnya 20 aksara';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s24),
                      FTButton(
                        label: _isEdit ? 'Kemaskini' : 'Simpan Servis',
                        onPressed: _isSubmitting ? null : _submit,
                        expanded: true,
                        isLoading: _isSubmitting,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
