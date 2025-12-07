import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WebCompatibleImageImpl extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const WebCompatibleImageImpl({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final String processedUrl = _processUrl(imageUrl);
    final String viewType = 'img-${processedUrl.hashCode}';

    // Register the view factory if it hasn't been registered yet.
    // Note: In a real app we might want to track registration more formally,
    // but hashCode based types are unique enough for this scope.
    // We re-register blindly or check? ui_web doesn't expose strict check.
    // But registering same key twice might throw or just overwrite.
    // To be safe, we assume standard usage.
    
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = processedUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = _boxFitToCss(fit);
      return img;
    });

    return HtmlElementView(viewType: viewType);
  }

  String _processUrl(String url) {
    if (url.contains('drive.google.com') && url.contains('/view')) {
      // Convert /file/d/{id}/view... to /uc?export=view&id={id}
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        final fileIndex = segments.indexOf('file');
        if (fileIndex != -1 && fileIndex + 2 < segments.length) {
           final id = segments[fileIndex + 2];
           // Use thumbnail API which is more reliable for embedding than export=view
           return 'https://drive.google.com/thumbnail?id=$id&sz=w1000';
        }
      } catch (e) {
        // Fallback to original if parsing fails
      }
    }
    return url;
  }

  String _boxFitToCss(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
      default:
        return 'cover';
    }
  }
}
