import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportStudentProgress({required String teacherUid}) async {
  if (teacherUid.isEmpty) return;

  // Fetch the class for this teacher
  final classSnapshot = await FirebaseFirestore.instance
      .collection('classes')
      .where('teacherId', isEqualTo: teacherUid)
      .limit(1)
      .get();

  if (classSnapshot.docs.isEmpty) return;

  final classData = classSnapshot.docs.first.data();
  final studentUids = List<String>.from(classData['students'] ?? []);

  if (studentUids.isEmpty) return;

  // Fetch student names
  final userSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('id', whereIn: studentUids)
      .get();

  final uidToName = {
    for (var doc in userSnapshot.docs) doc.data()['id']: doc.data()['fullName'],
  };

  // CSV header
  List<List<dynamic>> rows = [
    ['Name', 'Word', 'Word Transcript', 'Accuracy', 'Correct?', 'Date'],
  ];

  // Fetch each student's progress
  for (String uid in studentUids) {
    final progressSnapshot = await FirebaseFirestore.instance
        .collection('student.progress')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (progressSnapshot.docs.isEmpty) continue;

    final progressData = progressSnapshot.docs.first.data();
    final attemptsList = List<String>.from(progressData['attempts'] ?? []);

    for (var attemptId in attemptsList) {
      final attemptDoc = await FirebaseFirestore.instance
          .collection('attempts')
          .doc(attemptId)
          .get();

      if (!attemptDoc.exists) continue;

      final attemptData = attemptDoc.data()!;
      final word = attemptData['wordId'] ?? '';
      final transcript = attemptData['speechToTextTranscript'] ?? '';
      final score = (attemptData['score'] ?? 0).toDouble();
      final correct = score > 0.7 ? 'Yes' : 'No';
      final date = attemptData['createdAt'] != null
          ? (attemptData['createdAt'] as Timestamp).toDate().toString()
          : '';

      rows.add([
        uidToName[uid] ?? 'Unknown',
        word,
        transcript,
        score,
        correct,
        date,
      ]);
    }
  }

  // Convert CSV
  final csvData = const ListToCsvConverter().convert(rows);

  // Save CSV to temporary file
  final tempDir = await getTemporaryDirectory();
  final filePath = '${tempDir.path}/student_progress.csv';
  final file = File(filePath);
  await file.writeAsString(csvData);

  // Share CSV
  final xFile = XFile(filePath, name: 'student_progress.csv');

  await SharePlus.instance.share(
    ShareParams(text: 'Student Progress Export', files: [xFile]),
  );
}
