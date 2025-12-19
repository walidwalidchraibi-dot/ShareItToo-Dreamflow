import 'dart:math';
import 'package:flutter/material.dart';

/// Applies a warm duotone (sepia-like) tint and subtle film grain to its child.
/// Intended for iconography (emojis or Icons) inside round category chips.
class VintageIconContent extends StatelessWidget {
  final Widget child;
  final double grainOpacity;
  const VintageIconContent({super.key, required this.child, this.grainOpacity = 0.08});

  @override
  Widget build(BuildContext context) {
    // Warm/sepia duotone gradient
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB08A57), Color(0xFF8C5A3C)],
    );

    return Stack(children: [
      // Duotone tint mapped into the glyph/shape via srcATop
      ShaderMask(
        shaderCallback: (rect) => gradient.createShader(rect),
        blendMode: BlendMode.srcATop,
        child: child,
      ),
      // Subtle warm glaze to soften contrast
      IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFB08A57).withValues(alpha: 0.06),
                const Color(0xFF8C5A3C).withValues(alpha: 0.04),
              ],
            ),
          ),
        ),
      ),
      // Grain overlay
      IgnorePointer(child: CustomPaint(painter: _GrainPainter(color: const Color(0xFF5C4A3D), opacity: grainOpacity))),
    ]);
  }
}

class _GrainPainter extends CustomPainter {
  final Color color;
  final double opacity; // 0..1
  const _GrainPainter({required this.color, this.opacity = 0.08});

  @override
  void paint(Canvas canvas, Size size) {
    // Density scales with area to keep dot density visually consistent
    final area = size.width * size.height;
    final baseDots = max(120, (area / 16).round()); // ~1 dot per 4x4px
    final rnd = Random(1337); // stable pattern
    final paint = Paint()..color = color.withValues(alpha: opacity);

    for (int i = 0; i < baseDots; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 0.4 + rnd.nextDouble() * 0.8; // 0.4..1.2px
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}
