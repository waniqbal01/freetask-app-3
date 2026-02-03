import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router.dart';
import '../../core/storage/storage.dart';
import '../../core/utils/url_utils.dart'; // Added for UrlUtils.resolveImageUrl()
import '../../core/utils/error_utils.dart';
import '../../features/auth/auth_repository.dart';
import '../../services/http_client.dart';
import 'admin_repository.dart';

class NewAdminDashboardScreen extends StatefulWidget {
  const NewAdminDashboardScreen({super.key});

  @override
  State<NewAdminDashboardScreen> createState() =>
      _NewAdminDashboardScreenState();
}

class _NewAdminDashboardScreenState extends State<NewAdminDashboardScreen> {
  late final AdminRepository _adminRepo;

  @override
  void initState() {
    super.initState();
    final httpClient = HttpClient();
    _adminRepo = AdminRepository(dio: httpClient.dio);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.verified_user),
              tooltip: 'Bank Verification',
              onPressed: () => context.push('/admin/bank-verification'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log Keluar',
              onPressed: () => _handleLogout(context),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.approval), text: 'Services'),
              Tab(icon: Icon(Icons.shopping_bag), text: 'Orders'),
              Tab(icon: Icon(Icons.money), text: 'Withdrawals'),
              Tab(icon: Icon(Icons.gavel), text: 'Disputes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(adminRepo: _adminRepo),
            _UsersTab(adminRepo: _adminRepo),
            _ServicesTab(adminRepo: _adminRepo),
            _OrdersTab(adminRepo: _adminRepo),
            _WithdrawalsTab(adminRepo: _adminRepo),
            _DisputesTab(adminRepo: _adminRepo),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Keluar'),
        content: const Text('Adakah anda pasti mahu log keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Log Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final storage = appStorage;
      await storage.delete(AuthRepository.tokenStorageKey);
      await storage.delete(AuthRepository.refreshTokenStorageKey);
      authRefreshNotifier.value = DateTime.now();

      if (mounted) {
        appRouter.go('/login');
      }
    }
  }
}

// ============================================================================
// OVERVIEW TAB
// ============================================================================
class _OverviewTab extends StatefulWidget {
  final AdminRepository adminRepo;
  const _OverviewTab({required this.adminRepo});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _analytics;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final analyticsResponse = await widget.adminRepo.getAnalytics();
    final statsResponse = await widget.adminRepo.getSystemStats();

