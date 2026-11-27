import 'package:fixer/features/results/presentation/results_panel.dart';
import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RESULTS')),
      body: const ResultsPanel(),
    );
  }
}
