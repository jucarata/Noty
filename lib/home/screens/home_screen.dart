import 'package:flutter/material.dart';
import 'package:noty/core/widgets/noty_logo.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NotyLogo(),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () {},
                child: const Text('Vincular dispositivo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
