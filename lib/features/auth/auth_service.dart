import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthService {
  Future<void> signIn({required String email, required String password});

  Future<bool> signUp({required String email, required String password});

  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  const SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return response.session != null;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
