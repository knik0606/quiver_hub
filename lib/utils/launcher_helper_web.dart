import 'dart:html' as html;

class LauncherHelperImpl {
  static void launch(String url) {
    if (url.isNotEmpty) {
      html.window.open(url, '_blank');
    }
  }
}
