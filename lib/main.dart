import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/ride_screen.dart';

void main() {
  runApp(const ProviderScope(child: WattsonApp()));
}

class WattsonApp extends StatelessWidget {
  const WattsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wattson',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      home: const RideScreen(),
    );
  }
}
