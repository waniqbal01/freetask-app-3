import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/portfolio_item.dart';
import '../../../core/widgets/ft_button.dart';
import '../portfolio_repository.dart';

class EditPortfolioDialog extends StatefulWidget {
  const EditPortfolioDialog({super.key, this.item});

  final PortfolioItem? item;

  @override
  State<EditPortfolioDialog> createState() => _EditPortfolioDialogState();
}

class _EditPortfolioDialogState extends State<EditPortfolioDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _categoryController;
  late TextEditingController _mediaUrlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descController =
        TextEditingController(text: widget.item?.description ?? '');
    _categoryController =
        TextEditingController(text: widget.item?.category ?? '');
    _mediaUrlController =
        TextEditingController(text: widget.item?.mediaUrl ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'title': _titleController.text,
        'description': _descController.text,
        'category': _categoryController.text,
        'mediaUrl': _mediaUrlController.text,
      };

      if (widget.item == null) {
        await portfolioRepository.createPortfolioItem(data);
      } else {
        await portfolioRepository.updatePortfolioItem(widget.item!.id, data);
      }

      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan portfolio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.item == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Portfolio?'),
        content: const Text('Adakah anda pasti mahu menghapus item ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await portfolioRepository.deletePortfolioItem(widget.item!.id);
      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item == null ? 'Tambah Portfolio' : 'Edit Portfolio',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tajuk Projek'),
                validator: (v) => v?.isEmpty == true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Kategori Servis'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mediaUrlController,
                decoration:
                    const InputDecoration(labelText: 'URL Gambar/Media'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (widget.item != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _delete,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        child: const Text('Hapus'),
                      ),
                    ),
                  if (widget.item != null) const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FTButton(
                      label: 'Simpan',
                      onPressed: _isLoading ? null : _save,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
