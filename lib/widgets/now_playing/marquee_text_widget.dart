import 'package:flutter/material.dart';
import 'package:musify/widgets/marquee.dart';

class MarqueeTextWidget extends StatelessWidget {
  const MarqueeTextWidget({
    super.key,
    required this.text,
    required this.fontColor,
    required this.fontSize,
    required this.fontWeight,
  });
  final String text;
  final Color fontColor;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return MarqueeWidget(
      animationDuration: const Duration(seconds: 9),
      backDuration: const Duration(seconds: 6),
      pauseDuration: const Duration(milliseconds: 1500),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: fontColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
