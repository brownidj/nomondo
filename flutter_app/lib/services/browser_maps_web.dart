import 'package:web/web.dart' as web;

/// Open synchronously during the press gesture, without a Flutter plugin.
bool openBrowserMap(Uri uri) {
  web.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
  // With noopener, browsers intentionally provide no usable window handle.
  // A null result must not be treated as a launch failure.
  return true;
}
