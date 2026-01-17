import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'security_screen.dart'; // <--- IMPORTANTE: Importamos la pantalla de seguridad

const double kBottomNavigationBarHeight = 80.0;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _selectedCardIndex;
  final AuthService _authService = AuthService();
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

    if (user == null) {
      return const Scaffold(body: Center(child: Text("No hay sesión activa")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            String displayName = 'Cargando...';
            String email = user?.email ?? 'Sin correo';
            String initials = '';
            bool isLoading = true;

            if (snapshot.hasError) {
              displayName = 'Error al cargar';
              isLoading = false;
            }

            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              isLoading = false;
              final data = snapshot.data!.data() as Map<String, dynamic>;

              final String nombres = (data['nombres'] ?? data['name'] ?? '')
                  .toString()
                  .trim();
              final String apellidos =
                  (data['apellidos'] ?? data['surname'] ?? '')
                      .toString()
                      .trim();
              final String rol = (data['rol'] ?? '').toString();
              String prefix = '';

              if (rol == 'odontologo') {
                prefix = 'Odont. ';
              }

              if (nombres.isNotEmpty || apellidos.isNotEmpty) {
                displayName = '$prefix$nombres $apellidos'.trim();
              } else {
                displayName = 'Usuario sin nombre';
              }

              if (data['email'] != null &&
                  data['email'].toString().isNotEmpty) {
                email = data['email'];
              }

              // Calcular iniciales
              String letraN = '';
              String letraA = '';
              if (nombres.isNotEmpty) letraN = nombres[0];
              if (apellidos.isNotEmpty) letraA = apellidos[0];
              initials = (letraN + letraA).toUpperCase();

              if (initials.isEmpty && displayName.isNotEmpty) {
                if (nombres.isNotEmpty) {
                  initials = nombres[0].toUpperCase();
                } else {
                  initials = displayName[0].toUpperCase();
                }
              }
            } else if (snapshot.connectionState == ConnectionState.done) {
              isLoading = false;
              displayName = 'Usuario no encontrado';
            }

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

                    Text(
                      email,
                      style: const TextStyle(
                        color: kTextGrayColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // BOTÓN 1: SEGURIDAD (CONECTADO)
                    _buildProfileCard(
                      title: 'Seguridad',
                      icon: Icons.shield_outlined,
                      index: 0,
                      showArrow: true,
                      onTap: () {
                        // AQUÍ ESTÁ LA MAGIA: Navegamos a la pantalla de seguridad
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SecurityScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // BOTÓN 2: CERRAR SESIÓN
                    _buildProfileCard(
                      title: 'Cerrar Sesión',
                      icon: Icons.logout,
                      index: 1,
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
        setState(() {
          _selectedCardIndex = index;
        });
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
