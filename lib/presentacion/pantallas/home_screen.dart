import 'package:flutter/material.dart';
import '../../constants.dart';
import 'profile_screen.dart';
import 'ac_pasouno.dart';
import 'citas.dart';
import '../../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const int kHomePageIndex = 0;
const int kCalendarPageIndex = 1;
const int kNotificationsPageIndex = 2;
const int kProfilePageIndex = 3;
const double kBottomNavigationBarHeight = 80.0;

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({
    super.key,
    this.initialIndex = 0,
    Map<String, String>? newAppointment,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentPageIndex;
  final PageController _pageController = PageController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPageIndex);
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() => _currentPageIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToProfile() {
    _onItemTapped(kProfilePageIndex);
  }

  // --- HELPER: Parseo Inteligente (Soporte Español y Timestamps) ---
  DateTime? _parseSmartDate(Map<String, dynamic> data) {
    // Intentamos buscar la fecha en varios campos posibles
    var rawDate = data['fechaISO'] ?? data['fecha'];
    if (rawDate == null) return null;

    // CASO 1: Es un objeto Timestamp de Firebase directamente
    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    // CASO 2: Es un String
    String dateStr = rawDate.toString().trim();

    // Limpieza: Si viene como "Timestamp(seconds=...)" en string (error común de importación)
    if (dateStr.startsWith('Timestamp')) {
      try {
        // Extraer segundos
        final secondsPart = dateStr.split('seconds=')[1].split(',')[0];
        final seconds = int.parse(secondsPart);
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } catch (_) {}
    }

    // CASO 3: Formato Texto Español (ej: "Viernes, 16 de Ene 2026 - 03:00 PM")
    // Este es el formato que se ve en tus capturas.
    try {
      // 1. Limpiar día de la semana (lo que está antes de la primera coma)
      String cleanDate = dateStr;
      if (dateStr.contains(',')) {
        cleanDate = dateStr.split(',')[1].trim(); // "16 de Ene 2026 - 03:00 PM"
      }

      // 2. Separar fecha y hora
      String datePart = cleanDate;
      String timePart = "";

      if (cleanDate.contains('-')) {
        var parts = cleanDate.split('-');
        datePart = parts[0].trim(); // "16 de Ene 2026"
        if (parts.length > 1) timePart = parts[1].trim(); // "03:00 PM"
      }

      // 3. Parsear la fecha (día mes año)
      var dateTokens = datePart.split(' '); // ["16", "de", "Ene", "2026"]
      // Filtramos "de" para quedarnos con [16, Ene, 2026]
      dateTokens = dateTokens.where((t) => t.toLowerCase() != 'de').toList();

      if (dateTokens.length >= 3) {
        int day = int.parse(dateTokens[0]);
        int year = int.parse(dateTokens[2]);
        String monthStr = dateTokens[1].toLowerCase().substring(0, 3); // "ene"

        // Mapa de meses
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

        // 4. Agregar Hora si existe
        if (timePart.isNotEmpty) {
          // Formato esperado: "03:00 PM" o "10:00 AM"
          bool isPM = timePart.toUpperCase().contains('PM');
          bool isAM = timePart.toUpperCase().contains('AM');

          // Quitar letras para dejar solo "03:00"
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
    } catch (e) {
      // Fallo el parseo de texto español
    }

    // CASO 4: Fallback ISO (yyyy-mm-dd)
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getUserAppointments(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> allAppointments = [];
        Map<String, dynamic>? nextAppointment;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          // 1. Convertir documentos a Objetos con fecha real parseada
          var rawList = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            String nombreServicio = (data['nombreServicio'] ?? 'Tratamiento')
                .toString();
            String nombreOdonto = (data['nombreOdonto'] ?? 'Odontólogo')
                .toString();
            String apellidoOdonto = (data['apellidoOdonto'] ?? '').toString();
            String doctorDisplay = 'Odont. $nombreOdonto $apellidoOdonto'
                .trim();

            // Detectamos si el campo fecha visual ya tiene la hora integrada
            // (Como en "Viernes... - 03:00 PM")
            String displayDate = (data['fecha'] ?? 'Pendiente').toString();

            // Intentamos parsear
            DateTime? realDate = _parseSmartDate(data);

            return {
              'treatment': nombreServicio,
              'doctor': doctorDisplay,
              'date': displayDate,
              'realDate': realDate,
            };
          }).toList();

          // 2. Filtrar solo las fechas válidas
          var validList = rawList
              .where((app) => app['realDate'] != null)
              .toList();

          // 3. Ordenar TODAS cronológicamente para la lista "Mis Citas"
          validList.sort((a, b) {
            return (a['realDate'] as DateTime).compareTo(
              b['realDate'] as DateTime,
            );
          });

          allAppointments = validList;

          // 4. Encontrar la "Próxima Cita"
          final now = DateTime.now();
          // Margen de 1 hora: Si la cita es hoy a las 9am y son las 9:30, todavía la muestra un rato.
          final threshold = now.subtract(const Duration(hours: 1));

          try {
            // firstWhere devuelve el primer elemento que cumple la condición
            // Como la lista ya está ordenada (paso 3), la primera que sea mayor a 'ahora' es la más próxima.
            nextAppointment = validList.firstWhere((app) {
              return (app['realDate'] as DateTime).isAfter(threshold);
            });
          } catch (e) {
            nextAppointment = null;
          }
        }

        final List<Widget> widgetOptions = <Widget>[
          _HomeScreenContent(appointment: nextAppointment),
          AppointmentsScreen(appointments: allAppointments),
          const Center(
            child: Text(
              'Notificaciones',
              style: TextStyle(fontSize: 24, color: kLogoGrayColor),
            ),
          ),
          const ProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: Colors.white,
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPageIndex = index),
            children: widgetOptions,
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today),
                label: 'Citas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_none_outlined),
                activeIcon: Icon(Icons.notifications),
                label: 'Notis',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
            currentIndex: _currentPageIndex,
            selectedItemColor: kPrimaryColor,
            unselectedItemColor: kLogoGrayColor,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            elevation: 10.0,
            backgroundColor: Colors.white,
          ),
        );
      },
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  final Map<String, dynamic>? appointment;

  const _HomeScreenContent({this.appointment});

  @override
  State<_HomeScreenContent> createState() => __HomeScreenContentState();
}

