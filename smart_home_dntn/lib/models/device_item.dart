class DeviceItem {
  final int id;
  final int userId;
  final String deviceName;
  final String deviceCode;
  final bool isOnline;
  final String? lastSeen;
  final String? createdAt;

  DeviceItem({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.deviceCode,
    required this.isOnline,
    this.lastSeen,
    this.createdAt,
  });

  factory DeviceItem.fromJson(Map<String, dynamic> json) {
    return DeviceItem(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      deviceName: json['deviceName']?.toString() ?? '',
      deviceCode: json['deviceCode']?.toString() ?? '',
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}
