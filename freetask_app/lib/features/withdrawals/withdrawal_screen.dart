import 'package:flutter/material.dart';
import '../../core/utils/error_utils.dart';
import '../../models/withdrawal.dart';
import '../../services/http_client.dart';
import '../../features/auth/auth_repository.dart';
import 'withdrawal_repository.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  late final WithdrawalRepository _withdrawalRepo;

  double _balance = 0.0;
  List<Withdrawal> _withdrawals = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  final _amountController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  // final _bankNameController = TextEditingController(); // Replaced by _selectedBankCode

  String? _selectedBankCode;

  final Map<String, String> _banks = {
    'MBBEMYKL': 'Maybank',
    'BCBBMYKL': 'CIMB Bank',
    'PBBEMYKL': 'Public Bank',
    'RHBBMYKL': 'RHB Bank',
    'HLBBMYKL': 'Hong Leong Bank',
    'AMBBMYKL': 'AmBank',
    'BIMBMYKL': 'Bank Islam',
    'BKRM': 'Bank Rakyat',
    'BMMB': 'Bank Muamalat',
    'BSN': 'BSN',
  };

  @override
  void initState() {
    super.initState();
    final httpClient = HttpClient();
    _withdrawalRepo = WithdrawalRepository(dio: httpClient.dio);
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    // _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final balanceResponse = await _withdrawalRepo.getBalance();
    final withdrawalsResponse = await _withdrawalRepo.getMyWithdrawals();

    if (mounted) {
      setState(() {
        _balance = balanceResponse.data?['balance']?.toDouble() ?? 0.0;
        _withdrawals = withdrawalsResponse.data ?? [];
        _isLoading = false;

        // Pre-fill from verified profile if available
        final user = authRepository.currentUser;
        if (user != null) {
          if (_accountNameController.text.isEmpty) {
            _accountNameController.text = user.bankHolderName ?? '';
          }
          if (_accountNumberController.text.isEmpty) {
            _accountNumberController.text = user.bankAccount ?? '';
          }
          if (_selectedBankCode == null && user.bankCode != null) {
            _selectedBankCode = user.bankCode;
          }
        }
      });
    }
  }

  Future<void> _requestWithdrawal() async {
    final amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      showErrorSnackBar(context, 'Please enter a valid amount');
      return;
    }

    if (amount > _balance) {
      showErrorSnackBar(context, 'Insufficient balance');
      return;
    }

    if (_accountNameController.text.isEmpty ||
        _accountNumberController.text.isEmpty ||
        _selectedBankCode == null) {
      showErrorSnackBar(context, 'Please fill in all bank details');
      return;
    }

    setState(() => _isSubmitting = true);

    final response = await _withdrawalRepo.createWithdrawal(
      amount: amount,
      bankDetails: {
        'accountName': _accountNameController.text,
        'accountNumber': _accountNumberController.text,
        'bankCode': _selectedBankCode,
        'bankName': _banks[_selectedBankCode] ?? '',
      },
    );

    setState(() => _isSubmitting = false);

    if (response.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _amountController.clear();
        // Don't clear bank details if they are verified
        final user = authRepository.currentUser;
        if (user?.bankVerified != true) {
          _accountNameController.clear();
          _accountNumberController.clear();
          _selectedBankCode = null;
        }

        // Refresh data
        _loadData();
      }
    } else {
      if (mounted) {
        showErrorSnackBar(
            context, response.error ?? 'Failed to submit withdrawal request');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawals'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Balance Card
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Available Balance',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'RM ${_balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Request Withdrawal Form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Request Withdrawal',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              prefixText: 'RM ',
                              border: const OutlineInputBorder(),
                              hintText: 'Enter amount to withdraw',
                              helperText:
                                  'Available: RM ${_balance.toStringAsFixed(2)}',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Bank Account Details',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _accountNameController,
                            decoration: const InputDecoration(
                              labelText: 'Account Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _accountNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Account Number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedBankCode,
                            decoration: const InputDecoration(
                              labelText: 'Bank',
                              border: OutlineInputBorder(),
                            ),
                            items: _banks.entries.map((e) {
                              return DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedBankCode = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isSubmitting ? null : _requestWithdrawal,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(_isSubmitting
                                  ? 'Submitting...'
                                  : 'Submit Request'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Withdrawal History
                  const Text(
                    'Withdrawal History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_withdrawals.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No withdrawal history'),
                        ),
                      ),
                    )
                  else
                    ..._withdrawals.map((withdrawal) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _getStatusColor(withdrawal.status),
                              child: Icon(
                                _getStatusIcon(withdrawal.status),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              'RM ${withdrawal.amount.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${withdrawal.status}'),
                                Text(
                                    'Requested: ${_formatDate(withdrawal.createdAt)}'),
                                if (withdrawal.processedAt != null)
                                  Text(
                                      'Processed: ${_formatDate(withdrawal.processedAt!)}'),
                                if (withdrawal.rejectionReason != null)
                                  Text(
                                    'Reason: ${withdrawal.rejectionReason}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'PENDING':
      default:
        return Icons.pending;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
