import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'class/class_student_details_screen.dart';
import '../../models/current_user_model.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/class_repository.dart';
import '../../services/export_student_progress.dart';
import '../../services/student_repository.dart';
import '../../services/user_repository.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  UserModel? _currentUser;
  ClassModel? _classSection;

  // Audio retention state (loaded once)
  bool _audioRetention = false;
  bool _audioRetentionLoaded = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Check for existing user session on initialization
    // If a user is already signed in, we can skip the login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _currentUser = context.read<CurrentUserModel>().user;

        if (_currentUser != null) {
          debugPrint(
            'TeacherDashboardPage: Found existing user session for ${_currentUser?.username}',
          );
        } else {
          debugPrint('TeacherDashboardPage: No existing user session found.');
        } 

        _classSection = context.read<CurrentUserModel>().classSection;

        if (_classSection != null) {
          debugPrint('TeacherDashboardPage: Found existing class section for teacher ${_currentUser?.username}');
        } else {
          debugPrint('TeacherDashboardPage: No existing class section found for teacher ${_currentUser?.username}');
        }
      });
    });
  }

  // Get teacher uid asynchronously
  Future<String> get teacherUid async {
    return _currentUser?.id ?? '';
  }

  // Get students in teacher's class.
  Future<List<Map<String, dynamic>>> fetchStudents() async {

    // Ensure students and classSection are loaded into the CurrentUserModel
    await context.read<CurrentUserModel>().loadStudents();

    if (_classSection?.teacherId.isEmpty ?? true) {
      throw Exception('No teacher is currently signed in.');
    }

    final studentUids = <String>[];
    final studentIds = _classSection?.studentIds ?? [];
    if (studentIds.isNotEmpty) {
      final studentsList = List<String>.from(studentIds);
      studentUids.addAll(studentsList);
    } 

    if (studentUids.isEmpty) {
      return [];
    } 

    // Get student progress
    final studentSnapshot = await FirebaseFirestore.instance
        .collection('student.progress')
        .where('uid', whereIn: studentUids)
        .get();

    // Get student names
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('id', whereIn: studentUids)
        .get();

    // Creates a map from student UID to student name
    final uidToName = {
      for (var doc in userSnapshot.docs)
        doc.data()['id']: doc.data()['fullName'],
    };

    // Combine student progress with names
    return studentSnapshot.docs.map((doc) {
      final data = doc.data();
      final uid = data['uid'] ?? '';
      return {
        'uid': uid,
        'fullName': uidToName[uid] ?? 'No Name',
        'completed': data['completed'] ?? 0,
        'totalWordsToComplete': _classSection?.totalWordsToComplete ?? 0,
      };
    }).toList();
  }

  // Get Class Details
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
      'totalWordsToComplete': data['totalWordsToComplete'] ?? 0,
      'teacherId': data['teacherId'] ?? '',
      'audioRetention': data['audioRetention'] ?? false,
    };
  }

  // Get teacher name
  Future<String> fetchTeacherName(String teacherId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .where('id', isEqualTo: teacherId)
        .limit(1)
        .get();

    if (doc.docs.isEmpty) return 'Unknown';
    return doc.docs.first.data()['fullName'] ?? 'Unknown';
  }

  // Get class ID
  Future<String?> fetchClassId() async {
    final teacher = await teacherUid;
    if (teacher.isEmpty) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('teacherId', isEqualTo: teacher)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return snapshot.docs.first.id;
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
              child: FutureBuilder<Map<String, dynamic>>(
                future: fetchClassDetails(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final classData = snapshot.data!;
                  final classCode = classData['classCode'] ?? '';

                  return FutureBuilder<String?>(
                    future: fetchClassId(),
                    builder: (context, idSnapshot) {
                      if (!idSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final classId = idSnapshot.data ?? '';

                      // Pass class and teacher details to the student tab
                      return StudentsTab(
                        classId: classId,
                        classCode: classCode,
                        teacherUid: classData['teacherId'] ?? '',
                        studentsFuture: fetchStudents(),
                      );
                    },
                  );
                },
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

                  // Load audioRetention
                  if (!_audioRetentionLoaded) {
                    _audioRetention = classData['audioRetention'] ?? false;
                    _audioRetentionLoaded = true;
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Displays teacher name (after retrieving)
                        FutureBuilder<String>(
                          future: fetchTeacherName(
                            classData['teacherId'] ?? '',
                          ),
                          builder: (context, teacherSnapshot) {
                            final teacherName =
                                teacherSnapshot.data ?? 'Loading...';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Teacher',
                                  style: Theme.of(context).textTheme.titleMedium
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(classData['classCode'] ?? ''),
                        const Divider(height: 32, thickness: 1),

                        // Class Average
                        Text(
                          'Class Average',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('${classData['classAverage'] ?? 0}%'),
                        const Divider(height: 32, thickness: 1),

                        // Top Struggled Words
                        Text(
                          'Top Struggled Words',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              (classData['topStruggledWords'] == null ||
                                  (classData['topStruggledWords'] as List)
                                      .isEmpty)
                              ? [const Text('None')]
                              : (classData['topStruggledWords'] as List)
                                    .map<Widget>((w) => Text('• $w'))
                                    .toList(),
                        ),
                        const Divider(height: 32, thickness: 1),
                        const SizedBox(height: 8),

                        // Audio Retention Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Enable Audio Retention:',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Checkbox(
                              value: _audioRetention,
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() {
                                  _audioRetention = value;
                                });
                                final classId = await fetchClassId();
                                if (classId == null) return;
                                await FirebaseFirestore.instance
                                    .collection('classes')
                                    .doc(classId)
                                    .update({'audioRetention': value});
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        const Divider(height: 32, thickness: 1),
                        const SizedBox(height: 8),
                        Text(
                          'Additional Options:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        // Word Dashboard Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.book),
                            label: const Text('Access Word Dashboard'),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/teacher-word-dashboard',
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Export CSV Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text('Export Class Progress to .csv'),
                            onPressed: () {
                              if (_currentUser?.id != null) {
                                exportStudentProgress(
                                  teacherUid: _currentUser!.id!,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Students tab for listing, searching, sorting, and adding students.
class StudentsTab extends StatefulWidget {
  final String classId;
  final String classCode;
  final String teacherUid;
  final Future<List<Map<String, dynamic>>>? studentsFuture;

  const StudentsTab({
    super.key,
    required this.classId,
    required this.classCode,
    required this.teacherUid,
    this.studentsFuture,
  });

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  String searchText = '';
  String sortBy = 'name';
  bool ascending = true;

  // Opens a dialog allowing the teacher to manually create a new student.
  // Uses StudentRepository, which preserves teacher authentication.
  void _showAddStudentDialog(BuildContext context) {
    final parentContext = context;
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final usernameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Student'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                fullNameController.clear();
                emailController.clear();
                usernameController.clear();
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text("Create"),
              onPressed: () async {
                final fullName = fullNameController.text.trim();
                final email = emailController.text.trim();
                final username = usernameController.text.trim();

                // Prevents blank values.
                if (fullName.isEmpty || email.isEmpty || username.isEmpty)
                  return;

                try {
                  // Creates the student without switching authentication.
                  await StudentRepository.registerStudentByTeacherId(
                    username: username,
                    email: email,
                    fullName: fullName,
                    teacherUid: widget.teacherUid,
                  );

                  // Ensures context is still valid before using it.
                  if (!context.mounted) return;
                  
                  // Ask the parent state to re-fetch students and rebuild so the parent's
                  // FutureBuilder calls fetchStudents() again.
                  final parentState =
                    parentContext.findAncestorStateOfType<_TeacherDashboardPageState>();

                  // Reloads students in CurrentUserModel using the parent context (the dialog's context
                  // may not see the same providers / ancestors).
                  await parentContext.read<CurrentUserModel>().loadStudents();

                  // Ensure the StudentsTab state is still mounted before using it or the parent state.
                  if (!mounted) return;

                  if (parentState != null) {
                    // Trigger parent to rebuild so it re-creates the Future passed to the StudentsTab.
                    parentState.setState(() {});
                  }

                  fullNameController.clear();
                  emailController.clear();
                  usernameController.clear();
                  Navigator.pop(context);

                  // Reloads the student list.
                  setState(() {});
                } catch (e) {
                  debugPrint('Error creating student: $e');

                  if (!context.mounted) return;

                  // Shows an error message to the teacher.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create student: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the future passed from parent
    final studentsFuture = widget.studentsFuture;

    return Column(
      children: [
        Row(
          children: [
            // Search field
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
            // Add student button
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Add Student',
              onPressed: () => _showAddStudentDialog(context),
            ),
            const SizedBox(width: 8),
            // Sort
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
            future: studentsFuture,
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
                  .where(
                    (s) => (s['fullName'] as String).toLowerCase().contains(
                      searchText,
                    ),
                  )
                  .toList();

              // Sort
              filteredStudents.sort((a, b) {
                int result;
                if (sortBy == 'name') {
                  result = (a['fullName'] as String).toLowerCase().compareTo(
                    (b['fullName'] as String).toLowerCase(),
                  );
                } else {
                  final aPct = (a['totalWordsToComplete'] == 0)
                      ? 0
                      : (a['completed'] / a['totalWordsToComplete']);
                  final bPct = (b['totalWordsToComplete'] == 0)
                      ? 0
                      : (b['completed'] / b['totalWordsToComplete']);
                  result = aPct.compareTo(bPct);
                }
                return ascending ? result : -result;
              });

              if (filteredStudents.isEmpty) {
                return const Center(child: Text('No students found.'));
              }

              // Student tiles with progress bar
              return ListView.builder(
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = filteredStudents[index];
                  final completed = student['completed'] ?? 0;
                  final totalWordsToComplete = student['totalWordsToComplete'] ?? 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(student['fullName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Words completed: $completed/$totalWordsToComplete'),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: totalWordsToComplete == 0 ? 0 : completed / totalWordsToComplete,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            color: Colors.green,
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        // Navigate to student details screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ClassStudentDetails(studentUid: student['uid']),
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
