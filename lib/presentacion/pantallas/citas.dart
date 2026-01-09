import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';
import '../../services/database_service.dart'; // Importamos el servicio

class AppointmentsScreen extends StatefulWidget {
  // Ya no necesitamos recibir la lista por parámetro, la leeremos aquí mismo
  const AppointmentsScreen({
    super.key,
    List<Map<String, dynamic>>? appointments,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

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
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Expanded(
              // Usamos StreamBuilder para escuchar cambios en tiempo real
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getUserAppointments(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error al cargar citas'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Convertimos y ordenamos las citas
                  final docs = snapshot.data!.docs;
                  final List<Map<String, dynamic>> appointments = docs.map((
                    doc,
                  ) {
                    final data = doc.data() as Map<String, dynamic>;

                    // Formatear nombre del doctor
                    String nombreOdonto = (data['nombreOdonto'] ?? 'Odontólogo')
                        .toString();
                    String apellidoOdonto = (data['apellidoOdonto'] ?? '')
                        .toString();
                    String doctorDisplay =
                        'Odont. $nombreOdonto $apellidoOdonto'.trim();

                    return {
                      'treatment': (data['nombreServicio'] ?? 'Tratamiento')
                          .toString(),
                      'doctor': doctorDisplay,
                      'date': (data['fecha'] ?? 'Fecha pendiente').toString(),
                      'fechaISO': (data['fechaISO'] ?? '').toString(),
                    };
                  }).toList();

                  // Ordenar: Las más recientes primero (o al revés si prefieres)
                  // Aquí ordenamos por fechaISO descendente (nuevas arriba) o ascendente según prefieras
                  appointments.sort((a, b) {
                    String dateA = a['fechaISO'] ?? '';
                    String dateB = b['fechaISO'] ?? '';
                    return dateA.compareTo(
                      dateB,
                    ); // Ascendente: Pasadas -> Futuras
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 10.0,
                    ),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final app = appointments[index];
                      return _buildAppointmentCard(app);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            // ignore: deprecated_member_use
            color: kBorderGrayColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aún no tienes citas',
            style: TextStyle(
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // ignore: deprecated_member_use
        border: Border.all(color: kBorderGrayColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
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
          Text(
            appointment['treatment'] ?? '',
            style: const TextStyle(
              color: kLogoGrayColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
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
                  onPressed: () {},
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: kTextGrayColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
