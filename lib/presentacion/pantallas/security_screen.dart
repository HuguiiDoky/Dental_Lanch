import 'package:flutter/material.dart';
import '../../constants.dart';
import 'change_password_screen.dart';
import 'change_email_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  // Variable para saber cuál botón está seleccionado actualmente
  int? _selectedCardIndex;

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
          'Seguridad',
          style: TextStyle(color: kLogoGrayColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Opción 1: Cambiar Contraseña (Index 0)
              _buildSecurityOption(
                context,
                title: 'Cambiar Contraseña',
                icon: Icons.lock_outline,
                index: 0,
                onTap: () async {
                  // Navegamos y esperamos a que vuelva
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordScreen(),
                    ),
                  );
                  // Al volver, limpiamos la selección para que no se quede "pegado"
                  if (mounted) setState(() => _selectedCardIndex = null);
                },
              ),
              const SizedBox(height: 20),

              // Opción 2: Cambiar Correo (Index 1)
              _buildSecurityOption(
                context,
                title: 'Cambiar Correo Electrónico',
                icon: Icons.email_outlined,
                index: 1,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChangeEmailScreen(),
                    ),
                  );
                  if (mounted) setState(() => _selectedCardIndex = null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int index,
    required VoidCallback onTap,
  }) {
    // --- LÓGICA IDÉNTICA A PROFILE_SCREEN.DART ---
    final bool isSelected = _selectedCardIndex == index;

    // Colores dinámicos: Si está seleccionado, usa PrimaryColor, si no, usa el gris
    final Color borderColor = isSelected ? kPrimaryColor : kBorderGrayColor;
    final Color iconColor = isSelected ? kPrimaryColor : kLogoGrayColor;
    final Color textColor = isSelected ? kPrimaryColor : kLogoGrayColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCardIndex = index;
        });
        onTap(); // Ejecuta la navegación inmediatamente
      },
      // Usamos Container normal, no AnimatedContainer, para que el cambio sea instantáneo
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          // Borde dinámico: cambia color y grosor (1.5 si está seleccionado)
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
            Icon(
              Icons.arrow_forward_ios,
              // La flechita también se ilumina
              color: isSelected ? kPrimaryColor : kBorderGrayColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
