import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title; final String description;
  const PlaceholderScreen({super.key, required this.title, required this.description});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)), title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.construction, size: 56, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(description, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
          ]),
        ),
      ),
    );
  }
}
