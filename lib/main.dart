import 'package:flutter/material.dart';

void main() {
  runApp(const CallBreakPlusMinusApp());
}

class CallBreakPlusMinusApp extends StatelessWidget {
  const CallBreakPlusMinusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Break Plus/Minus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Text(
            'Call Break Plus/Minus\n\n'
            'Phase 1 game engine is installed.\n'
            'Gameplay UI comes in Phase 2.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
