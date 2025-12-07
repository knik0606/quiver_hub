import 'package:url_launcher/url_launcher.dart';

class LauncherHelperImpl {
  static Future<void> launch(String url) async {
    if (url.isNotEmpty) {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
