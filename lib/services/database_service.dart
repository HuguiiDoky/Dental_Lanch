// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

// --- IMPORTANTE: Importamos el servicio para que suene ---
import '../services/notification_service.dart';

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
      Map<String, dynamic>? patientData = await getUserData();

      if (patientData != null) {
        DocumentReference citaRef = await _db.collection('citas').add({
          'IDpaciente': user.uid,
          'IDodonto': appointmentData['IDodonto'] ?? 'no-id-odonto',
          'IDservicio': appointmentData['IDservicio'] ?? 'no-id-servicio',
          'nombrePaciente': patientData['nombres'],
          'apellidoPaciente': patientData['apellidos'],
          'nombreOdonto': appointmentData['nombreOdonto'],
          'apellidoOdonto': appointmentData['apellidoOdonto'] ?? '',
          'nombreServicio': appointmentData['nombreServicio'],
          'duracion': appointmentData['duracion'] ?? 30,
          'fechaISO': appointmentData['fechaISO'],
          'hora_inicio': appointmentData['hora_inicio'],
          'fecha': appointmentData['fecha'],
          'estado': 'pendiente',
          'fechaCreacion': FieldValue.serverTimestamp(),
          'recordatorioEnviado': false,
        });

        // Notificación de Confirmación (Base de datos)
        await _db
            .collection('usuarios')
            .doc(user.uid)
            .collection('notificaciones')
            .add({
              'titulo': 'Cita Agendada',
              'mensaje':
                  'Tu cita para ${appointmentData['nombreServicio']} ha sido registrada correctamente.',
              'fecha': FieldValue.serverTimestamp(),
              'leido': false,
              'tipo': 'recordatorio',
              'idCitaRelacionada': citaRef.id,
            });

        // Opcional: Si quieres que suene al crearla también, descomenta esto:
        /*
        await NotificationService.showNotification(
           id: citaRef.hashCode,
           title: 'Cita Agendada',
           body: 'Tu cita para ${appointmentData['nombreServicio']} ha sido registrada.',
        );
        */
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

  // --- NOTIFICACIONES ---

  Stream<List<NotificationModel>> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('usuarios')
        .doc(user.uid)
        .collection('notificaciones')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db
          .collection('usuarios')
          .doc(user.uid)
          .collection('notificaciones')
          .doc(notificationId)
          .update({'leido': true});
    }
  }

  // --- LOGICA AUTOMÁTICA ---

  // A. Revisar citas expiradas (MODIFICADO PARA QUE SUENE)
  Future<void> checkExpiredAppointments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    final querySnapshot = await _db
        .collection('citas')
        .where('IDpaciente', isEqualTo: user.uid)
        .where('estado', isEqualTo: 'pendiente')
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      DateTime? appointmentDate;

      if (data['fechaISO'] != null) {
        try {
          appointmentDate = DateTime.parse(data['fechaISO']);
        } catch (_) {}
      }

      if (appointmentDate != null) {
        // Si la fecha ya pasó
        if (appointmentDate.isBefore(now)) {
          // 1. Actualizamos estado en Firestore
          await _db.collection('citas').doc(doc.id).update({
            'estado': 'expirada',
          });

          String titulo = 'Cita Expirada';
          String mensaje =
              'Tu cita de ${data['nombreServicio']} programada para el ${data['fecha']} ha expirado.';

          // 2. Guardamos en el historial de notificaciones de la app
          await _db
              .collection('usuarios')
              .doc(user.uid)
              .collection('notificaciones')
              .add({
                'titulo': titulo,
                'mensaje': mensaje,
                'fecha': FieldValue.serverTimestamp(),
                'leido': false,
                'tipo': 'alerta',
                'idCitaRelacionada': doc.id,
              });

          // 3. ¡NUEVO! Enviamos la notificación al celular (Sonido/Vibración)
          await NotificationService.showNotification(
            id: doc.id.hashCode,
            title: titulo,
            body: mensaje,
          );

          print("⚠️ Cita expirada marcada y notificada: ${doc.id}");
        }
      }
    }
  }

  // B. Revisar recordatorios
  Future<void> checkUpcomingReminders() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final next24Hours = now.add(const Duration(hours: 24));

    final querySnapshot = await _db
        .collection('citas')
        .where('IDpaciente', isEqualTo: user.uid)
        .where('estado', isEqualTo: 'pendiente')
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();

      // Si ya enviamos el recordatorio, saltamos esta cita
      if (data['recordatorioEnviado'] == true) continue;

      DateTime? appointmentDate;
      if (data['fechaISO'] != null) {
        try {
          appointmentDate = DateTime.parse(data['fechaISO']);
        } catch (_) {}
      }

      if (appointmentDate != null) {
        // Si la cita es en el futuro cercano (dentro de 24h)
        if (appointmentDate.isAfter(now) &&
            appointmentDate.isBefore(next24Hours)) {
          final bool isToday =
              appointmentDate.day == now.day &&
              appointmentDate.month == now.month &&
              appointmentDate.year == now.year;

          String titulo = isToday ? '¡Tu Cita es Hoy!' : 'Recordatorio de Cita';
          String mensaje = isToday
              ? '¡No lo olvides! Tienes una cita HOY para ${data['nombreServicio']} a las ${data['hora_inicio']}.'
              : '¡Prepárate! Tienes una cita MAÑANA para ${data['nombreServicio']} a las ${data['hora_inicio']}.';

          // 1. Guardar en Firestore (Historial en la app)
          await _db
              .collection('usuarios')
              .doc(user.uid)
              .collection('notificaciones')
              .add({
                'titulo': titulo,
                'mensaje': mensaje,
                'fecha': FieldValue.serverTimestamp(),
                'leido': false,
                'tipo': 'recordatorio',
                'idCitaRelacionada': doc.id,
              });

          // 2. ENVIAR NOTIFICACIÓN AL CELULAR (Sonido/Vibración)
          await NotificationService.showNotification(
            id: doc.id.hashCode,
            title: titulo,
            body: mensaje,
          );

          // 3. Marcar como enviada para no repetir
          await _db.collection('citas').doc(doc.id).update({
            'recordatorioEnviado': true,
          });

          print("✅ Recordatorio enviado y marcado para cita: ${doc.id}");
        }
      }
    }
  }
}
