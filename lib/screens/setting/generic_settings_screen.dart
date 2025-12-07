import 'package:flutter/material.dart';

class GenericSettingsScreen extends StatelessWidget {
  final String title;
  const GenericSettingsScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              "$title \n(กำลังพัฒนา)", 
              textAlign: TextAlign.center, 
              style: const TextStyle(fontSize: 18, color: Colors.grey)
            ),
          ],
        ),
      ),
    );
  }
}