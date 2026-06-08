import 'package:flutter/material.dart';

class Mq2Control extends StatelessWidget {
  final bool mq2Enabled;
  final double threshold;
  final Color mainGreen;
  final Color lightGray;
  final Color darkText;
  final VoidCallback onToggleMq2;
  final ValueChanged<double> onThresholdChanged;

  const Mq2Control({
    super.key,
    required this.mq2Enabled,
    required this.threshold,
    required this.mainGreen,
    required this.lightGray,
    required this.darkText,
    required this.onToggleMq2,
    required this.onThresholdChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _circleIndicator(),
            const SizedBox(width: 20),
            _smallSwitch(
              value: mq2Enabled,
              onTap: onToggleMq2,
            ),
          ],
        ),

        const SizedBox(height: 36),

        Text(
          'Chỉnh ngưỡng cảnh báo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w500,
            color: mq2Enabled ? mainGreen : Colors.grey,
          ),
        ),

        const SizedBox(height: 24),

        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: (threshold / 1000).toStringAsFixed(3),
                style: TextStyle(
                  fontSize: 28,
                  color: darkText,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'ppm',
                style: TextStyle(
                  fontSize: 13,
                  color: darkText,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 12,
              disabledThumbRadius: 12,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: threshold,
            min: 0,
            max: 4095,
            activeColor: mainGreen,
            inactiveColor: lightGray,
            onChanged: mq2Enabled ? onThresholdChanged : null,
          ),
        ),
      ],
    );
  }

  Widget _circleIndicator({double size = 70}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade500, width: 1),
      ),
    );
  }

  Widget _smallSwitch({
    required bool value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 68,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: lightGray,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: mainGreen,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}