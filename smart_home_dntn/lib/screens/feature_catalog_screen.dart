import 'package:flutter/material.dart';

import '../models/feature_catalog_item.dart';
import '../services/api_service.dart';

class FeatureCatalogScreen extends StatefulWidget {
  const FeatureCatalogScreen({super.key});

  @override
  State<FeatureCatalogScreen> createState() => _FeatureCatalogScreenState();
}

class _FeatureCatalogScreenState extends State<FeatureCatalogScreen> {
  final ApiService apiService = ApiService();

  List<FeatureCatalogItem> features = [];
  bool isLoading = true;
  String? errorMessage;

  final Color mainPurple = const Color(0xFF7C3AED);
  final Color darkPurple = const Color(0xFF20104F);
  final Color bgColor = const Color(0xFFF7F4FF);

  @override
  void initState() {
    super.initState();
    fetchFeatureCatalog();
  }

  Future<void> fetchFeatureCatalog() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await apiService.getFeatureCatalog();

      if (!mounted) return;

      setState(() {
        features = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Không tải được kho chức năng';
      });

      print('GET FEATURE CATALOG ERROR: $e');
    }
  }

  IconData _featureIcon(String key) {
    switch (key) {
      case 'LIGHT':
        return Icons.lightbulb_outline;
      case 'GAS_SENSOR':
        return Icons.warning_amber_rounded;
      case 'RAIN_SENSOR':
        return Icons.water_drop_outlined;
      case 'CURTAIN':
        return Icons.curtains_outlined;
      case 'ONLINE_STATUS':
        return Icons.wifi_rounded;
      case 'AIR_CONDITIONER':
        return Icons.ac_unit_rounded;
      case 'FAN':
        return Icons.toys_rounded;
      case 'SOCKET':
        return Icons.power_rounded;
      case 'DOOR_LOCK':
        return Icons.lock_outline_rounded;
      default:
        return Icons.widgets_outlined;
    }
  }

  Color _featureColor(String key) {
    switch (key) {
      case 'LIGHT':
        return Colors.amber;
      case 'GAS_SENSOR':
        return Colors.redAccent;
      case 'RAIN_SENSOR':
        return Colors.blueAccent;
      case 'CURTAIN':
        return Colors.teal;
      case 'ONLINE_STATUS':
        return Colors.green;
      case 'AIR_CONDITIONER':
        return Colors.cyan;
      case 'FAN':
        return Colors.orange;
      case 'SOCKET':
        return Colors.deepPurple;
      case 'DOOR_LOCK':
        return Colors.indigo;
      default:
        return mainPurple;
    }
  }

  Widget _featureCard(FeatureCatalogItem item) {
    final color = _featureColor(item.featureKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_featureIcon(item.featureKey), color: color, size: 28),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.featureName,
                  style: TextStyle(
                    color: darkPurple,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.featureKey,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: item.allowQuantity
                  ? mainPurple.withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.allowQuantity ? 'Số lượng' : '1 bộ',
              style: TextStyle(
                color: item.allowQuantity ? mainPurple : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: mainPurple));
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
          'Chưa có chức năng nào trong kho',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: mainPurple,
      onRefresh: fetchFeatureCatalog,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFA855F7), Color(0xFF5B21B6)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: mainPurple.withOpacity(0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${features.length} chức năng',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kho chức năng chung của công ty',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          Row(
            children: [
              Text(
                'Danh sách chức năng',
                style: TextStyle(
                  color: darkPurple,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: fetchFeatureCatalog,
                icon: Icon(Icons.refresh_rounded, color: mainPurple),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...features.map(_featureCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: darkPurple),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Kho chức năng',
                        style: TextStyle(
                          color: darkPurple,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
