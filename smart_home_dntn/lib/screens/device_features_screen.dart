import 'package:flutter/material.dart';

import '../models/device_feature_item.dart';
import '../models/device_item.dart';
import '../services/api_service.dart';
import 'add_feature_to_device_screen.dart';

class DeviceFeaturesScreen extends StatefulWidget {
  final DeviceItem device;

  const DeviceFeaturesScreen({super.key, required this.device});

  @override
  State<DeviceFeaturesScreen> createState() => _DeviceFeaturesScreenState();
}

class _DeviceFeaturesScreenState extends State<DeviceFeaturesScreen> {
  final ApiService apiService = ApiService();

  bool isLoading = true;
  String? errorMessage;
  List<DeviceFeatureItem> features = [];

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleDark = Color(0xFF20104F);

  @override
  void initState() {
    super.initState();
    fetchFeatures();
  }

  Future<void> confirmDeleteFeature(DeviceFeatureItem feature) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa chức năng?'),
          content: Text(
            'Bạn có chắc muốn xóa "${feature.featureName}" khỏi thiết bị này không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await apiService.deleteDeviceFeature(feature.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa ${feature.featureName}'),
          backgroundColor: Colors.redAccent,
        ),
      );

      fetchFeatures();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không xóa được chức năng: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> fetchFeatures() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await apiService.getDeviceFeatures(widget.device.id);

      if (!mounted) return;

      setState(() {
        features = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Không tải được danh sách chức năng';
        isLoading = false;
      });

      print('GET DEVICE FEATURES ERROR: $e');
    }
  }

  Future<void> toggleFeature(DeviceFeatureItem feature, bool value) async {
    final oldValue = feature.isEnabled;

    setState(() {
      feature.isEnabled = value;
    });

    try {
      await apiService.updateDeviceFeature(
        featureId: feature.id,
        isEnabled: value,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Đã bật ${feature.featureName}'
                : 'Đã tắt ${feature.featureName}',
          ),
          backgroundColor: value ? Color(0xFF7C3AED) : Colors.grey,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        feature.isEnabled = oldValue;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không cập nhật được ${feature.featureName}'),
          backgroundColor: Colors.red,
        ),
      );

      print('UPDATE FEATURE ERROR: $e');
    }
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),

                  const SizedBox(height: 20),

                  _deviceCard(),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chức năng thiết bị',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: purpleDark,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: fetchFeatures,
                        icon: const Icon(Icons.refresh_rounded),
                        color: purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final added = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddFeatureToDeviceScreen(
                              deviceId: widget.device.id,
                              deviceName: widget.device.deviceName,
                            ),
                          ),
                        );

                        if (added == true) {
                          fetchFeatures();
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm chức năng'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          color: purpleDark,
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Text(
            'Cấu hình chức năng',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: purpleDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _deviceCard() {
    return Container(
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
              Icons.memory_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.device.deviceCode,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
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

    if (features.isEmpty) {
      return Center(
        child: Text(
          'Thiết bị này chưa có chức năng nào',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        ),
      );
    }

    return ListView.separated(
      itemCount: features.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _featureCard(features[index]);
      },
    );
  }

  Widget _featureCard(DeviceFeatureItem feature) {
    final icon = _featureIcon(feature.featureKey);
    final color = _featureColor(feature.featureKey);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: feature.isEnabled
              ? color.withOpacity(0.22)
              : Colors.grey.withOpacity(0.15),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: feature.isEnabled
                  ? color.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: feature.isEnabled ? color : Colors.grey,
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.featureName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: feature.isEnabled ? purpleDark : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.featureKey,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              confirmDeleteFeature(feature);
            },
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.redAccent,
          ),

          Switch(
            value: feature.isEnabled,
            activeColor: purple,
            onChanged: (value) {
              toggleFeature(feature, value);
            },
          ),
        ],
      ),
    );
  }

  IconData _featureIcon(String key) {
    if (key.startsWith('LIGHT_')) {
      return Icons.lightbulb_outline_rounded;
    }

    if (key.startsWith('FAN_')) {
      return Icons.toys_rounded;
    }

    if (key.startsWith('SOCKET_')) {
      return Icons.power_rounded;
    }

    if (key.startsWith('AIR_CONDITIONER_')) {
      return Icons.ac_unit_rounded;
    }

    switch (key) {
      case 'GAS_ALARM':
        return Icons.warning_amber_rounded;
      case 'RAIN_CURTAIN':
        return Icons.curtains_outlined;
      case 'ONLINE_STATUS':
        return Icons.wifi_rounded;
      case 'FIRE_ALARM':
        return Icons.local_fire_department_outlined;
      default:
        return Icons.extension_rounded;
    }
  }

  Color _featureColor(String key) {
    if (key.startsWith('LIGHT_')) {
      return Colors.amber;
    }

    if (key.startsWith('FAN_')) {
      return Colors.orange;
    }

    if (key.startsWith('SOCKET_')) {
      return Colors.deepPurple;
    }

    if (key.startsWith('AIR_CONDITIONER_')) {
      return Colors.cyan;
    }

    switch (key) {
      case 'GAS_ALARM':
        return Colors.redAccent;
      case 'RAIN_CURTAIN':
        return Colors.teal;
      case 'ONLINE_STATUS':
        return purple;
      case 'FIRE_ALARM':
        return Colors.deepOrange;
      default:
        return purple;
    }
  }
}
