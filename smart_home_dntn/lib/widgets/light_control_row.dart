import 'package:flutter/material.dart';

class LightControlRow extends StatelessWidget {
  final String title;
  final bool value;
  final Color mainGreen;
  final VoidCallback onTap;

  const LightControlRow({
    super.key,
    required this.title,
    required this.value,
    required this.mainGreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 24,
              color: mainGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(width: 12),

        _circleIndicator(size: 66),

        const Spacer(),

        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 120,
            height: 58,
            decoration: BoxDecoration(
              color: value ? mainGreen : Colors.white,
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: mainGreen, width: 1.8),
            ),
            child: Center(
              child: Text(
                value ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: value ? Colors.white : mainGreen,
                ),
              ),
            ),
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
}