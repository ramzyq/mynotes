import 'package:flutter/material.dart';
import 'package:mynotes/app.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppErrorHandler().init();
  runApp(const MyApp());
}
