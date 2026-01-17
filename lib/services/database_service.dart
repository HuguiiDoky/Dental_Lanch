import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- USUARIOS ---
  Future<void> saveUser(String uid, Map<String, dynamic> userData) async {
    userData['uid'] = uid;
    await _db.collection('usuarios').doc(uid).set(userData);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _db
          .collection('usuarios')
          .doc(user.uid)
          .get();
      return doc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  // --- SERVICIOS ---
  Stream<QuerySnapshot> getServices() {
    return _db.collection('servicios').snapshots();
  }

  // --- CITAS ---
  Future<void> createAppointment(Map<String, dynamic> appointmentData) async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Obtenemos datos del paciente
      Map<String, dynamic>? patientData = await getUserData();

      if (patientData != null) {
        await _db.collection('citas').add({
          // IDs
          'IDpaciente': user.uid,
          'IDodonto': appointmentData['IDodonto'] ?? 'no-id-odonto',
          'IDservicio': appointmentData['IDservicio'] ?? 'no-id-servicio',

          // Datos Paciente
          'nombrePaciente': patientData['nombres'],
          'apellidoPaciente': patientData['apellidos'],

          // Datos Odontólogo
          'nombreOdonto': appointmentData['nombreOdonto'],
          'apellidoOdonto': appointmentData['apellidoOdonto'] ?? '',

          // Datos Servicio
          'nombreServicio': appointmentData['nombreServicio'],

          // --- AQUÍ ESTABA EL FALTANTE: Agregamos los campos vitales ---
          'duracion':
              appointmentData['duracion'] ?? 30, // Guardamos la duración (int)
          'fechaISO':
              appointmentData['fechaISO'], // Guardamos fecha ISO para validaciones
          'hora_inicio':
              appointmentData['hora_inicio'], // Guardamos hora visual
          // Detalles Cita
          'fecha': appointmentData['fecha'],
          'estado': 'pendiente',
          'fechaCreacion': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Stream<QuerySnapshot> getUserAppointments() {
    User? user = _auth.currentUser;
    if (user != null) {
      return _db
          .collection('citas')
          .where('IDpaciente', isEqualTo: user.uid)
          .snapshots();
    }
    return const Stream.empty();
  }
}
