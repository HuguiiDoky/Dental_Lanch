// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import '../../services/database_service.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    required List<Map<String, dynamic>> appointments,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // --- ESTADO ---
  int _selectedTab = 0; // 0: Próximas, 1: Pasadas, 2: Canceladas
  String? _selectedDoctor;
  String? _selectedService;
  bool _isRescheduling = false; // Para mostrar carga al reagendar

  // --- HELPER: Parseo Inteligente ---
  DateTime? _parseSmartDate(Map<String, dynamic> data) {
    var rawDate = data['fechaISO'] ?? data['fecha'];
    if (rawDate == null) return null;

    if (rawDate is Timestamp) return rawDate.toDate();

    String dateStr = rawDate.toString().trim();

    if (dateStr.startsWith('Timestamp')) {
      try {
        final secondsPart = dateStr.split('seconds=')[1].split(',')[0];
        final seconds = int.parse(secondsPart);
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } catch (_) {}
    }

    // Soporte ISO directo
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    // Soporte Texto Antiguo
    try {
      String cleanDate = dateStr;
      if (dateStr.contains(',')) cleanDate = dateStr.split(',')[1].trim();

      String datePart = cleanDate;
      String timePart = "";
      if (cleanDate.contains('-')) {
        var parts = cleanDate.split('-');
        datePart = parts[0].trim();
        if (parts.length > 1) timePart = parts[1].trim();
      }

      var dateTokens = datePart
          .split(' ')
          .where((t) => t.toLowerCase() != 'de')
          .toList();

      if (dateTokens.length >= 3) {
        int day = int.parse(dateTokens[0]);
        int year = int.parse(dateTokens[2]);
        String monthStr = dateTokens[1].toLowerCase().substring(0, 3);
        const mapMeses = {
          'ene': 1,
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'abr': 4,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'ago': 8,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dic': 12,
          'dec': 12,
        };
        int month = mapMeses[monthStr] ?? 1;
        DateTime parsedDate = DateTime(year, month, day);

        if (timePart.isNotEmpty) {
          bool isPM = timePart.toUpperCase().contains('PM');
          bool isAM = timePart.toUpperCase().contains('AM');
          String cleanTime = timePart.replaceAll(RegExp(r'[A-Z\s]'), '');
          var tParts = cleanTime.split(':');
          if (tParts.length == 2) {
            int h = int.parse(tParts[0]);
            int m = int.parse(tParts[1]);
            if (isPM && h < 12) h += 12;
            if (isAM && h == 12) h = 0;
            parsedDate = DateTime(year, month, day, h, m);
          }
        }
        return parsedDate;
      }
    } catch (_) {}
    return null;
  }

  // --- LÓGICA DE BASE DE DATOS ---

  void _checkAndExpireAppointments(List<Map<String, dynamic>> appointments) {
    final now = DateTime.now();
    for (var app in appointments) {
      if (app['realDate'] == null || app['original_id'] == null) continue;
      DateTime date = app['realDate'];
      String status = (app['status'] ?? 'pendiente').toString().toLowerCase();
      String docId = app['original_id'];

      if (date.isBefore(now) && status == 'pendiente') {
        FirebaseFirestore.instance.collection('citas').doc(docId).update({
          'estado': 'expirada',
        });
      }
    }
  }

  Future<void> _cancelAppointment(String docId) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Cita'),
        content: const Text('¿Estás seguro que deseas cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('citas')
                  .doc(docId)
                  .update({'estado': 'cancelada'});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cita cancelada correctamente')),
              );
            },
            child: const Text(
              'Sí, Cancelar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAppointment(String docId) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cita'),
        content: const Text(
          'Esta acción borrará el registro permanentemente. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('citas')
                  .doc(docId)
                  .delete();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- REAGENDAMIENTO BLINDADO (La Joya de la Corona) ---
  Future<void> _showRescheduleDialog(
    BuildContext context,
    String docId,
    DateTime currentDate,
    String doctorId,
    int durationMinutes, // Recibimos la duración original
  ) async {
    // 1. Seleccionar Fecha
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate.isBefore(DateTime.now())
          ? DateTime.now()
          : currentDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null) return;

    // 2. Seleccionar Hora
    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return;

    // 3. Construir Fechas Nuevas
    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final newEnd = newStart.add(Duration(minutes: durationMinutes));

    // Validar que sea futuro
    if (newStart.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes reagendar al pasado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isRescheduling = true);

    try {
      // 4. VALIDACIÓN DE CONFLICTOS (Lógica Idéntica al Paso 3)

      // a) Verificar horario clínica
      final Map<int, String> diasSemana = {
        1: 'lunes',
        2: 'martes',
        3: 'miercoles',
        4: 'jueves',
        5: 'viernes',
        6: 'sabado',
        7: 'domingo',
      };
      String diaKey = diasSemana[newStart.weekday]!;

      DocumentSnapshot configDoc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('horarios_clinica')
          .get();
      if (configDoc.exists) {
        Map<String, dynamic> configData =
            configDoc.data() as Map<String, dynamic>;
        if (configData.containsKey(diaKey)) {
          Map<String, dynamic> diaData = configData[diaKey];
          if (!(diaData['abierto'] ?? false)) {
            throw "La clínica está cerrada los $diaKey.";
          }

          // Validar límites de hora (apertura/cierre)
          // (Opcional: implementar parseo de horas de apertura para ser estricto,
          //  por ahora confiamos en la validación de colisiones como principal filtro)
        }
      }

      // b) Verificar colisiones con otras citas
      QuerySnapshot conflictQuery = await FirebaseFirestore.instance
          .collection('citas')
          .where('IDodonto', isEqualTo: doctorId)
          .where('estado', isNotEqualTo: 'cancelada')
          .get();

      for (var doc in conflictQuery.docs) {
        // ¡IMPORTANTE! Ignorar la cita actual que estamos moviendo, si no chocará consigo misma
        if (doc.id == docId) continue;

        var data = doc.data() as Map<String, dynamic>;

        // Parsear fecha existente
        DateTime? existingStart;
        if (data['fechaISO'] != null) {
          try {
            existingStart = DateTime.parse(data['fechaISO'].toString());
          } catch (_) {}
        } else if (data['fecha'] is Timestamp) {
          existingStart = (data['fecha'] as Timestamp).toDate();
        }

        if (existingStart == null) continue;

        // Verificar solo si es el mismo día
        if (existingStart.year == newStart.year &&
            existingStart.month == newStart.month &&
            existingStart.day == newStart.day) {
          int existingDur =
              int.tryParse(data['duracion']?.toString() ?? '30') ?? 30;
          DateTime existingEnd = existingStart.add(
            Duration(minutes: existingDur),
          );

          // Fórmula de Colisión
          if (newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart)) {
            throw "El doctor ya tiene una cita a esa hora (choca con otra de $existingDur min).";
          }
        }
      }

      // 5. Preparar Datos Visuales
      const dias = {
        'Monday': 'Lunes',
        'Tuesday': 'Martes',
        'Wednesday': 'Miércoles',
        'Thursday': 'Jueves',
        'Friday': 'Viernes',
        'Saturday': 'Sábado',
        'Sunday': 'Domingo',
      };
      const meses = {
        1: 'Ene',
        2: 'Feb',
        3: 'Mar',
        4: 'Abr',
        5: 'May',
        6: 'Jun',
        7: 'Jul',
        8: 'Ago',
        9: 'Sep',
        10: 'Oct',
        11: 'Nov',
        12: 'Dic',
      };

      String diaIngles = DateFormat('EEEE').format(newStart);
      String diaEsp = dias[diaIngles] ?? 'Día';
      String mesEsp = meses[newStart.month] ?? '';
      String hourStr = DateFormat('hh:mm a').format(newStart);
      String fechaVisual =
          "$diaEsp, ${newStart.day} de $mesEsp ${newStart.year} - $hourStr";

      // 6. ACTUALIZAR FIREBASE (Conservando Duración)
      await FirebaseFirestore.instance.collection('citas').doc(docId).update({
        'fecha': fechaVisual,
        'fechaISO': newStart.toIso8601String(),
        'hora_inicio': hourStr,
        // No tocamos 'duracion', se mantiene la original
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita reagendada con éxito')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception:", "")),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRescheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'Mis Citas',
            style: TextStyle(
              color: kLogoGrayColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getUserAppointments(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error cargando citas'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<Map<String, dynamic>> allAppointments = [];
              Set<String> uniqueDoctors = {};
              Set<String> uniqueServices = {};

              if (snapshot.hasData) {
                allAppointments = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  String nombreOdonto = (data['nombreOdonto'] ?? 'Odontólogo')
                      .toString();
                  String apellidoOdonto = (data['apellidoOdonto'] ?? '')
                      .toString();
                  String doctorDisplay = 'Odont. $nombreOdonto $apellidoOdonto'
                      .trim();
                  String servicio = (data['nombreServicio'] ?? 'Tratamiento')
                      .toString();

                  if (doctorDisplay.length > 7) {
                    uniqueDoctors.add(doctorDisplay);
                  }
                  if (servicio.isNotEmpty) uniqueServices.add(servicio);

                  return {
                    'treatment': servicio,
                    'doctor': doctorDisplay,
                    'date': (data['fecha'] ?? 'Fecha pendiente').toString(),
                    'realDate': _parseSmartDate(data),
                    'original_id': doc.id,
                    'status': (data['estado'] ?? 'pendiente')
                        .toString()
                        .toLowerCase(),

                    // --- DATOS CLAVE PARA REAGENDAR ---
                    'doctor_id':
                        data['IDodonto'], // ID del doctor para validar agenda
                    'duration':
                        data['duracion'] ??
                        30, // Duración original (default 30)
                  };
                }).toList();

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _checkAndExpireAppointments(allAppointments),
                );
              }

              // FILTRADO
              final now = DateTime.now();
              var filteredList = allAppointments.where((app) {
                if (app['realDate'] == null) return false;
                final date = app['realDate'] as DateTime;
                final status = app['status'];

                if (_selectedTab == 0) {
                  return date.isAfter(now) && status != 'cancelada';
                }
                if (_selectedTab == 1) {
                  return date.isBefore(now) && status != 'cancelada';
                }
                return status == 'cancelada';
              }).toList();

              if (_selectedDoctor != null) {
                filteredList = filteredList
                    .where((app) => app['doctor'] == _selectedDoctor)
                    .toList();
              }
              if (_selectedService != null) {
                filteredList = filteredList
                    .where((app) => app['treatment'] == _selectedService)
                    .toList();
              }

              filteredList.sort((a, b) {
                DateTime dA = a['realDate'];
                DateTime dB = b['realDate'];
                return _selectedTab == 0 ? dA.compareTo(dB) : dB.compareTo(dA);
              });

              return SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _buildTabButton('Próximas', 0),
                                _buildTabButton('Pasadas', 1),
                                _buildTabButton('Canceladas', 2),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (allAppointments.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip<String>(
                                    label: 'Odóntologo',
                                    value: _selectedDoctor,
                                    items: uniqueDoctors.toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedDoctor = val),
                                    icon: Icons.person_outline,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildFilterChip<String>(
                                    label: 'Servicio',
                                    value: _selectedService,
                                    items: uniqueServices.toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedService = val),
                                    icon: Icons.medical_services_outlined,
                                  ),
                                  if (_selectedDoctor != null ||
                                      _selectedService != null) ...[
                                    const SizedBox(width: 10),
                                    IconButton(
                                      onPressed: () => setState(() {
                                        _selectedDoctor = null;
                                        _selectedService = null;
                                      }),
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filteredList.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) =>
                                  _buildAppointmentCard(filteredList[index]),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Overlay de carga
          if (_isRescheduling)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              ),
            ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildTabButton(String text, int index) {
    bool isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isActive ? kPrimaryColor : kLogoGrayColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: value != null ? kPrimaryColor.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value != null ? kPrimaryColor : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: value != null ? kPrimaryColor : kLogoGrayColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null ? kPrimaryColor : kLogoGrayColor,
                ),
              ),
            ],
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: value != null ? kPrimaryColor : kLogoGrayColor,
          ),
          isDense: true,
          items: items
              .map(
                (String item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item.length > 20 ? '${item.substring(0, 20)}...' : item,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon = _selectedTab == 0
        ? Icons.calendar_today_outlined
        : (_selectedTab == 1 ? Icons.history : Icons.event_busy_outlined);
    String text = _selectedTab == 0
        ? 'No tienes citas próximas'
        : (_selectedTab == 1
              ? 'No hay historial de citas'
              : 'No hay citas canceladas');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: kBorderGrayColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: kTextGrayColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    bool isUpcoming = _selectedTab == 0;
    String status = (appointment['status'] ?? '').toString().toUpperCase();
    String badgeText = isUpcoming
        ? 'PENDIENTE'
        : (_selectedTab == 1
              ? (status == 'EXPIRADA' ? 'EXPIRADA' : 'FINALIZADA')
              : 'CANCELADA');
    Color badgeColor = isUpcoming
        ? kPrimaryColor
        : (_selectedTab == 1 ? Colors.grey : Colors.red.shade300);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isUpcoming ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderGrayColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appointment['treatment'] ?? '',
                style: TextStyle(
                  color: isUpcoming ? kLogoGrayColor : kTextGrayColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: badgeColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            appointment['doctor'] ?? '',
            style: const TextStyle(color: kTextGrayColor, fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: kBorderGrayColor),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18, color: kPrimaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appointment['date'] ?? '',
                  style: const TextStyle(
                    color: kLogoGrayColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRescheduleDialog(
                      context,
                      appointment['original_id'],
                      appointment['realDate'],
                      appointment['doctor_id'], // Pasar ID Doctor
                      int.tryParse(appointment['duration'].toString()) ??
                          30, // Pasar Duración Real
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Reagendar',
                      style: TextStyle(color: kPrimaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        _cancelAppointment(appointment['original_id']),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: kTextGrayColor),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_selectedTab == 2) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _deleteAppointment(appointment['original_id']),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 18,
                ),
                label: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
