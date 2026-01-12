import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import 'services_repository.dart';

class CreateServiceScreen extends StatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  PlatformFile? _selectedImage;

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
      String? thumbnailUrl;
      if (_selectedImage != null) {
        thumbnailUrl =
            await servicesRepository.uploadServiceImage(_selectedImage!);
      }

      // 2. Create Service
      await servicesRepository.createService(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        category: _selectedCategory!,
        thumbnailUrl: thumbnailUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis berjaya dicipta!')),
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
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cipta Servis Baru'),
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
                  child: imageProvider == null
                      ? Column(
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
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              // Title
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
              const SizedBox(height: 16),

              const SizedBox(height: 32),

              FTButton(
                label: _isLoading ? 'Sedang Cipta...' : 'Cipta Servis',
                onPressed: _isLoading ? null : _submit,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
