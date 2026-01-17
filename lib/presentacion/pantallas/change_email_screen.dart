import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _updateEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = _auth.currentUser;

    if (user != null && user.email != null) {
      try {
        // 1. Re-autenticación
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordController.text,
        );
        await user.reauthenticateWithCredential(credential);

        // 2. Verificar nuevo correo
        await user.verifyBeforeUpdateEmail(_newEmailController.text.trim());

        // 3. Actualizar Firestore
        await _db.collection('usuarios').doc(user.uid).update({
          'email': _newEmailController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Se ha enviado un correo de verificación. Confírmalo para finalizar.',
              ),
              backgroundColor: kPrimaryColor,
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        String msg = 'Error al actualizar';
        if (e.code == 'wrong-password') msg = 'La contraseña es incorrecta';
        if (e.code == 'email-already-in-use') {
          msg = 'Este correo ya está registrado';
        }
        if (e.code == 'invalid-email') msg = 'El correo no es válido';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kLogoGrayColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Cambiar Correo',
          style: TextStyle(color: kLogoGrayColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- LOGO DEL CORREO ---
              Center(
                child: Image.asset(
                  'assets/images/correo.png', // Asegúrate que el nombre coincida
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                'Por seguridad, debes ingresar tu contraseña actual para cambiar tu correo.',
                style: TextStyle(color: kTextGrayColor, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Campo 1: Contraseña Actual
              _buildTextField(
                label: 'Contraseña Actual',
                hintText: 'Tu contraseña actual',
                controller: _passwordController,
                isPassword: true,
                isVisible: _isPasswordVisible,
                onVisibilityChanged: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
                validator: (val) => val!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),

              // Campo 2: Nuevo Correo
              _buildTextField(
                label: 'Nuevo Correo Electrónico',
                hintText: 'ejemplo@correo.com',
                controller: _newEmailController,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Ingresa el nuevo correo';
                  }
                  if (!val.contains('@')) return 'Correo no válido';
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Actualizar Correo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE ESTILO ---
  Widget _buildTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: kLogoGrayColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !isVisible,
          validator: validator,
          decoration: _buildInputDecoration(
            hintText: hintText,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: kTextGrayColor,
                    ),
                    onPressed: onVisibilityChanged,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: kBorderGrayColor),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 16.0,
        horizontal: 20.0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderGrayColor, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderGrayColor, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}
