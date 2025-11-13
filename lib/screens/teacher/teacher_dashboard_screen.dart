import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'class/class_student_details_screen.dart';
import '../../services/user_repository.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  // Get teacher uid asynchronously
  Future<String> get teacherUid async {
    final user = await UserRepository().fetchCurrentUser();
    return user?.id ?? '';
  }

  Future<List<Map<String, dynamic>>> fetchStudents() async {
    final teacherUid = await this.teacherUid;

    if (teacherUid.isEmpty) {
      throw Exception('No teacher is currently signed in.');
    }

    final classSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: teacherUid)
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
      for (var doc in userSnapshot.docs)
        doc.data()['uid']: doc.data()['displayName']
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
    final teacherUid = await this.teacherUid;

    final classSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: teacherUid)
        .limit(1)
        .get();

    if (classSnapshot.docs.isEmpty) return {};

    final data = classSnapshot.docs.first.data();
    return {
      'classAverage': data['classAverage'] ?? 0.0,
      'topStruggledWords': List<String>.from(data['topStruggledWords'] ?? []),
      'classCode': data['classCode'] ?? '',
      'totalWords': data['totalWords'] ?? 0,
      'teacherId': data['teacherId'] ?? '',
    };
  }

  Future<String> fetchTeacherName(String teacherId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .where('id', isEqualTo: teacherId)
        .limit(1)
        .get();
    if (doc.docs.isEmpty) return 'Unknown';
    return doc.docs.first.data()['fullName'] ?? 'Unknown';
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
              child: StudentsTab(),
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
                      // Teacher Name
                      FutureBuilder<String>(
                        future: fetchTeacherName(classData['teacherId'] ?? ''),
                        builder: (context, teacherSnapshot) {
                          final teacherName =
                              teacherSnapshot.data ?? 'Loading...';
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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(classData['classCode'] ?? ''),
                      const Divider(height: 32, thickness: 1),

                      // Class Average
                      Text(
                        'Class Average',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('${classData['classAverage'] ?? 0}%'),
                      const Divider(height: 32, thickness: 1),

                      // Top Struggled Words
                      Text(
                        'Top Struggled Words',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
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

/// Students
class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  String searchText = '';
   // default sort by name
  String sortBy = 'name';
  
   // default ascending
  bool ascending = true;

  @override
  Widget build(BuildContext context) {
    final parent =
        context.findAncestorWidgetOfExactType<TeacherDashboardPage>();

    return Column(
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
                onChanged: (value) {
                  setState(() {
                    searchText = value.toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: (value) {
                setState(() {
                  if (value == 'name_asc') {
                    sortBy = 'name';
                    ascending = true;
                  } else if (value == 'name_desc') {
                    sortBy = 'name';
                    ascending = false;
                  } else if (value == 'completion_asc') {
                    sortBy = 'completion';
                    ascending = true;
                  } else if (value == 'completion_desc') {
                    sortBy = 'completion';
                    ascending = false;
                  }
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'name_asc',
                  child: Text('Name A → Z'),
                ),
                const PopupMenuItem(
                  value: 'name_desc',
                  child: Text('Name Z → A'),
                ),
                const PopupMenuItem(
                  value: 'completion_asc',
                  child: Text('Completion Low → High'),
                ),
                const PopupMenuItem(
                  value: 'completion_desc',
                  child: Text('Completion High → Low'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Student List
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: parent?.fetchStudents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final students = snapshot.data ?? [];

              // Filter by search text
              final filteredStudents = students
                  .where((s) => (s['displayName'] as String)
                      .toLowerCase()
                      .contains(searchText))
                  .toList();

              // Sort
              filteredStudents.sort((a, b) {
                int result;
                if (sortBy == 'name') {
                  result = (a['displayName'] as String)
                      .toLowerCase()
                      .compareTo((b['displayName'] as String).toLowerCase());
                } else {
                  final aPct = (a['totalWords'] == 0)
                      ? 0
                      : (a['completed'] / a['totalWords']);
                  final bPct = (b['totalWords'] == 0)
                      ? 0
                      : (b['completed'] / b['totalWords']);
                  result = aPct.compareTo(bPct);
                }
                return ascending ? result : -result;
              });

              if (filteredStudents.isEmpty) {
                return const Center(child: Text('No students found.'));
              }

              return ListView.builder(
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = filteredStudents[index];
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
                            value: totalWords == 0
                                ? 0
                                : completed / totalWords,
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
                            builder: (_) => ClassStudentDetails(
                                studentUid: student['uid']),
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
    );
  }
}
