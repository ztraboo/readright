import 'package:flutter/material.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
      ),
      body: Center(
        // list of classes associated with whatever teacher will determine
        // how many buttons here and what they're called
        child: Column(
          children: [
            Text("Maybe overall statistics here?"),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, "/class-dashboard");
              }, child: Text("Class 1"),
            ),
          ],
        ),
      ),
    );
  }
}