import 'launcher_helper_mobile.dart' if (dart.library.html) 'launcher_helper_web.dart';

class LauncherHelper {
  static void launch(String url) {
    LauncherHelperImpl.launch(url);
  }
}
