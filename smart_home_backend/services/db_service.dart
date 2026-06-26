import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:mysql1/mysql1.dart';

class DbService {
  late MySqlConnection conn;

  String generateDeviceToken({int length = 32}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();

    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    return sha256.convert(bytes).toString();
  }

  bool isPasswordCorrect({
    required String inputPassword,
    required String storedPassword,
  }) {
    final input = inputPassword.trim();
    final stored = storedPassword.trim();

    // Cách cũ: database đang lưu trực tiếp 123456
    if (stored == input) {
      return true;
    }

    // Cách mới: database lưu hash của mật khẩu
    if (stored == hashPassword(input)) {
      return true;
    }

    return false;
  }

  Future<void> checkAndSaveGasAlert({
    required int deviceId,
    required int gasValue,
  }) async {
    // 1. Lấy ngưỡng gas hiện tại của thiết bị
    final thresholdResult = await conn.query(
      '''
    SELECT gas_threshold
    FROM device_states
    WHERE device_id = ?
    LIMIT 1
    ''',
      [deviceId],
    );

    if (thresholdResult.isEmpty) return;

    final int threshold = thresholdResult.first['gas_threshold'] as int;

    // 2. Kiểm tra xem đang có cảnh báo gas chưa xử lý không
    final openAlertResult = await conn.query(
      '''
    SELECT id
    FROM alerts
    WHERE device_id = ?
      AND alert_type = 'GAS'
      AND is_resolved = 0
    ORDER BY id DESC
    LIMIT 1
    ''',
      [deviceId],
    );

    final bool hasOpenAlert = openAlertResult.isNotEmpty;

    // 3. Nếu gas vượt ngưỡng và chưa có cảnh báo mở → tạo cảnh báo mới
    if (gasValue >= threshold && !hasOpenAlert) {
      await conn.query(
        '''
      INSERT INTO alerts (
        device_id,
        alert_type,
        message,
        gas_value,
        is_resolved
      )
      VALUES (?, 'GAS', ?, ?, 0)
      ''',
        [
          deviceId,
          'Cảnh báo khí gas vượt ngưỡng. Giá trị gas: $gasValue, ngưỡng: $threshold',
          gasValue,
        ],
      );

      print('⚠️ GAS ALERT CREATED: gasValue=$gasValue, threshold=$threshold');
    }

    // 4. Nếu gas đã an toàn lại và đang có cảnh báo mở → đóng cảnh báo
    if (gasValue < threshold && hasOpenAlert) {
      final alertId = openAlertResult.first['id'];

      await conn.query(
        '''
      UPDATE alerts
      SET 
        is_resolved = 1,
        resolved_at = NOW()
      WHERE id = ?
      ''',
        [alertId],
      );

      print('✅ GAS ALERT RESOLVED: gasValue=$gasValue, threshold=$threshold');
    }
  }

  Future<int?> verifyDevice({
    required String deviceCode,
    required String deviceToken,
  }) async {
    final results = await conn.query(
      '''
    SELECT id
    FROM devices
    WHERE device_code = ?
      AND device_token = ?
    LIMIT 1
    ''',
      [deviceCode, deviceToken],
    );

    if (results.isEmpty) {
      return null;
    }

    return results.first['id'] as int;
  }

  Future<void> connect() async {
    final settings = ConnectionSettings(
      host: '127.0.0.1',
      port: 3306,
      user: 'smarthome',
      password: '123456',
      db: 'smart_home_dntn',
    );

    conn = await MySqlConnection.connect(settings);
    print('✅ Connected to MySQL database');
  }

