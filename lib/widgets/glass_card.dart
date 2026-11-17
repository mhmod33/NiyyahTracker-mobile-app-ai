import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A reusable frosted-glass surface.
///
/// Composed as [ClipRRect] (rounded corners) → [BackdropFilter]
/// ([ui.ImageFilter.blur]) → a semi-transparent [Container] with a subtle white
/// border and an optional [Gradient]. The translucent fill is what lets the
/// backdrop blur read through, so callers should pass a translucent `color`
/// (or a translucent `gradient`) — solid colors will hide the blur.
///
/// Constructor params (stable API — FEAT-003 depends on these):
/// * [child]          — the content painted on top of the glass. (required)
/// * [borderRadius]   — corner radius of the clip + fill. Default `20`.
/// * [blurSigma]      — sigma passed to [ui.ImageFilter.blur] for both axes.
///                      Default `12`.
/// * [color]          — semi-transparent solid fill. Ignored when [gradient]
///                      is non-null. Defaults to a translucent brand-green tint
///                      ([AppColors.paleGreen] for light, [AppColors.darkGreen]
///                      for dark) chosen by [isDark].
/// * [gradient]       — optional [Gradient] fill; takes precedence over [color].
/// * [borderColor]    — border color. Defaults to a subtle white edge.
/// * [borderWidth]    — border thickness. Default `1`.
/// * [padding]        — inner padding of the fill [Container]. Default none.
/// * [margin]         — outer margin around the clip. Default none.
/// * [isDark]         — picks the default `color`/`borderColor` when neither is
///                      supplied. Default `false`.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isDark;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blurSigma = 12,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.padding,
    this.margin,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final defaultFill = isDark
        ? AppColors.darkGreen.withValues(alpha: 0.28)
        : AppColors.paleGreen.withValues(alpha: 0.50);
    final defaultBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.60);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: gradient == null ? (color ?? defaultFill) : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? defaultBorder,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
