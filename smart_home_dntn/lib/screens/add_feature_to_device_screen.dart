import 'package:flutter/material.dart';

import '../models/feature_catalog_item.dart';
import '../services/api_service.dart';

class AddFeatureToDeviceScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const AddFeatureToDeviceScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<AddFeatureToDeviceScreen> createState() =>
      _AddFeatureToDeviceScreenState();
}

class _AddFeatureToDeviceScreenState extends State<AddFeatureToDeviceScreen> {
  final ApiService apiService = ApiService();

  List<FeatureCatalogItem> catalog = [];
  FeatureCatalogItem? selectedFeature;

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  int quantity = 1;

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleDark = Color(0xFF20104F);
  static const Color bgColor = Color(0xFFF7F4FF);

  @override
  void initState() {
    super.initState();
    fetchCatalog();
  }

  Future<void> fetchCatalog() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await apiService.getFeatureCatalog();

      if (!mounted) return;

      setState(() {
        catalog = data;
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

  Future<void> saveFeature() async {
    if (selectedFeature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn chức năng cần thêm'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await apiService.addFeatureFromCatalogToDevice(
        deviceId: widget.deviceId,
        featureKey: selectedFeature!.featureKey,
        quantity: selectedFeature!.allowQuantity ? quantity : 1,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${selectedFeature!.featureName}'),
          backgroundColor: purple,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thêm được chức năng: $e'),
          backgroundColor: Colors.red,
        ),
      );

      print('ADD FEATURE ERROR: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });
    }
  }

  IconData _featureIcon(String key) {
    switch (key) {
      case 'LIGHT':
        return Icons.lightbulb_outline_rounded;
      case 'GAS_ALARM':
        return Icons.warning_amber_rounded;
      case 'RAIN_CURTAIN':
        return Icons.curtains_outlined;
      case 'ONLINE_STATUS':
        return Icons.wifi_rounded;
      case 'AIR_CONDITIONER':
        return Icons.ac_unit_rounded;
      case 'FAN_1':
      case 'FAN_2':
        return Icons.toys_rounded;

      case 'SOCKET_1':
      case 'SOCKET_2':
      case 'SOCKET_3':
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
      case 'GAS_ALARM':
        return Colors.redAccent;
      case 'RAIN_CURTAIN':
        return Colors.teal;
      case 'ONLINE_STATUS':
        return purple;
      case 'AIR_CONDITIONER':
        return Colors.cyan;
      case 'FAN_1':
      case 'FAN_2':
        return Colors.orange;
      case 'SOCKET_1':
      case 'SOCKET_2':
      case 'SOCKET_3':
        return Colors.deepPurple;
      case 'DOOR_LOCK':
        return Colors.indigo;
      default:
        return purple;
    }
  }

  void selectFeature(FeatureCatalogItem item) {
    setState(() {
      selectedFeature = item;
      quantity = 1;
    });
  }

  Widget _catalogCard(FeatureCatalogItem item) {
    final bool selected = selectedFeature?.id == item.id;
    final color = _featureColor(item.featureKey);

    return GestureDetector(
      onTap: () => selectFeature(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? purple : color.withOpacity(0.18),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? purple.withOpacity(0.18)
                  : Colors.black.withOpacity(0.045),
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
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _featureIcon(item.featureKey),
                color: color,
                size: 28,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.featureName,
                    style: const TextStyle(
                      color: purpleDark,
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

            const SizedBox(width: 8),

            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? purple : Colors.grey.shade400,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityBox() {
    if (selectedFeature == null || !selectedFeature!.allowQuantity) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: purple.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Số lượng',
              style: TextStyle(
                color: purpleDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          IconButton(
            onPressed: quantity > 1
                ? () {
                    setState(() {
                      quantity--;
                    });
                  }
                : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: purple,
          ),

          Container(
            width: 54,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              quantity.toString(),
              style: const TextStyle(
                color: purple,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          IconButton(
            onPressed: () {
              setState(() {
                quantity++;
              });
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: purple,
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Container(
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
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.deviceName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Chọn chức năng cần thêm cho thiết bị',
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

              const SizedBox(height: 24),

              const Text(
                'Kho chức năng',
                style: TextStyle(
                  color: purpleDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 14),

              ...catalog.map((item) {
                return Column(
                  children: [
                    _catalogCard(item),

                    if (selectedFeature?.id == item.id && item.allowQuantity)
                      _quantityBox(),
                  ],
                );
              }),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSaving || selectedFeature == null
                  ? null
                  : saveFeature,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(isSaving ? 'Đang thêm...' : 'Thêm chức năng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
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
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: purpleDark,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Thêm chức năng',
                          style: TextStyle(
                            color: purpleDark,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
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
