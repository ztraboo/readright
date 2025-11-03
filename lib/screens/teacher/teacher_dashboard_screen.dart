import 'package:flutter/material.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Temporary student data
    final students = [
      {'name': 'Alice Johnson', 'progress': 0.85},
      {'name': 'Ben Carter', 'progress': 0.62},
      {'name': 'Chloe Davis', 'progress': 0.45},
      {'name': 'David Kim', 'progress': 0.90},
      {'name': 'Ella Brown', 'progress': 0.25},
    ];

    // Temporary class data
    final double classAverage = 68.7;
    final List<String> topStruggledWords = ['the', 'and', 'play'];
    final String classCode = 'ENG101-AB';
    final int wordCount = 42;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.info_outline), text: 'Class Details'),
            ],
          ),
        ),

        // Main content
        body: TabBarView(
          children: [
            // ---------------- Students Tab ----------------
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Students',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Add Student',
                        onPressed: () {
                          // Add Functionality
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search + Sort Row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 55,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search students...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            onChanged: null, // placeholder
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Sort Icon (Dropdown placeholder)
                      IconButton(
                        icon: const Icon(Icons.sort),
                        tooltip: 'Sort Options',
                        onPressed: () {
                          showMenu(
                            context: context,
                            position: const RelativeRect.fromLTRB(200, 100, 0, 0),
                            items: const [
                              PopupMenuItem(
                                value: 'name',
                                child: Text('Sort by Name'),
                              ),
                              PopupMenuItem(
                                value: 'time',
                                child: Text('Sort by Time Completed'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Student List
                  Expanded(
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        final name = student['name'] as String;
                        final progress = student['progress'] as double;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(10),
                                  backgroundColor: Colors.grey[300],
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 4),
                                Text('${(progress * 100).toStringAsFixed(0)}% complete'),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.pushNamed(context, '/class-student-details');
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ---------------- Class Details Tab ----------------
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Class Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24, thickness: 1),

                  // Class Average
                  const Text(
                    'Class Average',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${classAverage.toStringAsFixed(1)}%'),
                  const Divider(height: 32, thickness: 1),

                  // Top Struggled Words
                  const Text(
                    'Top Struggled Words',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: topStruggledWords
                        .map((word) => Text('• $word'))
                        .toList(),
                  ),
                  const Divider(height: 32, thickness: 1),

                  // Class Code
                  const Text(
                    'Class Code',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(classCode),
                  const Divider(height: 32, thickness: 1),

                  // Word Count
                  const Text(
                    'Number of Words in Class List',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('$wordCount words'),
                ],
              ),
            ),
          ],
        ),

        // Floating button that stays at the bottom across tabs
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: SizedBox(
          width: 280,
          height: 50,
          child: FloatingActionButton.extended(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Colors.black87,
            elevation: 2,
            onPressed: () {
              Navigator.pushNamed(context, '/teacher-word-dashboard');
            },
            icon: const Icon(Icons.book),
            label: const Text(
              'Go to Word Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              
            ),
          ),
        ),
      ),
    );
  }
}
