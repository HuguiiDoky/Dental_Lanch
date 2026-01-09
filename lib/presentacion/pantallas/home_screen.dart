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
  const HomeScreen({super.key, this.initialIndex = 0});

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getUserAppointments(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> appointments = [];

        if (snapshot.hasData) {
          // 1. Convertir docs a lista
          final rawDocs = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            String nombreServicio = (data['nombreServicio'] ?? 'Tratamiento')
                .toString();
            String nombreOdonto = (data['nombreOdonto'] ?? 'Odontólogo')
                .toString();
            String apellidoOdonto = (data['apellidoOdonto'] ?? '').toString();
            String fechaTexto = (data['fecha'] ?? 'Fecha pendiente').toString();
            String fechaISO = (data['fechaISO'] ?? '').toString();

            String doctorDisplay = 'Odont. $nombreOdonto $apellidoOdonto'
                .trim();

            return <String, dynamic>{
              'treatment': nombreServicio,
              'doctor': doctorDisplay,
              'date': fechaTexto,
              'fechaISO': fechaISO,
              'hora_inicio': (data['hora_inicio'] ?? '00:00').toString(),
            };
          }).toList();

          // 2. Ordenar por fecha (fechaISO)
          rawDocs.sort((a, b) {
            String dateA = (a['fechaISO'] ?? '').toString();
            String dateB = (b['fechaISO'] ?? '').toString();
            // Comparación de Strings ISO es segura para fechas (YYYY-MM-DD...)
            // "2026-01-09" es menor que "2026-01-10"
            return dateA.compareTo(dateB);
          });

          // 3. Filtrar citas pasadas
          final now = DateTime.now();
          // Usamos una tolerancia de 2 horas atrás para que la cita no desaparezca apenas empieza
          final threshold = now.subtract(const Duration(hours: 2));

          appointments = rawDocs.where((app) {
            String isoStr = (app['fechaISO'] ?? '').toString();
            if (isoStr.isEmpty) return false;
            try {
              DateTime date = DateTime.parse(isoStr);
              return date.isAfter(threshold);
            } catch (e) {
              return false;
            }
          }).toList();

          // Si todas son pasadas, mostramos la lista vacía o la última (opcional)
          // appointments = rawDocs; // Descomentar para ver TODAS sin filtrar pasadas
        }

        final List<Widget> widgetOptions = <Widget>[
          _HomeScreenContent(
            appointments: appointments,
          ), // Lista ordenada y filtrada
          AppointmentsScreen(appointments: appointments),
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
  final List<Map<String, dynamic>> appointments;

  const _HomeScreenContent({required this.appointments});

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

    // Al estar la lista ya ordenada por fecha (ascendente) y filtrada (futuras),
    // el primer elemento SIEMPRE es la cita más próxima.
    final nextAppointment = widget.appointments.isNotEmpty
        ? widget.appointments.first
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: _firestoreService.getUserData(),
              builder: (context, snapshot) {
                String userName = 'Cargando...';
                String initials = '...';
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!;
                  final nombres = (data['nombres'] ?? data['name'] ?? 'Usuario')
                      .toString();
                  final apellidos = (data['apellidos'] ?? data['surname'] ?? '')
                      .toString();
                  userName = '$nombres $apellidos';
                  if (nombres.isNotEmpty) {
                    initials =
                        '${nombres[0]}${apellidos.isNotEmpty ? apellidos[0] : ""}'
                            .toUpperCase();
                  }
                }
                return _buildHeader(userName, initials);
              },
            ),
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

  Widget _buildHeader(String name, String initials) {
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
