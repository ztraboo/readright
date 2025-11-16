import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassStudentDetails extends StatelessWidget {
  final String studentUid;

  const ClassStudentDetails({super.key, required this.studentUid});

  Future<Map<String, dynamic>> fetchStudentData() async {
    // Fetch student document
    final studentDoc = await FirebaseFirestore.instance
        .collection('student.progress')
        .where('uid', isEqualTo: studentUid)
        .limit(1)
        .get();

    if (studentDoc.docs.isEmpty) return {};

    final studentData = studentDoc.docs.first.data();

    // Fetch displayName from users collection
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: studentUid)
        .limit(1)
        .get();

    final displayName = userDoc.docs.isNotEmpty
        ? userDoc.docs.first.data()['displayName'] ?? 'No Name'
        : 'No Name';

    // Fetch class info
    final classDoc = await FirebaseFirestore.instance
        .collection('classes')
        .where('students', arrayContains: studentUid)
        .limit(1)
        .get();

    final classData = classDoc.docs.isNotEmpty ? classDoc.docs.first.data() : {};

    return {
      'displayName': displayName,
      'completed': studentData['completed'] ?? 0,
      'totalAttempts': studentData['totalAttempts'] ?? 0,
      'averageScore': studentData['averageScore'] ?? 0.0,
      'topStruggledWords':
          List<String>.from(studentData['topStruggled'] ?? []),
      'totalWords': classData['totalWords'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchStudentData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data ?? {};
          final displayName = data['displayName'] ?? 'No Name';
          final completed = data['completed'] ?? 0;
          final totalWords = data['totalWords'] ?? 0;
          final averageScore = data['averageScore'] ?? 0.0;
          final totalAttempts = data['totalAttempts'] ?? 0;
          final topStruggledWords = data['topStruggledWords'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Name
                Text(
                  displayName,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Progress Section
                Text('Words completed: $completed / $totalWords'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: totalWords == 0 ? 0 : completed / totalWords,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  color: Colors.green,
                ),
                const Divider(height: 32, thickness: 1),

                // Averages Section
                const Text('Averages',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Average Score: $averageScore%'),
                const Divider(height: 32, thickness: 1),

                // Attempts Section
                const Text('Attempts',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Total Attempts: $totalAttempts'),
                const Divider(height: 32, thickness: 1),

                // Top Struggled Words
                const Text('Top Struggled Words',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      topStruggledWords.map<Widget>((w) => Text('• $w')).toList(),
                ),
                const Divider(height: 32, thickness: 1),

                // Audio Retention Checkbox
                Row(
                  children: const [
                    Checkbox(value: false, onChanged: null),
                    SizedBox(width: 8),
                    Text('Enable Audio Retention'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