class __HomeScreenContentState extends State<_HomeScreenContent> {
  int? _selectedCardIndex;
  bool _isNotificationActive = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>();
    final nextAppointment = widget.appointment;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildNextAppointmentCard(nextAppointment),
            const SizedBox(height: 40),
            const Text(
              '¿Qué necesitas hoy?',
              style: TextStyle(
                color: kLogoGrayColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildNavigationCard(
              title: 'Agendar cita',
              icon: Icons.calendar_today_outlined,
              index: 0,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScheduleAppointmentScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildNavigationCard(
              title: 'Mis citas',
              icon: Icons.list_alt_outlined,
              index: 1,
              onTap: () => homeScreenState?._onItemTapped(kCalendarPageIndex),
            ),
            const SizedBox(height: 16),
            _buildNavigationCard(
              title: 'Mi Perfil',
              icon: Icons.person_outline,
              index: 2,
              onTap: () => homeScreenState?._navigateToProfile(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _firestoreService.getUserData(),
      builder: (context, snapshot) {
        String name = 'Cargando...';
        String initials = '...';

        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          final n = (data['nombres'] ?? data['name'] ?? 'Usuario').toString();
          final a = (data['apellidos'] ?? data['surname'] ?? '').toString();
          final rol = (data['rol'] ?? '').toString();

          String prefix = '';
          if (rol == 'odontologo') {
            prefix = 'Odont. ';
          }

          name = '$prefix$n $a'.trim();

          if (n.isNotEmpty) {
            initials =
                n[0].toUpperCase() + (a.isNotEmpty ? a[0].toUpperCase() : '');
          }
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bienvenido,',
                    style: TextStyle(color: kTextGrayColor, fontSize: 18),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      color: kLogoGrayColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 35,
              backgroundColor: kPrimaryColor,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNextAppointmentCard(Map<String, dynamic>? appointment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // ignore: deprecated_member_use
        border: Border.all(color: kBorderGrayColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Próxima Cita',
                style: TextStyle(
                  color: kPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isNotificationActive
                      ? Icons.notifications
                      : Icons.notifications_none_outlined,
                  color: _isNotificationActive ? kPrimaryColor : kLogoGrayColor,
                ),
                onPressed: () => setState(
                  () => _isNotificationActive = !_isNotificationActive,
                ),
              ),
            ],
          ),
          if (appointment == null) ...[
            const SizedBox(height: 20),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.event_note, color: kBorderGrayColor, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'No tienes citas programadas',
                    style: TextStyle(color: kTextGrayColor, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              appointment['treatment']?.toString() ?? '',
              style: const TextStyle(
                color: kLogoGrayColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              appointment['doctor']?.toString() ?? '',
              style: const TextStyle(color: kTextGrayColor, fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Divider(color: kBorderGrayColor),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: kLogoGrayColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appointment['date']?.toString() ?? '',
                    style: const TextStyle(
                      color: kLogoGrayColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationCard({
    required String title,
    required IconData icon,
    required int index,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _selectedCardIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCardIndex = index);
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimaryColor : kBorderGrayColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? kPrimaryColor : kLogoGrayColor,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: kLogoGrayColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isSelected ? kPrimaryColor : kBorderGrayColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
