import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/alert_item.dart';
import '../models/notification_item.dart';
import '../models/user_session.dart';
import '../models/customer_item.dart';
import '../models/device_item.dart';
import '../models/device_feature_item.dart';
import '../models/feature_catalog_item.dart';
import '../models/door_access_log_item.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.26:8080';

  Future<List<DoorAccessLogItem>> getDoorAccessLogs(int deviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/door-access-logs?deviceId=$deviceId'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map(
            (item) => DoorAccessLogItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception('Không tải được lịch sử mở cửa');
  }

  Future<void> updateUserProfile({
    required int userId,
    required String fullName,
    required String email,
    required String phone,
    String password = '',
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'ok') {
      return;
    }

    throw Exception(data['message'] ?? 'Không cập nhật được thông tin');
  }

  Future<int> createDeviceForCustomer({
    required int customerId,
    required String deviceName,
    required String deviceCode,
    required String deviceToken,
  }) async {
    final url = Uri.parse('$baseUrl/admin/customers/$customerId/devices');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'deviceName': deviceName,
        'deviceCode': deviceCode,
        'deviceToken': deviceToken,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Không tạo được thiết bị');
    }

    return data['deviceId'];
  }

  Future<void> deleteDeviceFeature(int featureId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/device-features/$featureId'),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'ok') {
      print('DELETE DEVICE FEATURE OK: $featureId');
      return;
    }

    throw Exception(data['message'] ?? 'Không xóa được chức năng');
  }

  Future<void> addFeatureFromCatalogToDevice({
    required int deviceId,
    required String featureKey,
    required int quantity,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/devices/$deviceId/features/from-catalog'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'featureKey': featureKey, 'quantity': quantity}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'ok') {
      print('ADD FEATURE OK: $featureKey - quantity: $quantity');
      return;
    }

    throw Exception(data['message'] ?? 'Không thêm được chức năng');
  }

  Future<List<FeatureCatalogItem>> getFeatureCatalog() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/feature-catalog'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map(
            (item) => FeatureCatalogItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('Failed to fetch feature catalog');
    }
  }

  Future<void> deleteCustomer(int customerId) async {
    final url = '$baseUrl/admin/customers/$customerId';

    print('DELETE CUSTOMER URL: $url');

    final response = await http.delete(Uri.parse(url));

    print('DELETE CUSTOMER STATUS: ${response.statusCode}');
    print('DELETE CUSTOMER BODY: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'ok') {
      return;
    }

    throw Exception(
      data['detail'] ?? data['message'] ?? 'Không xóa được khách hàng',
    );
  }

  Future<List<DeviceItem>> getCustomerDevices(int customerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/customers/$customerId/devices'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map((item) => DeviceItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Không tải được danh sách thiết bị');
  }

  Future<List<DeviceFeatureItem>> getDeviceFeatures(int deviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/devices/$deviceId/features'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map(
            (item) => DeviceFeatureItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception('Không tải được danh sách chức năng');
  }

  Future<void> updateDeviceFeature({
    required int featureId,
    required bool isEnabled,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/device-features/$featureId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'isEnabled': isEnabled}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'ok') {
      return;
    }

    throw Exception(data['message'] ?? 'Không cập nhật được chức năng');
  }

  Future<void> createCustomer({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/customers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
        'phone': phone,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'ok') {
      return;
    }

    throw Exception(data['message'] ?? 'Không tạo được khách hàng');
  }

  Future<List<CustomerItem>> getCustomers() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/customers'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map((item) => CustomerItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to fetch customers');
    }
  }

  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password.trim()}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Login failed');
    }

    return UserSession.fromJson(data['user']);
  }

  Future<List<NotificationItem>> getNotifications(int deviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications?deviceId=$deviceId'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map(
            (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('Failed to fetch notifications');
    }
  }

  Future<Map<String, dynamic>> getDeviceState(int userId) async {
    final url = Uri.parse('$baseUrl/device?userId=$userId');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load device state');
    }

    return jsonDecode(response.body);
  }

  Future<List<AlertItem>> getAlerts(int deviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/alerts?deviceId=$deviceId'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map((item) => AlertItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to fetch alerts');
    }
  }

  Future<void> sendCommand({
    required int deviceId,
    required Map<String, dynamic> command,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/device?deviceId=$deviceId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(command),
    );

    if (response.statusCode == 200) {
      print('Command sent to deviceId=$deviceId: $command');
      return;
    }

    print('Failed to send command: ${response.statusCode}');
    print(response.body);

    throw Exception('Gửi lệnh thất bại');
  }

  Future<void> updateThreshold(int deviceId, double value) async {
    await sendCommand(deviceId: deviceId, command: {'threshold': value});

    print('Send threshold to deviceId=$deviceId: $value');
  }

  Future<void> updateLight1(int deviceId, bool value) async {
    await sendCommand(deviceId: deviceId, command: {'light1': value});
  }

  Future<void> updateLight2(int deviceId, bool value) async {
    await sendCommand(deviceId: deviceId, command: {'light2': value});
  }

  Future<void> updateMq2Enabled(int deviceId, bool value) async {
    await sendCommand(deviceId: deviceId, command: {'mq2Enabled': value});
  }

  Future<void> updateAutoMode(int deviceId, bool value) async {
    await sendCommand(deviceId: deviceId, command: {'autoMode': value});
  }

  Future<void> updateCurtainIn(int deviceId, bool value) async {
    await sendCommand(deviceId: deviceId, command: {'curtainIn': value});
  }

  Future<void> updateCurtainOut(int deviceId, bool value) async {
    await sendCommand(deviceId: deviceId, command: {'curtainOut': value});
  }
}
