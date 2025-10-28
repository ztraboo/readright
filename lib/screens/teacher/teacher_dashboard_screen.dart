import 'package:flutter/material.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    //Temp - used for visual example
    final List<String> classes = [
      'English 101',
      'English 102',
      'Lit and Lang',
      'Advanced Reading',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Classes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                //Add class
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Class',
                  onPressed: () {
                    //Add Functionality
                  },
                ),
              ],
            ),
          ),

          Expanded(
            //List of classes
            child: ListView.builder(
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final className = classes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(className),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pushNamed(context, '/class-dashboard');
                    },
                  ),
                );
              },
            ),
          ),

          //Button to access Teacher Word Dashboard
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/teacher-word-dashboard');
                },
                icon: const Icon(Icons.book),
                label: const Text('Go to Word Dashboard'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
