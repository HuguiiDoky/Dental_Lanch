import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'security_screen.dart';

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

  // --- FUNCIÓN PARA MOSTRAR EL MODAL "ACERCA DE" ---
  void _showAboutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent, // Para que se vean los bordes redondeados
      isScrollControlled: true, // Permite que el modal se ajuste al contenido
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Se ajusta al tamaño del contenido
            children: [
              // Encabezado con Título y Cerrar (X)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Acerca de',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kLogoGrayColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: kTextGrayColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Imagen del logo (info.png)
              Image.asset(
                'assets/images/info.png', // Asegúrate de que esta ruta sea correcta en tu pubspec.yaml
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),

              // Nombre de la App
              const Text(
                'Dental Lanch',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),

              // Versión
              const Text(
                'Versión 0.1.0',
                style: TextStyle(fontSize: 16, color: kTextGrayColor),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Desarrollador
              const Text(
                'Desarrollada por:',
                style: TextStyle(fontSize: 14, color: kTextGrayColor),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hugo Yael Castrejón Salgado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kLogoGrayColor,
                ),
                textAlign: TextAlign.center,
              ),
              // Espacio extra abajo para que no quede pegado al borde del celular
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        );
      },
    );
  }

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

                    // BOTÓN 1: SEGURIDAD (Índice 0)
                    _buildProfileCard(
                      title: 'Seguridad',
                      icon: Icons.shield_outlined,
                      index: 0,
                      showArrow: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SecurityScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // BOTÓN 2: ACERCA DE (NUEVO - Índice 1)
                    _buildProfileCard(
                      title: 'Acerca de',
                      icon: Icons.info_outline, // Icono de información
                      index: 1,
                      showArrow: true,
                      onTap: () {
                        _showAboutModal(
                          context,
                        ); // Llama a la función del modal
                      },
                    ),
                    const SizedBox(height: 20),

                    // BOTÓN 3: CERRAR SESIÓN (Índice 2)
                    _buildProfileCard(
                      title: 'Cerrar Sesión',
                      icon: Icons.logout,
                      index: 2,
                      isDestructive: true,
                      onTap: _logout,
                    ),

                    // ESPACIO Y VERSIÓN AL PIE
                    const SizedBox(height: 40),
                    const Text(
                      'Dental Lanch v0.1.0',
                      style: TextStyle(color: kTextGrayColor, fontSize: 14),
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