  Future<Map<String, dynamic>?> getDeviceState(int deviceId) async {
    await checkAndMarkDeviceOffline(deviceId);

    final results = await conn.query(
      '''
    SELECT 
      ds.light1,
      ds.light2,
      ds.mq2_enabled,
      ds.auto_mode,
      ds.curtain_in,
      ds.curtain_out,
      ds.gas_value,
      ds.gas_threshold,
      d.id AS device_id,
      d.device_name,
      d.last_seen,
      CASE
        WHEN d.last_seen IS NOT NULL 
         AND TIMESTAMPDIFF(SECOND, d.last_seen, NOW()) <= 15
        THEN 1
        ELSE 0
      END AS is_online_now
    FROM device_states ds
    JOIN devices d ON d.id = ds.device_id
    WHERE ds.device_id = ?
    LIMIT 1
    ''',
      [deviceId],
    );

    if (results.isEmpty) return null;

    final row = results.first;

    final features = await getDeviceFeaturesMap(deviceId);

    return {
      'deviceId': row['device_id'],
      'deviceName': mysqlValueToString(row['device_name']),

      'light1': row['light1'] == 1,
      'light2': row['light2'] == 1,
      'mq2Enabled': row['mq2_enabled'] == 1,
      'autoMode': row['auto_mode'] == 1,
      'curtainIn': row['curtain_in'] == 1,
      'curtainOut': row['curtain_out'] == 1,
      'gasValue': row['gas_value'],
      'threshold': row['gas_threshold'],
      'isOnline': row['is_online_now'] == 1,
      'lastSeen': row['last_seen']?.toString(),

      // Danh sách chức năng được bật/tắt cho thiết bị này
      'features': features,
    };
  }

  Future<void> updateStateFromApp({
    required int deviceId,
    bool? light1,
    bool? light2,
    bool? mq2Enabled,
    bool? autoMode,
    bool? curtainIn,
    bool? curtainOut,
    int? threshold,
  }) async {
    await conn.query(
      '''
      UPDATE device_states
      SET
        light1 = COALESCE(?, light1),
        light2 = COALESCE(?, light2),
        mq2_enabled = COALESCE(?, mq2_enabled),
        auto_mode = COALESCE(?, auto_mode),
        curtain_in = COALESCE(?, curtain_in),
        curtain_out = COALESCE(?, curtain_out),
        gas_threshold = COALESCE(?, gas_threshold),
        updated_at = NOW()
      WHERE device_id = ?
      ''',
      [
        boolToIntOrNull(light1),
        boolToIntOrNull(light2),
        boolToIntOrNull(mq2Enabled),
        boolToIntOrNull(autoMode),
        boolToIntOrNull(curtainIn),
        boolToIntOrNull(curtainOut),
        threshold,
        deviceId,
      ],
    );
  }

  Future<void> updateStateFromEsp32({
    required int deviceId,
    int? gasValue,
    bool? light1,
    bool? light2,
    bool? mq2Enabled,
    bool? autoMode,
    bool? curtainIn,
    bool? curtainOut,
    bool? isRaining,
  }) async {
    bool? wasRaining;

    // Đoạn này nằm NGOÀI dấu ''' '''
    // Mục đích: đọc trạng thái mưa cũ trước khi UPDATE
    if (isRaining != null) {
      final rainResult = await conn.query(
        '''
      SELECT is_raining
      FROM device_states
      WHERE device_id = ?
      LIMIT 1
      ''',
        [deviceId],
      );

      if (rainResult.isNotEmpty) {
        wasRaining = rainResult.first['is_raining'] == 1;
      }
    }

    await conn.query(
      '''
    UPDATE device_states
    SET
      gas_value = COALESCE(?, gas_value),
      light1 = COALESCE(?, light1),
      light2 = COALESCE(?, light2),
      mq2_enabled = COALESCE(?, mq2_enabled),
      auto_mode = COALESCE(?, auto_mode),
      curtain_in = COALESCE(?, curtain_in),
      curtain_out = COALESCE(?, curtain_out),
      is_raining = COALESCE(?, is_raining),
      updated_at = NOW()
    WHERE device_id = ?
    ''',
      [
        gasValue,
        boolToIntOrNull(light1),
        boolToIntOrNull(light2),
        boolToIntOrNull(mq2Enabled),
        boolToIntOrNull(autoMode),
        boolToIntOrNull(curtainIn),
        boolToIntOrNull(curtainOut),
        boolToIntOrNull(isRaining),
        deviceId,
      ],
    );

    // Đoạn này cũng nằm NGOÀI dấu ''' '''
    // Mục đích: nếu trạng thái mưa thay đổi thì lưu vào device_events
    if (isRaining != null && wasRaining != null && wasRaining != isRaining) {
      if (isRaining) {
        await insertDeviceEvent(
          deviceId: deviceId,
          eventType: 'RAIN_DETECTED',
          title: 'Rain',
          message: 'Phát hiện trời mưa. Hệ thống đã ghi nhận trạng thái mưa.',
        );
      } else {
        await insertDeviceEvent(
          deviceId: deviceId,
          eventType: 'RAIN_STOPPED',
          title: 'Rain Stopped',
          message: 'Trời đã tạnh mưa. Hệ thống đã ghi nhận kết thúc mưa.',
        );
      }
    }

    await markDeviceOnline(deviceId);

    if (gasValue != null) {
      await conn.query(
        '''
      INSERT INTO sensor_logs (
        device_id,
        gas_value
      )
      VALUES (?, ?)
      ''',
        [deviceId, gasValue],
      );

      await checkAndSaveGasAlert(deviceId: deviceId, gasValue: gasValue);
    }
  }

