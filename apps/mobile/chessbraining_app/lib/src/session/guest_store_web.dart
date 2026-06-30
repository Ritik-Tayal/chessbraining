import 'package:web/web.dart' as web;

String? readGuestValue(String key) => web.window.localStorage.getItem(key);

Future<void> writeGuestValue(String key, String value) async {
  web.window.localStorage.setItem(key, value);
}
