import 'package:flutter/material.dart';
import '../core/theme.dart';

class MyAttendanceScreen extends StatelessWidget {
  const MyAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('My Attendance', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🕐', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              Text(
                'Teacher Self-Attendance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              SizedBox(height: 8),
              Text(
                'Sign-in / sign-out tracking and monthly attendance history coming soon.',
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
