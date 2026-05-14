import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static SharedPreferences? _prefsInstance;
  static Future<SharedPreferences>? _initializationFuture;
  bool _initialized = false;

  AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_initialized && _prefsInstance != null) return;
    
    // Avoid multiple simultaneous initialization attempts
    _initializationFuture ??= SharedPreferences.getInstance();
    _prefsInstance = await _initializationFuture;
    _initialized = true;
  }

  SharedPreferences get _prefs {
    if (_prefsInstance == null) {
      throw StateError('AuthService not initialized. Call initialize() first.');
    }
    return _prefsInstance!;
  }

  Future<void> saveUser(User user) async {
    await _prefs.setString('user_id', user.id);
    await _prefs.setString('user_email', user.email);
    await _prefs.setString('user_name', user.name);
    await _prefs.setString('user_role', user.role);
    await _prefs.setString('user_outlet_id', user.outletId);
  }

  User? getSavedUser() {
    final userId = _prefs.getString('user_id');
    if (userId == null) return null;

    return User(
      id: userId,
      email: _prefs.getString('user_email') ?? '',
      name: _prefs.getString('user_name') ?? '',
      role: _prefs.getString('user_role') ?? 'barista',
      outletId: _prefs.getString('user_outlet_id') ?? '',
      createdAt: DateTime.now(),
    );
  }

  Future<void> clearUser() async {
    await _prefs.remove('user_id');
    await _prefs.remove('user_email');
    await _prefs.remove('user_name');
    await _prefs.remove('user_role');
    await _prefs.remove('user_outlet_id');
  }

  bool isLoggedIn() {
    return _prefs.getString('user_id') != null;
  }
}
