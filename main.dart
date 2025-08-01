import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


// ------------------------- DEVOTIONAL MODEL -------------------------
class Devotional {
  final String id;
  final String title;
  final String content;
  final DateTime date;

  Devotional({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  factory Devotional.fromJson(Map<String, dynamic> json) {
    return Devotional(
      id: json['id'].toString(),
      title: json['title'],
      content: json['content'],
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
    };
  }

  factory Devotional.fromMap(Map<String, dynamic> map) {
    return Devotional(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      date: DateTime.parse(map['date']),
    );
  }
}

// ------------------------- SUPABASE FUNCTIONS -------------------------
Future<String?> fetchAdminPassword() async {
  final response = await Supabase.instance.client
      .from('admin_settings')
      .select('value')
      .eq('key', 'admin_password')
      .limit(1)
      .single();

  return response['value'] as String?;
}

Future<void> addDevotional({
  required String title,
  required String content,
  required DateTime date,
}) async {
  try {
    final response = await Supabase.instance.client.from('devotionals').insert({
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
    });

    print('✅ Inserted: $response');
    print('Devotional added');
  } catch (error) {
    print('❌ Insert failed: $error');
  }
}

Future<List<Devotional>> fetchDevotionals() async {
  final response = await Supabase.instance.client
      .from('devotionals')
      .select()
      .order('date', ascending: false);

  return (response as List)
      .map((json) => Devotional.fromJson(json))
      .toList();
}


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  // Ensure permissions are handled
  if (await Permission.notification.isDenied ||
      await Permission.notification.isRestricted ||
      await Permission.notification.isPermanentlyDenied) {
    await Permission.notification.request();
  }

  // Check current permission status
  final status = await Permission.notification.status;
  print('🔔 Notification permission status: $status');

  // Android settings
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
    print('✅ Notification plugin initialized');
  } catch (e) {
    print('❌ Notification plugin failed to initialize: $e');
  }

  // Initialize timezones
  tz.initializeTimeZones();
}


Future<void> showTestNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'test_channel',
    'Test Notifications',
    channelDescription: 'Test notifications for app',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  try {
    await flutterLocalNotificationsPlugin.show(
      0,
      '📖 Test Notification',
      'This is a test notification. It works!',
      notificationDetails,
    );
    print('✅ Test notification shown');
  } catch (e) {
    print('❌ Failed to show test notification: $e');
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  tz.initializeTimeZones();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Supabase.initialize(
    url: 'https://mmwxmkenjsojevilyxyx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1td3hta2VuanNvamV2aWx5eHl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwOTkwNTcsImV4cCI6MjA2NzY3NTA1N30.W7uO_wePLk9y8-8nqj3aT9KZFABjFVouiS4ixVFu9Pw',
  );



  runApp(
    ScreenUtilInit(
      designSize: Size(375, 812), // Match your design's width and height
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return const DailyDevotionalApp();
      },
    ),
  );
}

class DownloadsDatabase {
  static final DownloadsDatabase instance = DownloadsDatabase._init();

  static Database? _database;

  DownloadsDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('downloads.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE downloads (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertDevotional(Devotional devotional) async {
    final db = await instance.database;

    await db.insert(
      'downloads',
      {
        'id': devotional.id,
        'title': devotional.title,
        'content': devotional.content,
        'date': devotional.date.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Devotional>> getAllDevotionals() async {
    final db = await instance.database;
    final result = await db.query('downloads');

    return result.map((json) => Devotional(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
    )).toList();
  }

  Future<Devotional?> getDevotionalById(String id) async {
    final db = await instance.database;

    final maps = await db.query(
      'downloads',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final json = maps.first;
      return Devotional(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        date: DateTime.parse(json['date'] as String),
      );
    } else {
      return null;
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

class DevotionalDatabase {
  static Database? _database;

  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'devotionals.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            date TEXT
          )
        ''');
      },
    );
    return _database!;
  }

  static Future<void> insertDevotional(Devotional devotional) async {
    final db = await getDatabase();
    await db.insert(
      'downloads',
      devotional.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Devotional>> getAllDownloads() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('downloads');
    return maps.map((map) => Devotional.fromMap(map)).toList();
  }

  static Future<void> deleteDevotional(String id) async {
    final db = await getDatabase();
    await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> isDownloaded(String id) async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps =
    await db.query('downloads', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty;
  }
}

class DailyDevotionalApp extends StatefulWidget {
  const DailyDevotionalApp({super.key});

  @override
  State<DailyDevotionalApp> createState() => _DailyDevotionalAppState();
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {"title": "Change Password", "icon": Icons.lock, "page": const ChangePasswordPage()},
      {"title": "Payment Plans", "icon": Icons.payment, "page": const PaymentPlansPage()},
      {"title": "Update", "icon": Icons.system_update, "page": const UpdatePage()},
      {"title": "Notifications", "icon": Icons.notifications, "page": const NotificationSettingsPage()},
      {"title": "Login/Logout", "icon": Icons.login, "page": const LoginLogoutPage()},
    ];


    return Scaffold(
      appBar: AppBar(title: const Text("SETTINGS")),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item["icon"] as IconData, color: Colors.amber),
            title: Text(item["title"] as String),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => item["page"] as Widget),
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);
  final FlutterLocalNotificationsPlugin _notificationsPlugin = flutterLocalNotificationsPlugin;


  @override
  void initState() {
    super.initState();
    _loadSettings();
    tz.initializeTimeZones();
  }

  Future<void> _scheduleTestNotification() async {
    final date = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

    await _notificationsPlugin.zonedSchedule(
      2,
      'Test Reminder',
      'This is a 10-second test 🔔',
      date,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled Notifications',
          channelDescription: 'Channel for scheduled tests',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // ✅ updated
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('✅ Scheduled 10-second test notification at $date');
  }


  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      final hour = prefs.getInt('notification_hour') ?? 8;
      final minute = prefs.getInt('notification_minute') ?? 0;
      _notificationTime = TimeOfDay(hour: hour, minute: minute);
    });
    if (_notificationsEnabled) {
      _scheduleNotification();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('notifications_enabled', _notificationsEnabled);
    prefs.setInt('notification_hour', _notificationTime.hour);
    prefs.setInt('notification_minute', _notificationTime.minute);
  }

  Future<void> _scheduleNotification() async {
    final now = tz.TZDateTime.now(tz.local);

    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _notificationTime.hour,
      _notificationTime.minute,
    );

    // If the time is in the past, schedule for tomorrow
    final notificationDate = scheduledDate.isBefore(now)
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;

    const androidDetails = AndroidNotificationDetails(
      'scheduled_channel',
      'Scheduled Notifications',
      channelDescription: 'Channel for daily devotional notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.zonedSchedule(
        1,
        '📖 Daily Devotion',
        'Time for your daily devotional 🙏',
        notificationDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('✅ Scheduled daily notification at $notificationDate');
    } catch (e, stack) {
      print('❌ Error scheduling: $e');
      print(stack);
    }

  }


  Future<void> _cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  void _toggleNotifications(bool value) {
    setState(() {
      _notificationsEnabled = value;
    });
    if (value) {
      _scheduleNotification();
    } else {
      _cancelNotification();
    }
    _saveSettings();
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (picked != null) {
      setState(() {
        _notificationTime = picked;
      });
      if (_notificationsEnabled) {
        _scheduleNotification();
      }
      _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notification Settings")),
      body: ListView(
        children: [

          ElevatedButton(
            onPressed: _scheduleTestNotification,
            child: Text('Schedule 10s Test Notification'),
          ),


          SwitchListTile(
            title: const Text("Daily Notification"),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
          ListTile(
            title: const Text("Notification Time"),
            subtitle: Text(_notificationTime.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
        ],
      ),
    );
  }
}


class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Change Password")));
}

class PaymentPlansPage extends StatelessWidget {
  const PaymentPlansPage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Payment Plans")));
}

class UpdatePage extends StatelessWidget {
  const UpdatePage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Update")));
}

class LoginLogoutPage extends StatelessWidget {
  const LoginLogoutPage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Login / Logout")));
}

class _DailyDevotionalAppState extends State<DailyDevotionalApp> {
  int _currentIndex = 0;
  bool _showBlurSheet = false;
  bool _hasShownWelcome = false;

  final List<Widget> _pages = [
    const DevotionalHomePage(),
    const MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff262626),
        primarySwatch: Colors.amber,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      home: Builder( // 👈 This gives us a context *below* MaterialApp
        builder: (innerContext) {
          // 👇 Safe to use ScaffoldMessenger here
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_hasShownWelcome) {
              _hasShownWelcome = true;
              ScaffoldMessenger.of(innerContext).showSnackBar(
                const SnackBar(
                  content: Text("👋 Welcome, God bless you!"),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });

          return Container(
            color: const Color(0xff262626),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  _pages[_currentIndex],
                  if (_showBlurSheet)
                    BlurBottomSheet(
                      onDismiss: () => setState(() => _showBlurSheet = false),
                    ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                backgroundColor: Colors.amber,
                elevation: 0,
                shape: const CircleBorder(),
                onPressed: () {
                  setState(() {
                    _showBlurSheet = !_showBlurSheet;
                  });
                },
                child: const Icon(Icons.apps, color: Colors.black),
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
              bottomNavigationBar: BottomAppBar(
                shape: const CircularNotchedRectangle(),
                notchMargin: 11.0,
                color: Colors.black,
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.home,
                            color: _currentIndex == 0 ? Colors.amber : Colors.white70),
                        onPressed: () {
                          setState(() {
                            _currentIndex = 0;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.settings,
                            color: _currentIndex == 1 ? Colors.amber : Colors.white70),
                        onPressed: () {
                          setState(() {
                            _currentIndex = 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FeaturedDevotionalCard extends StatefulWidget {
  final String title;

  const FeaturedDevotionalCard({super.key, required this.title});

  @override
  State<FeaturedDevotionalCard> createState() => _FeaturedDevotionalCardState();
}

class _FeaturedDevotionalCardState extends State<FeaturedDevotionalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildAnimatedGlowBorder(Widget child) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        // Use full gradient cycle to interpolate glow color smoothly
        final List<Color> colors = [Colors.red, Colors.amber, Colors.yellow, Colors.red];
        final double t = (_animation.value / (2 * pi)) * (colors.length - 1);

        final int i = t.floor();
        final double localT = t - i;

        final Color startColor = colors[i % colors.length];
        final Color endColor = colors[(i + 1) % colors.length];
        final Color interpolatedGlowColor = Color.lerp(startColor, endColor, localT)!;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: SweepGradient(
              colors: colors,
              startAngle: 0,
              endAngle: 2 * pi,
              transform: GradientRotation(_animation.value),
            ),
            boxShadow: [
              BoxShadow(
                color: interpolatedGlowColor.withOpacity(0.6),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4), // thickness of glow border
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: interpolatedGlowColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    final String today = DateTime.now().toString().substring(0, 10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          buildAnimatedGlowBorder(
            Container(
              height: screenHeight * 0.15,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // child card widget
          Positioned(
            top: -20,
            left: -10,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Text(
                today,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BlurBottomSheet extends StatefulWidget {
  final VoidCallback onDismiss;

  const BlurBottomSheet({super.key, required this.onDismiss});

  @override
  State<BlurBottomSheet> createState() => _BlurBottomSheetState();
}

class DevotionalsPage extends StatelessWidget {
  const DevotionalsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Devotionals")));
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Favorites")));
}

class AddDevotionalPage extends StatefulWidget {
  const AddDevotionalPage({super.key});

  @override
  State<AddDevotionalPage> createState() => _AddDevotionalPageState();
}

class _AddDevotionalPageState extends State<AddDevotionalPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      await addDevotional(
        title: _titleController.text,
        content: _contentController.text,
        date: _selectedDate,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devotional added!')),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      _titleController.clear();
      _contentController.clear();
      setState(() {
        _selectedDate = DateTime.now();
      });

      Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Devotional")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 6,
                validator: (value) =>
                value == null || value.isEmpty ? 'Enter content' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _pickDate,
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Submit Devotional'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Settings")));
}

class _BlurBottomSheetState extends State<BlurBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  void _promptForPassword(BuildContext parentContext) {
    final TextEditingController _passwordController = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Enter Admin Password"),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Password"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final enteredPassword = _passwordController.text.trim();

                try {
                  final storedPassword = await fetchAdminPassword();
                  print("Entered: $enteredPassword");
                  print("Stored: $storedPassword");

                  Navigator.of(dialogContext).pop(); // close dialog
                  await Future.delayed(const Duration(milliseconds: 200));

                  if (enteredPassword == storedPassword) {
                    widget.onDismiss(); // close blur sheet
                    Navigator.of(parentContext).push(
                      MaterialPageRoute(
                        builder: (_) => const AddDevotionalPage(),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text("❌ Incorrect password")),
                    );
                  }
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  await Future.delayed(const Duration(milliseconds: 200));
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text("❗ Error validating password")),
                  );
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: _handleDismiss,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
        ),
        Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _MenuItem(
                      icon: Icons.auto_stories,
                      label: "Devotionals",
                      iconColor: Colors.deepOrange,
                      onTap: () {
                        widget.onDismiss();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DevotionalsPage(),
                          ),
                        );
                      },
                    ),
                    _MenuItem(
                      icon: Icons.favorite,
                      label: "Favorites",
                      iconColor: Colors.pink,
                      onTap: () {
                        widget.onDismiss();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FavoritesPage(),
                          ),
                        );
                      },
                    ),
                    _MenuItem(
                      icon: Icons.add,
                      label: "Add",
                      iconColor: Colors.blue,
                      onTap: () {
                        _promptForPassword(context); // 👈 Trigger password check
                      },
                    ),
                    _MenuItem(
                      icon: Icons.settings,
                      label: "Settings",
                      iconColor: Colors.green,
                      onTap: () {
                        widget.onDismiss();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 96,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.black87,
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DevotionalHomePage extends StatefulWidget {
  const DevotionalHomePage({super.key});

  @override
  State<DevotionalHomePage> createState() => _DevotionalHomePageState();
}

class _DevotionalHomePageState extends State<DevotionalHomePage> with TickerProviderStateMixin {
  List<Devotional> devotionals = [];
  bool isLoading = true;
  bool _hasShownWelcome = false;
  bool _isOnline = true;

  late Stream<List<ConnectivityResult>> _connectivityStream = Connectivity().onConnectivityChanged;
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> categories = const [
    {"title": "Archive", "icon": Icons.archive},
    {"title": "Favourites", "icon": Icons.favorite},
    {"title": "Bible", "icon": Icons.menu_book},
    {"title": "Downloads", "icon": Icons.download},
  ];

  @override
  void initState() {
    super.initState();
    loadDevotionals();

    // ✅ Initial check for current connectivity
    Connectivity().checkConnectivity().then((result) {
      final hasInternet = result != ConnectivityResult.none;
      if (mounted) setState(() => _isOnline = hasInternet);
    });

    // ✅ Listen for future connectivity changes
    _connectivityStream = Connectivity().onConnectivityChanged;
    _connectivityStream.listen((result) {
      final hasInternet = result != ConnectivityResult.none;
      if (mounted) setState(() => _isOnline = hasInternet);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }


  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> loadDevotionals() async {
    try {
      final result = await fetchDevotionals();
      setState(() {
        devotionals = result;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching devotionals: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayDevotional = devotionals.firstWhere(
          (d) => DateFormat('yyyy-MM-dd').format(d.date) == todayStr,
      orElse: () => Devotional(
        id: '',
        title: 'No devotional for today.',
        content: '',
        date: DateTime.now(),
      ),
    );

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NKC DEVOTIONAL',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Reload',
                      onPressed: () async {
                        setState(() => isLoading = true);
                        await loadDevotionals();
                      },
                    ),
                    ScaleTransition(
                      scale: Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(
                        parent: _pulseController,
                        curve: Curves.easeInOut,
                      )),
                      child: Icon(
                        _isOnline ? Icons.wifi : Icons.wifi_off,
                        color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                        size: 24.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: Colors.black12,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Column(
                  children: [
                    SizedBox(height: 40.h),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DevotionalDetailPage(devotional: todayDevotional),
                          ),
                        );
                      },
                      child: FeaturedDevotionalCard(title: todayDevotional.title),
                    ),

                    SizedBox(height: 30.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: categories.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.2,
                          mainAxisSpacing: 16.h,
                          crossAxisSpacing: 16.w,
                        ),
                        itemBuilder: (context, index) {
                          final category = categories[index];

                          void handleTap() {
                            switch (category["title"]) {
                              case "Archive":
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivePage()));
                                break;
                              case "Favourites":
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const FavouritesPage()));
                                break;
                              case "Bible":
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const BiblePage()));
                                break;
                              case "Downloads":
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsPage()));
                                break;
                            }
                          }

                          return GestureDetector(
                            onTap: handleTap,
                            child: Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF292929), Color(0xFF1E1E1E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6.r,
                                    offset: Offset(0, 3.h),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    category["icon"],
                                    size: 30.sp,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    category["title"],
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 20.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: const InfoCardWidget(
                        title: 'Verse of the Day',
                        content: 'I can do all things through Christ... - Philippians 4:13',
                        icon: Icons.menu_book,
                      ),
                    ),

                    SizedBox(height: 10.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: const InfoCardWidget(
                        title: 'Confession of the Day',
                        content: 'I am more than a conqueror through Christ!',
                        icon: Icons.record_voice_over,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}





class VerseOfTheDayWidget extends StatelessWidget {
  const VerseOfTheDayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book, color: Colors.yellow[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Verse of the Day: "I can do all things through Christ..." - Philippians 4:13',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        ],
      ),
    );
  }
}


class DevotionalDetailPage extends StatefulWidget {
  final Devotional devotional;

  const DevotionalDetailPage({super.key, required this.devotional});

  @override
  State<DevotionalDetailPage> createState() => _DevotionalDetailPageState();
}

class _DevotionalDetailPageState extends State<DevotionalDetailPage> {
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkIfDownloaded();
  }

  Future<void> _checkIfDownloaded() async {
    final existing =
    await DownloadsDatabase.instance.getDevotionalById(widget.devotional.id);
    setState(() {
      _isDownloaded = existing != null;
    });
  }

  Future<void> _downloadDevotional() async {
    if (widget.devotional.id.isEmpty ||
        widget.devotional.content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No devotional to download.")),
      );
      return;
    }

    await DownloadsDatabase.instance.insertDevotional(widget.devotional);
    setState(() {
      _isDownloaded = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Devotional downloaded for offline use")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.devotional.title),
        backgroundColor: Colors.black,
        actions: [
          if (widget.devotional.id.isNotEmpty &&
              widget.devotional.content.trim().isNotEmpty)
            IconButton(
              icon: Icon(
                _isDownloaded ? Icons.download_done : Icons.download,
                color: Colors.white,
              ),
              onPressed: _isDownloaded ? null : _downloadDevotional,
              tooltip: _isDownloaded ? 'Already downloaded' : 'Download',
            ),
        ],
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.devotional.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.devotional.content,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Date: ${widget.devotional.date.toLocal().toString().split(' ')[0]}",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class InfoCardWidget extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const InfoCardWidget({
    super.key,
    required this.title,
    required this.content,
    this.icon = Icons.menu_book,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.yellow[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title: "$content"',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        ],
      ),
    );
  }
}

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Devotional> archiveDevotionals = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadArchiveDevotionals();
  }

  Future<void> loadArchiveDevotionals() async {
    try {
      final result = await fetchDevotionals();

      print("✅ Loaded devotionals: ${result.length}");
      for (final d in result) {
        print("${d.title} - ${d.date}");
      }

      setState(() {
        archiveDevotionals = result;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error loading archive: $e");
      setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Devotional Archive")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : archiveDevotionals.isEmpty
          ? const Center(child: Text("No devotionals available."))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: archiveDevotionals.length,
        itemBuilder: (context, index) {
          final devotional = archiveDevotionals[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DevotionalDetailPage(devotional: devotional),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('yyyy-MM-dd').format(devotional.date),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    devotional.title,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    devotional.content.length > 100
                        ? "${devotional.content.substring(0, 100)}..."
                        : devotional.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}



class FavouritesPage extends StatelessWidget {
  const FavouritesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Favourites")));
}

class BiblePage extends StatelessWidget {
  const BiblePage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text("Bible")));
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<Devotional> _downloads = [];

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    final downloaded = await DownloadsDatabase.instance.getAllDevotionals();
    setState(() {
      _downloads = downloaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📥 Downloads"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: _downloads.isEmpty
          ? const Center(
        child: Text(
          "No downloads yet",
          style: TextStyle(color: Colors.white54),
        ),
      )
          : ListView.builder(
        itemCount: _downloads.length,
        itemBuilder: (context, index) {
          final devotional = _downloads[index];
          return ListTile(
            title: Text(devotional.title,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              devotional.date.toLocal().toString().split(' ')[0],
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      DevotionalDetailPage(devotional: devotional),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
