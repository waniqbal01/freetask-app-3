import 'dart:async';

class Service {
  const Service({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.rating,
    required this.deliveryDays,
    required this.includes,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final double rating;
  final int deliveryDays;
  final List<String> includes;
}

class ServicesRepository {
  ServicesRepository();

  static final List<Service> _mockServices = <Service>[
    const Service(
      id: 'design-001',
      title: 'Logo Design Premium',
      description: 'Reka bentuk logo profesional dengan 3 konsep dan revisi tanpa had.',
      category: 'Design',
      price: 350.0,
      rating: 4.9,
      deliveryDays: 5,
      includes: <String>[
        '3 konsep awal',
        'Fail sumber vektor',
        'Mockup persembahan',
        'Revisi tanpa had',
      ],
    ),
    const Service(
      id: 'writing-002',
      title: 'Penulisan Artikel SEO',
      description: 'Artikel 1500 patah perkataan dengan penyelidikan kata kunci dan SEO on-page.',
      category: 'Penulisan',
      price: 220.0,
      rating: 4.7,
      deliveryDays: 3,
      includes: <String>[
        'Penyelidikan kata kunci',
        'Artikel 1500 patah perkataan',
        'Optimasi meta tag',
        '2 kali semakan',
      ],
    ),
    const Service(
      id: 'dev-003',
      title: 'Landing Page Responsif',
      description: 'Landing page moden dengan integrasi borang dan analitik asas.',
      category: 'Pembangunan',
      price: 780.0,
      rating: 4.8,
      deliveryDays: 7,
      includes: <String>[
        'Reka bentuk responsif',
        'Integrasi borang hubungi',
        'Pemasangan analitik asas',
        'Tutorial pengurusan kandungan',
      ],
    ),
    const Service(
      id: 'marketing-004',
      title: 'Kempen Media Sosial 1 Bulan',
      description: 'Pengurusan 3 platform media sosial dengan kandungan tersusun.',
      category: 'Pemasaran',
      price: 650.0,
      rating: 4.6,
      deliveryDays: 30,
      includes: <String>[
        'Kalender kandungan bulanan',
        '12 posting grafik',
        '4 video pendek',
        'Laporan prestasi mingguan',
      ],
    ),
  ];

  Future<List<Service>> getServices({String? query, String? category}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final lowerQuery = query?.toLowerCase().trim();
    final filtered = _mockServices.where((Service service) {
      final matchesQuery = lowerQuery == null || lowerQuery.isEmpty
          ? true
          : service.title.toLowerCase().contains(lowerQuery) ||
              service.description.toLowerCase().contains(lowerQuery);
      final matchesCategory =
          category == null || category.isEmpty || category == 'Semua'
              ? true
              : service.category.toLowerCase() == category.toLowerCase();
      return matchesQuery && matchesCategory;
    }).toList();

    filtered.sort((Service a, Service b) => a.title.compareTo(b.title));
    return filtered;
  }

  Future<Service?> getServiceById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      return _mockServices.firstWhere((Service service) => service.id == id);
    } on StateError {
      return null;
    }
  }

  List<String> getCategories() {
    final categories = _mockServices.map((Service service) => service.category).toSet().toList()
      ..sort();
    return categories;
  }
}

final servicesRepository = ServicesRepository();
