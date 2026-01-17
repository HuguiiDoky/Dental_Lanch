import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';
import 'ac_pasotres.dart';

class ScheduleAppointmentStep2Screen extends StatefulWidget {
  final Map<String, String> serviceData;

  const ScheduleAppointmentStep2Screen({super.key, required this.serviceData});

  @override
  State<ScheduleAppointmentStep2Screen> createState() =>
      _ScheduleAppointmentStep2ScreenState();
}

class _ScheduleAppointmentStep2ScreenState
    extends State<ScheduleAppointmentStep2Screen> {
  String? _selectedDentistId;
  Map<String, String>? _selectedDentistData;

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
                      'Paso 2 de 4',
                      style: TextStyle(color: kTextGrayColor, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona un Odontólogo',
                      style: TextStyle(
                        color: kPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Servicio: ${widget.serviceData['title']}',
                        style: const TextStyle(
                          color: kTextGrayColor,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('usuarios')
                          .where('rol', isEqualTo: 'odontologo')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(child: Text('Error al cargar'));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No hay odontólogos registrados'),
                          );
                        }

                        return Column(
                          children: snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String id = doc.id;
                            final String nombres =
                                (data['nombres'] ??
                                        data['name'] ??
                                        'Odontólogo')
                                    .toString();
                            final String apellidos =
                                (data['apellidos'] ?? data['surname'] ?? '')
                                    .toString();
                            final String especialidad =
                                (data['especialidad'] ?? 'General').toString();
                            final String displayName =
                                'Odont. $nombres $apellidos'.trim();
                            String initials =
                                (nombres.isNotEmpty ? nombres[0] : '') +
                                (apellidos.isNotEmpty ? apellidos[0] : '');

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildDentistCard(
                                name: displayName,
                                specialty: especialidad,
                                initials: initials.toUpperCase(),
                                id: id,
                                fullData: {
                                  'id': id,
                                  'name': displayName,
                                  'rawName': nombres,
                                  'rawSurname': apellidos,
                                  'specialty': especialidad,
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
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
                  onPressed: _selectedDentistId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ScheduleAppointmentStep3Screen(
                                    serviceData: widget
                                        .serviceData, // PASAJE DIRECTO DE DATOS
                                    dentistData: _selectedDentistData!,
                                  ),
                            ),
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
                    'Siguiente',
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

  Widget _buildDentistCard({
    required String name,
    required String specialty,
    required String initials,
    required String id,
    required Map<String, String> fullData,
  }) {
    final bool isSelected = _selectedDentistId == id;
    final Color borderColor = isSelected ? kPrimaryColor : kBorderGrayColor;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedDentistId = id;
        _selectedDentistData = fullData;
      }),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isSelected
                  ? kPrimaryColor
                  // ignore: deprecated_member_use
                  : kLogoGrayColor.withOpacity(0.5),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kLogoGrayColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialty,
                    style: const TextStyle(fontSize: 15, color: kTextGrayColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
