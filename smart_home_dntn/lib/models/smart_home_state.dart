class SmartHomeState {
  double gasValue;
  double threshold;

  bool isOnline;
  String? lastSeen;

  bool mq2Enabled;
  bool light1;
  bool light2;
  bool autoMode;
  bool curtainIn;
  bool curtainOut;

  int deviceId;
  String deviceName;

  Map<String, bool> features;

  bool hasFeature(String key) {
    return features[key] == true;
  }

  SmartHomeState({
    required this.gasValue,
    required this.threshold,
    required this.mq2Enabled,
    required this.light1,
    required this.light2,
    required this.autoMode,
    required this.curtainIn,
    required this.curtainOut,
    required this.isOnline,
    required this.features,
    required this.deviceId,
    required this.deviceName,
    this.lastSeen,
  });

  factory SmartHomeState.initial() {
    return SmartHomeState(
      gasValue: 500,
      threshold: 1982,
      mq2Enabled: true,
      light1: false,
      light2: false,
      autoMode: false,
      curtainIn: false,
      curtainOut: false,
      isOnline: false,
      lastSeen: null,
      deviceId: 0,
      deviceName: 'Nhà thông minh',
      
      // Mặc định ban đầu bật hết để app không bị trống khi chưa fetch được backend
      features: {
        'LIGHT_1': true,
        'LIGHT_2': true,
        'GAS_SENSOR': true,
        'RAIN_SENSOR': true,
        'CURTAIN': true,
        'ONLINE_STATUS': true,
        
      },
    );
  }
}
