class DoorAccessLogItem {
  final int id;
  final int deviceId;
  final String cardUid;
  final String cardName;
  final String status;
  final String message;
  final String createdAt;

  DoorAccessLogItem({
    required this.id,
    required this.deviceId,
    required this.cardUid,
    required this.cardName,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory DoorAccessLogItem.fromJson(Map<String, dynamic> json) {
    return DoorAccessLogItem(
      id: json['id'] ?? 0,
      deviceId: json['deviceId'] ?? 0,
      cardUid: json['cardUid']?.toString() ?? '',
      cardName: json['cardName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  bool get isGranted => status.toUpperCase() == 'GRANTED';
}
