import 'package:flutter/material.dart';

class DirectionalIcon extends StatelessWidget {
  final bool isBack;
  final double size;
  final Color? color;
  const DirectionalIcon({Key? key, this.isBack = true, this.size = 18, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final IconData icon;
    if (dir == TextDirection.rtl) {
      icon = isBack ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new;
    } else {
      icon = isBack ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios_rounded;
    }
    return Icon(icon, size: size, color: color);
  }
}
