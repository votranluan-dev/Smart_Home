import 'package:flutter/material.dart';

import '../models/customer_item.dart';
import '../models/device_item.dart';
import '../services/api_service.dart';
import 'device_features_screen.dart';
import 'create_device_screen.dart';

class CustomerDevicesScreen extends StatefulWidget {
  final CustomerItem customer;

  const CustomerDevicesScreen({super.key, required this.customer});

  @override
  State<CustomerDevicesScreen> createState() => _CustomerDevicesScreenState();
}

class _CustomerDevicesScreenState extends State<CustomerDevicesScreen> {
  final ApiService apiService = ApiService();

  bool isLoading = true;
  String? errorMessage;
  List<DeviceItem> devices = [];

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleDark = Color(0xFF20104F);

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  Future<void> fetchDevices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await apiService.getCustomerDevices(widget.customer.id);

      if (!mounted) return;

      setState(() {
        devices = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Không tải được thiết bị của khách hàng';
        isLoading = false;
      });

      print('GET CUSTOMER DEVICES ERROR: $e');
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

                  _customerCard(),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Thiết bị của khách',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: purpleDark,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: fetchDevices,
                        icon: const Icon(Icons.refresh_rounded),
                        color: purple,
                      ),
                    ],
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
            'Thiết bị khách hàng',
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

  Widget _customerCard() {
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
              Icons.person_rounded,
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
                  widget.customer.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.customer.email,
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

    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.memory_rounded, size: 38, color: purple),
            ),

            const SizedBox(height: 18),

            Text(
              'Khách hàng này chưa có thiết bị nào',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tạo thiết bị ESP32 để khách hàng có thể điều khiển nhà thông minh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateDeviceScreen(
                        customerId: widget.customer.id,
                        customerName: widget.customer.fullName,
                      ),
                    ),
                  );

                  if (created == true) {
                    fetchDevices();
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo thiết bị'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _deviceCard(devices[index]);
      },
    );
  }

  Widget _deviceCard(DeviceItem device) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceFeaturesScreen(device: device),
          ),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: purple.withOpacity(0.1)),
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
                color: device.isOnline
                    ? Color(0xFF7C3AED).withOpacity(0.12)
                    : Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                Icons.memory_rounded,
                color: device.isOnline ? Color(0xFF7C3AED) : Colors.grey,
                size: 29,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: purpleDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.deviceCode,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    device.isOnline ? 'Đang online' : 'Đang offline',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: device.isOnline ? Color(0xFF7C3AED) : Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
