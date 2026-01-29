import 'package:flutter/material.dart';
import '../components/tr.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Tr('Learn')),
      body: Center(child: Tr('Education Hub coming soon!')),
    );
  }
}
