// main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io'; 

// ✅ Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 🔄 CHANGE THIS: Replace with your actual staff login file path
import 'login_function/login_staff.dart'; 

import 'role_views/admin_view.dart';
import 'role_views/manager_view.dart';
import 'role_views/cashier_view.dart';
import 'role_views/staff_view.dart';

// 🛑 REMOVED: customer_view.dart, login_customer.dart, and cart_service.dart imports

// ✅ Custom class to handle SSL certificate validation on Android
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
          host == 'aaron.pythonanywhere.com';
  }
}

// ✅ Define a channel for Android notifications
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 
  'High Importance Notifications', 
  description: 'This channel is used for important notifications.', 
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ Background notification handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

// ✅ Handle permissions and foreground notifications
void setupFirebaseMessaging() async {
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: 'launch_background',
          ),
        ),
      );
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = MyHttpOverrides(); 

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  setupFirebaseMessaging(); 

  final startScreen = await _getStartScreen();

  runApp(
    // 🛑 REMOVED: ChangeNotifierProvider since CartService is no longer needed
    MyApp(startScreen),
  );
}

Future<Widget> _getStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final role = prefs.getString('role');
  final staffId = prefs.getInt('staff_id');

  // 🛑 REMOVED: customerId tracking from logs and preferences
  print('SharedPref: is_logged_in=$isLoggedIn, role=$role, staff_id=$staffId');

  if (isLoggedIn && role != null) {
    switch (role) {
      case 'admin':
        if (staffId != null) return AdminView(staffId: staffId);
        break;
      case 'manager':
        if (staffId != null) return ManagerView(staffId: staffId);
        break;
      case 'cashier':
        if (staffId != null) return CashierView(staffId: staffId);
        break;
      case 'staff':
        if (staffId != null) return StaffView(staffId: staffId);
        break;
      // 🛑 REMOVED: case 'customer' block entirely
    }
  }

  // 🛑 CHANGED: Default fallback screen. 
  // It now routes directly to your Staff Login view if not logged in.
  return const LoginStaff(); 
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp(this.startScreen, {super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: MaterialApp(
        title: 'Capstone App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: startScreen,
      ),
    );
  }
}