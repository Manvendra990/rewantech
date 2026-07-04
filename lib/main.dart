import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rtstrack/dashboard_guide.dart';
import 'package:rtstrack/project_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(); // google-services.json se auto-config hoga
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RTSTrack',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    setState(() {
      _uid = uid;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_uid != null && _uid!.isNotEmpty) {
      return const DashboardGridScreen();
    }
    return const LoginPage();
  }
}
