import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Variables para controlar la visibilidad de cada campo
  bool _showCurrentPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;

  void _sendResetEmail() async {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      try {
        await _auth.sendPasswordResetEmail(email: user.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Correo enviado a ${user.email}'),
              backgroundColor: kPrimaryColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al enviar correo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = _auth.currentUser;

    if (user != null && user.email != null) {
      try {
        // 1. RE-AUTENTICACIÓN
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPassController.text,
        );

        await user.reauthenticateWithCredential(credential);

        // 2. ACTUALIZAR CONTRASEÑA
        await user.updatePassword(_newPassController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contraseña actualizada con éxito'),
              backgroundColor: kPrimaryColor,
            ),
          );
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        String msg = 'Ocurrió un error';
        if (e.code == 'wrong-password') {
          msg = 'La contraseña actual es incorrecta';
        }
        if (e.code == 'weak-password') msg = 'La contraseña nueva es muy débil';
        if (e.code == 'requires-recent-login') {
          msg = 'Por favor cierra sesión y vuelve a entrar';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error desconocido'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
          'Cambiar Contraseña',
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
              // --- LOGO DEL CANDADO ---
              Center(
                child: Image.asset(
                  'assets/images/candado.png', // Asegúrate que el nombre coincida
                  height: 100, // Ajusta la altura según necesites
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 30),

              // Campo 1: Contraseña Actual
              _buildTextField(
                label: 'Contraseña Actual',
                hintText: 'Ingresa tu contraseña actual',
                controller: _currentPassController,
                isPassword: true,
                isVisible: _showCurrentPass,
                onVisibilityChanged: () =>
                    setState(() => _showCurrentPass = !_showCurrentPass),
                validator: (val) => val!.isEmpty ? 'Requerido' : null,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _sendResetEmail,
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(color: kPrimaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Campo 2: Nueva Contraseña
              _buildTextField(
                label: 'Nueva Contraseña',
                hintText: 'Mínimo 6 caracteres',
                controller: _newPassController,
                isPassword: true,
                isVisible: _showNewPass,
                onVisibilityChanged: () =>
                    setState(() => _showNewPass = !_showNewPass),
                validator: (val) =>
                    (val!.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 20),

              // Campo 3: Confirmar
              _buildTextField(
                label: 'Confirmar Nueva Contraseña',
                hintText: 'Repite la nueva contraseña',
                controller: _confirmPassController,
                isPassword: true,
                isVisible: _showConfirmPass,
                onVisibilityChanged: () =>
                    setState(() => _showConfirmPass = !_showConfirmPass),
                validator: (val) {
                  if (val != _newPassController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
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
                          'Actualizar Contraseña',
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
