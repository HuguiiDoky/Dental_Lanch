import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- USUARIOS ---
  // Colección: "usuarios"
  // Campos: uid, nombres, apellidos, email, rol, genero, cedula, especialidad

  Future<void> saveUser(String uid, Map<String, dynamic> userData) async {
    // Aseguramos que el uid esté dentro del documento como campo también
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
  // Colección: "servicios"
  // Campos: descripcion, duracion, nombreServicio, precio

  Stream<QuerySnapshot> getServices() {
    return _db.collection('servicios').snapshots();
  }

  // --- CITAS ---
  // Colección: "citas"
  // Campos: IDodonto, IDpaciente, IDservicio, apellidoOdonto, apellidoPaciente,
  //         estado, fecha, nombreOdonto, nombrePaciente, nombreServicio.

  Future<void> createAppointment(Map<String, dynamic> appointmentData) async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Obtenemos los datos del paciente actual para llenar apellidoPaciente y nombrePaciente
      Map<String, dynamic>? patientData = await getUserData();

      if (patientData != null) {
        await _db.collection('citas').add({
          // IDs
          'IDpaciente': user.uid,
          'IDodonto':
              appointmentData['IDodonto'] ??
              'no-id-odonto', // Debería venir del flujo anterior
          'IDservicio': appointmentData['IDservicio'] ?? 'no-id-servicio',

          // Datos Paciente
          'nombrePaciente': patientData['nombres'],
          'apellidoPaciente': patientData['apellidos'],

          // Datos Odontólogo
          'nombreOdonto': appointmentData['nombreOdonto'],
          'apellidoOdonto': appointmentData['apellidoOdonto'] ?? '',

          // Datos Servicio
          'nombreServicio': appointmentData['nombreServicio'],

          // Detalles Cita
          'fecha':
              appointmentData['fecha'], // String o Timestamp según prefieras
          'estado': 'pendiente', // Estado inicial
          // Metadata extra (opcional pero útil para ordenar)
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
          //.orderBy('fecha', descending: false) // Asegúrate de crear el índice en Firebase si usas esto
          .snapshots();
    }
    return const Stream.empty();
  }
}
