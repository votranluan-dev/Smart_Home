import 'package:flutter/material.dart';

class SwitchControlRow extends StatelessWidget {
  final String title;
  final bool value;
  final Color mainGreen;
  final VoidCallback onTap;

  const SwitchControlRow({
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
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              height: 1.15,
              color: mainGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 28),
        _bigSwitch(value: value, onTap: onTap),
      ],
    );
  }

  Widget _bigSwitch({
    required bool value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 138,
        height: 66,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFCFCFCF),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.grey.shade500, width: 1.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: mainGreen,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}