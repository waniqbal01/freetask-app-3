import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_utils.dart';
import 'admin_job_model.dart';
import 'admin_repository.dart';
import 'overview_stats_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  OverviewStats? _stats;
  List<AdminJob> _disputedJobs = <AdminJob>[];
  bool _isLoading = true;
  String? _errorMessage;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        adminRepository.getOverview(),
        adminRepository.getDisputedJobs(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as OverviewStats;
        _disputedJobs = results[1] as List<AdminJob>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = friendlyErrorMessage(error);
      });
      showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadDashboard();
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'ACCEPTED':
        return 'Accepted';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'REJECTED':
        return 'Rejected';
      case 'DISPUTED':
        return 'Disputed';
      default:
        return status;
    }
  }

  Color _statusColor(String status, BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    switch (status.toUpperCase()) {
      case 'PENDING':
        return scheme.secondary;
      case 'ACCEPTED':
        return scheme.primary;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
      case 'REJECTED':
        return Colors.redAccent;
      case 'DISPUTED':
        return Colors.deepOrange;
      default:
        return scheme.outline;
    }
  }

  Future<void> _handleResolve(AdminJob job) async {
    final String? newStatus = await _showResolveDialog();
    if (newStatus == null) return;

    try {
      await adminRepository.resolveDispute(job.id, newStatus);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Job berjaya dikemas kini.');
      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    }
  }

  Future<String?> _showResolveDialog() {
    String selected = 'COMPLETED';
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: const Text('Pilih status baharu'),
              content: DropdownButton<String>(
                value: selected,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'COMPLETED', child: Text('Tandai sebagai selesai')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('Batalkan job')),
                ],
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    selected = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: const Text('Sahkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final stats = _stats;
    if (stats == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard('Users', stats.totalUsers, Colors.indigo),
            _buildStatCard('Clients', stats.totalClients, Colors.blue),
            _buildStatCard('Freelancers', stats.totalFreelancers, Colors.teal),
            _buildStatCard('Services', stats.totalServices, Colors.deepPurple),
            _buildStatCard('Jobs', stats.totalJobs, Colors.orange),
            _buildStatCard('Completed', stats.totalCompletedJobs, Colors.green),
            _buildStatCard('Disputes', stats.totalDisputedJobs, Colors.redAccent),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Jobs mengikut status',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.jobsByStatus.entries
              .map(
                (entry) => Chip(
                  label: Text('${_statusLabel(entry.key)} (${entry.value})'),
                  backgroundColor: _statusColor(entry.key, context).withValues(alpha: 0.1),
                  labelStyle: TextStyle(color: _statusColor(entry.key, context), fontWeight: FontWeight.w600),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDisputedJobs() {
    if (_disputedJobs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tiada job dispute buat masa ini.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _disputedJobs.map((AdminJob job) {
        final statusColor = _statusColor(job.status, context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Chip(
                      label: Text(_statusLabel(job.status)),
                      backgroundColor: statusColor.withValues(alpha: 0.12),
                      labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Client: ${job.clientName}'),
                Text('Freelancer: ${job.freelancerName}'),
                Text('Dibuat: ${_dateFormat.format(job.createdAt)}'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => _handleResolve(job),
                    child: const Text('Resolve'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorMessage ?? 'Ralat memuatkan data.'),
                ),
              )
            else ...[
              _buildOverviewSection(),
              const SizedBox(height: 24),
              Text(
                'Job dalam dispute',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDisputedJobs(),
            ],
          ],
        ),
      ),
    );
  }
}
