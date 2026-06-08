import 'dart:async';
import 'package:flutter/material.dart';

import 'notifications.dart';
import 'edit_profile_screen.dart';

import '../widgets/app_header.dart';
import '../widgets/gas_gauge.dart';
import '../widgets/mq2_control.dart';
import '../widgets/light_control_row.dart';

import '../models/user_session.dart';
import '../models/smart_home_state.dart';

import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final UserSession user;
  final bool isAdminDemo;
  final String? titleOverride;

  const HomeScreen({
    super.key,
    required this.user,
    this.isAdminDemo = false,
    this.titleOverride,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color mainGreen = const Color(0xFF7C3AED);
  final Color lightGray = const Color(0xFFE7E0F8);
  final Color darkText = const Color(0xFF20104F);

  SmartHomeState state = SmartHomeState.initial();

  final ApiService apiService = ApiService();

  Timer? syncTimer;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    fetchDeviceState();

    syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      fetchDeviceState();
    });
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    super.dispose();
  }

  double _toDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? fallback;
  }

  bool _toBool(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }

  Future<void> fetchDeviceState() async {
    try {
      final data = await apiService.getDeviceState(widget.user.id);

      if (!mounted) return;

      setState(() {
        state.gasValue = _toDouble(data['gasValue'], state.gasValue);
        state.threshold = _toDouble(data['threshold'], state.threshold);
        state.mq2Enabled = _toBool(data['mq2Enabled'], state.mq2Enabled);
        state.light1 = _toBool(data['light1'], state.light1);
        state.light2 = _toBool(data['light2'], state.light2);
        state.autoMode = _toBool(data['autoMode'], state.autoMode);
        state.curtainIn = _toBool(data['curtainIn'], state.curtainIn);
        state.curtainOut = _toBool(data['curtainOut'], state.curtainOut);

        state.isOnline = _toBool(data['isOnline'], state.isOnline);
        state.lastSeen = data['lastSeen']?.toString();

        state.deviceId = data['deviceId'] ?? state.deviceId;
        state.deviceName = data['deviceName']?.toString() ?? state.deviceName;

        final rawFeatures = data['features'];

        if (rawFeatures is Map) {
          state.features = rawFeatures.map(
            (key, value) => MapEntry(key.toString(), _toBool(value, false)),
          );
        }

        errorMessage = null;
      });

      print('GET device state: $data');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Không kết nối được backend';
      });

      print('Error fetching device state: $e');
    }
  }

  Future<void> sendCommandAndRefresh(Future<void> command) async {
    try {
      await command;
      await fetchDeviceState();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Gửi lệnh thất bại';
      });

      print('Error sending command: $e');
    }
  }

  Future<void> updateCurtainState({
    required bool curtainIn,
    required bool curtainOut,
  }) async {
    setState(() {
      state.curtainIn = curtainIn;
      state.curtainOut = curtainOut;
    });

    try {
      await apiService.updateCurtainIn(state.deviceId, curtainIn);
      await apiService.updateCurtainOut(state.deviceId, curtainOut);
      await fetchDeviceState();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Gửi lệnh kéo sạp thất bại';
      });

      print('Error updating curtain: $e');
    }
  }

  Widget _activeText({required String text, required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? mainGreen.withOpacity(0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: active
            ? [
                BoxShadow(
                  color: mainGreen.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 250),
        style: TextStyle(
          color: active ? mainGreen : darkText.withOpacity(0.45),
          fontSize: 14,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
        child: Text(text),
      ),
    );
  }

  Widget _manualAutoControl() {
    final bool isAuto = state.autoMode;

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _activeText(text: 'Thủ công', active: !isAuto),
          ),
        ),

        GestureDetector(
          onTap: () {
            final newValue = !state.autoMode;

            setState(() {
              state.autoMode = newValue;
            });

            sendCommandAndRefresh(
              apiService.updateAutoMode(state.deviceId, newValue),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 84,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isAuto ? mainGreen.withOpacity(0.22) : lightGray,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isAuto ? mainGreen : Colors.grey.shade400,
                width: 1,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: isAuto ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: mainGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: mainGreen.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _activeText(text: 'Tự động', active: isAuto),
          ),
        ),
      ],
    );
  }

  Widget _curtainButtonRow({
    required String title,
    required bool value,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: state.autoMode ? 0.45 : 1,
      child: IgnorePointer(
        ignoring: state.autoMode,
        child: LightControlRow(
          title: title,
          value: value,
          mainGreen: mainGreen,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAnyControl =
        state.hasFeature('GAS_ALARM') ||
        state.hasFeature('LIGHT_1') ||
        state.hasFeature('LIGHT_2') ||
        state.hasFeature('RAIN_CURTAIN');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppHeader(
                    mainGreen: mainGreen,
                    darkText: darkText,
                    isOnline: state.isOnline == true,
                    title: widget.titleOverride ?? state.deviceName,
                    onBackTap: () {
                      Navigator.maybePop(context);
                    },
                    onNotificationTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NotificationsScreen(deviceId: state.deviceId),
                        ),
                      );
                    },
                    onProfileTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(user: widget.user),
                        ),
                      );

                      if (updated == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vui lòng đăng nhập lại để cập nhật thông tin mới',
                            ),
                          ),
                        );
                      }
                    },
                    onLogoutTap: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (route) => false,
                      );
                    },
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  SizedBox(height: state.hasFeature('GAS_ALARM') ? 34 : 24),

                  if (state.hasFeature('GAS_ALARM')) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: GasGauge(
                            gasValue: state.gasValue,
                            threshold: state.threshold,
                            mq2Enabled: state.mq2Enabled,
                            mainGreen: mainGreen,
                            lightGray: lightGray,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 5,
                          child: Mq2Control(
                            mq2Enabled: state.mq2Enabled,
                            threshold: state.threshold,
                            mainGreen: mainGreen,
                            lightGray: lightGray,
                            darkText: darkText,
                            onToggleMq2: () {
                              final newValue = !state.mq2Enabled;

                              setState(() {
                                state.mq2Enabled = newValue;
                              });

                              sendCommandAndRefresh(
                                apiService.updateMq2Enabled(
                                  state.deviceId,
                                  newValue,
                                ),
                              );
                            },
                            onThresholdChanged: (value) {
                              setState(() {
                                state.threshold = value;
                              });

                              sendCommandAndRefresh(
                                apiService.updateThreshold(
                                  state.deviceId,
                                  value,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 56),
                  ],

                  if (state.hasFeature('LIGHT_1') ||
                      state.hasFeature('LIGHT_2') ||
                      state.hasFeature('RAIN_CURTAIN')) ...[
                    Text(
                      'Điều khiển thiết bị',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (state.hasFeature('LIGHT_1')) ...[
                    LightControlRow(
                      title: 'Đèn 1',
                      value: state.light1,
                      mainGreen: mainGreen,
                      onTap: () {
                        final newValue = !state.light1;

                        setState(() {
                          state.light1 = newValue;
                        });

                        sendCommandAndRefresh(
                          apiService.updateLight1(state.deviceId, newValue),
                        );
                      },
                    ),

                    const SizedBox(height: 34),
                  ],

                  if (state.hasFeature('LIGHT_2')) ...[
                    LightControlRow(
                      title: 'Đèn 2',
                      value: state.light2,
                      mainGreen: mainGreen,
                      onTap: () {
                        final newValue = !state.light2;

                        setState(() {
                          state.light2 = newValue;
                        });

                        sendCommandAndRefresh(
                          apiService.updateLight2(state.deviceId, newValue),
                        );
                      },
                    ),

                    const SizedBox(height: 46),
                  ],

                  if (!hasAnyControl) ...[
                    const SizedBox(height: 90),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.widgets_outlined,
                            size: 58,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có chức năng điều khiển nào được bật',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vui lòng liên hệ Admin để cấu hình thiết bị.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (state.hasFeature('RAIN_CURTAIN')) ...[
                    _manualAutoControl(),

                    const SizedBox(height: 30),

                    _curtainButtonRow(
                      title: 'Kéo vào',
                      value: state.curtainIn,
                      onTap: () {
                        final newCurtainIn = !state.curtainIn;

                        updateCurtainState(
                          curtainIn: newCurtainIn,
                          curtainOut: newCurtainIn ? false : state.curtainOut,
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    _curtainButtonRow(
                      title: 'Kéo ra',
                      value: state.curtainOut,
                      onTap: () {
                        final newCurtainOut = !state.curtainOut;

                        updateCurtainState(
                          curtainIn: newCurtainOut ? false : state.curtainIn,
                          curtainOut: newCurtainOut,
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
