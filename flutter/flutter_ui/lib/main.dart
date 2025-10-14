// main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'dart:io'; // <-- ADDED THIS IMPORT

// ✅ Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'login_function/login_customer.dart';
import 'role_views/admin_view.dart';
import 'role_views/manager_view.dart';
import 'role_views/cashier_view.dart';
import 'role_views/staff_view.dart';
import 'role_views/customer_view.dart';
import 'role_views/customer_features/cart_service.dart';

// ✅ Custom class to handle SSL certificate validation on Android
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
          host == 'aaron.pythonanywhere.com';
  }
}
// <-- END OF ADDED CODE

// ✅ Define a channel for Android notifications
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.', // description
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ Background notification handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

// ✅ New function to handle permissions and foreground notifications
void setupFirebaseMessaging() async {
  // 1. Request notification permissions
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  // 2. Create the Android notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 3. Handle foreground notifications
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
// END OF NEW CODE -->

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = MyHttpOverrides(); // <-- ADDED THIS LINE

  // ✅ Initialize Firebase before running app
  await Firebase.initializeApp();

  // ✅ Set up FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Call the new setup function
  setupFirebaseMessaging(); 

  final startScreen = await _getStartScreen();

  runApp(
    ChangeNotifierProvider(
      create: (context) => CartService(),
      child: MyApp(startScreen),
    ),
  );
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
        if (staffId != null) return ManagerView(staffId: staffId);
        break;
      case 'cashier':
        if (staffId != null) return CashierView(staffId: staffId);
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
    // ⬇️ START OF THE FIX ⬇️
    return MediaQuery(
      // 1. Get the current system's media settings
      data: MediaQuery.of(context).copyWith(
        // 2. Set textScaleFactor to 1.0 to disable system font scaling
        textScaleFactor: 1.0,
      ),
      // 3. Apply the modified settings to the MaterialApp and the whole app
      child: MaterialApp(
        title: 'Capstone App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: startScreen,
      ),
    );
    // ⬆️ END OF THE FIX ⬆️
  }
}