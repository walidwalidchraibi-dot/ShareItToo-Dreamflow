import 'package:flutter/material.dart';

class OutlineIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;
  
  const OutlineIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).iconTheme.color ?? Colors.white;
    
    return CustomPaint(
      size: Size(size, size),
      painter: OutlineIconPainter(
        icon: icon,
        color: iconColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class OutlineIconPainter extends CustomPainter {
  final IconData icon;
  final Color color;
  final double strokeWidth;

  OutlineIconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw the icon as outline
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size.width,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Create path from text
    final builder = _PathFromTextBuilder();
    textPainter.paint(canvas, Offset.zero);
    
    // Draw outline version
    canvas.drawPath(builder.path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PathFromTextBuilder {
  Path path = Path();
}

// Alternative simpler approach - using stroke effect on regular icon
class SimpleOutlineIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;
  
  const SimpleOutlineIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).iconTheme.color ?? Colors.white;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Stroke (outline)
        Icon(
          icon,
          size: size,
          color: iconColor.withValues(alpha: 0.3),
        ),
        // Main icon with reduced opacity for outline effect
        Icon(
          icon,
          size: size - strokeWidth,
          color: Colors.transparent,
        ),
        // Actual outline using shader mask
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [iconColor, iconColor],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Icon(
            icon,
            size: size,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Using the actual Material outline icons where available
class MaterialOutlineIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  
  const MaterialOutlineIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).iconTheme.color ?? Colors.white;
    
    // Map filled icons to their outline versions
    IconData outlineIcon = _getOutlineIcon(icon);
    
    return Icon(
      outlineIcon,
      size: size,
      color: iconColor,
    );
  }
  
  IconData _getOutlineIcon(IconData icon) {
    // Common icon mappings from filled to outline
    final Map<IconData, IconData> outlineMapping = {
      Icons.home: Icons.home_outlined,
      Icons.favorite: Icons.favorite_outline,
      Icons.person: Icons.person_outline,
      Icons.message: Icons.message_outlined,
      Icons.bookmark: Icons.bookmark_outline,
      Icons.shopping_cart: Icons.shopping_cart_outlined,
      Icons.star: Icons.star_outline,
      Icons.settings: Icons.settings_outlined,
      Icons.camera: Icons.camera_alt_outlined,
      Icons.phone: Icons.phone_outlined,
      Icons.email: Icons.email_outlined,
      Icons.location_on: Icons.location_on_outlined,
      Icons.work: Icons.work_outline,
      Icons.school: Icons.school_outlined,
      Icons.music_note: Icons.music_note_outlined,
      Icons.sports_soccer: Icons.sports_soccer_outlined,
      Icons.directions_car: Icons.directions_car_outlined,
      Icons.computer: Icons.computer_outlined,
      Icons.kitchen: Icons.kitchen_outlined,
      Icons.build: Icons.build_outlined,
      Icons.sports: Icons.sports_outlined,
      Icons.toys: Icons.toys_outlined,
      Icons.apps: Icons.apps_outlined,
      Icons.category: Icons.category_outlined,
    };
    
    return outlineMapping[icon] ?? icon;
  }
}