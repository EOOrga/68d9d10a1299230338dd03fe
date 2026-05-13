import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool _environmentScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

void main() {
  runApp(const DrapierPhilippeApp());
}

class DrapierPhilippeApp extends StatefulWidget {
  const DrapierPhilippeApp({super.key, this.screenshotModeOverride});

  final bool? screenshotModeOverride;

  @override
  State<DrapierPhilippeApp> createState() => _DrapierPhilippeAppState();
}

class _DrapierPhilippeAppState extends State<DrapierPhilippeApp> {
  late final OperationsStore _store = OperationsStore(
    screenshotMode: widget.screenshotModeOverride ?? _environmentScreenshotMode,
  );
  late final Future<void> _loadFuture = _store.load();

  @override
  Widget build(BuildContext context) {
    return OperationsScope(
      store: _store,
      child: MaterialApp(
        title: 'DRAPIER PHILIPPE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingScreen();
            }

            return const OperationsHome();
          },
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DrapierPhilippeApp();
  }
}

class AppTheme {
  static const Color ink = Color(0xFF1C2433);
  static const Color navy = Color(0xFF2E3950);
  static const Color slate = Color(0xFF63636C);
  static const Color gold = Color(0xFFDD9A3D);
  static const Color teal = Color(0xFF326A72);
  static const Color surface = Color(0xFFF6F7FA);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
      primary: navy,
      secondary: teal,
      tertiary: gold,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: navy,
        onPrimary: Colors.white,
        secondary: teal,
        onSecondary: Colors.white,
        tertiary: gold,
        onTertiary: ink,
        surface: Colors.white,
        onSurface: ink,
        surfaceContainerHighest: const Color(0xFFE9ECF2),
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE0E3EA)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD8DDE8)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: gold.withValues(alpha: .22),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: ink,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class OperationsScope extends InheritedNotifier<OperationsStore> {
  const OperationsScope({
    required OperationsStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static OperationsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OperationsScope>();
    assert(scope != null, 'OperationsScope is missing');
    return scope!.notifier!;
  }
}

class OperationsStore extends ChangeNotifier {
  OperationsStore({required this.screenshotMode});

  final bool screenshotMode;
  List<Reservation> reservations = <Reservation>[];
  List<MaintenanceTicket> tickets = <MaintenanceTicket>[];
  List<AttendanceRecord> attendance = <AttendanceRecord>[];
  List<TrainingCourse> training = <TrainingCourse>[];
  String siteLead = 'Operations desk';
  bool compactDashboard = false;

  static const String _reservationsKey = 'reservations';
  static const String _ticketsKey = 'tickets';
  static const String _attendanceKey = 'attendance';
  static const String _trainingKey = 'training';
  static const String _leadKey = 'siteLead';
  static const String _compactKey = 'compactDashboard';

  Future<void> load() async {
    if (screenshotMode) {
      _loadSampleData();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    reservations = _decodeList(
      prefs.getString(_reservationsKey),
      Reservation.fromJson,
    );
    tickets = _decodeList(
      prefs.getString(_ticketsKey),
      MaintenanceTicket.fromJson,
    );
    attendance = _decodeList(
      prefs.getString(_attendanceKey),
      AttendanceRecord.fromJson,
    );
    training = _decodeList(
      prefs.getString(_trainingKey),
      TrainingCourse.fromJson,
    );
    siteLead = prefs.getString(_leadKey) ?? 'Operations desk';
    compactDashboard = prefs.getBool(_compactKey) ?? false;

    if (reservations.isEmpty &&
        tickets.isEmpty &&
        attendance.isEmpty &&
        training.isEmpty) {
      _loadStarterData();
    }
  }

  void addReservation(Reservation reservation) {
    reservations = <Reservation>[reservation, ...reservations];
    _saveAndNotify();
  }

  void addTicket(MaintenanceTicket ticket) {
    tickets = <MaintenanceTicket>[ticket, ...tickets];
    _saveAndNotify();
  }

  void updateTicketStatus(String id, String status) {
    tickets = tickets
        .map(
          (ticket) =>
              ticket.id == id ? ticket.copyWith(status: status) : ticket,
        )
        .toList();
    _saveAndNotify();
  }

  void markTrainingProgress(String id, int progress) {
    training = training
        .map(
          (course) =>
              course.id == id ? course.copyWith(progress: progress) : course,
        )
        .toList();
    _saveAndNotify();
  }

  void updateSettings({String? lead, bool? compact}) {
    siteLead = lead ?? siteLead;
    compactDashboard = compact ?? compactDashboard;
    _saveAndNotify();
  }

  int get openTicketCount =>
      tickets.where((ticket) => ticket.status != 'Resolved').length;

  int get arrivalsToday => reservations
      .where((reservation) => reservation.status == 'Arriving')
      .length;

  int get presentStaff =>
      attendance.where((record) => record.state == 'Present').length;

  int get trainingAverage {
    if (training.isEmpty) {
      return 0;
    }
    final total = training.fold<int>(0, (sum, course) => sum + course.progress);
    return (total / training.length).round();
  }

  List<Reservation> get upcomingReservations => reservations.take(4).toList();

  List<MaintenanceTicket> get urgentTickets =>
      tickets.where((ticket) => ticket.priority != 'Low').take(4).toList();

  Future<void> _saveAndNotify() async {
    notifyListeners();
    if (screenshotMode) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _reservationsKey,
      jsonEncode(reservations.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _ticketsKey,
      jsonEncode(tickets.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _attendanceKey,
      jsonEncode(attendance.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _trainingKey,
      jsonEncode(training.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_leadKey, siteLead);
    await prefs.setBool(_compactKey, compactDashboard);
  }

  List<T> _decodeList<T>(
    String? source,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (source == null || source.isEmpty) {
      return <T>[];
    }

    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  void _loadStarterData() {
    reservations = <Reservation>[
      Reservation(
        id: 'res-${DateTime.now().millisecondsSinceEpoch}',
        guestName: 'Atelier Renard',
        space: 'Salon Lumiere',
        date: 'Today',
        time: '09:30',
        status: 'Arriving',
        notes: 'Coffee service and projector check before arrival.',
      ),
    ];
    tickets = <MaintenanceTicket>[
      MaintenanceTicket(
        id: 'mt-${DateTime.now().millisecondsSinceEpoch}',
        area: 'Kitchen pass',
        issue: 'Refrigeration temperature check',
        priority: 'Medium',
        status: 'Open',
        dueDate: 'Today',
      ),
    ];
    attendance = <AttendanceRecord>[
      const AttendanceRecord(
        id: 'att-1',
        employee: 'Camille D.',
        role: 'Front desk',
        shift: 'Morning',
        state: 'Present',
      ),
      const AttendanceRecord(
        id: 'att-2',
        employee: 'Nora P.',
        role: 'Facilities',
        shift: 'Midday',
        state: 'Expected',
      ),
    ];
    training = <TrainingCourse>[
      const TrainingCourse(
        id: 'tr-1',
        title: 'Guest handoff checklist',
        module: 'Operations',
        progress: 45,
        dueDate: 'This week',
      ),
      const TrainingCourse(
        id: 'tr-2',
        title: 'Maintenance escalation',
        module: 'Facilities',
        progress: 20,
        dueDate: 'Next week',
      ),
    ];
  }

  void _loadSampleData() {
    siteLead = 'Philippe Drapier';
    compactDashboard = false;
    reservations = const <Reservation>[
      Reservation(
        id: 'res-1',
        guestName: 'Maison Verlaine',
        space: 'Boardroom A',
        date: 'Today',
        time: '08:45',
        status: 'Arriving',
        notes: 'Welcome tray, badges, and seating plan ready at reception.',
      ),
      Reservation(
        id: 'res-2',
        guestName: 'Canal Partners',
        space: 'Training suite',
        date: 'Today',
        time: '13:15',
        status: 'Confirmed',
        notes: 'Sixteen seats, hybrid screen, and catering at 15:00.',
      ),
      Reservation(
        id: 'res-3',
        guestName: 'Lefevre Consulting',
        space: 'Private office 3',
        date: 'Tomorrow',
        time: '10:00',
        status: 'Preparing',
        notes: 'Prepare access cards and room inspection.',
      ),
      Reservation(
        id: 'res-4',
        guestName: 'Ardent Design',
        space: 'Workshop floor',
        date: 'Friday',
        time: '11:30',
        status: 'Confirmed',
        notes: 'Move tables into project layout.',
      ),
    ];
    tickets = const <MaintenanceTicket>[
      MaintenanceTicket(
        id: 'mt-1',
        area: 'Main entrance',
        issue: 'Door closer needs adjustment before evening arrivals',
        priority: 'High',
        status: 'Open',
        dueDate: 'Today',
      ),
      MaintenanceTicket(
        id: 'mt-2',
        area: 'Training suite',
        issue: 'Replace HDMI adapter in presenter drawer',
        priority: 'Medium',
        status: 'Assigned',
        dueDate: 'Today',
      ),
      MaintenanceTicket(
        id: 'mt-3',
        area: 'Storage room',
        issue: 'Inventory linen shelves after delivery',
        priority: 'Low',
        status: 'Open',
        dueDate: 'Tomorrow',
      ),
    ];
    attendance = const <AttendanceRecord>[
      AttendanceRecord(
        id: 'att-1',
        employee: 'Anais Morel',
        role: 'Reservations',
        shift: '07:30-15:30',
        state: 'Present',
      ),
      AttendanceRecord(
        id: 'att-2',
        employee: 'Luc Martin',
        role: 'Maintenance',
        shift: '08:00-16:00',
        state: 'Present',
      ),
      AttendanceRecord(
        id: 'att-3',
        employee: 'Maya Costa',
        role: 'Training lead',
        shift: '10:00-18:00',
        state: 'Expected',
      ),
      AttendanceRecord(
        id: 'att-4',
        employee: 'Hugo Blanc',
        role: 'Evening desk',
        shift: '15:00-23:00',
        state: 'Expected',
      ),
    ];
    training = const <TrainingCourse>[
      TrainingCourse(
        id: 'tr-1',
        title: 'Reservation handoff routine',
        module: 'Front desk',
        progress: 88,
        dueDate: 'Today',
      ),
      TrainingCourse(
        id: 'tr-2',
        title: 'Maintenance triage standards',
        module: 'Facilities',
        progress: 64,
        dueDate: 'This week',
      ),
      TrainingCourse(
        id: 'tr-3',
        title: 'Attendance exception review',
        module: 'Staffing',
        progress: 42,
        dueDate: 'May 20',
      ),
    ];
  }
}

class Reservation {
  const Reservation({
    required this.id,
    required this.guestName,
    required this.space,
    required this.date,
    required this.time,
    required this.status,
    required this.notes,
  });

  final String id;
  final String guestName;
  final String space;
  final String date;
  final String time;
  final String status;
  final String notes;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as String,
      guestName: json['guestName'] as String,
      space: json['space'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'guestName': guestName,
      'space': space,
      'date': date,
      'time': time,
      'status': status,
      'notes': notes,
    };
  }
}

class MaintenanceTicket {
  const MaintenanceTicket({
    required this.id,
    required this.area,
    required this.issue,
    required this.priority,
    required this.status,
    required this.dueDate,
  });

  final String id;
  final String area;
  final String issue;
  final String priority;
  final String status;
  final String dueDate;

  MaintenanceTicket copyWith({String? status}) {
    return MaintenanceTicket(
      id: id,
      area: area,
      issue: issue,
      priority: priority,
      status: status ?? this.status,
      dueDate: dueDate,
    );
  }

  factory MaintenanceTicket.fromJson(Map<String, dynamic> json) {
    return MaintenanceTicket(
      id: json['id'] as String,
      area: json['area'] as String,
      issue: json['issue'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      dueDate: json['dueDate'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'area': area,
      'issue': issue,
      'priority': priority,
      'status': status,
      'dueDate': dueDate,
    };
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employee,
    required this.role,
    required this.shift,
    required this.state,
  });

  final String id;
  final String employee;
  final String role;
  final String shift;
  final String state;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      employee: json['employee'] as String,
      role: json['role'] as String,
      shift: json['shift'] as String,
      state: json['state'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'employee': employee,
      'role': role,
      'shift': shift,
      'state': state,
    };
  }
}

class TrainingCourse {
  const TrainingCourse({
    required this.id,
    required this.title,
    required this.module,
    required this.progress,
    required this.dueDate,
  });

  final String id;
  final String title;
  final String module;
  final int progress;
  final String dueDate;

  TrainingCourse copyWith({int? progress}) {
    return TrainingCourse(
      id: id,
      title: title,
      module: module,
      progress: progress ?? this.progress,
      dueDate: dueDate,
    );
  }

  factory TrainingCourse.fromJson(Map<String, dynamic> json) {
    return TrainingCourse(
      id: json['id'] as String,
      title: json['title'] as String,
      module: json['module'] as String,
      progress: json['progress'] as int,
      dueDate: json['dueDate'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'module': module,
      'progress': progress,
      'dueDate': dueDate,
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class OperationsHome extends StatefulWidget {
  const OperationsHome({super.key});

  @override
  State<OperationsHome> createState() => _OperationsHomeState();
}

class _OperationsHomeState extends State<OperationsHome> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardPage(),
    ReservationsPage(),
    MaintenancePage(),
    TrainingPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = <String>[
      'Operations',
      'Reservations',
      'Requests',
      'Training',
      'Settings',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_index],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: const <Widget>[
          Padding(padding: EdgeInsets.only(right: 16), child: _BrandChip()),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: 'Reserve',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: 'Work',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Train',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          'DP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _HeroPanel(store: store),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.28,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            _MetricCard(
              icon: Icons.meeting_room_outlined,
              label: 'Arrivals',
              value: '${store.arrivalsToday}',
              caption: 'today',
              color: AppTheme.navy,
            ),
            _MetricCard(
              icon: Icons.build_circle_outlined,
              label: 'Requests',
              value: '${store.openTicketCount}',
              caption: 'open',
              color: AppTheme.gold,
            ),
            _MetricCard(
              icon: Icons.badge_outlined,
              label: 'Attendance',
              value: '${store.presentStaff}/${store.attendance.length}',
              caption: 'present',
              color: AppTheme.teal,
            ),
            _MetricCard(
              icon: Icons.menu_book_outlined,
              label: 'Training',
              value: '${store.trainingAverage}%',
              caption: 'average',
              color: AppTheme.slate,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Next reservations',
          actionLabel: 'Add',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReservationFormPage(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...store.upcomingReservations.map(
          (reservation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ReservationTile(reservation: reservation),
          ),
        ),
        const SizedBox(height: 10),
        _SectionHeader(title: 'Maintenance watchlist'),
        const SizedBox(height: 8),
        ...store.urgentTickets.map(
          (ticket) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MaintenanceTile(ticket: ticket),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.navy,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Opacity(
              opacity: .18,
              child: Image.asset('docs/featured.png', fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'DRAPIER PHILIPPE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Daily reservations, requests, attendance, and training in one local workspace.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _StatusPill(
                      icon: Icons.supervisor_account_outlined,
                      label: store.siteLead,
                    ),
                    const _StatusPill(
                      icon: Icons.lock_outline,
                      label: 'Local data',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, color: color, size: 26),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$label $caption',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 18),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'reservation-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ReservationFormPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Reservation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: <Widget>[
          const _ScreenIntro(
            title: 'Reservation board',
            text:
                'Track arrivals, room setup, notes, and status before every handoff.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _FilterChip(label: 'Today'),
              _FilterChip(label: 'Confirmed'),
              _FilterChip(label: 'Preparing'),
            ],
          ),
          const SizedBox(height: 14),
          ...store.reservations.map(
            (reservation) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ReservationTile(reservation: reservation, showNotes: true),
            ),
          ),
        ],
      ),
    );
  }
}

class ReservationTile extends StatelessWidget {
  const ReservationTile({
    required this.reservation,
    this.showNotes = false,
    super.key,
  });

  final Reservation reservation;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReservationDetailPage(reservation: reservation),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      reservation.guestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _PriorityBadge(text: reservation.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.meeting_room_outlined,
                    size: 18,
                    color: AppTheme.slate,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reservation.space,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Icon(Icons.schedule, size: 18, color: AppTheme.slate),
                  const SizedBox(width: 6),
                  Text('${reservation.date} at ${reservation.time}'),
                ],
              ),
              if (showNotes) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  reservation.notes,
                  style: const TextStyle(color: AppTheme.slate, height: 1.3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ReservationDetailPage extends StatelessWidget {
  const ReservationDetailPage({required this.reservation, super.key});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservation detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _DetailHeader(
            icon: Icons.event_available,
            title: reservation.guestName,
            subtitle: reservation.space,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            children: <Widget>[
              _InfoRow(label: 'Date', value: reservation.date),
              _InfoRow(label: 'Time', value: reservation.time),
              _InfoRow(label: 'Status', value: reservation.status),
              _InfoRow(label: 'Setup notes', value: reservation.notes),
            ],
          ),
          const SizedBox(height: 14),
          const _ChecklistBlock(
            title: 'Handoff checklist',
            items: <String>[
              'Room inspection complete',
              'Arrival notes shared with staff',
              'Follow-up owner assigned',
            ],
          ),
        ],
      ),
    );
  }
}

class ReservationFormPage extends StatefulWidget {
  const ReservationFormPage({super.key});

  @override
  State<ReservationFormPage> createState() => _ReservationFormPageState();
}

class _ReservationFormPageState extends State<ReservationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _guestController = TextEditingController();
  final _spaceController = TextEditingController();
  final _dateController = TextEditingController(text: 'Today');
  final _timeController = TextEditingController(text: '14:00');
  final _notesController = TextEditingController();
  String _status = 'Confirmed';

  @override
  void dispose() {
    _guestController.dispose();
    _spaceController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New reservation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const _ScreenIntro(
              title: 'Create a reservation',
              text:
                  'Save the arrival details and setup notes your team needs before service.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _guestController,
              decoration: const InputDecoration(
                labelText: 'Guest or company',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _spaceController,
              decoration: const InputDecoration(
                labelText: 'Reserved space',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(labelText: 'Date'),
                    validator: _requiredField,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _timeController,
                    decoration: const InputDecoration(labelText: 'Time'),
                    validator: _requiredField,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: const <String>['Confirmed', 'Preparing', 'Arriving']
                  .map(
                    (status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.fact_check_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Setup notes',
                alignLabelWithHint: true,
              ),
              validator: _requiredField,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                if (!_formKey.currentState!.validate()) {
                  return;
                }
                store.addReservation(
                  Reservation(
                    id: 'res-${DateTime.now().microsecondsSinceEpoch}',
                    guestName: _guestController.text.trim(),
                    space: _spaceController.text.trim(),
                    date: _dateController.text.trim(),
                    time: _timeController.text.trim(),
                    status: _status,
                    notes: _notesController.text.trim(),
                  ),
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save reservation'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _requiredField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'maintenance-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MaintenanceFormPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Request'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: <Widget>[
          const _ScreenIntro(
            title: 'Maintenance queue',
            text:
                'Prioritize requests by area, urgency, owner, and service deadline.',
          ),
          const SizedBox(height: 12),
          ...store.tickets.map(
            (ticket) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MaintenanceTile(ticket: ticket, showAction: true),
            ),
          ),
          const SizedBox(height: 10),
          const _SectionHeader(title: 'Attendance snapshot'),
          const SizedBox(height: 8),
          ...store.attendance.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttendanceTile(record: record),
            ),
          ),
        ],
      ),
    );
  }
}

class MaintenanceTile extends StatelessWidget {
  const MaintenanceTile({
    required this.ticket,
    this.showAction = false,
    super.key,
  });

  final MaintenanceTicket ticket;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    ticket.area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _PriorityBadge(text: ticket.priority),
              ],
            ),
            const SizedBox(height: 8),
            Text(ticket.issue, style: const TextStyle(height: 1.3)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SmallLabel(icon: Icons.flag_outlined, text: ticket.status),
                _SmallLabel(icon: Icons.event_outlined, text: ticket.dueDate),
              ],
            ),
            if (showAction) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ticket.status == 'Assigned'
                          ? null
                          : () =>
                                store.updateTicketStatus(ticket.id, 'Assigned'),
                      icon: const Icon(Icons.assignment_ind_outlined),
                      label: const Text('Assign'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: ticket.status == 'Resolved'
                          ? null
                          : () =>
                                store.updateTicketStatus(ticket.id, 'Resolved'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Resolve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MaintenanceFormPage extends StatefulWidget {
  const MaintenanceFormPage({super.key});

  @override
  State<MaintenanceFormPage> createState() => _MaintenanceFormPageState();
}

class _MaintenanceFormPageState extends State<MaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _issueController = TextEditingController();
  final _dueController = TextEditingController(text: 'Today');
  String _priority = 'Medium';

  @override
  void dispose() {
    _areaController.dispose();
    _issueController.dispose();
    _dueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const _ScreenIntro(
              title: 'Log maintenance work',
              text:
                  'Capture the issue, location, urgency, and deadline without leaving the local app.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Area',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issueController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Issue',
                alignLabelWithHint: true,
              ),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.priority_high_outlined),
              ),
              items: const <String>['High', 'Medium', 'Low']
                  .map(
                    (priority) => DropdownMenuItem<String>(
                      value: priority,
                      child: Text(priority),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _priority = value ?? _priority),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dueController,
              decoration: const InputDecoration(
                labelText: 'Due date',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              validator: _requiredField,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                if (!_formKey.currentState!.validate()) {
                  return;
                }
                store.addTicket(
                  MaintenanceTicket(
                    id: 'mt-${DateTime.now().microsecondsSinceEpoch}',
                    area: _areaController.text.trim(),
                    issue: _issueController.text.trim(),
                    priority: _priority,
                    status: 'Open',
                    dueDate: _dueController.text.trim(),
                  ),
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save request'),
            ),
          ],
        ),
      ),
    );
  }
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        const _ScreenIntro(
          title: 'Staff training',
          text:
              'Keep service routines, maintenance standards, and handoff lessons moving.',
        ),
        const SizedBox(height: 12),
        ...store.training.map(
          (course) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TrainingCard(course: course),
          ),
        ),
      ],
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.course});

  final TrainingCourse course;

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);
    final nextProgress = (course.progress + 12).clamp(0, 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${course.module} / due ${course.dueDate}',
                        style: const TextStyle(color: AppTheme.slate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: course.progress / 100,
                backgroundColor: const Color(0xFFE4E8EF),
                color: AppTheme.teal,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${course.progress}% complete',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: course.progress >= 100
                      ? null
                      : () =>
                            store.markTrainingProgress(course.id, nextProgress),
                  icon: const Icon(Icons.trending_up, size: 18),
                  label: const Text('Advance'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _leadController = TextEditingController();
  bool _seededController = false;

  @override
  void dispose() {
    _leadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);
    if (!_seededController) {
      _leadController.text = store.siteLead;
      _seededController = true;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        const _ScreenIntro(
          title: 'Local workspace settings',
          text:
              'Tune the on-device operations workspace without accounts, cloud sync, or OS permissions.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Site lead',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _leadController,
                  decoration: const InputDecoration(
                    labelText: 'Lead name',
                    prefixIcon: Icon(Icons.supervisor_account_outlined),
                  ),
                  onSubmitted: (value) =>
                      store.updateSettings(lead: value.trim()),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: store.compactDashboard,
                  onChanged: (value) => store.updateSettings(compact: value),
                  title: const Text('Compact dashboard cards'),
                  subtitle: const Text('Reduce summary spacing for busy days.'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          children: <Widget>[
            _InfoRow(label: 'Storage', value: 'Records stay on this device'),
            _InfoRow(label: 'Accounts', value: 'No sign-in required'),
            _InfoRow(label: 'Cloud sync', value: 'Not used'),
            _InfoRow(label: 'Permissions', value: 'No Android permissions'),
          ],
        ),
        const SizedBox(height: 12),
        const _ChecklistBlock(
          title: 'Daily close review',
          items: <String>[
            'Confirm tomorrow arrivals',
            'Resolve urgent requests',
            'Check attendance exceptions',
            'Advance required training',
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      side: const BorderSide(color: Color(0xFFD8DDE8)),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = switch (text) {
      'High' || 'Arriving' => const Color(0xFF9F3D30),
      'Medium' || 'Assigned' || 'Preparing' => AppTheme.gold,
      'Resolved' => AppTheme.teal,
      _ => AppTheme.navy,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: AppTheme.slate),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: AppTheme.slate)),
      ],
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.teal.withValues(alpha: .14),
          child: const Icon(Icons.badge_outlined, color: AppTheme.teal),
        ),
        title: Text(
          record.employee,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${record.role} / ${record.shift}'),
        trailing: _PriorityBadge(text: record.state),
      ),
    );
  }
}

class _ScreenIntro extends StatelessWidget {
  const _ScreenIntro({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(color: AppTheme.slate, height: 1.35)),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: .78)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.slate,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistBlock extends StatelessWidget {
  const _ChecklistBlock({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.teal,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
