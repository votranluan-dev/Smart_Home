class CustomerItem {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String? createdAt;

  CustomerItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.createdAt,
  });

  factory CustomerItem.fromJson(Map<String, dynamic> json) {
    return CustomerItem(
      id: json['id'] ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'CUSTOMER',
      createdAt: json['createdAt']?.toString(),
    );
  }
}
