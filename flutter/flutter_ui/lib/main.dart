import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

// ✅ Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ Local notifications import
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'login_function/login_customer.dart';
import 'login_function/login_staff.dart';

import 'role_views/admin_view.dart';
import 'role_views/manager_view.dart';
import 'role_views/cashier_view.dart';
import 'role_views/staff_view.dart';
import 'role_views/customer_view.dart';
import 'role_views/customer_features/cart_service.dart';

// ✅ Global instance for local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase before running app
  await Firebase.initializeApp();

  // ✅ Optional: Set up FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final startScreen = await _getStartScreen();

  runApp(
    ChangeNotifierProvider(
      create: (context) => CartService(),
      child: MyApp(startScreen),
    ),
  );
}

// ✅ Background notification handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

Future<Widget> _getStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final role = prefs.getString('role');
  final staffId = prefs.getInt('staff_id');
  final customerId = prefs.getInt('customerId');

  print('SharedPref: is_logged_in=$isLoggedIn, role=$role, staff_id=$staffId, customerId=$customerId');

  if (isLoggedIn && role != null) {
    switch (role) {
      case 'admin':
        if (staffId != null) return AdminView(staffId: staffId);
        break;
      case 'manager':
        if (staffId != null) {
          return ManagerView(staffId: staffId);
        }
        break;
      case 'cashier':
        if (staffId != null) {
          return CashierView(staffId: staffId);
        }
        break;
      case 'staff':
        if (staffId != null) return StaffView(staffId: staffId);
        break;
      case 'customer':
        return const CustomerView();
    }
  }

  // If not logged in, or if session data is incomplete, default to the customer login screen.
  return const LoginCustomer();
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp(this.startScreen, {super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Request FCM token + permissions when app starts
    _initFCM();

    return MaterialApp(
      title: 'Capstone App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: startScreen,
    );
  }

  // ✅ Initialize FCM, request permissions, and listen for foreground messages
  void _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 🔔 Request notification permission (iOS + Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print("🔔 User granted permission: ${settings.authorizationStatus}");

    // ✅ Get device FCM token
    String? token = await messaging.getToken();
    print("🔑 FCM Token: $token");

    // ✅ Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // ✅ Listen for foreground messages and show visible notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📩 Foreground message received: '
          'Title: ${message.notification?.title}, '
          'Body: ${message.notification?.body}');

      // Show popup notification
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          'foreground_channel', // channel id
          'Foreground Notifications', // channel name
          channelDescription: 'This channel is for foreground messages',
          importance: Importance.max,
          priority: Priority.high,
        );
        const NotificationDetails platformDetails =
            NotificationDetails(android: androidDetails);

        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          platformDetails,
        );
      }
    });

    // TODO: Send token to Django backend for customers
  }
}
