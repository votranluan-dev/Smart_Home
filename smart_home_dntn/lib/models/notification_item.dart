class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String message;
  final int? gasValue;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.gasValue,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      gasValue: json['gasValue'],
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}
