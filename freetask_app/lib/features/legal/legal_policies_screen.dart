import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class LegalPoliciesScreen extends StatelessWidget {
  const LegalPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Polisi & Syarat'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Terma Perkhidmatan'),
              Tab(text: 'Dasar Privasi (PDPA)'),
              Tab(text: 'Polisi Pemulangan / Pembatalan'),
              Tab(text: 'Polisi Pertikaian'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TermsOfServiceTab(),
            _PrivacyPolicyTab(),
            _RefundPolicyTab(),
            _DisputePolicyTab(),
          ],
        ),
      ),
    );
  }
}

class _TermsOfServiceTab extends StatelessWidget {
  const _TermsOfServiceTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Terma Perkhidmatan (Terms of Service)',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          const Text(
            'Dengan menggunakan aplikasi Freetask, anda bersetuju dengan terma dan syarat yang ditetapkan. '
            'Freetask merupakan platform perkongsian kerja yang menghubungkan pelanggan dengan freelancer. '
            'Pengguna tertakluk kepada peraturan yang mematuhi undang-undang Malaysia dan bertanggungjawab penuh '
            'ke atas kualiti tugas dan pembayaran yang diamanahkan melalui sistem escrow kami.\n\n'
            'Caj Platform:\n'
            'Freetask mengenakan caj platform sebanyak 7% untuk setiap tempahan kerja atau servis yang berjaya disiapkan. '
            'Caj ini hanya akan ditolak secara automatik daripada jumlah bayaran akhir atau pendapatan yang diterima oleh freelancer.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PrivacyPolicyTab extends StatelessWidget {
  const _PrivacyPolicyTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dasar Privasi & Pematuhan PDPA',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          const Text(
            'Selaras dengan Akta Perlindungan Data Peribadi 2010 (PDPA) yang berkuatkuasa di Malaysia, '
            'kami komited untuk melindungi data peribadi anda. Data seperti nama, e-mel, dan nombor '
            'telefon hanya akan digunakan untuk tujuan operasi aplikasi Freetask dan tidak akan dikongsi '
            'kepada pihak ketiga tanpa kebenaran anda.\n\n'
            'Dengan mendaftar, anda bersetuju memberi keizinan kepada Freetask untuk menyimpan dan memproses maklumat peribadi anda.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RefundPolicyTab extends StatelessWidget {
  const _RefundPolicyTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Polisi Pemulangan Wang & Pembatalan',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          const Text(
            '1. Pembatalan hanya dibenarkan jika persetujuan bersama (mutual) tercapai antara pelanggan dan freelancer peringkat kerja belum dimulakan.\n'
            '2. Kesemua dana (kecuali caj gerbang pembayaran, jika terpakai) akan dipulangkan ke baki akaun (wallet) pelanggan.\n'
            '3. Pemulangan wang hanya diproses menerusi dompet dalaman secara automatik bagi tempahan yang dibatalkan oleh pihak kami atau tidak diterima oleh freelancer.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DisputePolicyTab extends StatelessWidget {
  const _DisputePolicyTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Polisi Pertikaian (Dispute)',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          const Text(
            'Jika terdapat pertikaian (dispute) berhubung penyelesaian tugasan:\n\n'
            '1. Pengguna perlu menekan butang "Dispute" di dalam halaman butiran job berkenaan.\n'
            '2. Satu huraian sekurang-kurangnya 10 perkataan perlu dikemukakan sebagai bukti masalah.\n'
            '3. Dana escrow akan terus dipegang (HELD) sehingga pertikaian diselesaikan.\n'
            '4. Keputusan yang dibuat oleh pihak pentadbir Freetask (sama ada dipulangkan kepada pelanggan atau dilepaskan kepada freelancer) adalah muktamad.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