  Future<List<Map<String, dynamic>>> getGasAlerts({
    required int deviceId,
    int limit = 50,
  }) async {
    final results = await conn.query(
      '''
    SELECT
      id,
      alert_type,
      message,
      gas_value,
      is_resolved,
      created_at,
      resolved_at
    FROM alerts
    WHERE device_id = ?
      AND alert_type = 'GAS'
    ORDER BY created_at DESC
    LIMIT ?
    ''',
      [deviceId, limit],
    );

    return results.map((row) {
      return {
        'id': row['id'],
        'alertType': mysqlValueToString(row['alert_type']),
        'message': mysqlValueToString(row['message']),
        'gasValue': row['gas_value'],
        'isResolved': row['is_resolved'] == 1,
        'createdAt': row['created_at']?.toString(),
        'resolvedAt': row['resolved_at']?.toString(),
      };
    }).toList();
  }

  String mysqlValueToString(dynamic value) {
    if (value == null) return '';

    if (value is Blob) {
      return utf8.decode(value.toBytes());
    }

    return value.toString();
  }

  Future<void> insertDeviceEvent({
    required int deviceId,
    required String eventType,
    required String title,
    required String message,
  }) async {
    await conn.query(
      '''
    INSERT INTO device_events (
      device_id,
      event_type,
      title,
      message,
      created_at
    )
    VALUES (?, ?, ?, ?, NOW())
    ''',
      [deviceId, eventType, title, message],
    );

    print('📌 DEVICE EVENT CREATED: $eventType');
  }

  Future<void> markDeviceOnline(int deviceId) async {
    final result = await conn.query(
      '''
    SELECT 
      is_online,
      last_seen,
      CASE
        WHEN last_seen IS NOT NULL
         AND TIMESTAMPDIFF(SECOND, last_seen, NOW()) <= 15
        THEN 1
        ELSE 0
      END AS is_online_now
    FROM devices
    WHERE id = ?
    LIMIT 1
    ''',
      [deviceId],
    );

    if (result.isEmpty) return;

    final row = result.first;

    // Online thật sự là có last_seen trong vòng 15 giây gần nhất
    final bool wasReallyOnline = row['is_online_now'] == 1;

    await conn.query(
      '''
    UPDATE devices
    SET 
      is_online = 1,
      last_seen = NOW()
    WHERE id = ?
    ''',
      [deviceId],
    );

    // Nếu trước đó đã quá 15 giây không gửi dữ liệu,
    // lần gửi mới này được xem là kết nối lại
    if (!wasReallyOnline) {
      await insertDeviceEvent(
        deviceId: deviceId,
        eventType: 'ONLINE',
        title: 'Online',
        message: 'ESP32 đã kết nối lại hệ thống.',
      );
    }
  }

