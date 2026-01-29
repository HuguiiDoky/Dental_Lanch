import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final bool isRead;
  final String type; // 'recordatorio', 'info', 'sistema'
  final String? relatedId; // ID de la cita relacionada (opcional)

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.isRead = false,
    this.type = 'info',
    this.relatedId,
  });

  // Convertir de Firestore a Objeto Dart
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Manejo seguro de la fecha
    DateTime parsedDate = DateTime.now();
    if (data['fecha'] != null) {
      if (data['fecha'] is Timestamp) {
        parsedDate = (data['fecha'] as Timestamp).toDate();
      } else {
        parsedDate =
            DateTime.tryParse(data['fecha'].toString()) ?? DateTime.now();
      }
    }

    return NotificationModel(
      id: doc.id,
      title: data['titulo'] ?? 'Notificación',
      body: data['mensaje'] ?? '',
      date: parsedDate,
      isRead: data['leido'] ?? false,
      type: data['tipo'] ?? 'info',
      relatedId: data['idCitaRelacionada'],
    );
  }

  // Convertir de Objeto Dart a Mapa (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'titulo': title,
      'mensaje': body,
      'fecha': Timestamp.fromDate(date),
      'leido': isRead,
      'tipo': type,
      'idCitaRelacionada': relatedId,
    };
  }
}
