// web_compatible_image.dart
import 'package:flutter/material.dart';

// Conditional imports
import 'web_compatible_image_mobile.dart' if (dart.library.html) 'web_compatible_image_web.dart';

class WebCompatibleImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const WebCompatibleImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return WebCompatibleImageImpl(imageUrl: imageUrl, fit: fit);
  }
}
