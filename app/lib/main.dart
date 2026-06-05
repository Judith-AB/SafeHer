import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:safeher/theme.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      print("Successfully signed in anonymously!");
    } else {
      print("User already signed in: ${currentUser.uid}");
    }
  } catch (e) {
    print("Error signing in anonymously: $e");
  }
  runApp(const SafeHerApp());
}

class SafeHerApp extends StatelessWidget {
  const SafeHerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeHer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
