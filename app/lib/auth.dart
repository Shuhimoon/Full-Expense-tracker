import 'package:flutter/widgets.dart';
import 'package:full_jizhang/api.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.api});

  final ApiClient api;
  AppUser? user;
  bool ready = false;
  bool _disposed = false;

  bool get isLoggedIn => user != null;

  Future<void> bootstrap() async {
    try {
      user = await api.me();
    } on ApiException {
      user = null;
    } catch (_) {
      user = null;
    }
    ready = true;
    _notify();
  }

  Future<void> login({required String email, required String password}) async {
    user = await api.login(email: email, password: password);
    ready = true;
    _notify();
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    user = await api.register(email: email, password: password);
    ready = true;
    _notify();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    _notify();
  }

  void rememberBook(String? bookId) {
    final current = user;
    if (current == null || current.lastBookId == bookId) return;
    user = AppUser(
      id: current.id,
      email: current.email,
      lastBookId: bookId,
      createdAt: current.createdAt,
    );
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    api.close();
    super.dispose();
  }
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController auth,
    required super.child,
  }) : super(notifier: auth);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing above this context');
    return scope!.notifier!;
  }
}
