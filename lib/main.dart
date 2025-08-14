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


class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const String _notificationChannelId = 'daily_devotional_channel';
  static const String _notificationChannelName = 'Daily Devotional';
  static const String _notificationChannelDescription =
      'Daily reminders for devotional reading';

  // Notification ID for daily devotional
  static const int _dailyNotificationId = 1000;

  // SharedPreferences keys
  static const String _enabledKey = 'notifications_enabled';
  static const String _hourKey = 'notification_hour';
  static const String _minuteKey = 'notification_minute';

  /// Initialize notifications with proper permissions and settings
  static Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Android settings
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings (if you plan to support iOS)
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      print('✅ Notification service initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize notifications: $e');
    }
  }

  /// Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: _notificationChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // You can navigate to specific page here if needed
  }

  /// Enable daily notifications at specified time (defaults to 12 AM)
  static Future<void> enableDailyNotifications({
    int hour = 0,  // 12 AM (midnight)
    int minute = 0,
  }) async {
    try {
      // Save settings
      await _saveNotificationSettings(
        enabled: true,
        hour: hour,
        minute: minute,
      );

      // Schedule the notification
      await _scheduleDailyNotification(hour, minute);

      print('✅ Daily notifications enabled at ${_formatTime(hour, minute)}');
    } catch (e) {
      print('❌ Failed to enable daily notifications: $e');
      rethrow;
    }
  }

  /// Disable daily notifications
  static Future<void> disableDailyNotifications() async {
    try {
      // Cancel existing notification
      await _notifications.cancel(_dailyNotificationId);

      // Save settings
      await _saveNotificationSettings(enabled: false);

      print('✅ Daily notifications disabled');
    } catch (e) {
      print('❌ Failed to disable daily notifications: $e');
      rethrow;
    }
  }

  /// Update notification time
  static Future<void> updateNotificationTime(int hour, int minute) async {
    try {
      final isEnabled = await isNotificationsEnabled();

      if (isEnabled) {
        // Cancel existing and reschedule with new time
        await _notifications.cancel(_dailyNotificationId);
        await _scheduleDailyNotification(hour, minute);
      }

      // Save new time settings
      await _saveNotificationSettings(
        enabled: isEnabled,
        hour: hour,
        minute: minute,
      );

      print('✅ Notification time updated to ${_formatTime(hour, minute)}');
    } catch (e) {
      print('❌ Failed to update notification time: $e');
      rethrow;
    }
  }

  /// Schedule daily recurring notification
  static Future<void> _scheduleDailyNotification(int hour, int minute) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Calculate next notification time
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time is in the past, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.zonedSchedule(
      _dailyNotificationId,
      '📖 Daily Devotional',
      'Your daily devotional is ready! Tap to read today\'s message 🙏',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // This makes it repeat daily
      payload: 'daily_devotional',
    );

    print('📅 Next notification scheduled for: $scheduledDate');
  }

  /// Send a test notification immediately
  static Future<void> sendTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Channel for test notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notifications.show(
        999, // Different ID for test notifications
        '🧪 Test Notification',
        'This is a test notification. Your daily reminders will look like this!',
        notificationDetails,
        payload: 'test_notification',
      );

      print('✅ Test notification sent');
    } catch (e) {
      print('❌ Failed to send test notification: $e');
      rethrow;
    }
  }

  /// Save notification settings to SharedPreferences
  static Future<void> _saveNotificationSettings({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_enabledKey, enabled);

    if (hour != null) {
      await prefs.setInt(_hourKey, hour);
    }

    if (minute != null) {
      await prefs.setInt(_minuteKey, minute);
    }
  }

  /// Check if notifications are enabled
  static Future<bool> isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Get saved notification time
  static Future<TimeOfDay> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_hourKey) ?? 0;  // Default to 12 AM
    final minute = prefs.getInt(_minuteKey) ?? 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Load and apply saved notification settings (call this on app start)
  static Future<void> loadAndApplySettings() async {
    try {
      final isEnabled = await isNotificationsEnabled();

      if (isEnabled) {
        final time = await getNotificationTime();
        await _scheduleDailyNotification(time.hour, time.minute);
        print('📱 Restored daily notifications at ${_formatTime(time.hour, time.minute)}');
      }
    } catch (e) {
      print('❌ Failed to load notification settings: $e');
    }
  }

  /// Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🗑️ All notifications cancelled');
  }

  /// Format time for display
  static String _formatTime(int hour, int minute) {
    final timeOfDay = TimeOfDay(hour: hour, minute: minute);
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);

    // Simple 12-hour format
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '$displayHour:$displayMinute $period';
  }
}

