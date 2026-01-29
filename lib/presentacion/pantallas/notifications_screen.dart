// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:dental_lanch/models/notification_model.dart';
import '../../services/database_service.dart';
import '../../constants.dart'; // Importante para tus colores

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirestoreService _db = FirestoreService();

  // Función auxiliar para formatear la fecha
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays == 1) {
      return "Ayer";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  // Icono según el tipo
  IconData _getIconForType(String type) {
    switch (type) {
      case 'recordatorio':
        return Icons.calendar_month;
      case 'alerta':
        return Icons.warning_amber_rounded;
      case 'finalizada':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Scaffold pero sin AppBar para mantener el estilo "Clean" de tu app
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER (Título Grande igual al Home/Citas) ---
            const Padding(
              padding: EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 20.0),
              child: Text(
                'Notificaciones',
                style: TextStyle(
                  color: kLogoGrayColor, // Color gris oscuro de tu marca
                  fontSize: 24, // Tamaño grande
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // --- LISTA DE NOTIFICACIONES ---
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _db.getUserNotifications(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: kBorderGrayColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No tienes notificaciones",
                            style: TextStyle(
                              color: kTextGrayColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      color: kBorderGrayColor, // Línea divisoria sutil
                    ),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final bool isUnread = !notification.isRead;

                      return Container(
                        // Fondo sutil si no está leída, blanco si ya se leyó
                        decoration: BoxDecoration(
                          color: isUnread
                              ? kPrimaryColor.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(
                            12,
                          ), // Bordes redondeados opcionales
                        ),
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                        ), // Espacio entre tarjetas
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isUnread
                                ? kPrimaryColor
                                : Colors.grey[200],
                            child: Icon(
                              _getIconForType(notification.type),
                              color: isUnread ? Colors.white : kLogoGrayColor,
                            ),
                          ),
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              color: kLogoGrayColor, // Color de marca
                              fontSize: 16,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                notification.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color:
                                      kTextGrayColor, // Color gris suave para texto secundario
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(notification.date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color:
                                      kBorderGrayColor, // Fecha en gris muy claro
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: isUnread
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.red, // Punto rojo de alerta
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          onTap: () {
                            if (isUnread) {
                              _db.markNotificationAsRead(notification.id);
                            }
                          },
                        ),
                      );
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
}
