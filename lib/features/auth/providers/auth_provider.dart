import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../../../core/services/fcm_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._repository);

  AuthStatus get status => _status;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      final loggedIn = await _repository.isLoggedIn();
      if (loggedIn) {
        final user = await _repository.getCurrentUser();
        if (user != null) {
          _user = user;
          _status = AuthStatus.authenticated;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_user_id', user.id);
          await FcmService.instance.registerCurrentToken(userId: user.id);
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _repository.login(email: email, password: password);
      final user = await _repository.getCurrentUser();
      _user = user;
      _status = AuthStatus.authenticated;
      // Cache userId so FcmService can register the token
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_id', user.id);
        await FcmService.instance.registerCurrentToken(userId: user.id);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signup({
    required String firstName,
    required String lastName,
    required String birthday,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _repository.signup(
        firstName: firstName,
        lastName: lastName,
        birthday: birthday,
        email: email,
        password: password,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendVerification(String email) async {
    try {
      await _repository.resendVerification(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    // Unregister FCM token before clearing session
    if (_user != null) {
      await FcmService.instance.unregisterToken(_user!.id);
    }
    await _repository.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user_id');
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setForcedUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    _user = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
