import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
// import 'package:file_picker/file_picker.dart';
// import 'dart:io';

class CsvWord {
  final String word;
  final String category;
  final List<String> sentences;

  CsvWord({
    required this.word,
    required this.category,
    required this.sentences,
  });

  @override
  String toString (){
    return 'word: $word\ncategory: $category\n${sentences.join("\n")}';
  }
}


// extract only the words from seed_worlds.csv
Future <List<String>> loadWords() async {
  final words = await rootBundle.loadString('data/seed_words.csv');
  final lines = words.split('\n');
  return lines.skip(1).map((line) => line.split(',')[0].trim()).toList();
}

// extract the full csv into Map<word, CsvWord with details>
Future<Map<String, CsvWord>> loadCsv() async {
  final csv = await rootBundle.loadString('data/seed_words.csv');
  final lines = csv.split('\n');
  final Map<String, CsvWord> wordMap = {};

  for (var line in lines.skip(1)) {
    final pieces = _splitCsv(line);
    if (pieces.length < 5) continue;

    final word = pieces[0].trim();
    final category = pieces[1].trim();
    final sentences = pieces.sublist(2).map((s) => s.trim()).toList();

    wordMap[word] = CsvWord(
      word: word,
      category: category,
      sentences: sentences,
    );
  }
  return wordMap;
}


List<String> _splitCsv(String line) {
  // via Microsoft CoPilot:
  final regex = RegExp(r'''((?:[^,"']|"[^"]*"|'[^']*')+)''');
  return regex.allMatches(line).map((m) => m.group(0)!.replaceAll('"', '')).toList();
}

class TeacherWordDashboardPage extends StatefulWidget {
  const TeacherWordDashboardPage({super.key});

  @override
  State<TeacherWordDashboardPage> createState() => _TeacherWordDashboardPage();
}


class _TeacherWordDashboardPage extends State<TeacherWordDashboardPage> {
  int? expandedIndex;
  int? editingIndex;

  final Map<String, TextEditingController> sentenceControllers = {};
  final TextEditingController categoryController = TextEditingController();
  
  Map<String, bool> switchStates = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBE2F9),
      appBar: AppBar(
        title: const Text('Word Dashboard'),
        backgroundColor: const Color(0xFFF88843),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'seed_words.csv',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    // todo: add csv picker logic if/a
                  },
                  child: const Text('Add CSV'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, CsvWord>>(
              future: loadCsv(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Words list is empty'));
                }

                final wordMap = snapshot.data!;
                final words = wordMap.keys.toList();

                return ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final word = words[index];
                    final entry = wordMap[word]!;
                    final isExpanded = expandedIndex == index;
                    final isEditing = editingIndex == index;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Switch(
                            value: switchStates[word] ?? false,
                            onChanged: (val) {
                              // TODO: Add logic later
                              setState(() {
                                switchStates[word] = val;
                              });
                            },
                          ),
                          title: Text(word),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(isEditing ? Icons.check : Icons.edit),
                                onPressed: () {
                                  // todo: add writing logic to stored csv
                                  setState(() {
                                    if (isEditing) {
                                      editingIndex = null;
                                    } else {
                                      categoryController.text = entry.category;
                                      for (int i = 0; i < entry.sentences.length; i++) {
                                        sentenceControllers['$word-$i'] ??= TextEditingController(text: entry.sentences[i]);
                                      }
                                      editingIndex = index;
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  // todo: add delete logic
                                  debugPrint('Delete ${entry.word}');
                                },
                              ),
                            ],
                          ),

                          onTap: () {
                            setState(() {
                              expandedIndex = isExpanded ? null : index;
                            });
                          },
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: isEditing
                                  ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: categoryController,
                                    decoration: const InputDecoration(labelText: 'Category'),
                                  ),
                                  const SizedBox(height: 8),
                                  for (int i = 0; i < entry.sentences.length; i++)
                                    TextField(
                                      controller: sentenceControllers['$word-$i'],
                                      decoration: InputDecoration(labelText: 'Sentence ${i + 1}'),
                                    ),
                                ],
                              )
                                  : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category: ${entry.category}'),
                                  const SizedBox(height: 8),
                                  ...entry.sentences.map((s) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('- $s'),
                                  )),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
