import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../models/door_access_log_item.dart';

import '../services/api_service.dart';

enum NotificationFilter { all, gasAlert, offline, online, rain, doorAccess }

class NotificationsScreen extends StatefulWidget {
  final int deviceId;

  const NotificationsScreen({super.key, required this.deviceId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService apiService = ApiService();

  bool isLoading = true;
  String? errorMessage;

  List<NotificationItem> notifications = [];
  List<DoorAccessLogItem> doorLogs = [];

  NotificationFilter selectedFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final data = await apiService.getNotifications(widget.deviceId);
      final doorData = await apiService.getDoorAccessLogs(widget.deviceId);

      if (!mounted) return;

      setState(() {
        notifications = data;
        doorLogs = doorData;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Không tải được thông báo';
      });

      print('Fetch notifications error: $e');
    }
  }

  String formatDateTime(String value) {
    if (value.isEmpty) return 'Không rõ thời gian';

    try {
      final dateTime = DateTime.parse(value).toLocal();

      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();

      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day/$month/$year, $hour:$minute';
    } catch (_) {
      return value;
    }
  }

  String getCurrentDateTitle() {
    final now = DateTime.now();

    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();

    return '$day/$month/$year';
  }

  List<NotificationItem> getVisibleNotifications() {
    switch (selectedFilter) {
      case NotificationFilter.all:
        return notifications;

      case NotificationFilter.gasAlert:
        return notifications.where((item) => item.type == 'GAS_ALERT').toList();

      case NotificationFilter.offline:
        return notifications.where((item) => item.type == 'OFFLINE').toList();

      case NotificationFilter.online:
        return notifications.where((item) => item.type == 'ONLINE').toList();

      case NotificationFilter.rain:
        return notifications
            .where(
              (item) =>
                  item.type == 'RAIN_DETECTED' || item.type == 'RAIN_STOPPED',
            )
            .toList();

      case NotificationFilter.doorAccess:
        return [];
    }
  }

  List<NotificationItem> getVisibleGasAlerts() {
    if (selectedFilter == NotificationFilter.all ||
        selectedFilter == NotificationFilter.gasAlert) {
      return notifications;
    }

    return [];
  }

  bool get isEmptyForSelectedFilter {
    if (selectedFilter == NotificationFilter.all ||
        selectedFilter == NotificationFilter.gasAlert) {
      return notifications.isEmpty;
    }

    return true;
  }