  Future<void> checkAndMarkDeviceOffline(int deviceId) async {
    final result = await conn.query(
      '''
    SELECT 
      is_online,
      last_seen,
      CASE
        WHEN last_seen IS NOT NULL 
         AND TIMESTAMPDIFF(SECOND, last_seen, NOW()) <= 15
        THEN 1
        ELSE 0
      END AS is_online_now
    FROM devices
    WHERE id = ?
    LIMIT 1
    ''',
      [deviceId],
    );

    if (result.isEmpty) return;

    final row = result.first;

    final bool wasOnline = row['is_online'] == 1;
    final bool isOnlineNow = row['is_online_now'] == 1;

    if (wasOnline && !isOnlineNow) {
      await conn.query(
        '''
      UPDATE devices
      SET is_online = 0
      WHERE id = ?
      ''',
        [deviceId],
      );

      await insertDeviceEvent(
        deviceId: deviceId,
        eventType: 'OFFLINE',
        title: 'Offline',
        message:
            'ESP32 đã mất kết nối hoặc không gửi dữ liệu trong thời gian quy định.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications({
    required int deviceId,
    int limit = 50,
  }) async {
    final List<Map<String, dynamic>> notifications = [];

    // 1. Lấy cảnh báo gas từ bảng alerts
    final gasAlertResults = await conn.query(
      '''
    SELECT
      id,
      alert_type,
      message,
      gas_value,
      created_at
    FROM alerts
    WHERE device_id = ?
      AND alert_type = 'GAS'
    ORDER BY created_at DESC
    LIMIT ?
    ''',
      [deviceId, limit],
    );

    for (final row in gasAlertResults) {
      notifications.add({
        'id': row['id'],
        'type': 'GAS_ALERT',
        'title': 'Gas Alert',
        'message': mysqlValueToString(row['message']),
        'gasValue': row['gas_value'],
        'createdAt': row['created_at']?.toString(),
      });
    }

    // 2. Lấy lịch sử online/offline từ bảng device_events
    final deviceEventResults = await conn.query(
      '''
    SELECT
      id,
      event_type,
      title,
      message,
      created_at
    FROM device_events
    WHERE device_id = ?
      AND event_type IN ('ONLINE', 'OFFLINE', 'RAIN_DETECTED', 'RAIN_STOPPED')
    ORDER BY created_at DESC
    LIMIT ?
    ''',
      [deviceId, limit],
    );

    for (final row in deviceEventResults) {
      notifications.add({
        'id': row['id'],
        'type': mysqlValueToString(row['event_type']),
        'title': mysqlValueToString(row['title']),
        'message': mysqlValueToString(row['message']),
        'createdAt': row['created_at']?.toString(),
      });
    }

    // 3. Sắp xếp lại toàn bộ thông báo theo thời gian mới nhất
    notifications.sort((a, b) {
      final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '');
      final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '');

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    // 4. Giới hạn số lượng trả về
    if (notifications.length > limit) {
      return notifications.take(limit).toList();
    }

    return notifications;
  }

  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    final results = await conn.query(
      '''
    SELECT 
      id,
      full_name,
      email,
      password_hash,
      phone,
      role
    FROM users
    WHERE email = ?
    LIMIT 1
    ''',
      [email.trim()],
    );

    if (results.isEmpty) return null;

    final row = results.first;

    final storedPassword = mysqlValueToString(row['password_hash']);

    final isCorrect = isPasswordCorrect(
      inputPassword: password,
      storedPassword: storedPassword,
    );

    if (!isCorrect) {
      return null;
    }

    return {
      'id': row['id'],
      'fullName': mysqlValueToString(row['full_name']),
      'email': mysqlValueToString(row['email']),
      'phone': mysqlValueToString(row['phone']),
      'role': mysqlValueToString(row['role']),
    };
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final results = await conn.query('''
    SELECT
      id,
      full_name,
      email,
      phone,
      role,
      created_at
    FROM users
    WHERE role = 'CUSTOMER'
    ORDER BY id DESC
    ''');

    return results.map((row) {
      return {
        'id': row['id'],
        'fullName': mysqlValueToString(row['full_name']),
        'email': mysqlValueToString(row['email']),
        'phone': mysqlValueToString(row['phone']),
        'role': mysqlValueToString(row['role']),
        'createdAt': row['created_at']?.toString(),
      };
    }).toList();
  }

