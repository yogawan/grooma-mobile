import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_exception.dart';
import 'auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-wide auth state. `unknown` means the startup session check (via
/// `/auth/me`) hasn't resolved yet — the UI should show a splash screen
/// during that window.
class AuthController extends ChangeNotifier {
  AuthController(this._authService);

  final AuthService _authService;

  AuthStatus status = AuthStatus.unknown;
  User? user;

  Future<void> checkSession() async {
    try {
      user = await _authService.me();
      status = AuthStatus.authenticated;
    } on ApiException {
      user = null;
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Throws [ApiException] on failure; the login screen reads the error
  /// code to show the right message.
  Future<void> login(String username, String password) async {
    user = await _authService.login(username, password);
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } on ApiException {
      // Clear local state below regardless of server-side result.
    }
    _clearLocal();
  }

  /// Keeps the session's cached [User] in sync after a profile edit
  /// (profile doc §5), so things like the dashboard greeting don't show
  /// a stale name until the next login/session check.
  void updateName(String name) {
    final current = user;
    if (current == null) return;
    user = User(
      id: current.id,
      username: current.username,
      name: name,
      role: current.role,
      branch: current.branch,
    );
    notifyListeners();
  }

  /// Hooked into [ApiClient.onUnauthenticated]: any request coming back
  /// 401 means the session is gone server-side, so drop local state too.
  void handleUnauthenticated() {
    if (status == AuthStatus.authenticated) {
      _clearLocal();
    }
  }

  void _clearLocal() {
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
