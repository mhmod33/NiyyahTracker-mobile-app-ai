import 'package:flutter/material.dart';

class DirectionalIcon extends StatelessWidget {
  final bool isBack;
  final double size;
  final Color? color;
  const DirectionalIcon({Key? key, this.isBack = true, this.size = 18, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    // Use keyboard_arrow icons — Flutter does NOT mirror these in RTL,
    // so we get pixel-exact control over direction without double-flipping.
    final IconData icon;
    if (dir == TextDirection.rtl) {
      // In RTL layout: back = right (→), forward = left (←)
      icon = isBack ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_left_rounded;
    } else {
      icon = isBack ? Icons.keyboard_arrow_left_rounded : Icons.keyboard_arrow_right_rounded;
    }
    return Icon(icon, size: size + 4, color: color);
  }
}
