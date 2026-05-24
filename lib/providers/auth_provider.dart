import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  final _authService = AuthService();
  final _supabaseService = SupabaseService();

  Future<void> initialize() async {
    final saved = _authService.getSavedUser();

    // Resolve current user (and investorId remap) from Supabase session.
    final current = await _supabaseService.getCurrentUserWithProfile();

    _currentUser = current ?? saved;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
    int retryCount = 3,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    int attempt = 0;
    while (attempt < retryCount) {
      try {
        // Use Supabase authentication with custom database login
        _currentUser = await _supabaseService.signIn(
          email: email,
          password: password,
        );
        
        // Save user locally for offline access
        await _authService.saveUser(_currentUser!);
        _isLoading = false;
        notifyListeners();
        return;
      } catch (e) {
        attempt++;
        _error = e.toString();
        
        // If last attempt failed, stop retrying
        if (attempt >= retryCount) {
          _isLoading = false;
          notifyListeners();
          rethrow;
        }
        
        // Wait before retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
      await _authService.clearUser();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
