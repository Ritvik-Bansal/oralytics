import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:oralytics/firebase_options.dart';
import 'package:oralytics/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: AuthScreen());
  }
}
