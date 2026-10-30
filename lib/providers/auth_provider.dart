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

    try {
      // Resolve the profile from the live Supabase session.
      final current = await _supabaseService.getCurrentUserWithProfile();

      if (current != null) {
        _currentUser = current;
        // Refresh the cache so a re-keyed profile replaces the old id on disk.
        await _authService.saveUser(current);
      } else if (_supabaseService.hasActiveSession) {
        // The session is live but no users row matches it: the profile was removed or
        // recreated. Selling under the cached id would write sales no report can
        // attribute, so end the session and ask for a fresh login.
        try {
          await _supabaseService.signOut();
        } catch (_) {
          // Even when the server call fails the local cache must not keep the old id.
        }
        await _authService.clearUser();
        _currentUser = null;
      } else {
        // No session left (expired, or signed out elsewhere). A cached id can point at
        // a profile that has since been replaced; it is not proof of a login.
        await _authService.clearUser();
        _currentUser = null;
      }
    } catch (e) {
      // Offline: the profile cannot be re-verified. Boot with the cached identity so
      // the app stays usable; it is checked again on the next online start.
      _currentUser = saved;
    }

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
        _error = e.toString();

        // A missing profile will not appear on retry; send the user to the login screen.
        if (e is MissingProfileException) {
          _isLoading = false;
          notifyListeners();
          rethrow;
        }

        attempt++;

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

  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;

    try {
      final freshUser = await _supabaseService.getUserProfile(_currentUser!.id);
      _currentUser = freshUser;
      await _authService.saveUser(freshUser);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
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
