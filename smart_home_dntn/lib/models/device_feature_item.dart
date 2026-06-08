class DeviceFeatureItem {
  final int id;
  final int deviceId;
  final String featureKey;
  final String featureName;
  bool isEnabled;
  final String? createdAt;
  final String? updatedAt;

  DeviceFeatureItem({
    required this.id,
    required this.deviceId,
    required this.featureKey,
    required this.featureName,
    required this.isEnabled,
    this.createdAt,
    this.updatedAt,
  });

  factory DeviceFeatureItem.fromJson(Map<String, dynamic> json) {
    return DeviceFeatureItem(
      id: json['id'] ?? 0,
      deviceId: json['deviceId'] ?? 0,
      featureKey: json['featureKey']?.toString() ?? '',
      featureName: json['featureName']?.toString() ?? '',
      isEnabled: json['isEnabled'] == true,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}
