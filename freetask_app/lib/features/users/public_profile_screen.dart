import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart';
import '../../models/service.dart';
import '../../core/utils/url_utils.dart';
import '../reviews/reviews_repository.dart';
import 'users_repository.dart';
import '../chat/chat_repository.dart';

import 'package:flutter/services.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<({Map<String, dynamic> user, List<Review> reviews})> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<({Map<String, dynamic> user, List<Review> reviews})>
      _fetchData() async {
    final user = await usersRepository.getPublicProfile(widget.userId);
    final reviews = await reviewsRepository
        .getReviewsForFreelancer(int.tryParse(widget.userId) ?? 0);
    return (user: user, reviews: reviews);
  }

  void _copyProfileLink() {
    // Construct the deep link
    // Scheme: freetask://app/users/{userId}
    final deepLink = 'freetask://app/users/${widget.userId}';

    // We can also add a message
    // Note: Since we don't have a dynamic link service, we provide raw links.
    final message = 'Lihat profil saya di FreeTask!\n\n'
        'Buka di aplikasi: $deepLink\n\n'
        'Jika belum ada aplikasi, muat turun di sini: https://play.google.com/store/apps/details?id=com.freetask.apps';

    Clipboard.setData(ClipboardData(text: message));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pautan profil disalin! Boleh dikongsi dengan rakan.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pengguna'),
        actions: [
          IconButton(
            onPressed: _copyProfileLink,
            icon: const Icon(Icons.share),
            tooltip: 'Kongsi Profil',
          ),
        ],
      ),
      body: FutureBuilder<({Map<String, dynamic> user, List<Review> reviews})>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat profil',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _loadData();
                      });
                    },
                    child: const Text('Cuba Lagi'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Pengguna tidak dijumpai'));
          }

          final data = snapshot.data!;
          final userMap = data.user;
          final user = AppUser.fromJson(userMap);
          final reviews = data.reviews;
          final servicesData = (userMap['services'] as List<dynamic>?) ?? [];
          final services = servicesData
              .map((e) => Service.fromJson(e as Map<String, dynamic>))
              .toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(user, reviews),
                const Divider(height: 1),
                if (services.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Servis Ditawarkan (${services.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  _buildServiceList(services),
                ] else if (user.roleEnum.isFreelancer)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'Tiada servis ditawarkan.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Ulasan & Rating (${reviews.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _buildReviewList(reviews),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageButton(AppUser user) {
    return FilledButton.icon(
      onPressed: () => _handleProfileMessage(user),
      icon: const Icon(Icons.chat),
      label: const Text('Mesej'),
    );
  }

  Future<void> _handleProfileMessage(AppUser user) async {
    if (!mounted) return;

    try {
      final chatRepo = ChatRepository();
      // widget.userId is the freelancerId (otherUserId)
      final thread =
          await chatRepo.createConversation(otherUserId: widget.userId);

      if (!mounted) return;
      context.push('/chats/${thread.id}/messages');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka chat: $e')),
      );
    }
  }

  Widget _buildHeader(AppUser user, List<Review> reviews) {
    final avatarUrl = user.avatarUrl;
    final name = user.name;
    final bio = user.bio;
    final skills = user.skills ?? [];
    final rate = user.rate;

    // Calculate average rating
    double avgRating = 0;
    if (reviews.isNotEmpty) {
      avgRating =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(UrlUtils.resolveImageUrl(avatarUrl))
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          if (user.roleEnum.isFreelancer) ...[
            const SizedBox(height: 12),
            _buildLevelBadge(user.level),
          ],
          if (rate != null) ...[
            const SizedBox(height: 4),
            Text(
              'RM $rate/jam',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],

          // Rating Row
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, color: Colors.amber.shade600, size: 20),
              const SizedBox(width: 4),
              Text(
                avgRating > 0 ? avgRating.toStringAsFixed(1) : 'Tiada Rating',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (reviews.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '(${reviews.length} ulasan)',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ],
          ),

          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              bio,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],

          if (user.state != null && user.state!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.grey.shade500, size: 16),
                const SizedBox(width: 4),
                Text(
                  user.district != null && user.district!.isNotEmpty
                      ? '${user.district}, ${user.state}'
                      : user.state!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          _buildMessageButton(user),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: skills.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                  ),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewList(List<Review> reviews) {
    if (reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'Belum ada ulasan.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: reviews.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Pelanggan', // We might want review.reviewerName later
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(review.createdAt),
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          children: List.generate(5, (starIndex) {
                            return Icon(
                              starIndex < review.rating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 14,
                              color: Colors.amber,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  review.comment!,
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildServiceList(List<Service> services) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: services.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              context.push('/service/${service.id}');
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: service.thumbnailUrl != null &&
                            service.thumbnailUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              UrlUtils.resolveImageUrl(service.thumbnailUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported,
                                      color: Colors.grey),
                            ),
                          )
                        : const Icon(Icons.image_not_supported,
                            color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RM ${service.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.category,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelBadge(String level) {
    Color color;
    String label;
    IconData icon;
    switch (level) {
      case 'PRO':
        color = Colors.purple;
        label = 'Pro';
        icon = Icons.star;
        break;
      case 'STANDARD':
        color = Colors.blue;
        label = 'Standard';
        icon = Icons.verified;
        break;
      default:
        color = Colors.green;
        label = 'Newbie';
        icon = Icons.circle;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
