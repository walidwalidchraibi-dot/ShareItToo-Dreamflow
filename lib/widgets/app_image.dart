import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lendify/services/auth_service.dart';
import 'package:lendify/services/backend_config.dart';

/// AppImage renders images from http/https URLs, data: URIs, and file paths.
/// It gracefully falls back to a neutral placeholder if the input is empty.
class AppImage extends StatelessWidget {
  /// Source URL/path. Can be null/invalid when coming from older local storage
  /// entries on web (which may surface as JS `undefined`).
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppImage(
      {super.key,
      required this.url,
      this.fit = BoxFit.cover,
      this.width,
      this.height,
      this.borderRadius});

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
    final src = (url ?? '').trim();
    if (src.isEmpty) {
      return const ColoredBox(color: Color(0x14000000));
    }
    if (src.startsWith('http')) {
      if (BackendConfig.isManagedListingImageUrl(src)) {
        return _ManagedNetworkImage(url: src, fit: fit);
      }
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0x14000000)),
      );
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
        final path =
            src.startsWith('file:') ? src.replaceFirst('file://', '') : src;
        return Image.file(File(path), fit: fit);
      } catch (_) {
        return const ColoredBox(color: Color(0x14000000));
      }
    }
    // Unknown scheme: try network as a last resort
    return Image.network(
      src,
      fit: fit,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0x14000000)),
    );
  }
}

class _ManagedNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const _ManagedNetworkImage({required this.url, required this.fit});

  @override
  State<_ManagedNetworkImage> createState() => _ManagedNetworkImageState();
}

class _ManagedNetworkImageState extends State<_ManagedNetworkImage> {
  late Future<String?> _accessToken;

  @override
  void initState() {
    super.initState();
    _accessToken = _loadAccessToken();
  }

  @override
  void didUpdateWidget(covariant _ManagedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _accessToken = _loadAccessToken();
    }
  }

  Future<String?> _loadAccessToken() {
    return AuthService.accessToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _accessToken,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(color: Color(0x14000000));
        }
        final token = snapshot.data;
        return Image.network(
          widget.url,
          fit: widget.fit,
          headers: token == null || token.isEmpty
              ? null
              : <String, String>{'Authorization': 'Bearer $token'},
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0x14000000)),
        );
      },
    );
  }
}