    if (mounted) {
      setState(() {
        _analytics = analyticsResponse.data;
        _stats = statsResponse.data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Analytics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard(
                  'Total Users',
                  _analytics?['totalUsers']?.toString() ?? '0',
                  Icons.people,
                  Colors.blue),
              _buildStatCard(
                  'Total Jobs',
                  _analytics?['totalJobs']?.toString() ?? '0',
                  Icons.work,
                  Colors.green),
              _buildStatCard(
                  'Total Services',
                  _analytics?['totalServices']?.toString() ?? '0',
                  Icons.store,
                  Colors.orange),
              _buildStatCard(
                  'Completed Jobs',
                  _analytics?['completedJobs']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.teal),
              _buildStatCard(
                  'Pending Jobs',
                  _analytics?['pendingJobs']?.toString() ?? '0',
                  Icons.pending,
                  Colors.amber),
              _buildStatCard(
                  'Disputed Jobs',
                  _analytics?['disputedJobs']?.toString() ?? '0',
                  Icons.gavel,
                  Colors.red),
              _buildStatCard(
                  'Total Revenue',
                  'RM ${_analytics?['totalRevenue']?.toString() ?? '0'}',
                  Icons.attach_money,
                  Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          const Text('System Stats (Last 30 Days)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard(
                  'New Users',
                  _stats?['newUsersLast30Days']?.toString() ?? '0',
                  Icons.person_add,
                  Colors.indigo),
              _buildStatCard(
                  'New Jobs',
                  _stats?['newJobsLast30Days']?.toString() ?? '0',
                  Icons.add_task,
                  Colors.cyan),
              _buildStatCard(
                  'Active Users',
                  _stats?['activeUsers']?.toString() ?? '0',
                  Icons.people_alt,
                  Colors.pink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// USERS TAB
// ============================================================================
class _UsersTab extends StatefulWidget {
  final AdminRepository adminRepo;
  const _UsersTab({required this.adminRepo});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    final response = await widget.adminRepo.getUsers();

    if (mounted && response.isSuccess) {
      setState(() {
        _users = response.data?['users'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorSnackBar(context, response.error ?? 'Failed to load users');
      }
    }
  }

  Future<void> _toggleUserStatus(int userId, bool currentStatus) async {
    final newStatus = !currentStatus;
    final response = await widget.adminRepo.updateUserStatus(
      userId: userId,
      isActive: newStatus,
    );

    if (response.isSuccess) {
      if (mounted) {
        showSuccessSnackBar(
            context, newStatus ? 'User activated' : 'User banned');
      }
      _loadUsers();
    } else {
      if (mounted) {
        showErrorSnackBar(context, response.error ?? 'Failed to update user');
      }
    }
  }

  Future<void> _updateTrustScore(int userId, int currentScore) async {
    final controller = TextEditingController(text: currentScore.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Trust Score'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter new trust score (0-100):'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Score',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newScore = int.tryParse(controller.text);
      if (newScore == null || newScore < 0 || newScore > 100) {
        if (mounted) {
          showErrorSnackBar(context, 'Please enter a valid score (0-100)');
        }
        return;
      }

      final response = await widget.adminRepo.updateTrustScore(
        userId: userId,
        score: newScore,
      );

      if (response.isSuccess) {
        if (mounted) {
          showSuccessSnackBar(context, 'Trust score updated');
        }
        _loadUsers();
      } else {
        if (mounted) {
          showErrorSnackBar(
              context, response.error ?? 'Failed to update trust score');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: _users.isEmpty
          ? const Center(child: Text('No users found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isActive = user['isActive'] ?? true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['avatarUrl'] != null
                          ? NetworkImage(
                              UrlUtils.resolveImageUrl(user['avatarUrl']))
                          : null,
                      child: user['avatarUrl'] == null
                          ? Text(user['name'][0].toUpperCase())
                          : null,
                    ),
                    title: Text(user['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['email']),
                        Text('Role: ${user['role']}'),
                        if (user['balance'] != null)
                          Text('Balance: RM ${user['balance']}'),
                        Text(
                          'Trust Score: ${user['trustScore'] ?? 50}',
                          style: TextStyle(
                            color: (user['trustScore'] ?? 50) >= 80
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.verified_user_outlined),
                          tooltip: 'Trust Score: ${user['trustScore'] ?? 50}',
                          onPressed: () => _updateTrustScore(
                              user['id'], user['trustScore'] ?? 50),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (value) =>
                              _toggleUserStatus(user['id'], isActive),
                          inactiveThumbColor: Colors.red,
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// SERVICES TAB
// ============================================================================
class _ServicesTab extends StatefulWidget {
  final AdminRepository adminRepo;
  const _ServicesTab({required this.adminRepo});

  @override
  State<_ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<_ServicesTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);

    final response = await widget.adminRepo.getPendingServices();

    if (mounted && response.isSuccess) {
      setState(() {
        _services = response.data?['services'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorSnackBar(context, response.error ?? 'Failed to load services');
      }
    }
  }

  Future<void> _approveService(int serviceId) async {
    final response = await widget.adminRepo.approveService(serviceId);

    if (response.isSuccess) {
      if (mounted) {
        showSuccessSnackBar(context, 'Service approved');
      }
      _loadServices();
    } else {
      if (mounted) {
        showErrorSnackBar(
            context, response.error ?? 'Failed to approve service');
      }
    }
  }

  Future<void> _rejectService(int serviceId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Service'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.isNotEmpty) {
      final response = await widget.adminRepo.rejectService(
        serviceId: serviceId,
        reason: reasonController.text,
      );

      if (response.isSuccess) {
        if (mounted) {
          showSuccessSnackBar(context, 'Service rejected');
        }
        _loadServices();
      } else {
        if (mounted) {
          showErrorSnackBar(
              context, response.error ?? 'Failed to reject service');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadServices,
      child: _services.isEmpty
          ? const Center(child: Text('No pending services'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (service['thumbnailUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              UrlUtils.resolveImageUrl(service['thumbnailUrl']),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          service['title'],
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(service['description']),
                        const SizedBox(height: 8),
                        Text('Price: RM ${service['price']}'),
                        Text('Category: ${service['category']}'),
                        if (service['freelancer'] != null)
                          Text('Freelancer: ${service['freelancer']['name']}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _approveService(service['id']),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _rejectService(service['id']),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// ORDERS TAB
// ============================================================================
class _OrdersTab extends StatefulWidget {
  final AdminRepository adminRepo;
  const _OrdersTab({required this.adminRepo});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _selectedStatus;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    final response =
        await widget.adminRepo.getAllOrders(status: _selectedStatus);

    if (mounted && response.isSuccess) {
      setState(() {
        _orders = response.data?['orders'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorSnackBar(context, response.error ?? 'Failed to load orders');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Status filter chips
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _selectedStatus == null,
                onSelected: (selected) {
                  setState(() => _selectedStatus = null);
                  _loadOrders();
                },
              ),
              const SizedBox(width: 8),
              ...['PENDING', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED', 'DISPUTED']
                  .map(
                (status) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: _selectedStatus == status,
                    onSelected: (selected) {
                      setState(
                          () => _selectedStatus = selected ? status : null);
                      _loadOrders();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: _orders.isEmpty
                      ? const Center(child: Text('No orders found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(order['service']?['title'] ??
                                    'Job #${order['id']}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Client: ${order['client']?['name']}'),
                                    Text(
                                        'Freelancer: ${order['freelancer']?['name']}'),
                                    Text('Amount: RM ${order['amount']}'),
                                    Chip(
                                      label: Text(order['status']),
                                      backgroundColor:
                                          _getStatusColor(order['status']),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green.withValues(alpha: 0.2);
      case 'DISPUTED':
        return Colors.red.withValues(alpha: 0.2);
      case 'IN_PROGRESS':
        return Colors.blue.withValues(alpha: 0.2);
      default:
        return Colors.grey.withValues(alpha: 0.2);
    }
  }
}

// ============================================================================
// WITHDRAWALS TAB
// ============================================================================
class _WithdrawalsTab extends StatefulWidget {
  final AdminRepository adminRepo;
  const _WithdrawalsTab({required this.adminRepo});

  @override
  State<_WithdrawalsTab> createState() => _WithdrawalsTabState();
}

class _WithdrawalsTabState extends State<_WithdrawalsTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _withdrawals = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    setState(() => _isLoading = true);

    // Fetch both PENDING and PAYOUT_FAILED
    final pendingResponse =
        await widget.adminRepo.getWithdrawals(status: 'PENDING');
    final failedResponse =
        await widget.adminRepo.getWithdrawals(status: 'PAYOUT_FAILED');

    if (mounted) {
      final pending = pendingResponse.data?['withdrawals'] ?? [];
      final failed = failedResponse.data?['withdrawals'] ?? [];

      setState(() {
        _withdrawals = [...pending, ...failed];
        // Sort by newest first
        _withdrawals.sort((a, b) {
          final dateA = DateTime.tryParse(a['createdAt']) ?? DateTime.now();
          final dateB = DateTime.tryParse(b['createdAt']) ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        _isLoading = false;
      });

      if (!pendingResponse.isSuccess || !failedResponse.isSuccess) {
        showErrorSnackBar(context, 'Failed to load some withdrawals');
      }
    }
  }

  Future<void> _approveWithdrawal(int withdrawalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Withdrawal'),
        content:
            const Text('Are you sure you want to approve this withdrawal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await widget.adminRepo.approveWithdrawal(withdrawalId);

      if (response.isSuccess) {
        if (mounted) {
          showSuccessSnackBar(context, 'Withdrawal approved');
        }
        _loadWithdrawals();
      } else {
        if (mounted) {
          showErrorSnackBar(
              context, response.error ?? 'Failed to approve withdrawal');
        }
      }
    }
  }

  Future<void> _rejectWithdrawal(int withdrawalId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Withdrawal'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason (Optional)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await widget.adminRepo.rejectWithdrawal(
        withdrawalId: withdrawalId,
        reason: reasonController.text.isEmpty ? null : reasonController.text,
      );

      if (response.isSuccess) {
        if (mounted) {
          showSuccessSnackBar(context, 'Withdrawal rejected');
        }
        _loadWithdrawals();
      } else {
        if (mounted) {
          showErrorSnackBar(
              context, response.error ?? 'Failed to reject withdrawal');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadWithdrawals,
      child: _withdrawals.isEmpty
          ? const Center(child: Text('No pending withdrawals'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _withdrawals.length,
              itemBuilder: (context, index) {
                final withdrawal = _withdrawals[index];
                final bankDetails =
                    withdrawal['bankDetails'] as Map<String, dynamic>?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RM ${withdrawal['amount']}',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        Text(
                            'Freelancer: ${withdrawal['freelancer']?['name']}'),
                        Text('Email: ${withdrawal['freelancer']?['email']}'),
                        Text(
                            'Current Balance: RM ${withdrawal['freelancer']?['balance']}'),
                        if (bankDetails != null) ...[
                          const SizedBox(height: 8),
                          const Text('Bank Details:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Account Name: ${bankDetails['accountName']}'),
                          Text(
                              'Account Number: ${bankDetails['accountNumber']}'),
                          Text('Bank: ${bankDetails['bankName']}'),
                        ],
                        const SizedBox(height: 12),
                        if (withdrawal['status'] == 'PAYOUT_FAILED') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Failed: ${withdrawal['payoutError'] ?? 'Unknown error'}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _approveWithdrawal(withdrawal['id']),
                                icon: Icon(
                                    withdrawal['status'] == 'PAYOUT_FAILED'
                                        ? Icons.refresh
                                        : Icons.check),
                                label: Text(
                                    withdrawal['status'] == 'PAYOUT_FAILED'
                                        ? 'Retry Payout'
                                        : 'Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _rejectWithdrawal(withdrawal['id']),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// DISPUTES TAB
// ============================================================================
class _DisputesTab extends StatefulWidget {
  final AdminRepository adminRepo;
  const _DisputesTab({required this.adminRepo});

  @override
  State<_DisputesTab> createState() => _DisputesTabState();
}

class _DisputesTabState extends State<_DisputesTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _disputes = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);

    final response = await widget.adminRepo.getDisputes();

    if (mounted && response.isSuccess) {
      setState(() {
        _disputes = response.data?['disputes'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorSnackBar(context, response.error ?? 'Failed to load disputes');
      }
    }
  }

  Future<void> _resolveDispute(int jobId) async {
    String? resolution;
    final refundController = TextEditingController();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Resolve Dispute'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resolution Type:'),
                ListTile(
                  title: const Text('Release (Give to Freelancer)'),
                  leading: Radio<String?>(
                    value: 'RELEASE',
                    groupValue: resolution,
                    onChanged: (value) {
                      setDialogState(() => resolution = value);
                    },
                  ),
                  onTap: () {
                    setDialogState(() => resolution = 'RELEASE');
                  },
                ),
                ListTile(
                  title: const Text('Refund (Return to Client)'),
                  leading: Radio<String?>(
                    value: 'REFUND',
                    groupValue: resolution,
                    onChanged: (value) {
                      setDialogState(() => resolution = value);
                    },
                  ),
                  onTap: () {
                    setDialogState(() => resolution = 'REFUND');
                  },
                ),
                ListTile(
                  title: const Text('Partial (Split Amount)'),
                  leading: Radio<String?>(
                    value: 'PARTIAL',
                    groupValue: resolution,
                    onChanged: (value) {
                      setDialogState(() => resolution = value);
                    },
                  ),
                  onTap: () {
                    setDialogState(() => resolution = 'PARTIAL');
                  },
                ),
                if (resolution == 'PARTIAL')
                  TextField(
                    controller: refundController,
                    decoration: const InputDecoration(
                      labelText: 'Refund Amount to Client',
                      hintText: 'Enter amount',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Resolution Notes (Optional)',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: resolution == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Resolve'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && resolution != null) {
      final response = await widget.adminRepo.resolveDispute(
        jobId: jobId,
        resolution: resolution!,
        refundAmount:
            resolution == 'PARTIAL' && refundController.text.isNotEmpty
                ? double.tryParse(refundController.text)
                : null,
        notes: notesController.text.isEmpty ? null : notesController.text,
      );

      if (response.isSuccess) {
        if (mounted) {
          showSuccessSnackBar(context, 'Dispute resolved');
        }
        _loadDisputes();
      } else {
        if (mounted) {
          showErrorSnackBar(
              context, response.error ?? 'Failed to resolve dispute');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDisputes,
      child: _disputes.isEmpty
          ? const Center(child: Text('No disputes'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _disputes.length,
              itemBuilder: (context, index) {
                final dispute = _disputes[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dispute['service']?['title'] ??
                              'Job #${dispute['id']}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Client: ${dispute['client']?['name']}'),
                        Text('Freelancer: ${dispute['freelancer']?['name']}'),
                        Text('Amount: RM ${dispute['amount']}'),
                        const SizedBox(height: 8),
                        if (dispute['disputeReason'] != null) ...[
                          const Text(
                            'Dispute Reason:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          Text(
                            dispute['disputeReason'],
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _resolveDispute(dispute['id']),
                            icon: const Icon(Icons.gavel),
                            label: const Text('Resolve Dispute'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Helper function
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.green),
  );
}
