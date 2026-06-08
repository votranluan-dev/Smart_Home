import 'package:flutter/material.dart';

import '../models/door_access_log_item.dart';
import '../services/api_service.dart';

class DoorAccessLogsScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const DoorAccessLogsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DoorAccessLogsScreen> createState() => _DoorAccessLogsScreenState();
}

class _DoorAccessLogsScreenState extends State<DoorAccessLogsScreen> {
  final ApiService apiService = ApiService();

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleDark = Color(0xFF20104F);

  bool isLoading = true;
  String? errorMessage;
  List<DoorAccessLogItem> logs = [];

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await apiService.getDoorAccessLogs(widget.deviceId);

      if (!mounted) return;

      setState(() {
        logs = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Không tải được lịch sử mở cửa';
        isLoading = false;
      });

      print('GET DOOR ACCESS LOGS ERROR: $e');
    }
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;

    final d = date.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _logCard(DoorAccessLogItem item) {
    final granted = item.isGranted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: granted
              ? purple.withOpacity(0.18)
              : Colors.redAccent.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: granted
                  ? purple.withOpacity(0.12)
                  : Colors.redAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              granted ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              color: granted ? purple : Colors.redAccent,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  granted ? 'Mở cửa thành công' : 'Từ chối mở cửa',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: purpleDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.cardName.isEmpty ? 'Thẻ RFID' : item.cardName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'UID: ${item.cardUid}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(item.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Text(
            item.status,
            style: TextStyle(
              color: granted ? purple : Colors.redAccent,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: purple));
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (logs.isEmpty) {
      return Center(
        child: Text(
          'Chưa có lịch sử mở cửa',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchLogs,
      color: purple,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _logCard(logs[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: purpleDark,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Lịch sử mở cửa',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: purpleDark,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: fetchLogs,
                        icon: const Icon(Icons.refresh_rounded),
                        color: purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA855F7), Color(0xFF5B21B6)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: purple.withOpacity(0.25),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.door_front_door_rounded,
                            color: Colors.white,
                            size: 31,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.deviceName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Danh sách quẹt thẻ RFID',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: purpleDark,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
