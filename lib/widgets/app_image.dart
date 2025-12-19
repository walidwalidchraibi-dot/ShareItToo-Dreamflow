import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// AppImage renders images from http/https URLs, data: URIs, and file paths.
/// It gracefully falls back to a neutral placeholder if the input is empty.
class AppImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppImage({super.key, required this.url, this.fit = BoxFit.cover, this.width, this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    Widget child = _buildInner();
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    return child;
  }

  Widget _buildInner() {
    final src = (url).trim();
    if (src.isEmpty) {
      return const ColoredBox(color: Color(0x14000000));
    }
    if (src.startsWith('http')) {
      return Image.network(src, fit: fit);
    }
    if (src.startsWith('data:image')) {
      try {
        final comma = src.indexOf(',');
        if (comma > 0) {
          final b64 = src.substring(comma + 1);
          final bytes = base64Decode(b64);
          return Image.memory(Uint8List.fromList(bytes), fit: fit);
        }
      } catch (_) {}
      return const ColoredBox(color: Color(0x14000000));
    }
    // File paths: only supported on non-web platforms
    if (!kIsWeb && (src.startsWith('/') || src.startsWith('file:'))) {
      try {
        final path = src.startsWith('file:') ? src.replaceFirst('file://', '') : src;
        return Image.file(File(path), fit: fit);
      } catch (_) {
        return const ColoredBox(color: Color(0x14000000));
      }
    }
    // Unknown scheme: try network as a last resort
    return Image.network(src, fit: fit);
  }
}
