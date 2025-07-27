import 'package:flutter/material.dart';

class ExportContent extends StatelessWidget {
  const ExportContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.print, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'หน้า Export',
            style: TextStyle(fontSize: 24),
          ),
        ],
      ),
    );
  }
}
