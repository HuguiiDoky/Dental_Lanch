import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importación directa para asegurar datos
import 'package:firebase_auth/firebase_auth.dart'; // Importación directa para Auth
import '../../constants.dart';
import '../../main.dart'; // Para ir a WelcomeScreen
import '../../services/auth_service.dart';

// Definimos la altura si no está en constants
const double kBottomNavigationBarHeight = 80.0;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _selectedCardIndex;
  final AuthService _authService = AuthService();

  // Obtenemos el usuario actual de Auth directamente
  final User? user = FirebaseAuth.instance.currentUser;

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Medida de seguridad: Si no hay usuario, mostrar mensaje
    if (user == null) {
      return const Scaffold(body: Center(child: Text("No hay sesión activa")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // USAMOS STREAMBUILDER: Escucha directa a la base de datos en tiempo real
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('usuarios') // Tu colección exacta
              .doc(user!.uid) // El ID del usuario
              .snapshots(),
          builder: (context, snapshot) {
            // -- VALORES POR DEFECTO --
            String displayName = 'Cargando...';
            String email = user?.email ?? 'Sin correo';
            String initials = '';
            bool isLoading = true;

            // 1. Manejo de Errores
            if (snapshot.hasError) {
              displayName = 'Error al cargar';
              isLoading = false;
            }

            // 2. Si hay datos, procesarlos
            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              isLoading = false;
              final data = snapshot.data!.data() as Map<String, dynamic>;

              // Imprimir en consola para depuración
              // ignore: avoid_print
              print("DEBUG - Datos obtenidos: $data");

              // Extraer nombres y apellidos con seguridad (soporta 'nombres' o 'name')
              final String nombres = (data['nombres'] ?? data['name'] ?? '')
                  .toString()
                  .trim();
              final String apellidos =
                  (data['apellidos'] ?? data['surname'] ?? '')
                      .toString()
                      .trim();

              // --- A. NOMBRE COMPLETO ---
              if (nombres.isNotEmpty || apellidos.isNotEmpty) {
                displayName = '$nombres $apellidos'.trim();
              } else {
                displayName = 'Usuario sin nombre';
              }

              // --- B. EMAIL (Preferimos el de la BD, si no el de Auth) ---
              if (data['email'] != null &&
                  data['email'].toString().isNotEmpty) {
                email = data['email'];
              }

              // --- C. INICIALES (Letra 1 Nombre + Letra 1 Apellido) ---
              String letraN = '';
              String letraA = '';

              if (nombres.isNotEmpty) letraN = nombres[0];
              if (apellidos.isNotEmpty) letraA = apellidos[0];

              initials = (letraN + letraA).toUpperCase();

              // Fallback: Si no hay iniciales (ej. campos vacíos), usar primera letra del display name
              if (initials.isEmpty && displayName.isNotEmpty) {
                initials = displayName[0].toUpperCase();
              }
            } else if (snapshot.connectionState == ConnectionState.done) {
              // Si terminó de cargar y no hay datos
              isLoading = false;
              displayName = 'Usuario no encontrado';
            }

            // -- INTERFAZ GRÁFICA --
            return SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 40.0,
                ),
                constraints: BoxConstraints(
                  minHeight:
                      size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      kBottomNavigationBarHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Mi Perfil',
                      style: TextStyle(
                        color: kLogoGrayColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Círculo de Avatar con Iniciales
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: kPrimaryColor,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Nombre Completo
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: kLogoGrayColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Correo
                    Text(
                      email,
                      style: const TextStyle(
                        color: kTextGrayColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Botones de acción
                    _buildProfileCard(
                      title: 'Editar Perfil',
                      icon: Icons.person_outline,
                      index: 0,
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    _buildProfileCard(
                      title: 'Seguridad',
                      icon: Icons.shield_outlined,
                      index: 1,
                      showArrow: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),

                    _buildProfileCard(
                      title: 'Cerrar Sesión',
                      icon: Icons.logout,
                      index: 2,
                      isDestructive: true,
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required IconData icon,
    required int index,
    required VoidCallback onTap,
    bool showArrow = false,
    bool isDestructive = false,
  }) {
    final bool isSelected = _selectedCardIndex == index;
    final Color borderColor = isSelected ? kPrimaryColor : kBorderGrayColor;
    final Color iconColor = isSelected
        ? kPrimaryColor
        : (isDestructive ? kPrimaryColor : kLogoGrayColor);
    final Color textColor = isSelected
        ? kPrimaryColor
        : (isDestructive ? kPrimaryColor : kLogoGrayColor);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCardIndex = index);
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (showArrow)
              Icon(
                Icons.arrow_forward_ios,
                color: isSelected ? kPrimaryColor : kBorderGrayColor,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
