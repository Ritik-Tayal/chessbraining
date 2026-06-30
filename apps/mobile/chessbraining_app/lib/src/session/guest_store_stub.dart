final Map<String, String> _guestMemoryStore = <String, String>{};

String? readGuestValue(String key) => _guestMemoryStore[key];

Future<void> writeGuestValue(String key, String value) async {
  _guestMemoryStore[key] = value;
}
