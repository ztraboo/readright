import 'package:flutter/material.dart';

class ClassStudentDetails extends StatelessWidget {
  const ClassStudentDetails({super.key});

  @override
  Widget build(BuildContext context) {
    // Temp placeholder data
    final double averageScore = 78.5;
    final int totalAttempts = 42;
    final List<String> topStruggledWords = ['and', 'the', 'play'];
    final List<String> classes = ['English 101', 'English 102'];
    final int wordsCompleted = 10;
    final int totalWords = 20;

    return Scaffold(
      appBar: AppBar(title: const Text('[Enter Student Name]')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Averages Section
            const Text(
              'Averages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Average Score: $averageScore%'),
            const Divider(height: 32, thickness: 1),

            //Attempts Section
            const Text(
              'Attempts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Total Attempts: $totalAttempts'),
            const Divider(height: 32, thickness: 1),

            //Classes Section
            const Text(
              'Classes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: classes.map((cls) => Text('• $cls')).toList(),
            ),
            const Divider(height: 32, thickness: 1),

            //Progress Section
            const Text(
              'Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('$wordsCompleted / $totalWords words completed'),
            const Divider(height: 32, thickness: 1),

            //Top Struggled Words Section
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

            //Audio Retention Checkbox
            Row(
              children: const [
                Checkbox(
                  value: false,
                  //Add functionality later
                  onChanged: null,
                ),
                SizedBox(width: 8),
                Text('Enable Audio Retention'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
