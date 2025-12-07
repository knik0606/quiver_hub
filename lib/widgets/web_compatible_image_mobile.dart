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
    // We apply the same URL processing for mobile as well, 
    // just in case direct links are better there too, 
    // although standard view links often work via redirect.
    final String processedUrl = _processUrl(imageUrl);

    return Image.network(
      processedUrl,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
           color: Colors.grey[800],
           child: const Center(
             child: Icon(Icons.broken_image, color: Colors.white54),
           ),
        );
      },
    );
  }
  
  String _processUrl(String url) {
    if (url.contains('drive.google.com') && url.contains('/view')) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        final fileIndex = segments.indexOf('file');
        if (fileIndex != -1 && fileIndex + 2 < segments.length) {
           final id = segments[fileIndex + 2];
           return 'https://drive.google.com/thumbnail?id=$id&sz=w1000';
        }
      } catch (e) {
        // Fallback
      }
    }
    return url;
  }
}
