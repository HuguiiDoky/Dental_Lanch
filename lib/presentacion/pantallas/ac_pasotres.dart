// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import 'ac_pasocuatro.dart';
import '../../services/database_service.dart'; // Importamos el servicio corregido

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
  List<String> _availableTimes = [];
  bool _isLoadingSlots = false;
  bool _isLoadingSubmit = false;
  String _debugMsg = "";

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAvailableSlots();
    });
  }

  // --- GENERADOR DE HORARIOS ---
  Future<void> _generateAvailableSlots() async {
    setState(() {
      _isLoadingSlots = true;
      _availableTimes = [];
      _selectedTime = null;
      _debugMsg = "";
    });

    try {
      final Map<int, String> diasSemana = {
        1: 'lunes',
        2: 'martes',
        3: 'miercoles',
        4: 'jueves',
        5: 'viernes',
        6: 'sabado',
        7: 'domingo',
      };
      String diaKey = diasSemana[_selectedDate.weekday]!;

      // 1. Configuración
      DocumentSnapshot configDoc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('horarios_clinica')
          .get();
      if (!configDoc.exists) {
        if (mounted) {
          setState(() {
            _isLoadingSlots = false;
            _debugMsg = "Error Config.";
          });
        }
        return;
      }
      Map<String, dynamic> configData =
          configDoc.data() as Map<String, dynamic>;

      if (!configData.containsKey(diaKey)) {
        if (mounted) {
          setState(() {
            _isLoadingSlots = false;
            _debugMsg = "Día no configurado.";
          });
        }
        return;
      }
      Map<String, dynamic> horarioDia =
          configData[diaKey] as Map<String, dynamic>;
      if (!(horarioDia['abierto'] ?? false)) {
        if (mounted) {
          setState(() {
            _isLoadingSlots = false;
            _debugMsg = "Clínica cerrada.";
          });
        }
        return;
      }

      // 2. Citas existentes
      QuerySnapshot citasSnapshot = await FirebaseFirestore.instance
          .collection('citas')
          .where('IDodonto', isEqualTo: widget.dentistData['id'])
          .where('estado', isNotEqualTo: 'cancelada')
          .get();

      List<Map<String, dynamic>> citasDelDia = [];
      for (var doc in citasSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime? fechaCita = _extraerFechaRobusta(data);

        if (fechaCita == null) continue;
        if (fechaCita.year == _selectedDate.year &&
            fechaCita.month == _selectedDate.month &&
            fechaCita.day == _selectedDate.day) {
          int duracionCita =
              int.tryParse(data['duracion']?.toString() ?? '30') ?? 30;
          citasDelDia.add({
            'inicio': fechaCita,
            'fin': fechaCita.add(Duration(minutes: duracionCita)),
          });
        }
      }

      // 3. Calcular Huecos
      String aperturaStr = horarioDia['apertura']?.toString() ?? "8:00 AM";
      String cierreStr = horarioDia['cierre']?.toString() ?? "8:00 PM";
      int stepVisual =
          int.tryParse(configData['step_visual']?.toString() ?? '30') ?? 30;
      int duracionServicio =
          int.tryParse(widget.serviceData['rawDuration'] ?? '30') ?? 30;

      DateTime horaInicio = _parseTimeStr(aperturaStr, _selectedDate);
      DateTime horaCierre = _parseTimeStr(cierreStr, _selectedDate);
      DateTime ahora = DateTime.now();
      bool esHoy =
          _selectedDate.year == ahora.year &&
          _selectedDate.month == ahora.month &&
          _selectedDate.day == ahora.day;

      List<String> tempSlots = [];
      DateTime iterador = horaInicio;

      while (iterador
              .add(Duration(minutes: duracionServicio))
              .isBefore(horaCierre) ||
          iterador
              .add(Duration(minutes: duracionServicio))
              .isAtSameMomentAs(horaCierre)) {
        DateTime finServicio = iterador.add(
          Duration(minutes: duracionServicio),
        );

        if (esHoy &&
            iterador.isBefore(ahora.add(const Duration(minutes: 30)))) {
          iterador = iterador.add(Duration(minutes: stepVisual));
          continue;
        }

        bool choca = false;
        for (var cita in citasDelDia) {
          if (iterador.isBefore(cita['fin']) &&
              finServicio.isAfter(cita['inicio'])) {
            choca = true;
            break;
          }
        }

        if (!choca) tempSlots.add(DateFormat('hh:mm a').format(iterador));
        iterador = iterador.add(Duration(minutes: stepVisual));
      }

      if (mounted) {
        setState(() {
          _availableTimes = tempSlots;
          _isLoadingSlots = false;
          if (tempSlots.isEmpty && _debugMsg.isEmpty) {
            _debugMsg = esHoy ? "No quedan horarios." : "Agenda llena.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
          _debugMsg = "Error cargando.";
        });
      }
    }
  }

  // --- HELPERS ---
  DateTime _parseTimeStr(String timeStr, DateTime dateBase) {
    try {
      String clean = timeStr.trim().toUpperCase();
      String nums = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      var parts = nums.split(':');
      if (parts.length < 2) return dateBase;
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      if (clean.contains('PM') && h != 12) h += 12;
      if (clean.contains('AM') && h == 12) h = 0;
      return DateTime(dateBase.year, dateBase.month, dateBase.day, h, m);
    } catch (e) {
      return dateBase;
    }
  }

  DateTime? _extraerFechaRobusta(Map<String, dynamic> data) {
    if (data['fechaISO'] != null) {
      try {
        return DateTime.parse(data['fechaISO'].toString());
      } catch (_) {}
    }
    if (data['fecha'] is Timestamp) {
      return (data['fecha'] as Timestamp).toDate();
    }
    if (data['fecha'] is String) {
      try {
        String f = data['fecha'];
        List<String> p = f.split(' - ');
        if (p.length == 2) return _parseTimeStr(p[1], _selectedDate);
      } catch (_) {}
    }
    return null;
  }

  // --- GUARDADO LIMPIO USANDO EL SERVICIO ---
  void _saveAppointment() async {
    if (_selectedTime == null) return;
    setState(() => _isLoadingSubmit = true);

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
    String formattedDateStr =
        "${days[_selectedDate.weekday - 1]}, ${_selectedDate.day} de ${months[_selectedDate.month - 1]} ${_selectedDate.year} - $_selectedTime";

    DateTime newStart = _parseTimeStr(_selectedTime!, _selectedDate);
    int duracionInt =
        int.tryParse(widget.serviceData['rawDuration'] ?? '30') ?? 30;
    DateTime newEnd = newStart.add(Duration(minutes: duracionInt));

    try {
      // Validación Anti-Choque
      QuerySnapshot checkQuery = await FirebaseFirestore.instance
          .collection('citas')
          .where('IDodonto', isEqualTo: widget.dentistData['id'])
          .where('estado', isNotEqualTo: 'cancelada')
          .get();

      for (var doc in checkQuery.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime? existingStart = _extraerFechaRobusta(data);
        if (data['fecha'] is String &&
            !data['fecha'].contains(
              "${_selectedDate.day} de ${months[_selectedDate.month - 1]} ${_selectedDate.year}",
            )) {
          continue;
        }
        if (existingStart == null) continue;

        if (existingStart.year == newStart.year &&
            existingStart.month == newStart.month &&
            existingStart.day == newStart.day) {
          int existingDuration =
              int.tryParse(data['duracion']?.toString() ?? '30') ?? 30;
          DateTime existingEnd = existingStart.add(
            Duration(minutes: existingDuration),
          );
          if (newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart)) {
            throw "¡Horario ocupado! ($existingDuration min)";
          }
        }
      }

      // --- USAMOS EL SERVICIO (Ahora sí funcionará) ---
      await _firestoreService.createAppointment({
        'IDodonto': widget.dentistData['id'],
        'IDservicio': widget.serviceData['id'],
        'nombreOdonto': widget.dentistData['rawName'],
        'apellidoOdonto': widget.dentistData['rawSurname'],
        'nombreServicio': widget.serviceData['title'],
        'fecha': formattedDateStr,

        // Estos campos ahora SÍ pasarán gracias a la actualización en database_service.dart
        'fechaISO': newStart.toIso8601String(),
        'duracion': duracionInt,
        'hora_inicio': _selectedTime,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentConfirmationScreen(
              serviceData: widget.serviceData,
              dentistData: widget.dentistData,
              selectedDate: _selectedDate,
              selectedTime: _selectedTime!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception:", "")),
            backgroundColor: Colors.red,
          ),
        );
        _generateAvailableSlots();
      }
    } finally {
      if (mounted) setState(() => _isLoadingSubmit = false);
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
                        ),
                        child: CalendarDatePicker(
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          onDateChanged: (newDate) {
                            setState(() => _selectedDate = newDate);
                            _generateAvailableSlots();
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
                    if (_isLoadingSlots)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: kPrimaryColor,
                          ),
                        ),
                      )
                    else if (_availableTimes.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.event_busy, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              _debugMsg.isNotEmpty
                                  ? _debugMsg
                                  : "No hay horarios disponibles.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _debugMsg.contains("Error")
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
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
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedTime == null || _isLoadingSubmit)
                      ? null
                      : _saveAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    disabledBackgroundColor: kBorderGrayColor.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoadingSubmit
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
