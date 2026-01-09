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
    // Formatear la fecha manualmente
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
                    const TextSpan(text: 'Tu cita con la '),
                    TextSpan(
                      text: dentistData['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '\nha sido agendada con éxito.'),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Fecha y Hora
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: kPrimaryColor),
                  const SizedBox(width: 12),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: kLogoGrayColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Botón "Ver mis citas"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // --- CORRECCIÓN: Ya no pasamos newAppointment ---
                    // Simplemente navegamos al tab 1 (Citas), Firebase ya tendrá los datos.
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(
                          initialIndex: 1, // Ir a pestaña Citas
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
                  // --- CORRECCIÓN: Ya no pasamos newAppointment ---
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(
                        initialIndex: 0, // Ir al Dashboard
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