// Extension to make TimeOfDay formatting easier
extension TimeOfDayExtension on TimeOfDay {
  String get formatted {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '$displayHour:$displayMinute $period';
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications FIRST
  await NotificationService.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Supabase.initialize(
    url: 'https://mmwxmkenjsojevilyxyx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1td3hta2VuanNvamV2aWx5eHl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwOTkwNTcsImV4cCI6MjA2NzY3NTA1N30.W7uO_wePLk9y8-8nqj3aT9KZFABjFVouiS4ixVFu9Pw',
  );

  // Load and apply saved notification settings
  await NotificationService.loadAndApplySettings();

  runApp(
    ScreenUtilInit(
      designSize: Size(375, 812),
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
  TimeOfDay _notificationTime = const TimeOfDay(hour: 0, minute: 0); // Default 12 AM
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Load current notification settings
  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);

      final isEnabled = await NotificationService.isNotificationsEnabled();
      final time = await NotificationService.getNotificationTime();

      setState(() {
        _notificationsEnabled = isEnabled;
        _notificationTime = time;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load settings: $e');
    }
  }

  /// Toggle notifications on/off
  Future<void> _toggleNotifications(bool enabled) async {
    try {
      setState(() => _notificationsEnabled = enabled);

      if (enabled) {
        await NotificationService.enableDailyNotifications(
          hour: _notificationTime.hour,
          minute: _notificationTime.minute,
        );
        _showSuccessSnackBar('Daily notifications enabled at ${_notificationTime.formatted}');
      } else {
        await NotificationService.disableDailyNotifications();
        _showSuccessSnackBar('Daily notifications disabled');
      }
    } catch (e) {
      // Revert the switch if operation failed
      setState(() => _notificationsEnabled = !enabled);
      _showErrorSnackBar('Failed to ${enabled ? 'enable' : 'disable'} notifications: $e');
    }
  }

  /// Pick a new notification time
  Future<void> _pickNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      helpText: 'Select daily notification time',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFF1E1E1E),
              hourMinuteTextColor: Colors.white,
              dayPeriodTextColor: Colors.white,
              dialHandColor: Colors.amber,
              dialBackgroundColor: Colors.grey[800],
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _notificationTime) {
      try {
        setState(() => _notificationTime = picked);

        // Update the notification time
        await NotificationService.updateNotificationTime(picked.hour, picked.minute);

        if (_notificationsEnabled) {
          _showSuccessSnackBar('Notification time updated to ${picked.formatted}');
        } else {
          _showInfoSnackBar('Time saved. Enable notifications to receive daily reminders.');
        }
      } catch (e) {
        _showErrorSnackBar('Failed to update notification time: $e');
      }
    }
  }

  /// Send a test notification
  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.sendTestNotification();
      _showSuccessSnackBar('Test notification sent! Check your notification panel.');
    } catch (e) {
      _showErrorSnackBar('Failed to send test notification: $e');
    }
  }

  /// Reset to default time (12 AM)
  Future<void> _resetToDefault() async {
    const defaultTime = TimeOfDay(hour: 0, minute: 0);

    try {
      setState(() => _notificationTime = defaultTime);
      await NotificationService.updateNotificationTime(0, 0);

      _showSuccessSnackBar('Reset to default time (12:00 AM)');
    } catch (e) {
      _showErrorSnackBar('Failed to reset time: $e');
    }
  }

  /// Show pending notifications for debugging
  Future<void> _showPendingNotifications() async {
    try {
      final pending = await NotificationService.getPendingNotifications();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Pending Notifications', style: TextStyle(color: Colors.white)),
          content: pending.isEmpty
              ? const Text('No pending notifications', style: TextStyle(color: Colors.white70))
              : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pending.map((notification) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'ID: ${notification.id}\nTitle: ${notification.title}\nBody: ${notification.body}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to get pending notifications: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $message'),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ℹ️ $message'),
        backgroundColor: Colors.blue[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🔔 Notification Settings"),
        backgroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'reset':
                  _resetToDefault();
                  break;
                case 'debug':
                  _showPendingNotifications();
                  break;
                case 'cancel_all':
                  NotificationService.cancelAllNotifications();
                  _showInfoSnackBar('All notifications cancelled');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'reset', child: Text('Reset to 12 AM')),
              const PopupMenuItem(value: 'debug', child: Text('Show Pending')),
              const PopupMenuItem(value: 'cancel_all', child: Text('Cancel All')),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/Disable Switch
          Card(
            color: const Color(0xFF2D2D2D),
            child: SwitchListTile(
              title: const Text(
                'Daily Notifications',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _notificationsEnabled
                    ? 'Receive daily devotional reminders'
                    : 'Notifications are disabled',
                style: TextStyle(
                  color: _notificationsEnabled ? Colors.green[300] : Colors.red[300],
                ),
              ),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeColor: Colors.amber,
              secondary: Icon(
                _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                color: _notificationsEnabled ? Colors.amber : Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Time Picker
          Card(
            color: const Color(0xFF2D2D2D),
            child: ListTile(
              leading: const Icon(Icons.access_time, color: Colors.amber),
              title: const Text(
                'Notification Time',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _notificationTime.formatted,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: _pickNotificationTime,
            ),
          ),

          const SizedBox(height: 24),

          // Test Notification Button
          ElevatedButton.icon(
            onPressed: _sendTestNotification,
            icon: const Icon(Icons.send),
            label: const Text('Send Test Notification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Info Card
          Card(
            color: Colors.blue[900]?.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[300]),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                          color: Colors.blue[300],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Notifications are sent daily at your chosen time\n'
                        '• Default time is 12:00 AM (midnight)\n'
                        '• Make sure your device allows notifications\n'
                        '• Notifications work even when the app is closed',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          // Current Status
          if (_notificationsEnabled) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.green[900]?.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[300]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Daily reminders active at ${_notificationTime.formatted}',
                        style: TextStyle(
                          color: Colors.green[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check and request notification permissions if needed
    await _checkNotificationPermissions();

    // Set up default notifications if this is first launch
    await _setupDefaultNotifications();
  }

  Future<void> _checkNotificationPermissions() async {
    try {
      // Request notification permissions (especially important for Android 13+)
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        if (status.isDenied && mounted) {
          // Show dialog explaining why notifications are important
          _showPermissionDialog();
        }
      }
    } catch (e) {
      print('❌ Error checking notification permissions: $e');
    }
  }

  Future<void> _setupDefaultNotifications() async {
    try {
      final isEnabled = await NotificationService.isNotificationsEnabled();

      // If notifications haven't been configured yet, enable them by default at 12 AM
      if (!isEnabled) {
        final prefs = await SharedPreferences.getInstance();
        final hasSetupNotifications = prefs.getBool('has_setup_notifications') ?? false;

        if (!hasSetupNotifications) {
          // First launch - enable notifications at 12 AM by default
          await NotificationService.enableDailyNotifications(hour: 0, minute: 0);
          await prefs.setBool('has_setup_notifications', true);

          print('📱 Default notifications enabled at 12:00 AM for first launch');

          // Show a brief welcome message about notifications if mounted
          if (mounted) {
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🔔 Daily devotional reminders enabled at 12:00 AM"),
                    duration: Duration(seconds: 3),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      print('❌ Failed to setup default notifications: $e');
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
            '🔔 Enable Notifications',
            style: TextStyle(color: Colors.white)
        ),
        content: const Text(
          'Get daily reminders for your devotional reading at 12:00 AM. You can customize the time in settings later.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
                'Maybe Later',
                style: TextStyle(color: Colors.grey)
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Permission.notification.request();
              // Try to setup notifications again after permission granted
              await _setupDefaultNotifications();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text(
                'Enable',
                style: TextStyle(color: Colors.black)
            ),
          ),
        ],
      ),
    );
  }

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
      home: Builder( // 👈 This gives us a context below MaterialApp
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

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  List<Devotional> devotionals = [];
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();
  PageController pageController = PageController();

  @override
  void initState() {
    super.initState();
    loadDevotionals();
  }

  Future<void> loadDevotionals() async {
    try {
      final result = await fetchDevotionals();
      setState(() {
        devotionals = result;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading devotionals: $e");
      setState(() => isLoading = false);
    }
  }

  List<Devotional> getDevotionalsForMonth(DateTime month) {
    return devotionals.where((devotional) {
      return devotional.date.year == month.year &&
          devotional.date.month == month.month;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📅 Calendar"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Column(
        children: [
          // Month Navigation
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedDate = DateTime(selectedDate.year, selectedDate.month - 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(selectedDate),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedDate = DateTime(selectedDate.year, selectedDate.month + 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                ),
              ],
            ),
          ),
          // Calendar Grid
          Expanded(
            child: _buildCalendarGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final monthDevotionals = getDevotionalsForMonth(selectedDate);
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDayOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday % 7;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Week headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 42, // 6 weeks * 7 days
              itemBuilder: (context, index) {
                final dayNumber = index - startingWeekday + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return Container(); // Empty cell
                }

                final dayDate = DateTime(selectedDate.year, selectedDate.month, dayNumber);
                final hasDevotional = monthDevotionals.any((d) =>
                d.date.day == dayNumber &&
                    d.date.month == selectedDate.month &&
                    d.date.year == selectedDate.year
                );

                final devotionalForDay = monthDevotionals.firstWhere(
                      (d) => d.date.day == dayNumber &&
                      d.date.month == selectedDate.month &&
                      d.date.year == selectedDate.year,
                  orElse: () => Devotional(id: '', title: '', content: '', date: dayDate),
                );

                final isToday = dayDate.day == DateTime.now().day &&
                    dayDate.month == DateTime.now().month &&
                    dayDate.year == DateTime.now().year;

                return GestureDetector(
                  onTap: hasDevotional ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DevotionalDetailPage(devotional: devotionalForDay),
                      ),
                    );
                  } : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday
                          ? Colors.amber.withOpacity(0.3)
                          : hasDevotional
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday ? Border.all(color: Colors.amber, width: 2) : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              color: hasDevotional ? Colors.white : Colors.white54,
                              fontWeight: hasDevotional ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (hasDevotional)
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: Colors.green,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(Colors.amber, "Today"),
                _buildLegendItem(Colors.green, "Has Devotional"),
                _buildLegendItem(Colors.grey, "No Devotional"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
            border: color == Colors.amber ? Border.all(color: color, width: 1) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
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


class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("❓ Help & FAQ"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHelpSection(
            "Getting Started",
            [
              _buildFAQItem(
                "How do I read today's devotional?",
                "The featured devotional card on the home page shows today's message. "
                    "Tap on it to read the full content.",
              ),
              _buildFAQItem(
                "How do I enable notifications?",
                "Go to Settings > Notifications and toggle on 'Daily Notifications'. "
                    "You can also set your preferred time for reminders.",
              ),
            ],
          ),

          _buildHelpSection(
            "Navigation",
            [
              _buildFAQItem(
                "How do I access different features?",
                "Tap the floating action button (⊕) in the center of the bottom bar "
                    "to access Calendar, About, Add devotional, and Help pages.",
              ),
              _buildFAQItem(
                "How do I view past devotionals?",
                "Use the Archive section to browse all previous devotionals, "
                    "or use the Calendar to view devotionals by specific dates.",
              ),
            ],
          ),

          _buildHelpSection(
            "Downloads & Offline Reading",
            [
              _buildFAQItem(
                "How do I download devotionals?",
                "Open any devotional and tap the download icon in the top-right corner. "
                    "Downloaded devotionals can be accessed offline.",
              ),
              _buildFAQItem(
                "Where can I find my downloads?",
                "Tap on 'Downloads' from the home page categories to see all "
                    "your offline devotionals.",
              ),
            ],
          ),

          _buildHelpSection(
            "Search & Organization",
            [
              _buildFAQItem(
                "How do I search for specific devotionals?",
                "In the Archive page, use the search bar to find devotionals by title "
                    "or content, and use the date picker to filter by specific dates.",
              ),
              _buildFAQItem(
                "How do I sort devotionals?",
                "In the Archive page, tap the sort button to arrange devotionals "
                    "by date (newest first, oldest first) or alphabetically.",
              ),
            ],
          ),

          _buildHelpSection(
            "Notifications",
            [
              _buildFAQItem(
                "I'm not receiving notifications. What should I do?",
                "1. Check that notifications are enabled in the app settings\n"
                    "2. Ensure your device allows notifications for this app\n"
                    "3. Check your device's Do Not Disturb settings\n"
                    "4. Try sending a test notification from the settings page",
              ),
              _buildFAQItem(
                "How do I change the notification time?",
                "Go to Settings > Notifications and tap on 'Notification Time' "
                    "to select your preferred reminder time.",
              ),
            ],
          ),

          _buildHelpSection(
            "Troubleshooting",
            [
              _buildFAQItem(
                "The app is running slowly. What can I do?",
                "Try refreshing the content using the refresh button on the home page. "
                    "If issues persist, restart the app.",
              ),
              _buildFAQItem(
                "I can't connect to load new devotionals.",
                "Check your internet connection. The app shows your connection status "
                    "in the top-right corner of the home page.",
              ),
              _buildFAQItem(
                "How do I report a bug or issue?",
                "Please contact our support team at support@nkcdevotional.com "
                    "with details about the issue you're experiencing.",
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Contact Support Card
          Card(
            color: Colors.blue.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.support_agent, color: Colors.blue, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    "Need More Help?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Can't find what you're looking for? Our support team is here to help!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // You could implement email launching here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Contact: support@nkcdevotional.com"),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.email),
                    label: const Text("Contact Support"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, List<Widget> items) {
    return Card(
      color: const Color(0xFF2D2D2D),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}


class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ℹ️ About"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo/Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.menu_book,
                  size: 80,
                  color: Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Name and Version
            const Center(
              child: Column(
                children: [
                  Text(
                    "NKC DEVOTIONAL",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Version 1.0.0",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Description
            _buildSection(
              "About This App",
              "NKC Devotional is your daily companion for spiritual growth and reflection. "
                  "Get inspired with daily devotional messages, manage your spiritual journey, "
                  "and stay connected with God through our carefully curated content.",
              Icons.info_outline,
            ),

            const SizedBox(height: 24),

            // Features
            _buildSection(
              "Features",
              "• Daily devotional messages\n"
                  "• Offline reading capability\n"
                  "• Search and archive functionality\n"
                  "• Calendar view of devotionals\n"
                  "• Daily notifications\n"
                  "• Download for offline access",
              Icons.star,
            ),

            const SizedBox(height: 24),

            // Contact/Support
            _buildSection(
              "Contact & Support",
              "For questions, feedback, or support, please reach out to us:\n\n"
                  "Email: support@nkcdevotional.com\n"
                  "Website: www.nkcdevotional.com\n\n"
                  "We'd love to hear from you!",
              Icons.contact_support,
            ),

            const SizedBox(height: 24),

            // Credits
            _buildSection(
              "Acknowledgments",
              "We thank God for His grace and guidance in creating this app. "
                  "Special thanks to all contributors and the community for their support.",
              Icons.favorite,
            ),

            const SizedBox(height: 32),

            // Copyright
            const Center(
              child: Text(
                "© 2024 NKC Devotional\nAll rights reserved",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    return Card(
      color: const Color(0xFF2D2D2D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                      icon: Icons.calendar_month,
                      label: "Calendar",
                      iconColor: Colors.deepOrange,
                      onTap: () {
                        widget.onDismiss();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CalendarPage(),
                          ),
                        );
                      },
                    ),
                    _MenuItem(
                      icon: Icons.info_outline,
                      label: "About",
                      iconColor: Colors.pink,
                      onTap: () {
                        widget.onDismiss();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutPage(),
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
                      icon: Icons.help_outline,
                      label: "Help",
                      iconColor: Colors.green,
                      onTap: () {
                        widget.onDismiss();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HelpPage(),
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
  List<Devotional> filteredDevotionals = [];
  bool isLoading = true;
  String searchQuery = '';
  DateTime? selectedDate;
  String sortOrder = 'newest'; // 'newest', 'oldest', 'alphabetical'

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadArchiveDevotionals();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text;
      _applyFiltersAndSort();
    });
  }

  Future<void> loadArchiveDevotionals() async {
    try {
      final result = await fetchDevotionals();
      setState(() {
        archiveDevotionals = result;
        filteredDevotionals = result;
        isLoading = false;
      });
      _applyFiltersAndSort();
    } catch (e) {
      print("❌ Error loading archive: $e");
      setState(() => isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    List<Devotional> filtered = List.from(archiveDevotionals);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((devotional) {
        return devotional.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            devotional.content.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Apply date filter
    if (selectedDate != null) {
      filtered = filtered.where((devotional) {
        return devotional.date.year == selectedDate!.year &&
            devotional.date.month == selectedDate!.month &&
            devotional.date.day == selectedDate!.day;
      }).toList();
    }

    // Apply sorting
    switch (sortOrder) {
      case 'newest':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'alphabetical':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
    }

    setState(() {
      filteredDevotionals = filtered;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _applyFiltersAndSort();
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      selectedDate = null;
      _applyFiltersAndSort();
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.arrow_downward,
                color: sortOrder == 'newest' ? Colors.amber : Colors.white70,
              ),
              title: const Text('Newest First', style: TextStyle(color: Colors.white)),
              trailing: sortOrder == 'newest'
                  ? const Icon(Icons.check, color: Colors.amber)
                  : null,
              onTap: () {
                setState(() {
                  sortOrder = 'newest';
                  _applyFiltersAndSort();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.arrow_upward,
                color: sortOrder == 'oldest' ? Colors.amber : Colors.white70,
              ),
              title: const Text('Oldest First', style: TextStyle(color: Colors.white)),
              trailing: sortOrder == 'oldest'
                  ? const Icon(Icons.check, color: Colors.amber)
                  : null,
              onTap: () {
                setState(() {
                  sortOrder = 'oldest';
                  _applyFiltersAndSort();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.sort_by_alpha,
                color: sortOrder == 'alphabetical' ? Colors.amber : Colors.white70,
              ),
              title: const Text('Alphabetical', style: TextStyle(color: Colors.white)),
              trailing: sortOrder == 'alphabetical'
                  ? const Icon(Icons.check, color: Colors.amber)
                  : null,
              onTap: () {
                setState(() {
                  sortOrder = 'alphabetical';
                  _applyFiltersAndSort();
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📚 Devotional Archive"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Sort Options',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => isLoading = true);
              await loadArchiveDevotionals();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2D2D2D),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search devotionals...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),

                // Date Filter Row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: selectedDate != null
                                ? Border.all(color: Colors.amber, width: 1)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: selectedDate != null ? Colors.amber : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedDate != null
                                    ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                                    : 'Filter by date',
                                style: TextStyle(
                                  color: selectedDate != null ? Colors.amber : Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (selectedDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearDateFilter,
                        icon: const Icon(Icons.clear, color: Colors.amber),
                        tooltip: 'Clear date filter',
                      ),
                    ],
                  ],
                ),

                // Results Count and Sort Info
                if (!isLoading) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredDevotionals.length} result${filteredDevotionals.length != 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'Sorted by: ${_getSortDisplayName()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Results List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : filteredDevotionals.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: filteredDevotionals.length,
              itemBuilder: (context, index) {
                final devotional = filteredDevotionals[index];
                return _buildDevotionalCard(devotional);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searchQuery.isNotEmpty || selectedDate != null
                ? Icons.search_off
                : Icons.auto_stories,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty || selectedDate != null
                ? 'No devotionals found'
                : 'No devotionals available',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (searchQuery.isNotEmpty || selectedDate != null)
            Text(
              'Try adjusting your search or date filter',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDevotionalCard(Devotional devotional) {
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
          color: const Color(0xFF2D2D2D),
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
            // Date and actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(devotional.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.amber,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Highlight search matches
                if (searchQuery.isNotEmpty && _isToday(devotional.date))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Title with search highlighting
            Text(
              devotional.title,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Content preview with search highlighting
            Text(
              devotional.content.length > 150
                  ? "${devotional.content.substring(0, 150)}..."
                  : devotional.content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),

            // Read more indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${devotional.content.split(' ').length} words',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
                const Row(
                  children: [
                    Text(
                      'Read more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: Colors.amber,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSortDisplayName() {
    switch (sortOrder) {
      case 'newest':
        return 'Newest First';
      case 'oldest':
        return 'Oldest First';
      case 'alphabetical':
        return 'Alphabetical';
      default:
        return 'Newest First';
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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