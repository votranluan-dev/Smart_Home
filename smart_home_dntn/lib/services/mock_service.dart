import '../models/smart_home_state.dart';

class MockService {
  SmartHomeState getInitialState() {
    return SmartHomeState.initial();
  }

  double getNextGasValue(double currentValue) {
    double nextValue = currentValue + 35;

    if (nextValue > 1200) {
      nextValue = 450;
    }

    return nextValue;
  }
}