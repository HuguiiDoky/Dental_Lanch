import 'package:flutter/material.dart';
import '../../constants.dart';
import 'home_screen.dart';

class AppointmentConfirmationScreen extends StatelessWidget {
  final Map<String, String> serviceData;
  final Map<String, String> dentistData;
  final DateTime selectedDate;
  final String selectedTime;

  const AppointmentConfirmationScreen({
    super.key,
    required this.serviceData,
    required this.dentistData,
    required this.selectedDate,
    required this.selectedTime,
  });

  @override
  Widget build(BuildContext context) {
    // Formatear la fecha manualmente para mostrarla bonita
    final List<String> days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final List<String> months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    final String dayName = days[selectedDate.weekday - 1];
    final String dayNum = selectedDate.day.toString();
    final String monthName = months[selectedDate.month - 1];
    final String year = selectedDate.year.toString();

    final String formattedDate =
        "$dayName, $dayNum de $monthName $year - $selectedTime";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icono de Éxito (Check verde)
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F7FA),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00C853),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Título
              const Text(
                '¡Cita Confirmada!',
                style: TextStyle(
                  color: kLogoGrayColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Descripción
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: kTextGrayColor, fontSize: 16),
                  children: [
                    const TextSpan(text: 'Tu cita con '), // Ajuste de texto
                    TextSpan(
                      text: dentistData['name'], // "Odont. Juan Perez"
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '\nha sido agendada con éxito.'),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Tarjeta Resumen Fecha y Hora
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: kPrimaryColor),
                    const SizedBox(width: 12),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: kLogoGrayColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Botón "Ver mis citas"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navegar al Home -> Pestaña 1 (Mis Citas)
                    // Usamos pushAndRemoveUntil para que no puedan volver atrás al formulario
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(
                          initialIndex: 1, // 1 = Pestaña de Citas
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ver mis citas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botón "Volver al inicio"
              TextButton(
                onPressed: () {
                  // Navegar al Home -> Pestaña 0 (Dashboard)
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(
                        initialIndex: 0, // 0 = Home Dashboard
                      ),
                    ),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Volver al inicio',
                  style: TextStyle(
                    color: kTextGrayColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
