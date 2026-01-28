class Withdrawal {
  final int id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int freelancerId;
  final double amount;
  final String status; // PENDING, APPROVED, REJECTED
  final Map<String, dynamic> bankDetails;
  final DateTime? processedAt;
  final int? processedById;
  final String? rejectionReason;
  final FreelancerInfo? freelancer;
  final ProcessedByInfo? processedBy;
  final String? payoutError;
  final String? billplzPayoutId;

  Withdrawal({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.freelancerId,
    required this.amount,
    required this.status,
    required this.bankDetails,
    this.processedAt,
    this.processedById,
    this.rejectionReason,
    this.freelancer,
    this.processedBy,
    this.payoutError,
    this.billplzPayoutId,
  });

  factory Withdrawal.fromJson(Map<String, dynamic> json) {
    return Withdrawal(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      freelancerId: json['freelancerId'] as int,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      bankDetails: json['bankDetails'] as Map<String, dynamic>,
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
      processedById: json['processedById'] as int?,
      rejectionReason: json['rejectionReason'] as String?,
      freelancer: json['freelancer'] != null
          ? FreelancerInfo.fromJson(json['freelancer'] as Map<String, dynamic>)
          : null,
      processedBy: json['processedBy'] != null
          ? ProcessedByInfo.fromJson(
              json['processedBy'] as Map<String, dynamic>)
          : null,
      payoutError: json['payoutError'] as String?,
      billplzPayoutId: json['billplzPayoutId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'freelancerId': freelancerId,
      'amount': amount,
      'status': status,
      'bankDetails': bankDetails,
      'processedAt': processedAt?.toIso8601String(),
      'processedById': processedById,
      'rejectionReason': rejectionReason,
    };
  }
}

class FreelancerInfo {
  final int id;
  final String name;
  final String email;
  final double? balance;

  FreelancerInfo({
    required this.id,
    required this.name,
    required this.email,
    this.balance,
  });

  factory FreelancerInfo.fromJson(Map<String, dynamic> json) {
    return FreelancerInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      balance:
          json['balance'] != null ? (json['balance'] as num).toDouble() : null,
    );
  }
}

class ProcessedByInfo {
  final int id;
  final String name;
  final String email;

  ProcessedByInfo({
    required this.id,
    required this.name,
    required this.email,
  });

  factory ProcessedByInfo.fromJson(Map<String, dynamic> json) {
    return ProcessedByInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}
