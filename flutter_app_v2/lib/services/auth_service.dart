import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
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
    final prefs = await SharedPreferences.getInstance();
    _citizenName = prefs.getString('citizen_name') ?? '';
    _citizenPhone = prefs.getString('citizen_phone') ?? '';
    _isAuthenticated = FirebaseAuth.instance.currentUser != null && _citizenName.isNotEmpty;
    notifyListeners();
  }

  Future<void> completeVerification(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('citizen_name', name);
    await prefs.setString('citizen_phone', phone);
    _citizenName = name;
    _citizenPhone = phone;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('citizen_name');
    await prefs.remove('citizen_phone');
    _citizenName = '';
    _citizenPhone = '';
    _isAuthenticated = false;
    notifyListeners();
  }
}
