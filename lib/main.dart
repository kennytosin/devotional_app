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

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

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


// Add these new authentication pages to your Flutter app

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  bool isLogin = true;
  late AnimationController _backgroundController;
  late AnimationController _formController;
  late Animation<double> _fadeAnimation;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeInOut,
    ));

    _formController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _formController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
    });

    _formController.reset();
    _formController.forward();
  }

  Future<void> _handleEmailAuth() async {
    setState(() => _isLoading = true);

    try {
      // Add your email authentication logic here
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isLogin ? 'Login successful!' : 'Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to main app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DailyDevotionalApp()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoading = true);

    try {
      // Add your Google authentication logic here
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google authentication successful!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to main app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DailyDevotionalApp()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google auth error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // App Logo/Title
                      _buildAppTitle(),

                      const SizedBox(height: 60),

                      // Glass Card
                      _buildGlassCard(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2D1B69),
                const Color(0xFF11092D),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Moving circles
              ...List.generate(6, (index) {
                final double animationOffset = (_backgroundController.value * 2 * pi) + (index * pi / 3);
                final double size = 80 + (index * 40).toDouble();
                final double moveX = sin(animationOffset) * 30;
                final double moveY = cos(animationOffset * 0.7) * 20;

                return Positioned(
                  left: (index * 80).toDouble() + moveX,
                  top: (index * 120).toDouble() + moveY,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _getOrangeColor(index).withOpacity(0.4),
                          _getOrangeColor(index).withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Additional floating elements
              ...List.generate(4, (index) {
                final double animationOffset = (_backgroundController.value * -1.5 * pi) + (index * pi / 2);
                final double moveX = cos(animationOffset) * 50;
                final double moveY = sin(animationOffset * 1.2) * 30;

                return Positioned(
                  right: (index * 100).toDouble() + moveX,
                  bottom: (index * 150).toDouble() + moveY,
                  child: Container(
                    width: 60 + (index * 20).toDouble(),
                    height: 60 + (index * 20).toDouble(),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.amber.withOpacity(0.3),
                          Colors.orange.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Color _getOrangeColor(int index) {
    final colors = [
      Colors.deepOrange,
      Colors.orange,
      Colors.amber,
      const Color(0xFFFF6B35),
      const Color(0xFFFF8C42),
      const Color(0xFFFFA552),
    ];
    return colors[index % colors.length];
  }

  Widget _buildAppTitle() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.orange.withOpacity(0.3),
                Colors.amber.withOpacity(0.2),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.menu_book,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'NKC DEVOTIONAL',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your Daily Spiritual Companion',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                isLogin ? 'Welcome Back' : 'Create Account',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Form Fields
              if (!isLogin) ...[
                _buildGlassTextField(
                  controller: _usernameController,
                  hint: 'Username',
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),
              ],

              _buildGlassTextField(
                controller: _emailController,
                hint: 'Email address',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _buildGlassTextField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock,
                isPassword: true,
                isVisible: _isPasswordVisible,
                onVisibilityToggle: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),

              if (!isLogin) ...[
                const SizedBox(height: 16),
                _buildGlassTextField(
                  controller: _confirmPasswordController,
                  hint: 'Confirm password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isVisible: _isConfirmPasswordVisible,
                  onVisibilityToggle: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ],

              if (isLogin) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Handle forgot password
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Forgot password feature coming soon!'),
                        ),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Email Auth Button
              _buildAuthButton(
                onPressed: _handleEmailAuth,
                label: isLogin ? 'Login' : 'Sign Up',
                isPrimary: true,
              ),

              const SizedBox(height: 16),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Google Auth Button
              _buildSocialButton(
                onPressed: _handleGoogleAuth,
                icon: Icons.g_mobiledata, // You can replace with Google logo
                label: 'Continue with Google',
                color: Colors.white,
              ),

              const SizedBox(height: 24),

              // Toggle Auth Mode
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? "Don't have an account? " : 'Already have an account? ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleAuthMode,
                    child: Text(
                      isLogin ? 'Sign Up' : 'Login',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !isVisible,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.6),
              ),
              prefixIcon: Icon(
                icon,
                color: Colors.white.withOpacity(0.8),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                onPressed: onVisibilityToggle,
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white.withOpacity(0.8),
                ),
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButton({
    required VoidCallback onPressed,
    required String label,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? Colors.orange.shade600
              : Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: color,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(icon, size: 24),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.orange,
        ),
      ),
    );
  }
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

  // 🔥 Initialize Bible Database Service
  await BibleDatabaseService.initialize();

  runApp(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return const DevotionalApp();
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


class DevotionalApp extends StatelessWidget {
  const DevotionalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NKC Devotional',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff262626),
        primarySwatch: Colors.amber,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      // Start with authentication page
      home: const AuthPage(),
    );
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
      {"title": "Logout", "icon": Icons.logout, "page": null}, // Special handling for logout
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
              if (item["title"] == "Logout") {
                // Handle logout
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text('Logout', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Are you sure you want to logout?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate back to auth page
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const AuthPage()),
                                (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: const Text('Logout', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => item["page"] as Widget),
                );
              }
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



class FavouritesPage extends StatefulWidget {
  const FavouritesPage({super.key});

  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
  List<String> favoriteDevotionals = [];
  List<String> favoriteBibleBooks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        favoriteDevotionals = prefs.getStringList('favorite_devotionals') ?? [];
        favoriteBibleBooks = prefs.getStringList('favorite_bible_books') ?? [];
        isLoading = false;
      });
    } catch (e) {
      print('Error loading favorites: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E1E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("💝 Favorites"),
          backgroundColor: Colors.black,
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Devotionals"),
              Tab(text: "Bible Books"),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        body: TabBarView(
          children: [
            _buildDevotionalsFavoritesTab(),
            _buildBibleBooksFavoritesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDevotionalsFavoritesTab() {
    if (favoriteDevotionals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: Colors.white30,
            ),
            SizedBox(height: 16),
            Text(
              'No favorite devotionals yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mark devotionals as favorites to see them here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favoriteDevotionals.length,
      itemBuilder: (context, index) {
        final devotionalId = favoriteDevotionals[index];
        return Card(
          color: const Color(0xFF2D2D2D),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(
              'Devotional ${devotionalId}',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Tap to read',
              style: TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              // Navigate to devotional detail
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Navigate to devotional detail')),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBibleBooksFavoritesTab() {
    if (favoriteBibleBooks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 80,
              color: Colors.white30,
            ),
            SizedBox(height: 16),
            Text(
              'No favorite Bible books yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mark Bible books as favorites in the Bible section',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favoriteBibleBooks.length,
      itemBuilder: (context, index) {
        final bookName = favoriteBibleBooks[index];
        return Card(
          color: const Color(0xFF2D2D2D),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(
              bookName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Bible Book',
              style: TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              // Navigate to Bible book
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening $bookName')),
              );
            },
          ),
        );
      },
    );
  }
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


class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<BibleBook> allBooks = [];
  List<BibleBook> filteredBooks = [];
  Set<String> favoriteBooks = {};
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeBibleBooks();
    _loadFavorites();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text;
      _filterBooks();
    });
  }

  void _filterBooks() {
    if (searchQuery.isEmpty) {
      filteredBooks = allBooks;
    } else {
      filteredBooks = allBooks.where((book) {
        return book.name.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }
  }

  // Complete list of Bible books (66 books total)
  void _initializeBibleBooks() {
    allBooks = const [
      // Old Testament (39 books)
      BibleBook(number: 1, name: "Genesis", testament: "Old", chapters: 50),
      BibleBook(number: 2, name: "Exodus", testament: "Old", chapters: 40),
      BibleBook(number: 3, name: "Leviticus", testament: "Old", chapters: 27),
      BibleBook(number: 4, name: "Numbers", testament: "Old", chapters: 36),
      BibleBook(number: 5, name: "Deuteronomy", testament: "Old", chapters: 34),
      BibleBook(number: 6, name: "Joshua", testament: "Old", chapters: 24),
      BibleBook(number: 7, name: "Judges", testament: "Old", chapters: 21),
      BibleBook(number: 8, name: "Ruth", testament: "Old", chapters: 4),
      BibleBook(number: 9, name: "1 Samuel", testament: "Old", chapters: 31),
      BibleBook(number: 10, name: "2 Samuel", testament: "Old", chapters: 24),
      BibleBook(number: 11, name: "1 Kings", testament: "Old", chapters: 22),
      BibleBook(number: 12, name: "2 Kings", testament: "Old", chapters: 25),
      BibleBook(number: 13, name: "1 Chronicles", testament: "Old", chapters: 29),
      BibleBook(number: 14, name: "2 Chronicles", testament: "Old", chapters: 36),
      BibleBook(number: 15, name: "Ezra", testament: "Old", chapters: 10),
      BibleBook(number: 16, name: "Nehemiah", testament: "Old", chapters: 13),
      BibleBook(number: 17, name: "Esther", testament: "Old", chapters: 10),
      BibleBook(number: 18, name: "Job", testament: "Old", chapters: 42),
      BibleBook(number: 19, name: "Psalms", testament: "Old", chapters: 150),
      BibleBook(number: 20, name: "Proverbs", testament: "Old", chapters: 31),
      BibleBook(number: 21, name: "Ecclesiastes", testament: "Old", chapters: 12),
      BibleBook(number: 22, name: "Song of Solomon", testament: "Old", chapters: 8),
      BibleBook(number: 23, name: "Isaiah", testament: "Old", chapters: 66),
      BibleBook(number: 24, name: "Jeremiah", testament: "Old", chapters: 52),
      BibleBook(number: 25, name: "Lamentations", testament: "Old", chapters: 5),
      BibleBook(number: 26, name: "Ezekiel", testament: "Old", chapters: 48),
      BibleBook(number: 27, name: "Daniel", testament: "Old", chapters: 12),
      BibleBook(number: 28, name: "Hosea", testament: "Old", chapters: 14),
      BibleBook(number: 29, name: "Joel", testament: "Old", chapters: 3),
      BibleBook(number: 30, name: "Amos", testament: "Old", chapters: 9),
      BibleBook(number: 31, name: "Obadiah", testament: "Old", chapters: 1),
      BibleBook(number: 32, name: "Jonah", testament: "Old", chapters: 4),
      BibleBook(number: 33, name: "Micah", testament: "Old", chapters: 7),
      BibleBook(number: 34, name: "Nahum", testament: "Old", chapters: 3),
      BibleBook(number: 35, name: "Habakkuk", testament: "Old", chapters: 3),
      BibleBook(number: 36, name: "Zephaniah", testament: "Old", chapters: 3),
      BibleBook(number: 37, name: "Haggai", testament: "Old", chapters: 2),
      BibleBook(number: 38, name: "Zechariah", testament: "Old", chapters: 14),
      BibleBook(number: 39, name: "Malachi", testament: "Old", chapters: 4),

      // New Testament (27 books)
      BibleBook(number: 40, name: "Matthew", testament: "New", chapters: 28),
      BibleBook(number: 41, name: "Mark", testament: "New", chapters: 16),
      BibleBook(number: 42, name: "Luke", testament: "New", chapters: 24),
      BibleBook(number: 43, name: "John", testament: "New", chapters: 21),
      BibleBook(number: 44, name: "Acts", testament: "New", chapters: 28),
      BibleBook(number: 45, name: "Romans", testament: "New", chapters: 16),
      BibleBook(number: 46, name: "1 Corinthians", testament: "New", chapters: 16),
      BibleBook(number: 47, name: "2 Corinthians", testament: "New", chapters: 13),
      BibleBook(number: 48, name: "Galatians", testament: "New", chapters: 6),
      BibleBook(number: 49, name: "Ephesians", testament: "New", chapters: 6),
      BibleBook(number: 50, name: "Philippians", testament: "New", chapters: 4),
      BibleBook(number: 51, name: "Colossians", testament: "New", chapters: 4),
      BibleBook(number: 52, name: "1 Thessalonians", testament: "New", chapters: 5),
      BibleBook(number: 53, name: "2 Thessalonians", testament: "New", chapters: 3),
      BibleBook(number: 54, name: "1 Timothy", testament: "New", chapters: 6),
      BibleBook(number: 55, name: "2 Timothy", testament: "New", chapters: 4),
      BibleBook(number: 56, name: "Titus", testament: "New", chapters: 3),
      BibleBook(number: 57, name: "Philemon", testament: "New", chapters: 1),
      BibleBook(number: 58, name: "Hebrews", testament: "New", chapters: 13),
      BibleBook(number: 59, name: "James", testament: "New", chapters: 5),
      BibleBook(number: 60, name: "1 Peter", testament: "New", chapters: 5),
      BibleBook(number: 61, name: "2 Peter", testament: "New", chapters: 3),
      BibleBook(number: 62, name: "1 John", testament: "New", chapters: 5),
      BibleBook(number: 63, name: "2 John", testament: "New", chapters: 1),
      BibleBook(number: 64, name: "3 John", testament: "New", chapters: 1),
      BibleBook(number: 65, name: "Jude", testament: "New", chapters: 1),
      BibleBook(number: 66, name: "Revelation", testament: "New", chapters: 22),
    ];

    filteredBooks = allBooks;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList('favorite_bible_books') ?? [];
      setState(() {
        favoriteBooks = favoritesJson.toSet();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_bible_books', favoriteBooks.toList());
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  void _toggleFavorite(BibleBook book) {
    setState(() {
      if (favoriteBooks.contains(book.name)) {
        favoriteBooks.remove(book.name);
      } else {
        favoriteBooks.add(book.name);
      }
    });
    _saveFavorites();

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          favoriteBooks.contains(book.name)
              ? '${book.name} added to favorites'
              : '${book.name} removed from favorites',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: favoriteBooks.contains(book.name)
            ? Colors.green
            : Colors.orange,
      ),
    );
  }

  List<BibleBook> get favoriteBooksList {
    return allBooks.where((book) => favoriteBooks.contains(book.name)).toList();
  }

  List<BibleBook> get oldTestamentBooks {
    final books = searchQuery.isEmpty ? allBooks : filteredBooks;
    return books.where((book) => book.testament == "Old").toList();
  }

  List<BibleBook> get newTestamentBooks {
    final books = searchQuery.isEmpty ? allBooks : filteredBooks;
    return books.where((book) => book.testament == "New").toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E1E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text("📖 Bible"),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "All Books"),
            Tab(text: "Favorites"),
            Tab(text: "Search"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar (visible on all tabs)
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search Bible books...',
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
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllBooksTab(),
                _buildFavoritesTab(),
                _buildSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllBooksTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Old Testament Section
          _buildTestamentSection("Old Testament", oldTestamentBooks),

          // New Testament Section
          _buildTestamentSection("New Testament", newTestamentBooks),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    final favorites = favoriteBooksList;

    if (favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: Colors.white30,
            ),
            SizedBox(height: 16),
            Text(
              'No favorite books yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the heart icon on any book to add it to favorites',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final book = favorites[index];
        return _buildBookCard(book, showTestament: true);
      },
    );
  }

  Widget _buildSearchTab() {
    if (searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.white30,
            ),
            SizedBox(height: 16),
            Text(
              'Search for Bible books',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Type in the search box above to find specific books',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    if (filteredBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 80,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            Text(
              'No books found for "$searchQuery"',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search term',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final book = filteredBooks[index];
        return _buildBookCard(book, showTestament: true);
      },
    );
  }

  Widget _buildTestamentSection(String title, List<BibleBook> books) {
    if (books.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${books.length} books)',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: books.length,
          itemBuilder: (context, index) {
            return _buildBookCard(books[index]);
          },
        ),
      ],
    );
  }

  Widget _buildBookCard(BibleBook book, {bool showTestament = false}) {
    final isFavorite = favoriteBooks.contains(book.name);

    return Card(
      color: const Color(0xFF2D2D2D),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: book.testament == "Old" ? Colors.blue[600] : Colors.green[600],
          child: Text(
            book.number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          book.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTestament) ...[
              Text(
                '${book.testament} Testament',
                style: TextStyle(
                  color: book.testament == "Old" ? Colors.blue[300] : Colors.green[300],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              '${book.chapters} ${book.chapters == 1 ? 'chapter' : 'chapters'}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.white54,
              ),
              onPressed: () => _toggleFavorite(book),
              tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
        onTap: () {
          // Navigate to book chapters or reading page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BibleBookPage(book: book),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------- BIBLE BOOK PAGE -------------------------
class BibleBookPage extends StatefulWidget {
  final BibleBook book;

  const BibleBookPage({super.key, required this.book});
  @override
  State<BibleBookPage> createState() => _BibleBookPageState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.name),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 80,
              color: book.testament == "Old" ? Colors.blue[300] : Colors.green[300],
            ),
            const SizedBox(height: 20),
            Text(
              book.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${book.testament} Testament',
              style: TextStyle(
                fontSize: 16,
                color: book.testament == "Old" ? Colors.blue[300] : Colors.green[300],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${book.chapters} ${book.chapters == 1 ? 'Chapter' : 'Chapters'}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Chapter selection and Bible text\nwould be implemented here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BibleBookPageState extends State<BibleBookPage> {
  List<int> chapters = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    final chaptersList = await BibleDatabaseService.getChapters(widget.book.id);
    setState(() {
      chapters = chaptersList;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.name),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BibleChapterPage(
                      book: widget.book,
                      chapter: chapter,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    chapter.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ------------------------- BIBLE CHAPTER PAGE -------------------------
class BibleChapterPage extends StatefulWidget {
  final BibleBook book;
  final int chapter;

  const BibleChapterPage({super.key, required this.book, required this.chapter});

  @override
  State<BibleChapterPage> createState() => _BibleChapterPageState();
}

class _BibleChapterPageState extends State<BibleChapterPage> {
  List<BibleVerse> verses = [];
  bool isLoading = true;
  double fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _loadVerses();
    _loadFontSize();
  }

  Future<void> _loadVerses() async {
    final versesList = await BibleDatabaseService.getChapterVerses(
      widget.book.id,
      widget.chapter,
    );
    setState(() {
      verses = versesList;
      isLoading = false;
    });
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      fontSize = prefs.getDouble('bible_font_size') ?? 16.0;
    });
  }

  Future<void> _saveFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bible_font_size', fontSize);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.book.name} ${widget.chapter}'),
        backgroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'font_size') {
                _showFontSizeDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'font_size',
                child: Row(
                  children: [
                    Icon(Icons.text_fields, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Font Size'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: verses.length,
        itemBuilder: (context, index) {
          final verse = verses[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${verse.verse} ',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: fontSize - 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: verse.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      height: 1.5,
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

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Font Size', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sample Text',
                style: TextStyle(color: Colors.white, fontSize: fontSize),
              ),
              const SizedBox(height: 16),
              Slider(
                value: fontSize,
                min: 12.0,
                max: 24.0,
                divisions: 12,
                activeColor: Colors.amber,
                onChanged: (value) {
                  setDialogState(() => fontSize = value);
                  setState(() => fontSize = value);
                },
              ),
              Text(
                '${fontSize.toInt()}px',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _saveFontSize();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

// ------------------------- BIBLE SEARCH WIDGET -------------------------
class BibleSearchWidget extends StatefulWidget {
  const BibleSearchWidget({super.key});

  @override
  State<BibleSearchWidget> createState() => _BibleSearchWidgetState();
}

class _BibleSearchWidgetState extends State<BibleSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<BibleVerse> searchResults = [];
  bool isSearching = false;
  Map<int, BibleBook> booksMap = {};

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await BibleDatabaseService.getBooks();
    setState(() {
      booksMap = {for (var book in books) book.id: book};
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    setState(() => isSearching = true);

    final results = await BibleDatabaseService.searchVerses(query);
    setState(() {
      searchResults = results;
      isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search verses...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFF2D2D2D),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: _performSearch,
          ),
        ),
        Expanded(
          child: isSearching
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : searchResults.isEmpty
              ? const Center(
            child: Text(
              'Enter a search term to find verses',
              style: TextStyle(color: Colors.white54),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final verse = searchResults[index];
              final book = booksMap[verse.bookId];

              return Card(
                color: const Color(0xFF2D2D2D),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${book?.name ?? 'Unknown'} ${verse.chapter}:${verse.verse}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        verse.text,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ------------------------- BIBLE SETTINGS WIDGET -------------------------
class BibleSettingsWidget extends StatefulWidget {
  const BibleSettingsWidget({super.key});

  @override
  State<BibleSettingsWidget> createState() => _BibleSettingsWidgetState();
}

class _BibleSettingsWidgetState extends State<BibleSettingsWidget> {
  String currentTranslation = '';
  Map<String, bool> availableTranslations = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => isLoading = true);

    setState(() {
      currentTranslation = BibleDatabaseService.currentTranslation;
    });

    // 🔥 Check which translations are actually available
    final translationChecks = <String, bool>{};
    for (final translation in BibleDatabaseService.availableTranslations.keys) {
      translationChecks[translation] = await BibleDatabaseService.isTranslationAvailable(translation);
    }

    setState(() {
      availableTranslations = translationChecks;
      isLoading = false;
    });

    // Debug log
    print('📖 Available translations: $availableTranslations');
  }

  Future<void> _switchTranslation(String translationCode) async {
    try {
      await BibleDatabaseService.switchTranslation(translationCode);
      setState(() {
        currentTranslation = translationCode;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Switched to $translationCode'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to switch translation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadTranslation(String translationCode) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BibleDownloadPage(selectedTranslation: translationCode),
      ),
    );

    // Reload settings when returning from download page
    if (result == true || result == null) {
      await _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current Translation Section
        Card(
          color: const Color(0xFF2D2D2D),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Translation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentTranslation.isEmpty ? 'None selected' :
                  '${BibleDatabaseService.availableTranslations[currentTranslation]} ($currentTranslation)',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                // Debug button
                ElevatedButton(
                  onPressed: () async {
                    final info = await BibleDatabaseService.getDatabaseInfo();
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text('Database Info', style: TextStyle(color: Colors.white)),
                          content: SingleChildScrollView(
                            child: Text(
                              info.toString(),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(color: Colors.amber)),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Debug Info'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Available Translations Section
        Card(
          color: const Color(0xFF2D2D2D),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Translations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...availableTranslations.entries.map((entry) {
                  final translationCode = entry.key;
                  final isAvailable = entry.value;
                  final translationName = BibleDatabaseService.availableTranslations[translationCode] ?? translationCode;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isAvailable ? Icons.check_circle : Icons.download,
                      color: isAvailable ? Colors.green : Colors.amber,
                    ),
                    title: Text(
                      translationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      translationCode,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: isAvailable
                        ? (currentTranslation == translationCode
                        ? const Icon(Icons.radio_button_checked, color: Colors.amber)
                        : TextButton(
                      onPressed: () => _switchTranslation(translationCode),
                      child: const Text('Switch', style: TextStyle(color: Colors.amber)),
                    ))
                        : TextButton(
                      onPressed: () => _downloadTranslation(translationCode),
                      child: const Text('Download', style: TextStyle(color: Colors.amber)),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // App Settings Section
        Card(
          color: const Color(0xFF2D2D2D),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.download, color: Colors.amber),
                  title: const Text(
                    'Manage Downloads',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Download or remove Bible translations',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BibleDownloadPage()),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storage, color: Colors.amber),
                  title: const Text(
                    'Clear Cache',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Free up storage space',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                  onTap: _showClearCacheDialog,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // About Section
        Card(
          color: const Color(0xFF2D2D2D),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bible Reader App v1.0.0',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Read the Bible offline with multiple translations and search functionality.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Clear Cache',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will clear temporary files and free up storage space. Your downloaded translations will not be affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearCache();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Clear', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    try {
      // Add your cache clearing logic here
      // For example: await BibleDatabaseService.clearCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ------------------------- DATA MODELS -------------------------
// You'll need to add these model classes and services

class BibleBook {
  final int number;
  final String name;
  final String testament;
  final int chapters;
  final String id;

  const BibleBook({
    required this.number,
    required this.name,
    required this.testament,
    required this.chapters,
  }) : id = name;

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'testament': testament,
    'chapters': chapters,
  };

  factory BibleBook.fromJson(Map<String, dynamic> json) => BibleBook(
    number: json['number'],
    name: json['name'],
    testament: json['testament'],
    chapters: json['chapters'],
  );
}

class BibleVerse {
  final int bookId;
  final int chapter;
  final int verse;
  final String text;

  BibleVerse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
  });
}

// ------------------------- DATABASE SERVICE -------------------------
// This is a placeholder - implement your actual database service
class BibleDatabaseService {
  static String currentTranslation = 'KJV';
  static Database? _currentDatabase;

  static final Map<String, String> availableTranslations = {
    'KJV': 'King James Version',
    'ASV': 'American Standard Version',
    'NHEB': 'New Heart English Bible',
  };

  // Get the current database connection
  static Future<Database?> get database async {
    if (_currentDatabase != null && _currentDatabase!.isOpen) {
      return _currentDatabase;
    }

    if (await isTranslationAvailable(currentTranslation)) {
      await _connectToTranslation(currentTranslation);
      return _currentDatabase;
    }

    return null;
  }

  // Connect to a specific translation database
  static Future<void> _connectToTranslation(String translation) async {
    try {
      final dbPath = await getDatabasesPath();
      final filePath = p.join(dbPath, '${translation.toUpperCase()}.db');

      final file = File(filePath);
      if (await file.exists()) {
        _currentDatabase = await openDatabase(
          filePath,
          readOnly: true,
        );

        // Save current translation preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_bible_translation', translation);

        print('✅ Connected to $translation database at $filePath');
      } else {
        print('❌ Database file not found: $filePath');
      }
    } catch (e) {
      print('❌ Error connecting to $translation database: $e');
      _currentDatabase = null;
    }
  }

  // Check if a translation is downloaded and available
  static Future<bool> isTranslationAvailable(String translationCode) async {
    try {
      final dbPath = await getDatabasesPath();
      final filePath = p.join(dbPath, '${translationCode.toUpperCase()}.db');
      final file = File(filePath);

      if (await file.exists() && await file.length() > 1000) {
        // Verify it's a valid database by trying to open it
        try {
          final db = await openDatabase(filePath, readOnly: true);
          // Check if it has the expected tables
          final tables = await db.query('sqlite_master',
              where: 'type = ?',
              whereArgs: ['table']
          );
          await db.close();

          // Look for common Bible database table structures
          final tableNames = tables.map((t) => (t['name'] as String).toLowerCase()).toList();
          final hasValidStructure = tableNames.any((name) =>
          name.contains('verse') || name.contains('scripture') || name.contains('bible')
          );

          return hasValidStructure;
        } catch (e) {
          print('❌ Invalid database file for $translationCode: $e');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error checking translation availability: $e');
      return false;
    }
  }

  // Switch to a different translation
  static Future<void> switchTranslation(String translationCode) async {
    if (!await isTranslationAvailable(translationCode)) {
      throw Exception('Translation $translationCode is not available');
    }

    // Close current database
    if (_currentDatabase != null && _currentDatabase!.isOpen) {
      await _currentDatabase!.close();
      _currentDatabase = null;
    }

    // Switch to new translation
    currentTranslation = translationCode;
    await _connectToTranslation(translationCode);
  }

  // Load saved translation preference
  static Future<void> loadSavedTranslation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('current_bible_translation');

      if (saved != null && await isTranslationAvailable(saved)) {
        currentTranslation = saved;
        await _connectToTranslation(saved);
      } else {
        // Try to find any available translation
        for (final translation in availableTranslations.keys) {
          if (await isTranslationAvailable(translation)) {
            currentTranslation = translation;
            await _connectToTranslation(translation);
            break;
          }
        }
      }
    } catch (e) {
      print('❌ Error loading saved translation: $e');
    }
  }

  // Enhanced method to detect and work with different database schemas
  static Future<Map<String, String>> _detectDatabaseSchema() async {
    final db = await database;
    if (db == null) return {};

    try {
      // Get all tables
      final tables = await db.query('sqlite_master',
          where: 'type = ?',
          whereArgs: ['table']
      );

      final schema = <String, String>{};

      for (final table in tables) {
        final tableName = table['name'] as String;
        if (tableName.startsWith('sqlite_')) continue;

        // Get table info
        final pragma = await db.rawQuery('PRAGMA table_info($tableName)');
        final columns = pragma.map((col) => col['name'] as String).toList();

        // Identify table types based on columns
        if (columns.any((col) => col.toLowerCase().contains('book'))) {
          schema['books_table'] = tableName;
        }
        if (columns.any((col) => col.toLowerCase().contains('verse')) ||
            columns.any((col) => col.toLowerCase().contains('text')) ||
            columns.any((col) => col.toLowerCase().contains('scripture'))) {
          schema['verses_table'] = tableName;

          // Map column names
          for (final col in columns) {
            final colLower = col.toLowerCase();
            if (colLower.contains('book')) schema['book_column'] = col;
            if (colLower.contains('chapter')) schema['chapter_column'] = col;
            if (colLower.contains('verse')) schema['verse_column'] = col;
            if (colLower.contains('text') || colLower.contains('scripture')) {
              schema['text_column'] = col;
            }
          }
        }
      }

      return schema;
    } catch (e) {
      print('❌ Error detecting database schema: $e');
      return {};
    }
  }

  // Get list of books from current database
  static Future<List<BibleBook>> getBooks() async {
    final db = await database;
    if (db == null) return [];

    try {
      final schema = await _detectDatabaseSchema();
      final booksTable = schema['books_table'];

      List<Map<String, dynamic>> results = [];

      if (booksTable != null) {
        // Use detected books table
        results = await db.query(booksTable, orderBy: 'id');
      } else {
        // Try common table names
        final possibleTables = ['books', 'book', 'book_names'];
        for (final tableName in possibleTables) {
          try {
            results = await db.query(tableName, orderBy: 'id');
            break;
          } catch (e) {
            continue;
          }
        }

        // If no books table, generate from verses table
        if (results.isEmpty) {
          final versesTable = schema['verses_table'] ?? 'verses';
          final bookColumn = schema['book_column'] ?? 'book';

          try {
            results = await db.query(
              versesTable,
              columns: ['DISTINCT $bookColumn as id'],
              orderBy: bookColumn,
            );

            // Add book names (you might want to create a mapping)
            results = results.map((row) {
              final id = row['id'] as int;
              return {
                'id': id,
                'name': _getBookName(id),
              };
            }).toList();
          } catch (e) {
            print('❌ Error generating books from verses: $e');
          }
        }
      }

      return results.map((row) {
        final id = row['id'] as int? ?? row['book_id'] as int? ?? 0;
        final name = row['name'] as String? ??
            row['book_name'] as String? ??
            row['title'] as String? ??
            _getBookName(id);

        return BibleBook(id: id, name: name);
      }).toList();

    } catch (e) {
      print('❌ Error fetching books: $e');
      return [];
    }
  }

  // Helper method to get book names from IDs
  static String _getBookName(int bookId) {
    const bookNames = [
      '', // 0 - placeholder
      'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
      'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
      '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
      'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
      'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah', 'Lamentations',
      'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
      'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
      'Zephaniah', 'Haggai', 'Zechariah', 'Malachi', 'Matthew',
      'Mark', 'Luke', 'John', 'Acts', 'Romans',
      '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians',
      'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
      'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter',
      '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation'
    ];

    if (bookId > 0 && bookId < bookNames.length) {
      return bookNames[bookId];
    }
    return 'Book $bookId';
  }

  // Get chapters for a specific book
  static Future<List<int>> getChapters(int bookId) async {
    final db = await database;
    if (db == null) return [];

    try {
      final schema = await _detectDatabaseSchema();
      final versesTable = schema['verses_table'] ?? 'verses';
      final bookColumn = schema['book_column'] ?? 'book';
      final chapterColumn = schema['chapter_column'] ?? 'chapter';

      final results = await db.query(
        versesTable,
        columns: ['DISTINCT $chapterColumn'],
        where: '$bookColumn = ?',
        whereArgs: [bookId],
        orderBy: chapterColumn,
      );

      return results.map((row) => row[chapterColumn] as int).toList();
    } catch (e) {
      print('❌ Error fetching chapters: $e');
      return [];
    }
  }

  // Get verses for a specific chapter
  static Future<List<BibleVerse>> getChapterVerses(int bookId, int chapter) async {
    final db = await database;
    if (db == null) return [];

    try {
      final schema = await _detectDatabaseSchema();
      final versesTable = schema['verses_table'] ?? 'verses';
      final bookColumn = schema['book_column'] ?? 'book';
      final chapterColumn = schema['chapter_column'] ?? 'chapter';
      final verseColumn = schema['verse_column'] ?? 'verse';
      final textColumn = schema['text_column'] ?? 'text';

      final results = await db.query(
        versesTable,
        where: '$bookColumn = ? AND $chapterColumn = ?',
        whereArgs: [bookId, chapter],
        orderBy: verseColumn,
      );

      return results.map((row) {
        return BibleVerse(
          bookId: row[bookColumn] as int,
          chapter: row[chapterColumn] as int,
          verse: row[verseColumn] as int,
          text: row[textColumn] as String,
        );
      }).toList();

    } catch (e) {
      print('❌ Error fetching chapter verses: $e');
      return [];
    }
  }

  // Search verses by text
  static Future<List<BibleVerse>> searchVerses(String query) async {
    final db = await database;
    if (db == null || query.trim().isEmpty) return [];

    try {
      final schema = await _detectDatabaseSchema();
      final versesTable = schema['verses_table'] ?? 'verses';
      final bookColumn = schema['book_column'] ?? 'book';
      final chapterColumn = schema['chapter_column'] ?? 'chapter';
      final verseColumn = schema['verse_column'] ?? 'verse';
      final textColumn = schema['text_column'] ?? 'text';

      final results = await db.query(
        versesTable,
        where: '$textColumn LIKE ?',
        whereArgs: ['%${query.trim()}%'],
        orderBy: '$bookColumn, $chapterColumn, $verseColumn',
        limit: 100,
      );

      return results.map((row) {
        return BibleVerse(
          bookId: row[bookColumn] as int,
          chapter: row[chapterColumn] as int,
          verse: row[verseColumn] as int,
          text: row[textColumn] as String,
        );
      }).toList();

    } catch (e) {
      print('❌ Error searching verses: $e');
      return [];
    }
  }

  // Initialize the database service
  static Future<void> initialize() async {
    await loadSavedTranslation();
  }

  // Close database connection
  static Future<void> close() async {
    if (_currentDatabase != null && _currentDatabase!.isOpen) {
      await _currentDatabase!.close();
      _currentDatabase = null;
    }
  }

  // Get database info for debugging
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    if (db == null) return {'error': 'No database connection'};

    try {
      final info = <String, dynamic>{
        'translation': currentTranslation,
        'isOpen': db.isOpen,
        'path': db.path,
      };

      // Get schema info
      final schema = await _detectDatabaseSchema();
      info['detected_schema'] = schema;

      // Get all tables
      final tables = await db.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
      info['tables'] = tables.map((t) => t['name']).toList();

      // Get sample data from each table
      for (final table in tables) {
        final tableName = table['name'] as String;
        if (!tableName.startsWith('sqlite_')) {
          try {
            final sample = await db.query(tableName, limit: 1);
            info['sample_$tableName'] = sample;
          } catch (e) {
            info['sample_$tableName'] = 'Error: $e';
          }
        }
      }

      return info;
    } catch (e) {
      return {'error': 'Database error: $e'};
    }
  }
}

// ------------------------- DOWNLOAD PAGE -------------------------
// Placeholder for the download page
class BibleDownloadPage extends StatefulWidget {
  final String? selectedTranslation;

  const BibleDownloadPage({super.key, this.selectedTranslation});

  @override
  State<BibleDownloadPage> createState() => _BibleDownloadPageState();
}

class _BibleDownloadPageState extends State<BibleDownloadPage> {
  Map<String, bool> downloadStatus = {};
  Map<String, double> downloadProgress = {};
  Map<String, bool> isDownloading = {};
  String? downloadError;
  bool isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    setState(() => isChecking = true);

    for (final translation in BibleDownloadManager.availableTranslations.keys) {
      final isAvailable = await BibleDatabaseService.isTranslationAvailable(translation);
      setState(() {
        downloadStatus[translation] = isAvailable;
        isDownloading[translation] = false;
        downloadProgress[translation] = 0.0;
      });
    }

    setState(() => isChecking = false);
  }

  Future<void> _downloadTranslation(String translation) async {
    setState(() {
      isDownloading[translation] = true;
      downloadProgress[translation] = 0.0;
      downloadError = null;
    });

    final success = await BibleDownloadManager.downloadBibleDatabase(
      translation,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            downloadProgress[translation] = progress;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            downloadError = error;
            isDownloading[translation] = false;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        isDownloading[translation] = false;
        downloadStatus[translation] = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $translation downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // If this is the first translation downloaded, switch to it
        if (BibleDatabaseService.currentTranslation.isEmpty) {
          await BibleDatabaseService.switchTranslation(translation);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to download $translation${downloadError != null ? ': $downloadError' : ''}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteTranslation(String translation) async {
    // Prevent deleting the current translation
    if (translation == BibleDatabaseService.currentTranslation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Cannot delete the currently active translation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Delete $translation?', style: const TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently remove the ${BibleDownloadManager.availableTranslations[translation]?['name']} from your device.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await BibleDownloadManager.deleteBibleDatabase(translation);
      setState(() {
        downloadStatus[translation] = !success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '🗑️ $translation deleted successfully!'
              : '❌ Failed to delete $translation'
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isChecking) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('📥 Download Bible'),
          backgroundColor: Colors.black,
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📥 Download Bible Translations'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _checkDownloadStatus,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Info
          Card(
            color: Colors.blue.withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.download_rounded, color: Colors.blue, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Download Bible Translations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Download different Bible translations for offline reading. Each translation is typically 4-5 MB.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Popular translations section
          _buildSectionHeader('Popular Translations'),
          ...['KJV'].map((translation) =>
              _buildTranslationCard(translation)
          ),

          const SizedBox(height: 24),

          // Other translations section
          _buildSectionHeader('Other Translations'),
          ...['ASV', 'NHEB', 'ESV', 'NASB'].map((translation) =>
              _buildTranslationCard(translation)
          ),

          if (downloadError != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Download Error',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            downloadError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Storage info
          Card(
            color: const Color(0xFF2D2D2D),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Storage Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Each translation is approximately 4-5 MB\n'
                        '• Downloads are stored locally on your device\n'
                        '• Internet connection required for downloading\n'
                        '• Downloaded translations work completely offline',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTranslationCard(String translation) {
    final data = BibleDownloadManager.availableTranslations[translation]!;
    final isDownloaded = downloadStatus[translation] ?? false;
    final isCurrentlyDownloading = isDownloading[translation] ?? false;
    final progress = downloadProgress[translation] ?? 0.0;
    final isCurrentTranslation = translation == BibleDatabaseService.currentTranslation;

    return Card(
      color: const Color(0xFF2D2D2D),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            data['name']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrentTranslation) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$translation • ${data['size']}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['description']!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDownloaded && !isCurrentTranslation)
                  IconButton(
                    onPressed: () => _deleteTranslation(translation),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (isCurrentlyDownloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[700],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Downloading... ${(progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isDownloaded
                      ? (isCurrentTranslation
                      ? null
                      : () async {
                    await BibleDatabaseService.switchTranslation(translation);
                    setState(() {}); // Refresh to show new active translation
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Switched to $translation'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  })
                      : () => _downloadTranslation(translation),
                  icon: Icon(
                    isDownloaded
                        ? (isCurrentTranslation ? Icons.check_circle : Icons.swap_horiz)
                        : Icons.download,
                    color: isDownloaded
                        ? (isCurrentTranslation ? Colors.green : Colors.amber)
                        : Colors.white,
                  ),
                  label: Text(
                    isDownloaded
                        ? (isCurrentTranslation ? 'Active Translation' : 'Switch To This')
                        : 'Download',
                    style: TextStyle(
                      color: isDownloaded
                          ? (isCurrentTranslation ? Colors.green : Colors.black)
                          : Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDownloaded
                        ? (isCurrentTranslation
                        ? Colors.green.withOpacity(0.2)
                        : Colors.amber)
                        : Colors.amber,
                    foregroundColor: isDownloaded
                        ? (isCurrentTranslation ? Colors.green : Colors.black)
                        : Colors.black,
                    disabledBackgroundColor: Colors.green.withOpacity(0.2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class BibleTranslation {
  final String translation;
  final String title;
  final String? license;

  BibleTranslation({
    required this.translation,
    required this.title,
    this.license,
  });

  factory BibleTranslation.fromMap(Map<String, dynamic> map) {
    return BibleTranslation(
      translation: map['translation'] as String,
      title: map['title'] as String,
      license: map['license'] as String?,
    );
  }
}

class BibleChapter {
  final int chapter;
  final List<BibleVerse> verses;

  BibleChapter({required this.chapter, required this.verses});
}

// ------------------------- BIBLE DATABASE SERVICE -------------------------


// ------------------------- DOWNLOAD MANAGER FOR BIBLE TRANSLATIONS -------------------------
class BibleDownloadManager {
  static final Map<String, Map<String, String>> _translations = {
    'KJV': {
      'name': 'King James Version',
      'url': 'https://github.com/scrollmapper/bible_databases/raw/master/formats/sqlite/KJV.db',
      'size': '4.2 MB',
      'description': 'Traditional English translation from 1611'
    },

    'ASV': {
      'name': 'American Standard Version',
      'url': 'https://github.com/scrollmapper/bible_databases/raw/master/formats/sqlite/ASV.db',
      'size': '4.1 MB',
      'description': 'Revised version of KJV from 1901'
    },
    'NHEB': {
      'name': 'New Heart English Bible',
      'url': 'https://github.com/scrollmapper/bible_databases/raw/master/formats/sqlite/NHEB.db',
      'size': '4.3 MB',
      'description': 'Modern English revision based on World English Bible'
    },

  };

  static Future<bool> downloadBibleDatabase(
      String translation, {
        Function(double)? onProgress,
        Function(String)? onError,
      }) async {
    final translationData = _translations[translation];
    if (translationData == null) {
      onError?.call('Translation not available');
      return false;
    }

    try {
      final url = translationData['url']!;
      final dbPath = await getDatabasesPath();
      final filePath = p.join(dbPath, '${translation.toUpperCase()}.db');

      print('📥 Starting download: $url');
      print('📁 Saving to: $filePath');

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted existing file');
      }

      // Download with progress tracking
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await http.Client().send(request);

      print('📡 Response status: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode != 200) {
        onError?.call('Download failed: HTTP ${streamedResponse.statusCode}');
        return false;
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      var downloadedBytes = 0;
      final bytes = <int>[];

      print('📊 Content length: $contentLength bytes');

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          onProgress?.call(progress);
          print('⬇️ Progress: ${(progress * 100).toInt()}%');
        }
      }

      // Write to file
      await file.writeAsBytes(bytes);
      print('💾 File written: ${bytes.length} bytes');

      // Verify file was created and is valid
      if (await file.exists() && await file.length() > 1000) {
        // Try to open the database to verify it's valid
        try {
          final db = await openDatabase(filePath, readOnly: true);
          final tables = await db.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
          await db.close();

          if (tables.isNotEmpty) {
            print('✅ Successfully downloaded and verified $translation Bible');
            return true;
          } else {
            onError?.call('Downloaded file appears to be invalid (no tables found)');
            await file.delete();
            return false;
          }
        } catch (e) {
          onError?.call('Downloaded file is not a valid SQLite database: $e');
          await file.delete();
          return false;
        }
      } else {
        onError?.call('Failed to save downloaded file');
        return false;
      }

    } catch (e) {
      print('❌ Download error: $e');
      onError?.call('Download error: $e');
      return false;
    }
  }

  static Future<bool> deleteBibleDatabase(String translation) async {
    try {
      final dbPath = await getDatabasesPath();
      final filePath = p.join(dbPath, '${translation.toUpperCase()}.db');
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted $translation Bible database');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting Bible database: $e');
      return false;
    }
  }

  static Map<String, Map<String, String>> get availableTranslations => _translations;
}
