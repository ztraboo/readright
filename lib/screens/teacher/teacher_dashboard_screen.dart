import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'class/class_student_details_screen.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  // Hardcoded teacher UID for now
  final String teacherUid = 'u002';

  Future<List<Map<String, dynamic>>> fetchStudents() async {
    final classSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherid', isEqualTo: teacherUid)
        .get();

    if (classSnapshot.docs.isEmpty) return [];

    final classData = classSnapshot.docs.first.data();
    final totalWords = classData['totalWords'] ?? 0;

    final studentUids = <String>[];
    if (classData.containsKey('students')) {
      final studentsList = List<String>.from(classData['students']);
      studentUids.addAll(studentsList);
    }

    if (studentUids.isEmpty) return [];

    final studentSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('uid', whereIn: studentUids)
        .get();

    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', whereIn: studentUids)
        .get();

    final uidToName = {
      for (var doc in userSnapshot.docs) doc.data()['uid']: doc.data()['displayName']
    };

    return studentSnapshot.docs.map((doc) {
      final data = doc.data();
      final uid = data['uid'] ?? '';
      return {
        'uid': uid,
        'displayName': uidToName[uid] ?? 'No Name',
        'completed': data['completed'] ?? 0,
        'totalWords': totalWords,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> fetchClassDetails() async {
    final classSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherid', isEqualTo: teacherUid)
        .limit(1)
        .get();

    if (classSnapshot.docs.isEmpty) return {};

    final data = classSnapshot.docs.first.data();
    return {
      'classAverage': data['classAverage'] ?? 0.0,
      'topStruggledWords': List<String>.from(data['topStruggledWords'] ?? []),
      'classCode': data['classCode'] ?? '',
      'totalWords': data['totalWords'] ?? 0,
      'teacherId': data['teacherid'] ?? '',
    };
  }

  Future<String> fetchTeacherName(String teacherId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: teacherId)
        .limit(1)
        .get();
    if (doc.docs.isEmpty) return 'Unknown';
    return doc.docs.first.data()['displayName'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.info), text: 'Class Details'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Students Tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search + Sort
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search students...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.sort),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Student List
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: fetchStudents(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        final students = snapshot.data ?? [];
                        if (students.isEmpty) {
                          return const Center(child: Text('No students found.'));
                        }
                        return ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final completed = student['completed'] ?? 0;
                            final totalWords = student['totalWords'] ?? 0;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                title: Text(student['displayName']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Words completed: $completed/$totalWords'),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: totalWords == 0 ? 0 : completed / totalWords,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[300],
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClassStudentDetails(studentUid: student['uid']),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Class Details Tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<Map<String, dynamic>>(
                future: fetchClassDetails(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final classData = snapshot.data ?? {};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Teacher at top
                      FutureBuilder<String>(
                        future: fetchTeacherName(classData['teacherId'] ?? ''),
                        builder: (context, teacherSnapshot) {
                          final teacherName = teacherSnapshot.data ?? 'Loading...';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teacher',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(teacherName),
                              const Divider(height: 32, thickness: 1),
                            ],
                          );
                        },
                      ),

                      // Class Code
                      Text(
                        'Class Code',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(classData['classCode'] ?? ''),
                      const Divider(height: 32, thickness: 1),

                      // Total Words
                      Text(
                        'Total Words',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('${classData['totalWords'] ?? 0}'),
                      const Divider(height: 32, thickness: 1),

                      // Class Average
                      Text(
                        'Class Average',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('${classData['classAverage'] ?? 0}%'),
                      const Divider(height: 32, thickness: 1),

                      // Top Struggled Words
                      Text(
                        'Top Struggled Words',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (classData['topStruggledWords'] ?? [])
                            .map<Widget>((w) => Text('• $w'))
                            .toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, '/teacher-word-dashboard');
          },
          icon: const Icon(Icons.book),
          label: const Text('Word Dashboard'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
