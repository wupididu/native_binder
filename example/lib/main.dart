import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const NativeBinderExampleApp());
}

class NativeBinderExampleApp extends StatelessWidget {
  const NativeBinderExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Binder Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
