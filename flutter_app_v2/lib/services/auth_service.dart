import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Finding #15: Citizen PII (name, phone) stored in encrypted storage
/// instead of plaintext SharedPreferences.
class AuthService extends ChangeNotifier {
  // FlutterSecureStorage uses Android Keystore / iOS Keychain
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isAuthenticated = false;
  String _citizenName = '';
  String _citizenPhone = '';

  bool get isAuthenticated => _isAuthenticated;
  String get citizenName => _citizenName;
  String get citizenPhone => _citizenPhone;

  AuthService() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    _citizenName = await _secureStorage.read(key: 'citizen_name') ?? '';
    _citizenPhone = await _secureStorage.read(key: 'citizen_phone') ?? '';
    _isAuthenticated = FirebaseAuth.instance.currentUser != null && _citizenName.isNotEmpty;
    notifyListeners();
  }

  Future<void> completeVerification(String name, String phone) async {
    await _secureStorage.write(key: 'citizen_name', value: name);
    await _secureStorage.write(key: 'citizen_phone', value: phone);
    _citizenName = name;
    _citizenPhone = phone;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await _secureStorage.delete(key: 'citizen_name');
    await _secureStorage.delete(key: 'citizen_phone');
    _citizenName = '';
    _citizenPhone = '';
    _isAuthenticated = false;
    notifyListeners();
  }
}
