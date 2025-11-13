import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'auth/login_screen.dart';
import 'home/main_screen.dart';

// -------------------- Local notifications setup --------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  debugPrint('🔔 Background message received: ${message.data}');
  _showLocalNotification(message);
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  final android = message.notification?.android;

  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'smartcollar_channel',
          'SmartCollar Notifications',
          channelDescription: 'Channel for SmartCollar alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  }
}

// -------------------- Main --------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  bool firebaseInitialized = false;
  try {
    Firebase.app();
    firebaseInitialized = true;
  } catch (_) {
    firebaseInitialized = false;
  }

  if (!firebaseInitialized) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (!errorString.contains('duplicate-app') &&
          !errorString.contains('already exists') &&
          !errorString.contains('[core/duplicate-app]')) {
        rethrow;
      }
    }
  }

  // Initialize local notifications
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  // Initialize Firebase Messaging
  await _initializeFirebaseMessaging();

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const SmartCollarApp());
}

// -------------------- Firebase Messaging Initialization --------------------
Future<void> _initializeFirebaseMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final notificationStatus = await _requestNotificationPermissions();
    debugPrint('🔔 Notification permission status: $notificationStatus');

    // Enable auto init
    await messaging.setAutoInitEnabled(true);

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Foreground message: ${message.data}');
      _showLocalNotification(message);
    });

    // Listen when a user taps a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Notification tapped: ${message.data}');
    });
  } catch (e) {
    debugPrint('Error initializing Firebase Messaging: $e');
  }
}

Future<AuthorizationStatus> _requestNotificationPermissions() async {
  final messaging = FirebaseMessaging.instance;

  final notificationSettings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
  );

  final iosImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  await iosImplementation?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
    critical: false,
  );

  return notificationSettings.authorizationStatus;
}

// -------------------- App --------------------
class SmartCollarApp extends StatelessWidget {
  const SmartCollarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartCollar',
      theme: ThemeData(primarySwatch: Colors.pink),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Map<String, dynamic>?> _getFirstPet(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("pets")
        .orderBy("createdAt")
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return {"id": doc.id, "data": doc.data()};
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final uid = snapshot.data!.uid;
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getFirstPet(uid),
            builder: (context, petSnapshot) {
              if (petSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final firstPet = petSnapshot.data;
              if (firstPet != null) {
                return MainScreen(
                  selectedPet: firstPet['data'],
                  petId: firstPet['id'],
                );
              } else {
                return const MainScreen(selectedPet: null, petId: null);
              }
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}
