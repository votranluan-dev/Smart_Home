class AlertItem {
  final int id;
  final String alertType;
  final String message;
  final int gasValue;
  final String createdAt;

  AlertItem({
    required this.id,
    required this.alertType,
    required this.message,
    required this.gasValue,
    required this.createdAt,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] ?? 0,
      alertType: json['alertType']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      gasValue: json['gasValue'] ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}