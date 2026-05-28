import 'package:shared_preferences/shared_preferences.dart';

class DeviceId {
  static String? _cached;
  
  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = DateTime.now().millisecondsSinceEpoch.toString(); // simple unique ID
      await prefs.setString('device_id', id);
    }
    _cached = id;
    return id;
  }
}
