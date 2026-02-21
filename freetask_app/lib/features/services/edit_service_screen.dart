import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import '../../models/service.dart';
import '../../theme/app_theme.dart';
import 'services_repository.dart';

class EditServiceScreen extends StatefulWidget {
  const EditServiceScreen({required this.service, super.key});

  final Service service;

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  String? _selectedCategory;
  bool _isLoading = false;
  bool _isDeleting = false;
  PlatformFile? _selectedImage;
  String? _currentThumbnailUrl;

  final List<String> _categories = [
    'Digital & Tech',
    'Design & Creative',
    'Marketing & Growth',
    'Writing & Translation',
    'Business & Admin',
    'Home & Repair Services',
    'Event & Media Services',
    'Education & Coaching',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.service.title);
    _descriptionController =
        TextEditingController(text: widget.service.description);
    _priceController =
        TextEditingController(text: widget.service.price.toString());
    _selectedCategory = widget.service.category;
    _currentThumbnailUrl = widget.service.thumbnailUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true, // Important for Web to get bytes
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedImage = result.files.first;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih kategori')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Upload Image if selected
      String? thumbnailUrl = _currentThumbnailUrl;
      if (_selectedImage != null) {
        thumbnailUrl =
            await servicesRepository.uploadServiceImage(_selectedImage!);
      }

      // 2. Update Service
      final parsedPrice = double.parse(_priceController.text);
      await servicesRepository.updateService(
        serviceId: widget.service.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(parsedPrice.toStringAsFixed(2)),
        category: _selectedCategory!,
        thumbnailUrl: thumbnailUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis berjaya dikemaskini!')),
      );
      context.pop(true); // Return result to refresh list
    } on DioException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, resolveDioErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Ralat tidak diketahui: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Servis?'),
        content: const Text(
          'Adakah anda pasti mahu memadamkan servis ini? Tindakan ini tidak boleh dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await servicesRepository.deleteService(widget.service.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis berjaya dipadamkan')),
      );
      context.pop(true); // Return true to indicate deletion
    } on DioException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, resolveDioErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Ralat tidak diketahui: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_selectedImage != null) {
      if (kIsWeb) {
        if (_selectedImage!.bytes != null) {
          imageProvider = MemoryImage(_selectedImage!.bytes!);
        }
      } else {
        if (_selectedImage!.path != null) {
          imageProvider = FileImage(File(_selectedImage!.path!));
        }
      }
    } else if (_currentThumbnailUrl != null &&
        _currentThumbnailUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_currentThumbnailUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Servis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _isLoading || _isDeleting ? null : _deleteService,
            tooltip: 'Padam Servis',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    image: imageProvider != null
                        ? DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (imageProvider == null)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'Tambah Gambar (Thumbnail)',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: AppShadows.card,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tajuk Servis',
                  hintText: 'Contoh: Saya akan buat logo professional',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Sila masukkan tajuk';
                  }
                  if (value.length < 10) {
                    return 'Tajuk terlalu pendek (min 10 huruf)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Harga (RM)',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Sila masukkan harga';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Harga tidak sah';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  hintText: 'Terangkan servis anda dengan teliti...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Sila masukkan deskripsi';
                  }
                  if (value.length < 20) {
                    return 'Deskripsi terlalu pendek';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              FTButton(
                label: _isLoading ? 'Sedang Kemaskini...' : 'Kemaskini Servis',
                onPressed: _isLoading || _isDeleting ? null : _submit,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
