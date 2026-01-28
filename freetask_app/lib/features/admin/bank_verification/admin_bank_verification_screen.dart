import 'package:flutter/material.dart';
import '../admin_repository.dart';

class AdminBankVerificationScreen extends StatefulWidget {
  final AdminRepository adminRepository;

  const AdminBankVerificationScreen({
    super.key,
    required this.adminRepository,
  });

  @override
  State<AdminBankVerificationScreen> createState() =>
      _AdminBankVerificationScreenState();
}

class _AdminBankVerificationScreenState
    extends State<AdminBankVerificationScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await widget.adminRepository.getPendingBankVerifications();

    if (!mounted) return;

    if (response.isSuccess) {
      setState(() {
        _users = response.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyUser(int userId, String name) async {
    // Optimistic update
    final index = _users.indexWhere((u) => u['id'] == userId);
    final user = index != -1 ? _users[index] : null;

    setState(() {
      _users.removeWhere((u) => u['id'] == userId);
    });

    final response = await widget.adminRepository.verifyBankDetails(userId);

    if (!mounted) return;

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bank details for $name verified!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Revert if failed
      if (user != null) {
        setState(() {
          _users.insert(index, user);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to verify: ${response.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Verification')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? const Center(
                      child: Text('No pending verifications'),
                    )
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(user['name'] ?? 'Unknown'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Bank: ${user['bankCode']}'),
                                Text('Account: ${user['bankAccount']}'),
                                Text('Holder: ${user['bankHolderName']}'),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _verifyUser(
                                user['id'],
                                user['name'] ?? 'User',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
