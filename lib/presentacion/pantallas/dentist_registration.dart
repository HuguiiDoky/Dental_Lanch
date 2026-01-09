import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importante para manejar errores específicos
import '../../constants.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class RegisterDentistScreen extends StatefulWidget {
  const RegisterDentistScreen({super.key});

  @override
  State<RegisterDentistScreen> createState() => _RegisterDentistScreenState();
}

class _RegisterDentistScreenState extends State<RegisterDentistScreen> {
  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _selectedGender;
  bool _isLoading = false;

  void _register() async {
    // 1. Validaciones iniciales
    if (_nameController.text.isEmpty ||
        _surnameController.text.isEmpty ||
        _cedulaController.text.isEmpty ||
        _specialtyController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, llena todos los campos')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Intentar crear usuario en Firebase Auth
      final userCredential = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        // 3. Guardar datos adicionales en Firestore
        await _firestoreService.saveUser(userCredential.user!.uid, {
          'nombres': _nameController.text.trim(),
          'apellidos': _surnameController.text.trim(),
          'cedula': _cedulaController.text.trim(),
          'especialidad': _specialtyController.text.trim(),
          'email': _emailController.text.trim(),
          'genero': _selectedGender,
          'rol': 'odontologo',
          'uid': userCredential.user!.uid,
          'fechaRegistro': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta de odontólogo creada exitosamente!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // --- MANEJO DE ERRORES AMIGABLE ---
      String errorMessage = 'Ocurrió un error al registrarse';

      if (e.code == 'email-already-in-use') {
        errorMessage = 'Este correo electrónico ya está registrado.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es muy débil (mínimo 6 caracteres).';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El correo electrónico no es válido.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Error de conexión. Verifica tu internet.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Error genérico
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
          'Crea tu perfil de Odontólogo',
          style: TextStyle(
            color: kLogoGrayColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 24.0,
            ),
            constraints: BoxConstraints(
              minHeight:
                  size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  label: 'Nombres',
                  hintText: 'Ej: Laura María',
                  controller: _nameController,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Apellidos',
                  hintText: 'Ej: Velasco Ruiz',
                  controller: _surnameController,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Cédula Profesional',
                  hintText: 'Ej: 12345678',
                  keyboardType: TextInputType.number,
                  controller: _cedulaController,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Especialidad',
                  hintText: 'Ej: Endodoncia',
                  controller: _specialtyController,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: 'Correo electrónico',
                  hintText: 'laura.velasco@ejemplo.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                ),
                const SizedBox(height: 20),

                const Text(
                  'Género',
                  style: TextStyle(
                    color: kLogoGrayColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  hint: const Text(
                    'Selecciona tu género',
                    style: TextStyle(color: kBorderGrayColor),
                  ),
                  decoration: _buildInputDecoration(hintText: ''),
                  items: ['Femenino', 'Masculino', 'Otro']
                      .map(
                        (label) =>
                            DropdownMenuItem(value: label, child: Text(label)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGender = value),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Contraseña',
                  style: TextStyle(
                    color: kLogoGrayColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: _buildInputDecoration(
                    hintText: 'Mínimo 8 caracteres',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Confirmar Contraseña',
                  style: TextStyle(
                    color: kLogoGrayColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: _buildInputDecoration(
                    hintText: 'Repite tu contraseña',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(
                        () => _isConfirmPasswordVisible =
                            !_isConfirmPasswordVisible,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                            ),
                          )
                        : const Text(
                            'Crear Cuenta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes una cuenta? ',
                      style: TextStyle(color: kTextGrayColor, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Inicia Sesión',
                        style: TextStyle(
                          color: kPrimaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
          decoration: _buildInputDecoration(hintText: hintText),
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
        borderSide: const BorderSide(color: kBorderGrayColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderGrayColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
    );
  }
}
