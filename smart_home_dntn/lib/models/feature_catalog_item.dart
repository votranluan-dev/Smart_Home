class FeatureCatalogItem {
  final int id;
  final String featureKey;
  final String featureName;
  final String description;
  final bool allowQuantity;
  final bool isActive;
  final String? createdAt;

  FeatureCatalogItem({
    required this.id,
    required this.featureKey,
    required this.featureName,
    required this.description,
    required this.allowQuantity,
    required this.isActive,
    this.createdAt,
  });

  factory FeatureCatalogItem.fromJson(Map<String, dynamic> json) {
    return FeatureCatalogItem(
      id: json['id'] ?? 0,
      featureKey: json['featureKey']?.toString() ?? '',
      featureName: json['featureName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      allowQuantity: json['allowQuantity'] == true,
      isActive: json['isActive'] == true,
      createdAt: json['createdAt']?.toString(),
    );
  }
}
