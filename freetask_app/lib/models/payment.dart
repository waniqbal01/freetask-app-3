class Payment {
  final int id;
  final int jobId;
  final double amount;
  final String status; // PENDING, COMPLETED, FAILED, REFUNDED
  final String? paymentMethod;
  final String? paymentGateway;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.status,
    this.paymentMethod,
    this.paymentGateway,
    this.transactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      jobId: json['jobId'] as int,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      paymentMethod: json['paymentMethod'] as String?,
      paymentGateway: json['paymentGateway'] as String?,
      transactionId: json['transactionId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'amount': amount,
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentGateway': paymentGateway,
      'transactionId': transactionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'PENDING';
  bool get isCompleted => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';
  bool get isRefunded => status == 'REFUNDED';
}