  String getEmptyMessage() {
    switch (selectedFilter) {
      case NotificationFilter.all:
        return 'Chưa có thông báo nào';
      case NotificationFilter.gasAlert:
        return 'Chưa có cảnh báo gas vượt ngưỡng';
      case NotificationFilter.offline:
        return 'Chưa có lịch sử offline';
      case NotificationFilter.online:
        return 'Chưa có lịch sử online';
      case NotificationFilter.rain:
        return 'Chưa có lịch sử phát hiện mưa';
      case NotificationFilter.doorAccess:
        return 'Chưa có lịch sử mở cửa';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color mainGreen = Color(0xFF00D26A);
    const Color darkText = Color(0xFF202124);
    const Color bgColor = Color(0xFFF7F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchNotifications,
          color: mainGreen,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              _buildTopBar(darkText),
              const SizedBox(height: 24),
              _buildTitleRow(darkText),
              const SizedBox(height: 18),
              _buildFilterRow(mainGreen),
              const SizedBox(height: 22),
              _buildContent(mainGreen, darkText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color darkText) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.arrow_back, size: 26, color: Color(0xFF222222)),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: fetchNotifications,
          icon: const Icon(Icons.refresh, size: 24, color: Color(0xFF222222)),
        ),
      ],
    );
  }

  Widget _buildTitleRow(Color darkText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: TextStyle(
            color: darkText,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              getCurrentDateTitle(),
              style: TextStyle(
                color: darkText,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF00A957),
              size: 30,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterRow(Color mainGreen) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(
            title: 'All',
            filter: NotificationFilter.all,
            color: mainGreen,
          ),
          _filterChip(
            title: 'Gas Alert',
            filter: NotificationFilter.gasAlert,
            color: mainGreen,
            dotColor: Colors.red,
          ),
          _filterChip(
            title: 'Offline',
            filter: NotificationFilter.offline,
            color: mainGreen,
            dotColor: Colors.grey.shade400,
          ),
          _filterChip(
            title: 'Online',
            filter: NotificationFilter.online,
            color: mainGreen,
            dotColor: Colors.greenAccent,
          ),
          _filterChip(
            title: 'Rain',
            filter: NotificationFilter.rain,
            color: mainGreen,
            dotColor: Colors.blueAccent,
          ),
          _filterChip(
            title: 'Mở cửa',
            filter: NotificationFilter.doorAccess,
            color: mainGreen,
            dotColor: Colors.purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String title,
    required NotificationFilter filter,
    required Color color,
    Color? dotColor,
  }) {
    final bool selected = selectedFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedFilter = filter;
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : const Color(0xFFE9E9EF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF119B57),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (dotColor != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color mainGreen, Color darkText) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 44),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: fetchNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (selectedFilter == NotificationFilter.doorAccess) {
      if (doorLogs.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: Colors.grey.shade400,
                size: 46,
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có lịch sử mở cửa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          for (final item in doorLogs) ...[
            _doorAccessCard(item, darkText),
            const SizedBox(height: 18),
          ],
        ],
      );
    }

    final visibleNotifications = getVisibleNotifications();

    if (selectedFilter == NotificationFilter.all) {
      final List<Map<String, dynamic>> allEvents = [];

      for (final item in visibleNotifications) {
        allEvents.add({
          'type': 'notification',
          'time': DateTime.tryParse(item.createdAt) ?? DateTime(1970),
          'data': item,
        });
      }

      for (final item in doorLogs) {
        allEvents.add({
          'type': 'door',
          'time': DateTime.tryParse(item.createdAt) ?? DateTime(1970),
          'data': item,
        });
      }

      allEvents.sort((a, b) {
        final aTime = a['time'] as DateTime;
        final bTime = b['time'] as DateTime;
        return bTime.compareTo(aTime);
      });

      if (allEvents.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: Colors.grey.shade400,
                size: 46,
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có thông báo nào',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          for (final event in allEvents) ...[
            if (event['type'] == 'notification')
              _notificationCard(event['data'] as NotificationItem, darkText)
            else
              _doorAccessCard(event['data'] as DoorAccessLogItem, darkText),

            const SizedBox(height: 18),
          ],
        ],
      );
    }

    if (visibleNotifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: Colors.grey.shade400,
              size: 46,
            ),
            const SizedBox(height: 12),
            Text(
              getEmptyMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final item in visibleNotifications) ...[
          _notificationCard(item, darkText),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget _notificationCard(NotificationItem item, Color darkText) {
    Color eventColor;
    IconData eventIcon;
    String subtitle;

    if (item.type == 'GAS_ALERT') {
      eventColor = Colors.red;
      eventIcon = Icons.warning_amber_rounded;
      subtitle = item.gasValue == null
          ? item.message
          : 'Cảnh báo! Khí gas vượt ngưỡng. Giá trị gas: ${item.gasValue} ppm';
    } else if (item.type == 'ONLINE') {
      eventColor = Color(0xFF7C3AED);
      eventIcon = Icons.wifi_rounded;
      subtitle = item.message;
    } else if (item.type == 'OFFLINE') {
      eventColor = Colors.grey;
      eventIcon = Icons.wifi_off_rounded;
      subtitle = item.message;
    } else if (item.type == 'RAIN_DETECTED' || item.type == 'RAIN_STOPPED') {
      eventColor = Colors.blue;
      eventIcon = Icons.water_drop_rounded;
      subtitle = item.message;
    } else {
      eventColor = Colors.grey;
      eventIcon = Icons.notifications_rounded;
      subtitle = item.message;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              margin: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: eventColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(item.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(eventIcon, color: eventColor, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: darkText,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14, right: 12),
              child: Icon(
                Icons.more_horiz,
                color: Colors.grey.shade700,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doorAccessCard(DoorAccessLogItem item, Color darkText) {
    final granted = item.isGranted;

    final eventColor = granted ? const Color(0xFF7C3AED) : Colors.redAccent;
    final eventIcon = granted
        ? Icons.lock_open_rounded
        : Icons.lock_outline_rounded;

    final title = granted ? 'Mở cửa thành công' : 'Từ chối mở cửa';

    final subtitle = item.message.isNotEmpty
        ? item.message
        : granted
        ? 'Thẻ RFID hợp lệ, cửa đã được mở.'
        : 'Thẻ RFID không hợp lệ hoặc không có quyền mở cửa.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              margin: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: eventColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(item.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(eventIcon, color: eventColor, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: darkText,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.cardName.isEmpty
                          ? 'UID: ${item.cardUid}'
                          : '${item.cardName} - UID: ${item.cardUid}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14, right: 12),
              child: Text(
                item.status,
                style: TextStyle(
                  color: eventColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
