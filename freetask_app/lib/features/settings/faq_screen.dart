import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soalan Lazim (FAQ)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFaqItem(
            'Bagaimana cara mendaftar sebagai freelancer?',
            'Untuk mendaftar sebagai freelancer, pergi ke tetapan pengguna, dan pilih untuk beralih ke mod Freelancer. Anda perlu mengisi maklumat bank, kategori kemahiran, dan lokasi bagi membolehkan anda ditugaskan.',
          ),
          _buildFaqItem(
            'Adakah bayaran saya selamat?',
            'Ya, setiap bayaran yang dibuat untuk apa-apa tugasan akan disimpan dalam sistem escrow kami. Wang hanya dilepaskan kepada freelancer selepas tugasan siap disahkan atau tiada bantahan.',
          ),
          _buildFaqItem(
            'Bolehkah saya membatalkan tempahan?',
            'Pembatalan tempahan boleh dibuat secara mutual (persetujuan kedua-dua pihak) atau anda boleh membuka bantahan (dispute) jika terdapat isu dengan servis yang dijanjikan. Admin akan meneliti dan akan memulangkan wang jika perlu.',
          ),
          _buildFaqItem(
            'Berapa lamakah tempoh pengesahan akaun bank?',
            'Pengesahan akaun bank kebiasaannya mengambil masa 1 ke 2 hari waktu bekerja. Anda akan disahkan oleh admin selepas pihak admin menyemak maklumat tersebut.',
          ),
          _buildFaqItem(
            'Bagaimana ingin hubungi pusat bantuan?',
            'Anda boleh terus menghantar e-mel ke masterfirst935@gmail.com dan pihak Sokongan Pelanggan (Customer Support) kami akan melayani anda secepat yang mungkin.',
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Masih mempunyai persoalan?\nSila e-mel masterfirst935@gmail.com',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: TextStyle(color: Colors.grey.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }
}
