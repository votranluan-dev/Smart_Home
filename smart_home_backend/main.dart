import 'dart:convert';
import 'dart:io';

import 'services/db_service.dart';

void main() async {
  final db = DbService();
  await db.connect();

  print('=== Smart Home Backend with MySQL ===');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('Backend listening on http://localhost:8080');

  await for (HttpRequest request in server) {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Origin, Content-Type, Accept, Authorization',
    );

    // Trình duyệt Flutter Web sẽ gửi OPTIONS trước khi gọi DELETE/PUT
    if (request.method == 'OPTIONS') {
      request.response..statusCode = 204;
      await request.response.close();
      continue;
    }
    
    // ======================================================
    // GET /door-access-logs?deviceId=...
    // Flutter app lấy lịch sử mở cửa theo thiết bị
    // ======================================================
    if (request.method == 'GET' && request.uri.path == '/door-access-logs') {
      try {
        final deviceIdText = request.uri.queryParameters['deviceId'];

        if (deviceIdText == null || deviceIdText.isEmpty) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Missing deviceId'}),
            );

          await request.response.close();
          continue;
        }

        final deviceId = int.tryParse(deviceIdText);

        if (deviceId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid deviceId'}),
            );

          await request.response.close();
          continue;
        }

        final logs = await db.getDoorAccessLogs(deviceId: deviceId, limit: 50);

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(logs));

        await request.response.close();

        print('GET DOOR ACCESS LOGS: deviceId=$deviceId, ${logs.length} logs');
      } catch (e) {
        print('GET DOOR ACCESS LOGS ERROR: $e');

        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get door access logs',
              'detail': e.toString(),
            }),
          );

        await request.response.close();
      }

      continue;
    }

    // ======================================================
    // POST /esp32/door-access
    // ESP32 gửi lịch sử quẹt thẻ RFID
    // ======================================================
    if (request.method == 'POST' && request.uri.path == '/esp32/door-access') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);

        final deviceCode = data['deviceCode']?.toString() ?? '';
        final deviceToken = data['deviceToken']?.toString() ?? '';
        final cardUid = data['cardUid']?.toString() ?? '';
        final cardName = data['cardName']?.toString();
        final status = data['status']?.toString() ?? '';
        final message = data['message']?.toString();

        if (deviceCode.isEmpty || deviceToken.isEmpty) {
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Missing deviceCode or deviceToken',
              }),
            );

          await request.response.close();
          continue;
        }

        if (cardUid.isEmpty || status.isEmpty) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Missing cardUid or status',
              }),
            );

          await request.response.close();
          continue;
        }

        final deviceId = await db.verifyDevice(
          deviceCode: deviceCode,
          deviceToken: deviceToken,
        );

        if (deviceId == null) {
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Invalid deviceCode or deviceToken',
              }),
            );

          await request.response.close();
          continue;
        }

        await db.insertDoorAccessLog(
          deviceId: deviceId,
          cardUid: cardUid,
          cardName: cardName,
          status: status,
          message: message,
        );

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({'status': 'ok', 'message': 'Door access log saved'}),
          );

        await request.response.close();

        print(
          'DOOR ACCESS: deviceId=$deviceId, cardUid=$cardUid, status=$status',
        );
      } catch (e) {
        print('DOOR ACCESS ERROR: $e');

        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot save door access log',
              'detail': e.toString(),
            }),
          );

        await request.response.close();
      }

      continue;
    }

    // ======================================================
    // PUT /users/:id
    // Cập nhật thông tin tài khoản người dùng
    // ======================================================
    if (request.method == 'PUT' && request.uri.pathSegments.length == 2) {
      final segments = request.uri.pathSegments;

      if (segments[0] == 'users') {
        try {
          final userId = int.tryParse(segments[1]);

          if (userId == null) {
            request.response
              ..statusCode = 400
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({'status': 'error', 'message': 'Invalid user id'}),
              );

            await request.response.close();
            continue;
          }

          final body = await utf8.decoder.bind(request).join();
          final data = jsonDecode(body);

          final fullName = data['fullName']?.toString().trim() ?? '';
          final email = data['email']?.toString().trim() ?? '';
          final phone = data['phone']?.toString().trim() ?? '';
          final password = data['password']?.toString().trim() ?? '';

          if (fullName.isEmpty || email.isEmpty) {
            request.response
              ..statusCode = 400
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'status': 'error',
                  'message': 'Full name and email are required',
                }),
              );

            await request.response.close();
            continue;
          }

          await db.updateUserProfile(
            userId: userId,
            fullName: fullName,
            email: email,
            phone: phone,
            password: password,
          );

          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'ok', 'message': 'User profile updated'}),
            );

          await request.response.close();

          print('UPDATE USER OK: userId=$userId');
        } catch (e) {
          print('UPDATE USER ERROR: $e');

          request.response
            ..statusCode = 500
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Cannot update user profile',
                'detail': e.toString(),
              }),
            );

          await request.response.close();
        }

        continue;
      }
    }

    // =====================================================
    // POST /admin/customers/:customerId/devices
    // Tạo thiết bị mới cho khách hàng
    // =====================================================
    if (request.method == 'POST' &&
        request.uri.pathSegments.length == 4 &&
        request.uri.pathSegments[0] == 'admin' &&
        request.uri.pathSegments[1] == 'customers' &&
        request.uri.pathSegments[3] == 'devices') {
      try {
        final customerId = int.parse(request.uri.pathSegments[2]);

        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);

        final deviceName = data['deviceName']?.toString().trim() ?? '';
        final deviceCode = data['deviceCode']?.toString().trim() ?? '';
        final deviceToken = data['deviceToken']?.toString().trim() ?? '';

        if (deviceName.isEmpty || deviceCode.isEmpty || deviceToken.isEmpty) {
          throw Exception('Missing device information');
        }

        final deviceId = await db.createDeviceForCustomer(
          userId: customerId,
          deviceName: deviceName,
          deviceCode: deviceCode,
          deviceToken: deviceToken,
        );

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok', 'deviceId': deviceId}));

        await request.response.close();

        print('CREATE DEVICE OK: customerId=$customerId, deviceId=$deviceId');
      } catch (e) {
        final isDuplicateDeviceCode =
            e.toString().contains('Duplicate') ||
            e.toString().contains('device_code');

        request.response
          ..statusCode = isDuplicateDeviceCode ? 409 : 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': isDuplicateDeviceCode
                  ? 'Device code already exists'
                  : 'Cannot create device',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('CREATE DEVICE ERROR: $e');
      }

      continue;
    }

    // =====================================================
    // DELETE /admin/device-features/:featureId
    // Xóa hẳn một chức năng khỏi thiết bị
    // =====================================================
    if (request.method == 'DELETE' &&
        request.uri.pathSegments.length == 3 &&
        request.uri.pathSegments[0] == 'admin' &&
        request.uri.pathSegments[1] == 'device-features') {
      try {
        final featureId = int.parse(request.uri.pathSegments[2]);

        await db.deleteDeviceFeature(featureId);

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));

        await request.response.close();

        print('DELETE DEVICE FEATURE OK: $featureId');
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot delete device feature',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('DELETE DEVICE FEATURE ERROR: $e');
      }

      continue;
    }

    // =====================================================
    // POST /admin/devices/:deviceId/features/from-catalog
    // Thêm chức năng từ kho vào thiết bị khách
    // =====================================================
    if (request.method == 'POST' &&
        request.uri.pathSegments.length == 5 &&
        request.uri.pathSegments[0] == 'admin' &&
        request.uri.pathSegments[1] == 'devices' &&
        request.uri.pathSegments[3] == 'features' &&
        request.uri.pathSegments[4] == 'from-catalog') {
      try {
        final deviceId = int.parse(request.uri.pathSegments[2]);

        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);

        final featureKey = data['featureKey']?.toString() ?? '';
        final quantity = int.tryParse(data['quantity']?.toString() ?? '1') ?? 1;

        if (featureKey.isEmpty) {
          throw Exception('featureKey is required');
        }

        await db.addFeatureFromCatalogToDevice(
          deviceId: deviceId,
          featureKey: featureKey,
          quantity: quantity,
        );

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));

        await request.response.close();

        print(
          'ADD FEATURE FROM CATALOG OK: deviceId=$deviceId, featureKey=$featureKey, quantity=$quantity',
        );
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot add feature from catalog',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('ADD FEATURE FROM CATALOG ERROR: $e');
      }

      continue;
    }

    // ======================================================
    // GET /admin/customers/:id/devices
    // Admin xem danh sách thiết bị của một khách hàng
    // ======================================================
    if (request.method == 'GET' &&
        request.uri.pathSegments.length == 4 &&
        request.uri.pathSegments[0] == 'admin' &&
        request.uri.pathSegments[1] == 'customers' &&
        request.uri.pathSegments[3] == 'devices') {
      try {
        final customerId = int.tryParse(request.uri.pathSegments[2]);

        if (customerId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid customer id'}),
            );

          await request.response.close();
          continue;
        }

        final devices = await db.getDevicesByCustomer(customerId);

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(devices));

        await request.response.close();

        print('GET CUSTOMER DEVICES OK: $customerId');
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get customer devices',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('GET CUSTOMER DEVICES ERROR: $e');
      }

      continue;
    }

    // =====================================================
    // GET /admin/feature-catalog
    // Lấy kho chức năng chung của công ty
    // =====================================================
    if (request.method == 'GET' &&
        request.uri.path == '/admin/feature-catalog') {
      try {
        final features = await db.getFeatureCatalog();

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(features));

        await request.response.close();
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get feature catalog',
              'detail': e.toString(),
            }),
          );

        await request.response.close();
      }

      continue;
    }

    // ======================================================
    // GET /admin/devices/:id/features
    // Admin xem danh sách chức năng của thiết bị
    // ======================================================
    if (request.method == 'GET' &&
        request.uri.pathSegments.length == 4 &&
        request.uri.pathSegments[0] == 'admin' &&
        request.uri.pathSegments[1] == 'devices' &&
        request.uri.pathSegments[3] == 'features') {
      try {
        final deviceId = int.tryParse(request.uri.pathSegments[2]);

        if (deviceId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid device id'}),
            );

          await request.response.close();
          continue;
        }

        final features = await db.getDeviceFeatures(deviceId);

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(features));

        await request.response.close();

        print('GET DEVICE FEATURES OK: $deviceId');
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get device features',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('GET DEVICE FEATURES ERROR: $e');
      }

      continue;
    }

    // ======================================================
    // PUT /admin/device-features/:id
    // Admin bật/tắt một chức năng của thiết bị
    // ======================================================
    if (request.method == 'PUT' &&
        request.uri.pathSegments.length == 3 &&
        request.uri.pathSegments[0] == 'admin' &&
        request.uri.pathSegments[1] == 'device-features') {
      try {
        final featureId = int.tryParse(request.uri.pathSegments[2]);

        if (featureId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid feature id'}),
            );

          await request.response.close();
          continue;
        }

        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);

        final isEnabled = data['isEnabled'];

        if (isEnabled is! bool) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'isEnabled must be boolean',
              }),
            );

          await request.response.close();
          continue;
        }

        await db.updateDeviceFeature(
          featureId: featureId,
          isEnabled: isEnabled,
        );

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));

        await request.response.close();

        print('UPDATE DEVICE FEATURE OK: $featureId -> $isEnabled');
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot update device feature',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('UPDATE DEVICE FEATURE ERROR: $e');
      }

      continue;
    }

    // ======================================================
    // DELETE /admin/customers/:id
    // Admin xóa tài khoản khách hàng
    // ======================================================
    if (request.method == 'DELETE' &&
        request.uri.pathSegments.length == 3 &&
        request.uri.pathSegments[0] == 'admin' &&
        request.uri.pathSegments[1] == 'customers') {
      try {
        final customerId = int.tryParse(request.uri.pathSegments[2]);

        if (customerId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid customer id'}),
            );

          await request.response.close();
          continue;
        }

        await db.deleteCustomer(customerId);

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));

        await request.response.close();

        print('DELETE CUSTOMER OK: $customerId');
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot delete customer',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('DELETE CUSTOMER ERROR: $e');
      }

      continue;
    }

    // ======================================================
    // POST /admin/customers
    // Admin tạo tài khoản khách hàng mới
    // ======================================================
    if (request.method == 'POST' && request.uri.path == '/admin/customers') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);

        final fullName = data['fullName']?.toString().trim();
        final email = data['email']?.toString().trim();
        final password = data['password']?.toString();
        final phone = data['phone']?.toString().trim() ?? '';

        if (fullName == null ||
            fullName.isEmpty ||
            email == null ||
            email.isEmpty ||
            password == null ||
            password.isEmpty) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Missing fullName, email or password',
              }),
            );

          await request.response.close();
          continue;
        }

        final newCustomerId = await db.createCustomer(
          fullName: fullName,
          email: email,
          password: password,
          phone: phone,
        );

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok', 'customerId': newCustomerId}));

        await request.response.close();

        print('CREATE CUSTOMER OK: $email');
      } catch (e) {
        final isDuplicateEmail = e.toString().contains('Email already exists');

        request.response
          ..statusCode = isDuplicateEmail ? 409 : 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': isDuplicateEmail
                  ? 'Email already exists'
                  : 'Cannot create customer',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('CREATE CUSTOMER ERROR: $e');
      }

      continue;
    }

    // ======================================================
    // GET /admin/customers
    // Lấy danh sách tài khoản khách hàng
    // ======================================================
    if (request.method == 'GET' && request.uri.path == '/admin/customers') {
      try {
        final customers = await db.getCustomers();

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(customers));

        await request.response.close();
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get customers',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('GET CUSTOMERS ERROR: $e');
      }

      continue;
    }

    // ======================================================
    // POST /login
    // Đăng nhập tài khoản Admin / Customer
    // ======================================================
    if (request.method == 'POST' && request.uri.path == '/login') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);

        final email = data['email']?.toString().trim();
        final password = data['password']?.toString();

        if (email == null ||
            email.isEmpty ||
            password == null ||
            password.isEmpty) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Missing email or password',
              }),
            );

          await request.response.close();
          continue;
        }

        final user = await db.loginUser(email: email, password: password);

        if (user == null) {
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Invalid email or password',
              }),
            );

          await request.response.close();
          continue;
        }

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok', 'user': user}));

        await request.response.close();

        print('LOGIN OK: ${user['email']} - ${user['role']}');
      } catch (e) {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Login error',
              'detail': e.toString(),
            }),
          );

        await request.response.close();

        print('LOGIN ERROR: $e');
      }

      continue;
    }

    // ======================================================
    // GET /device?userId=...
    // Flutter app lấy trạng thái thiết bị theo tài khoản khách đang đăng nhập
    // ======================================================
    if (request.method == 'GET' && request.uri.path == '/device') {
      try {
        final userIdText = request.uri.queryParameters['userId'];

        if (userIdText == null || userIdText.isEmpty) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Missing userId'}),
            );

          await request.response.close();
          continue;
        }

        final userId = int.tryParse(userIdText);

        if (userId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid userId'}),
            );

          await request.response.close();
          continue;
        }

        final device = await db.getFirstDeviceByUserId(userId);

        if (device == null) {
          request.response
            ..statusCode = 404
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Customer has no device',
              }),
            );

          await request.response.close();
          continue;
        }

        final deviceId = device['id'] as int;
        final deviceState = await db.getDeviceState(deviceId);

        final responseData = {
          ...?deviceState,
          'deviceId': device['id'],
          'deviceName': device['deviceName'],
          'deviceCode': device['deviceCode'],
          'isOnline': device['isOnline'],
          'lastSeen': device['lastSeen'],
        };

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(responseData));

        await request.response.close();

        print('GET /device OK: userId=$userId, deviceId=$deviceId');
      } catch (e) {
        print('GET /device error: $e');

        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get device state',
              'detail': e.toString(),
            }),
          );

        await request.response.close();
      }

      continue;
    }

    // ======================================================
    // GET /alerts?deviceId=...
    // Flutter app lấy lịch sử cảnh báo gas theo thiết bị
    // ======================================================
    if (request.method == 'GET' && request.uri.path == '/alerts') {
      try {
        final deviceIdText = request.uri.queryParameters['deviceId'];

        if (deviceIdText == null || deviceIdText.isEmpty) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Missing deviceId'}),
            );

          await request.response.close();
          continue;
        }

        final deviceId = int.tryParse(deviceIdText);

        if (deviceId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid deviceId'}),
            );

          await request.response.close();
          continue;
        }

        final alerts = await db.getGasAlerts(deviceId: deviceId, limit: 50);

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(alerts));

        await request.response.close();

        print('GET /alerts: deviceId=$deviceId, ${alerts.length} alerts');
      } catch (e) {
        print('GET /alerts error: $e');

        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get alerts',
              'detail': e.toString(),
            }),
          );

        await request.response.close();
      }

      continue;
    }

    // ======================================================
    // GET /notifications?deviceId=...
    // Flutter app lấy thông báo theo thiết bị
    // ======================================================
    if (request.method == 'GET' && request.uri.path == '/notifications') {
      try {
        final deviceIdText = request.uri.queryParameters['deviceId'];

        if (deviceIdText == null || deviceIdText.isEmpty) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Missing deviceId'}),
            );

          await request.response.close();
          continue;
        }

        final deviceId = int.tryParse(deviceIdText);

        if (deviceId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid deviceId'}),
            );

          await request.response.close();
          continue;
        }

        final notifications = await db.getNotifications(
          deviceId: deviceId,
          limit: 50,
        );

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(notifications));

        await request.response.close();

        print(
          'GET /notifications: deviceId=$deviceId, ${notifications.length} items',
        );
      } catch (e) {
        print('GET /notifications error: $e');

        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get notifications',
              'detail': e.toString(),
            }),
          );

        await request.response.close();
      }

      continue;
    }

    // ======================================================
    // GET /esp32/device
    // ESP32 lấy lệnh/trạng thái từ backend
    // Có kiểm tra deviceCode + deviceToken
    // ======================================================
    if (request.method == 'GET' && request.uri.path == '/esp32/device') {
      try {
        final deviceCode = request.uri.queryParameters['deviceCode'];
        final deviceToken = request.uri.queryParameters['deviceToken'];

        if (deviceCode == null || deviceToken == null) {
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Missing deviceCode or deviceToken',
              }),
            );

          await request.response.close();

          print('ESP32 GET missing deviceCode/deviceToken');
          continue;
        }

        final deviceId = await db.verifyDevice(
          deviceCode: deviceCode,
          deviceToken: deviceToken,
        );

        if (deviceId == null) {
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Invalid deviceCode or deviceToken',
              }),
            );

          await request.response.close();

          print('ESP32 GET unauthorized: $deviceCode');
          continue;
        }

        final deviceState = await db.getDeviceState(deviceId);

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(deviceState ?? {}));

        await request.response.close();

        print('ESP32 verified and fetched device state: $deviceCode');
      } catch (e) {
        print('GET /esp32/device error: $e');

        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Cannot get ESP32 device state',
              'detail': e.toString(),
            }),
          );

        await request.response.close();
      }

      continue;
    }

    // ======================================================
    // POST /device?deviceId=...
    // Flutter app gửi lệnh điều khiển đúng thiết bị đang đăng nhập
    // ======================================================
    if (request.method == 'POST' && request.uri.path == '/device') {
      try {
        final deviceIdText = request.uri.queryParameters['deviceId'];

        if (deviceIdText == null || deviceIdText.isEmpty) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Missing deviceId'}),
            );

          await request.response.close();
          continue;
        }

        final deviceId = int.tryParse(deviceIdText);

        if (deviceId == null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'status': 'error', 'message': 'Invalid deviceId'}),
            );

          await request.response.close();
          continue;
        }

        final body = await utf8.decoder.bind(request).join();
        print('RAW APP BODY: $body');

        final data = jsonDecode(body);

        await db.updateStateFromApp(
          deviceId: deviceId,
          light1: data['light1'],
          light2: data['light2'],
          mq2Enabled: data['mq2Enabled'],
          autoMode: data['autoMode'],
          curtainIn: data['curtainIn'],
          curtainOut: data['curtainOut'],
          threshold: data['threshold'] == null
              ? null
              : (data['threshold'] as num).toInt(),
        );

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));

        await request.response.close();

        print('POST /device OK: deviceId=$deviceId, data=$data');
      } catch (e) {
        print('POST /device error: $e');

        request.response
          ..statusCode = 400
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'status': 'error',
              'message': 'Invalid app JSON body',
              'detail': e.toString(),
            }),
          );

        await request.response.close();
      }

      continue;
    }

    // ======================================================
    // POST /esp32/state
    // ESP32 gửi trạng thái thật lên backend
    // Có kiểm tra deviceCode + deviceToken
    // ======================================================
    if (request.method == 'POST' && request.uri.path == '/esp32/state') {
      try {
        final body = await utf8.decoder.bind(request).join();
        print('RAW ESP32 BODY: $body');

        final data = jsonDecode(body);

        final deviceCode = data['deviceCode'];
        final deviceToken = data['deviceToken'];

        if (deviceCode == null || deviceToken == null) {
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Missing deviceCode or deviceToken',
              }),
            );

          await request.response.close();

          print('ESP32 missing deviceCode/deviceToken');
          continue;
        }

        final deviceId = await db.verifyDevice(
          deviceCode: deviceCode.toString(),
          deviceToken: deviceToken.toString(),
        );

        if (deviceId == null) {
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Invalid deviceCode or deviceToken',
              }),
            );

          await request.response.close();

          print('ESP32 unauthorized: $deviceCode');
          continue;
        }

        await db.updateStateFromEsp32(
          deviceId: deviceId,
          gasValue: data['gasValue'] == null
              ? null
              : (data['gasValue'] as num).toInt(),
          light1: data['light1'],
          light2: data['light2'],
          mq2Enabled: data['mq2Enabled'],
          autoMode: data['autoMode'],
          curtainIn: data['curtainIn'],
          curtainOut: data['curtainOut'],
          isRaining: data['isRaining'],
        );

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));

        await request.response.close();

        print('ESP32 verified and updated MySQL state: $data');
      } catch (e) {
        print('POST /esp32/state error: $e');

        try {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'error',
                'message': 'Invalid ESP32 JSON body',
                'detail': e.toString(),
              }),
            );

          await request.response.close();
        } catch (_) {
          print('Response already closed');
        }
      }

      continue;
    }

    // ======================================================
    // 404
    // ======================================================
    request.response
      ..statusCode = 404
      ..headers.contentType = ContentType.text
      ..write('Not Found');

    await request.response.close();
  }
}