  Future<int> createCustomer({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final existing = await conn.query(
      '''
    SELECT id
    FROM users
    WHERE email = ?
    LIMIT 1
    ''',
      [email],
    );

    if (existing.isNotEmpty) {
      throw Exception('Email already exists');
    }

    final result = await conn.query(
      '''
    INSERT INTO users (
      full_name,
      email,
      password_hash,
      phone,
      role
    )
    VALUES (?, ?, ?, ?, 'CUSTOMER')
    ''',
      [fullName, email, hashPassword(password), phone],
    );

    return result.insertId ?? 0;
  }

  Future<void> deleteCustomer(int customerId) async {
    // 1. Lấy danh sách thiết bị của khách hàng
    final deviceResults = await conn.query(
      '''
    SELECT id
    FROM devices
    WHERE user_id = ?
    ''',
      [customerId],
    );

    final deviceIds = deviceResults.map((row) => row['id'] as int).toList();

    // 2. Xóa toàn bộ dữ liệu con theo từng thiết bị
    for (final deviceId in deviceIds) {
      await conn.query('DELETE FROM door_access_logs WHERE device_id = ?', [
        deviceId,
      ]);

      await conn.query('DELETE FROM alerts WHERE device_id = ?', [deviceId]);

      await conn.query('DELETE FROM device_events WHERE device_id = ?', [
        deviceId,
      ]);

      await conn.query('DELETE FROM sensor_logs WHERE device_id = ?', [
        deviceId,
      ]);

      await conn.query('DELETE FROM commands WHERE device_id = ?', [deviceId]);

      await conn.query('DELETE FROM device_features WHERE device_id = ?', [
        deviceId,
      ]);

      await conn.query('DELETE FROM device_states WHERE device_id = ?', [
        deviceId,
      ]);
    }

    // 3. Xóa thiết bị của khách hàng
    await conn.query('DELETE FROM devices WHERE user_id = ?', [customerId]);

    // 4. Xóa tài khoản khách hàng
    await conn.query(
      '''
    DELETE FROM users
    WHERE id = ?
      AND role = 'CUSTOMER'
    ''',
      [customerId],
    );
  }

  Future<List<Map<String, dynamic>>> getDevicesByCustomer(
    int customerId,
  ) async {
    final results = await conn.query(
      '''
    SELECT
      id,
      user_id,
      device_name,
      device_code,
      is_online,
      last_seen,
      created_at
    FROM devices
    WHERE user_id = ?
    ORDER BY id DESC
    ''',
      [customerId],
    );

    return results.map((row) {
      return {
        'id': row['id'],
        'userId': row['user_id'],
        'deviceName': mysqlValueToString(row['device_name']),
        'deviceCode': mysqlValueToString(row['device_code']),
        'isOnline': row['is_online'] == 1,
        'lastSeen': row['last_seen']?.toString(),
        'createdAt': row['created_at']?.toString(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getDeviceFeatures(int deviceId) async {
    final results = await conn.query(
      '''
    SELECT
      id,
      device_id,
      feature_key,
      feature_name,
      is_enabled,
      created_at,
      updated_at
    FROM device_features
    WHERE device_id = ?
    ORDER BY id ASC
    ''',
      [deviceId],
    );

    return results.map((row) {
      return {
        'id': row['id'],
        'deviceId': row['device_id'],
        'featureKey': mysqlValueToString(row['feature_key']),
        'featureName': mysqlValueToString(row['feature_name']),
        'isEnabled': row['is_enabled'] == 1,
        'createdAt': row['created_at']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
      };
    }).toList();
  }

  Future<void> updateDeviceFeature({
    required int featureId,
    required bool isEnabled,
  }) async {
    final result = await conn.query(
      '''
    UPDATE device_features
    SET is_enabled = ?
    WHERE id = ?
    ''',
      [isEnabled ? 1 : 0, featureId],
    );

    if (result.affectedRows == 0) {
      throw Exception('Feature not found');
    }
  }

  Future<Map<String, bool>> getDeviceFeaturesMap(int deviceId) async {
    final results = await conn.query(
      '''
    SELECT feature_key, is_enabled
    FROM device_features
    WHERE device_id = ?
    ''',
      [deviceId],
    );

    final Map<String, bool> features = {};

    for (final row in results) {
      final key = mysqlValueToString(row['feature_key']);
      final enabled = row['is_enabled'] == 1;

      features[key] = enabled;
    }

    return features;
  }

  Future<List<Map<String, dynamic>>> getFeatureCatalog() async {
    final results = await conn.query('''
    SELECT
      id,
      feature_key,
      feature_name,
      description,
      allow_quantity,
      is_active,
      created_at
    FROM feature_catalog
    WHERE is_active = 1
    ORDER BY id ASC
    ''');

    return results.map((row) {
      return {
        'id': row['id'],
        'featureKey': mysqlValueToString(row['feature_key']),
        'featureName': mysqlValueToString(row['feature_name']),
        'description': mysqlValueToString(row['description']),
        'allowQuantity': row['allow_quantity'] == 1,
        'isActive': row['is_active'] == 1,
        'createdAt': row['created_at']?.toString(),
      };
    }).toList();
  }

  Future<void> addFeatureFromCatalogToDevice({
    required int deviceId,
    required String featureKey,
    required int quantity,
  }) async {
    final catalogResults = await conn.query(
      '''
    SELECT 
      feature_key,
      feature_name,
      allow_quantity
    FROM feature_catalog
    WHERE feature_key = ? AND is_active = 1
    LIMIT 1
    ''',
      [featureKey],
    );

    if (catalogResults.isEmpty) {
      throw Exception('Feature not found in catalog');
    }

    final catalog = catalogResults.first;
    final catalogKey = mysqlValueToString(catalog['feature_key']);
    final catalogName = mysqlValueToString(catalog['feature_name']);
    final allowQuantity = catalog['allow_quantity'] == 1;

    final int finalQuantity = allowQuantity ? quantity : 1;

    if (finalQuantity <= 0) {
      throw Exception('Quantity must be greater than 0');
    }

    // =====================================================
    // Loại 1 bộ: GAS_ALARM, RAIN_CURTAIN, ONLINE_STATUS...
    // Nếu đã có thì bật lại. Nếu chưa có thì thêm mới.
    // =====================================================
    if (!allowQuantity) {
      final exists = await conn.query(
        '''
      SELECT id
      FROM device_features
      WHERE device_id = ? AND feature_key = ?
      LIMIT 1
      ''',
        [deviceId, catalogKey],
      );

      if (exists.isNotEmpty) {
        await conn.query(
          '''
        UPDATE device_features
        SET 
          feature_name = ?,
          is_enabled = 1,
          updated_at = NOW()
        WHERE device_id = ? AND feature_key = ?
        ''',
          [catalogName, deviceId, catalogKey],
        );
      } else {
        await conn.query(
          '''
        INSERT INTO device_features (
          device_id,
          feature_key,
          feature_name,
          is_enabled
        )
        VALUES (?, ?, ?, 1)
        ''',
          [deviceId, catalogKey, catalogName],
        );
      }

      return;
    }

    // =====================================================
    // Loại có số lượng: LIGHT, FAN, SOCKET, AIR_CONDITIONER...
    // Tìm số lớn nhất hiện có rồi thêm tiếp.
    // Ví dụ đã có SOCKET_1, SOCKET_2, SOCKET_3
    // thêm quantity = 1 => SOCKET_4
    // =====================================================
    final existingResults = await conn.query(
      '''
    SELECT feature_key
    FROM device_features
    WHERE device_id = ?
    AND feature_key LIKE ?
    ''',
      [deviceId, '${catalogKey}_%'],
    );

    int maxIndex = 0;

    for (final row in existingResults) {
      final currentKey = mysqlValueToString(row['feature_key']);
      final prefix = '${catalogKey}_';

      if (currentKey.startsWith(prefix)) {
        final numberText = currentKey.substring(prefix.length);
        final number = int.tryParse(numberText);

        if (number != null && number > maxIndex) {
          maxIndex = number;
        }
      }
    }

    for (int i = 1; i <= finalQuantity; i++) {
      final int nextIndex = maxIndex + i;

      final String deviceFeatureKey = '${catalogKey}_$nextIndex';
      final String deviceFeatureName = '$catalogName $nextIndex';

      await conn.query(
        '''
      INSERT INTO device_features (
        device_id,
        feature_key,
        feature_name,
        is_enabled
      )
      VALUES (?, ?, ?, 1)
      ''',
        [deviceId, deviceFeatureKey, deviceFeatureName],
      );
    }
  }

  Future<void> deleteDeviceFeature(int featureId) async {
    await conn.query(
      '''
    DELETE FROM device_features
    WHERE id = ?
    ''',
      [featureId],
    );
  }

  Future<int> createDeviceForCustomer({
    required int userId,
    required String deviceName,
    required String deviceCode,
    required String deviceToken,
  }) async {
    final secureDeviceToken = generateDeviceToken();

    final result = await conn.query(
      '''
    INSERT INTO devices (
      user_id,
      device_name,
      device_code,
      device_token,
      is_online,
      created_at
    )
    VALUES (?, ?, ?, ?, 0, NOW())
    ''',
      [userId, deviceName, deviceCode, secureDeviceToken],
    );

    final deviceId = result.insertId;

    if (deviceId == null) {
      throw Exception('Cannot create device');
    }

    // Tạo trạng thái mặc định cho thiết bị mới
    await conn.query(
      '''
    INSERT INTO device_states (
      device_id,
      light1,
      light2,
      mq2_enabled,
      auto_mode,
      curtain_in,
      curtain_out,
      gas_value,
      gas_threshold,
      is_raining,
      updated_at
    )
    VALUES (?, 0, 0, 1, 0, 0, 0, 500, 1982, 0, NOW())
    ''',
      [deviceId],
    );

    // Thêm chức năng mặc định cho thiết bị mới
    final defaultFeatures = [
      {'key': 'LIGHT_1', 'name': 'Đèn 1'},
      {'key': 'LIGHT_2', 'name': 'Đèn 2'},
      {'key': 'GAS_ALARM', 'name': 'Bộ cảnh báo khí gas'},
      {'key': 'RAIN_CURTAIN', 'name': 'Bộ sạp mưa tự động'},
      {'key': 'ONLINE_STATUS', 'name': 'Trạng thái online/offline'},
    ];

    for (final feature in defaultFeatures) {
      await conn.query(
        '''
      INSERT INTO device_features (
        device_id,
        feature_key,
        feature_name,
        is_enabled,
        created_at,
        updated_at
      )
      VALUES (?, ?, ?, 1, NOW(), NOW())
      ''',
        [deviceId, feature['key'], feature['name']],
      );
    }

    return deviceId;
  }

  Future<Map<String, dynamic>?> getFirstDeviceByUserId(int userId) async {
    final results = await conn.query(
      '''
    SELECT 
      id,
      user_id,
      device_name,
      device_code,
      is_online,
      last_seen
    FROM devices
    WHERE user_id = ?
    ORDER BY id ASC
    LIMIT 1
    ''',
      [userId],
    );

    if (results.isEmpty) {
      return null;
    }

    final row = results.first;

    return {
      'id': row['id'],
      'userId': row['user_id'],
      'deviceName': row['device_name'],
      'deviceCode': row['device_code'],
      'isOnline': row['is_online'] == 1,
      'lastSeen': row['last_seen']?.toString(),
    };
  }

  Future<void> updateUserProfile({
    required int userId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
  }) async {
    final newPassword = password?.trim();

    if (newPassword != null && newPassword.isNotEmpty) {
      await conn.query(
        '''
      UPDATE users
      SET 
        full_name = ?,
        email = ?,
        phone = ?,
        password_hash = ?
      WHERE id = ?
      ''',
        [fullName, email, phone, hashPassword(newPassword), userId],
      );
    } else {
      await conn.query(
        '''
      UPDATE users
      SET 
        full_name = ?,
        email = ?,
        phone = ?
      WHERE id = ?
      ''',
        [fullName, email, phone, userId],
      );
    }
  }

  Future<void> insertDoorAccessLog({
    required int deviceId,
    required String cardUid,
    String? cardName,
    required String status,
    String? message,
  }) async {
    await conn.query(
      '''
    INSERT INTO door_access_logs (
      device_id,
      card_uid,
      card_name,
      status,
      message,
      created_at
    )
    VALUES (?, ?, ?, ?, ?, NOW())
    ''',
      [deviceId, cardUid, cardName, status, message],
    );
  }

  Future<List<Map<String, dynamic>>> getDoorAccessLogs({
    required int deviceId,
    int limit = 50,
  }) async {
    final results = await conn.query(
      '''
    SELECT
      id,
      device_id,
      card_uid,
      card_name,
      status,
      message,
      created_at
    FROM door_access_logs
    WHERE device_id = ?
    ORDER BY created_at DESC
    LIMIT ?
    ''',
      [deviceId, limit],
    );

    return results.map((row) {
      return {
        'id': row['id'],
        'deviceId': row['device_id'],
        'cardUid': mysqlValueToString(row['card_uid']),
        'cardName': mysqlValueToString(row['card_name']),
        'status': mysqlValueToString(row['status']),
        'message': mysqlValueToString(row['message']),
        'createdAt': row['created_at']?.toString(),
      };
    }).toList();
  }

  int? boolToIntOrNull(bool? value) {
    if (value == null) return null;
    return value ? 1 : 0;
  }
}
