import 'package:flutter/material.dart';

class ClassDashboard extends StatelessWidget {
  const ClassDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Text should be adopted to whatever class was clicked
        title: const Text('Class Dashboard'),
      ),
      body: Center(
        // list of students associated with whatever class will determine
        // how many buttons here and what they're named
        child: Column(
          children: [
            Text("Class 1 details/analytics here"),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, "/class-student-details");
              }, child: Text("Student 1"),
            ),
          ],
        ),
      ),
    );
  }
}