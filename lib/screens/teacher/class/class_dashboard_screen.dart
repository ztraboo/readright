import 'package:flutter/material.dart';
//No longer needed?
class ClassDashboard extends StatelessWidget {
  const ClassDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    //Temp Place Holder - Test Data
    final className = '[Enter Class Name]';

    //Temp Place Holder - Test Data
    final students = [
      {'name': 'Alice Johnson', 'progress': 0.85},
      {'name': 'Ben Carter', 'progress': 0.62},
      {'name': 'Chloe Davis', 'progress': 0.45},
      {'name': 'David Kim', 'progress': 0.90},
      {'name': 'Ella Brown', 'progress': 0.25},
    ];

    //Temp Place Holder - Test Data
    final words = [
      {'word': 'cat', 'category': 'Phonics Pattern'},
      {'word': 'dog', 'category': 'Phonics Pattern'},
      {'word': 'the', 'category': 'Sight Words'},
      {'word': 'and', 'category': 'Sight Words'},
      {'word': 'play', 'category': 'Phonics Pattern'},
    ];
    //Add tabs to screen
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          //Temp?
          title: Text(className),
          //Tab Bar
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.book), text: 'Class Words'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Students tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      //Student Tab
                      const Text(
                        'Students',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      //Dropdown - add more choice later
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: 'All',
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All'),
                              ),
                            ],
                            //Add Functionality
                            onChanged: null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      //Add Student
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Add Class',
                        onPressed: () {
                          //Add Functionality
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      //Temp?
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        //Temp?
                        final student = students[index];
                        final name = student['name'] as String;
                        final progress = student['progress'] as double;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            //Temp?
                            title: Text(name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                //Progress Bar
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(10),
                                  backgroundColor: Colors.grey[300],
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}% complete',
                                ),
                              ],
                            ),
                            //Go to Student Details
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/class-student-details',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Class Words tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  //Search List of Words
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search words...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    //Add functionality later
                    onChanged: null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      //Filter
                      const Text(
                        'Filter by category:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 16),
                      //Dropdown --- edit values later
                      DropdownButton<String>(
                        value: 'All',
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(
                            value: 'Sight Words',
                            child: Text('Sight Words'),
                          ),
                          DropdownMenuItem(
                            value: 'Phonics Pattern',
                            child: Text('Phonics Pattern'),
                          ),
                        ],
                        //Add functionality later
                        onChanged: null,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.control_point_outlined),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/teacher-word-dashboard',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    //List of words
                    child: ListView.builder(
                      //Temp?
                      itemCount: words.length,
                      itemBuilder: (context, index) {
                        final wordItem = words[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            //Enable words for class
                            leading: const Checkbox(
                              value: false,
                              onChanged: null,
                            ),
                            title: Text(wordItem['word'] ?? 'N/A'),
                            subtitle: Text(wordItem['category'] ?? 'N/A'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
