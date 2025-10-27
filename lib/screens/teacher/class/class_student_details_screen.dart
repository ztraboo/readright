import 'package:flutter/material.dart';

class ClassStudentDetails extends StatelessWidget {
  const ClassStudentDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
      ),
      body: Center(
        // details should describe the student clicked on from class_dashboard
        child: Text(
          "Details/analytics for Student 1 here"
        )
      ),
    );
  }
}