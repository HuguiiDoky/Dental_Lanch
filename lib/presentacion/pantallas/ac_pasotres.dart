import 'package:flutter/material.dart';
import '../../constants.dart';
import 'ac_pasocuatro.dart';
import '../../services/database_service.dart';

class ScheduleAppointmentStep3Screen extends StatefulWidget {
  final Map<String, String> serviceData;
  final Map<String, String> dentistData;

  const ScheduleAppointmentStep3Screen({
    super.key,
    required this.serviceData,
    required this.dentistData,
  });

  @override
  State<ScheduleAppointmentStep3Screen> createState() =>
      _ScheduleAppointmentStep3ScreenState();
}

class _ScheduleAppointmentStep3ScreenState
    extends State<ScheduleAppointmentStep3Screen> {
  late DateTime _selectedDate;
  String? _selectedTime;

  // Lista estática simple como pediste
  final List<String> _availableTimes = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
  ];

  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  void _saveAppointment() async {
    if (_selectedTime == null) return;

    setState(() => _isLoading = true);

    // Formateo de fecha para visualización
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
    final String dayName = days[_selectedDate.weekday - 1];
    final String monthName = months[_selectedDate.month - 1];
    final String formattedDateStr =
        "$dayName, ${_selectedDate.day} de $monthName ${_selectedDate.year} - $_selectedTime";

    // Fecha ISO para ordenamiento
    DateTime isoDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    int hour = int.parse(_selectedTime!.split(":")[0]);
    if (_selectedTime!.contains("PM") && hour != 12) hour += 12;
    if (_selectedTime!.contains("AM") && hour == 12) hour = 0;
    isoDate = isoDate.add(Duration(hours: hour));

    try {
      // --- AQUÍ ESTÁ LA SOLUCIÓN DEL APELLIDO ---
      // Usamos las claves 'rawName' y 'rawSurname' que vienen del Paso 2
      // para guardar los datos LIMPIOS en la base de datos.
      final String nombreLimpio = widget.dentistData['rawName'] ?? 'Odontólogo';
      final String apellidoLimpio = widget.dentistData['rawSurname'] ?? '';

      await _firestoreService.createAppointment({
        'IDodonto': widget.dentistData['id'] ?? 'temp_id',
        'IDservicio': widget.serviceData['id'] ?? 'temp_id',

        // Guardamos limpio, SIN "Odont."
        'nombreOdonto': nombreLimpio,
        'apellidoOdonto': apellidoLimpio,

        'nombreServicio': widget.serviceData['title'],
        'fecha': formattedDateStr,
        'fechaISO': isoDate.toIso8601String(),
        'hora_inicio': _selectedTime,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentConfirmationScreen(
              serviceData: widget.serviceData,
              dentistData: widget
                  .dentistData, // Sigue teniendo 'name' con "Odont." para la vista de confirmación
              selectedDate: _selectedDate,
              selectedTime: _selectedTime!,
            ),
          ),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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
          'Agendar Cita',
          style: TextStyle(
            color: kLogoGrayColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paso 3 de 4',
                      style: TextStyle(color: kTextGrayColor, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Elige fecha y hora',
                      style: TextStyle(
                        color: kPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: ThemeData(
                          colorScheme: const ColorScheme.light(
                            primary: kPrimaryColor,
                            onPrimary: Colors.white,
                            surface: Colors.transparent,
                            onSurface: kLogoGrayColor,
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                            ),
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: _selectedDate,
                          firstDate: today,
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          onDateChanged: (newDate) {
                            setState(() {
                              _selectedDate = newDate;
                              _selectedTime = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Horarios disponibles',
                      style: TextStyle(
                        color: kLogoGrayColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _availableTimes
                          .map((time) => _buildTimeChip(time))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedTime == null || _isLoading)
                      ? null
                      : _saveAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    // ignore: deprecated_member_use
                    disabledBackgroundColor: kBorderGrayColor.withOpacity(0.3),
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
                          'Confirmar y Siguiente',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String time) {
    final bool isSelected = _selectedTime == time;
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? kPrimaryColor : kBorderGrayColor,
          ),
        ),
        child: Text(
          time,
          style: TextStyle(
            color: isSelected ? Colors.white : kLogoGrayColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
