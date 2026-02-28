import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_categories.dart';
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

  final List<String> _categories = kServiceCategories;

  bool _isUploading = false;

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
        setState(() {
          _isUploading = true;
        });
        thumbnailUrl =
            await servicesRepository.uploadServiceImage(_selectedImage!);
        setState(() {
          _isUploading = false;
        });
      }

      // 2. Create Service
      final parsedPrice = double.parse(_priceController.text);
      await servicesRepository.createService(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(parsedPrice.toStringAsFixed(2)),
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
          _isUploading = false;
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
              // Image Picker with Upload Indicator
              Stack(
                children: [
                  GestureDetector(
                    onTap: _isLoading ? null : _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedImage != null
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                          width: 2,
                        ),
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
                                    size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Tambah Gambar Servis',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ketik untuk pilih gambar',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  // Upload Progress Overlay
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Memuat naik gambar...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Change Image Button
                  if (imageProvider != null && !_isUploading)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Tukar Gambar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 2,
                        ),
                      ),
                    ),
                ],
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
                  final parsed = double.tryParse(value);
                  if (parsed == null) {
                    return 'Harga tidak sah';
                  }
                  if (parsed < 50.0) {
                    return 'Harga minimum adalah RM 50.00';
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
