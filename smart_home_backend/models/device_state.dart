class DeviceState {
  double gasValue;
  double threshold;
  bool mq2Enabled;
  bool light1;
  bool light2;
  bool autoMode;
  bool curtainIn;
  bool curtainOut;

  DeviceState({
    this.gasValue = 0,
    this.threshold = 1000,
    this.mq2Enabled = false,
    this.light1 = false,
    this.light2 = false,
    this.autoMode = false,
    this.curtainIn = false,
    this.curtainOut = false,
  });

  Map<String, dynamic> toJson() => {
    'gasValue': gasValue,
    'threshold': threshold,
    'mq2Enabled': mq2Enabled,
    'light1': light1,
    'light2': light2,
    'autoMode': autoMode,
    'curtainIn': curtainIn,
    'curtainOut': curtainOut,
  };
}