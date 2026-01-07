import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage.dart';

const String nextStepsDismissedKey = 'role_selection_next_steps_dismissed';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _showNextSteps = true;

  @override
  void initState() {
    super.initState();
    _loadBannerState();
  }

  Future<void> _loadBannerState() async {
    final dismissed = await appStorage.read(nextStepsDismissedKey);
    if (!mounted) return;
    setState(() {
      _showNextSteps = dismissed != 'true';
    });
  }

  void _onRoleTap(String role) {
    setState(() {
      _selectedRole = role;
    });

    context.go('/register', extra: role);
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required List<String> bullets,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => _onRoleTap(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isSelected ? Colors.indigo : const Color(0xFFE0E0E0),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? Colors.white : Colors.indigo,
            ),
            const SizedBox(height: 16),
            Text(
              role,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...bullets.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.indigo.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Peranan'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda ingin mendaftar sebagai?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (_showNextSteps)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag_rounded, color: Colors.indigo),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Langkah seterusnya:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text('1. Daftar akaun atau log masuk'),
                          Text('2. Lengkapkan profil anda'),
                          Text(
                              '3. (Client) Pilih servis atau post job pertama'),
                          Text('4. (Freelancer) Tetapkan servis/skill anda'),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        setState(() => _showNextSteps = false);
                        await appStorage.write(nextStepsDismissedKey, 'true');
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  _buildRoleCard(
                    role: 'Client',
                    icon: Icons.business_center_outlined,
                    bullets: const [
                      'Upah freelancer untuk servis & job custom',
                      'Bayar guna sistem escrow selamat',
                      'Jejak status kerja & pembayaran',
                    ],
                  ),
                  _buildRoleCard(
                    role: 'Freelancer',
                    icon: Icons.person_outline,
                    bullets: const [
                      'Terima job dari client',
                      'Jana pendapatan dari kemahiran anda',
                      'Bina reputasi & rating',
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sudah ada akaun? Log masuk'),
            ),
          ],
        ),
      ),
    );
  }
}
