import 'package:flutter/material.dart';
import '../../../models/portfolio_item.dart';
import '../../users/portfolio_repository.dart';

class PortfolioListWidget extends StatelessWidget {
  const PortfolioListWidget({
    super.key,
    required this.userId,
    this.isEditable = false,
    required this.onEdit,
    this.onItemTap,
  });

  final int userId;
  final bool isEditable;
  final VoidCallback onEdit;
  final Function(PortfolioItem)? onItemTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PortfolioItem>>(
      future: portfolioRepository.getPortfolio(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text('Gagal memuat portfolio');
        }
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text('Tiada portfolio.'),
                if (isEditable)
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Tambah Portfolio'),
                  ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (isEditable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Portfolio (${items.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                    IconButton(icon: const Icon(Icons.add), onPressed: onEdit),
                  ],
                ),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onItemTap?.call(item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: item.mediaUrl != null
                              ? Image.network(item.mediaUrl!, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              if (item.category != null)
                                Text(item.category!,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
