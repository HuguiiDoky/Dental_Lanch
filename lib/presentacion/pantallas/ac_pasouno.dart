import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';
import 'ac_pasodos.dart';

class ScheduleAppointmentScreen extends StatefulWidget {
  const ScheduleAppointmentScreen({super.key});

  @override
  State<ScheduleAppointmentScreen> createState() =>
      _ScheduleAppointmentScreenState();
}

class _ScheduleAppointmentScreenState extends State<ScheduleAppointmentScreen> {
  String? _selectedServiceId;
  Map<String, String>? _selectedServiceData;

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
                      'Paso 1 de 4',
                      style: TextStyle(color: kTextGrayColor, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona un servicio',
                      style: TextStyle(
                        color: kPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('servicios')
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
                            child: Text('No hay servicios disponibles'),
                          );
                        }

                        return Column(
                          children: snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String id = doc.id;
                            final String title =
                                (data['nombreServicio'] ?? 'Servicio')
                                    .toString();
                            final String descripcion =
                                (data['descripcion'] ?? '').toString();

                            // --- EXTRACCIÓN ROBUSTA DE DURACIÓN ---
                            // Forzamos a String para evitar errores de tipo
                            var rawDuracion = data['duracion'];
                            String duracionStr = rawDuracion != null
                                ? rawDuracion.toString()
                                : '30';

                            var rawPrecio = data['precio'] ?? 0;
                            String subtitle = '$duracionStr min - $descripcion';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildServiceCard(
                                title: title,
                                subtitle: subtitle,
                                id: id,
                                // AQUÍ ENVIAMOS EL DATO "rawDuration"
                                fullData: {
                                  'id': id,
                                  'title': title,
                                  'subtitle': subtitle,
                                  'rawDuration':
                                      duracionStr, // ESTE ES EL DATO IMPORTANTE
                                  'price': rawPrecio.toString(),
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
                // ignore: deprecated_member_use
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
                  onPressed: _selectedServiceId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ScheduleAppointmentStep2Screen(
                                    serviceData: _selectedServiceData!,
                                  ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    // ignore: deprecated_member_use
                    disabledBackgroundColor: kBorderGrayColor.withOpacity(0.3),
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

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required String id,
    required Map<String, String> fullData,
  }) {
    final bool isSelected = _selectedServiceId == id;
    final Color borderColor = isSelected ? kPrimaryColor : kBorderGrayColor;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedServiceId = id;
        _selectedServiceData = fullData;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kLogoGrayColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 15, color: kTextGrayColor),
            ),
          ],
        ),
      ),
    );
  }
}
