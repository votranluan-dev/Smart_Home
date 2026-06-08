import 'package:flutter/material.dart';

class GasGauge extends StatelessWidget {
  final double gasValue;
  final double threshold;
  final bool mq2Enabled;
  final Color mainGreen;
  final Color lightGray;

  const GasGauge({
    super.key,
    required this.gasValue,
    required this.threshold,
    required this.mq2Enabled,
    required this.mainGreen,
    required this.lightGray,
  });

  @override
  Widget build(BuildContext context) {
    final double percent = (gasValue / 4095).clamp(0.0, 1.0);
    final bool isDanger = mq2Enabled && gasValue >= threshold;
    final Color activeColor = !mq2Enabled
        ? Colors.grey
        : isDanger
        ? Colors.red
        : mainGreen;

    return Column(
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 18,
                  strokeCap: StrokeCap.round,
                  backgroundColor: lightGray,
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: gasValue.toInt().toString(),
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w500,
                        color: activeColor,
                      ),
                    ),
                    TextSpan(
                      text: 'ppm',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: activeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
              Text(
                '4095',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
