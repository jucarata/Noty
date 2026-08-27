import 'package:flutter/material.dart';
import 'package:noty/core/widgets/noty_logo.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NotyLogo(),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () {},
                child: const Text('Compartir este dispositivo'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Añadir un dispositivo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
