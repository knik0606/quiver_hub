// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class LauncherHelperImpl {
  static void launch(String url) {
    if (url.isNotEmpty) {
      html.window.open(url, '_blank');
    }
  }
}
