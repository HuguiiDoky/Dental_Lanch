import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;

  // Stream para cambios de estado (Login/Logout)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Iniciar Sesión
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow; // Re-lanza el error para manejarlo en la UI
    }
  }

  // Registrarse
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Cerrar Sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
