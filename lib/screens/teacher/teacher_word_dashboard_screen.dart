//import 'package:flutter/material.dart';
//import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherWordDashboardPage extends StatefulWidget {
  const TeacherWordDashboardPage({super.key});

  @override
  State<TeacherWordDashboardPage> createState() =>
      _TeacherWordDashboardPageState();
}

// Colors for Tags
class _TeacherWordDashboardPageState extends State<TeacherWordDashboardPage> {
  final List<Color> levelColors = const [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  final Map<String, Color> _levelColorMap = {};

  //Map Colors
  Color getLevelColor(String level) {
    if (_levelColorMap.containsKey(level)) return _levelColorMap[level]!;
    final color = levelColors[_levelColorMap.length % levelColors.length];
    _levelColorMap[level] = color;
    return color;
  }

  // Delcare Variables for UI
  String _searchText = '';
  String _selectedLevel = 'All';
  String _selectedSort = 'A-Z';

  final List<String> sortOptions = ['A-Z', 'Z-A'];

  // Level order for badges
  final List<String> customLevelOrder = [
    'Pre-Primer',
    'Primer',
    'First Grade',
    'Second Grade',
    'Third Grade',
    'Fourth Grade',
    'Fifth Grade',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Word Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search Field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search words',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
            const SizedBox(height: 8),
            // Filter & Sort Row
            Row(
              children: [
                // Level Filter
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('words')
                        .snapshots(),
                    builder: (context, snapshot) {
                      List<String> levels = ['All'];
                      if (snapshot.hasData) {
                        levels.addAll(
                          snapshot.data!.docs
                              .map(
                                (doc) =>
                                    (doc.data()
                                            as Map<String, dynamic>)['level']
                                        .toString(),
                              )
                              .toSet()
                              .toList()
                            ..sort((a, b) {
                              final indexA = customLevelOrder.indexOf(a);
                              final indexB = customLevelOrder.indexOf(b);
                              return indexA.compareTo(indexB);
                            }),
                        );
                      }
                      if (!levels.contains(_selectedLevel)) {
                        _selectedLevel = 'All';
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedLevel,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Level',
                          border: OutlineInputBorder(),
                        ),
                        items: levels
                            .map(
                              (level) => DropdownMenuItem(
                                value: level,
                                child: Text(level),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLevel = value ?? 'All';
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Sort Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSort,
                    decoration: const InputDecoration(
                      labelText: 'Sort',
                      border: OutlineInputBorder(),
                    ),
                    items: sortOptions
                        .map(
                          (sort) =>
                              DropdownMenuItem(value: sort, child: Text(sort)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSort = value ?? 'A-Z';
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Word List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('words')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Convert snapshot to list of maps
                  List<Map<String, dynamic>> allWords = snapshot.data!.docs.map(
                    (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      return data;
                    },
                  ).toList();

                  // Apply search & level filter
                  List<Map<String, dynamic>> filteredWords = allWords.where((
                    word,
                  ) {
                    final matchesSearch = word['text']
                        .toString()
                        .toLowerCase()
                        .contains(_searchText.toLowerCase());
                    final matchesLevel =
                        _selectedLevel == 'All' ||
                        word['level'] == _selectedLevel;
                    return matchesSearch && matchesLevel;
                  }).toList();

                  // Apply sorting
                  filteredWords.sort((a, b) {
                    final textA = a['text'].toString().toLowerCase();
                    final textB = b['text'].toString().toLowerCase();
                    return _selectedSort == 'A-Z'
                        ? textA.compareTo(textB)
                        : textB.compareTo(textA);
                  });

                  if (filteredWords.isEmpty) {
                    return const Center(
                      child: Text('No words match your filter.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredWords.length,
                    itemBuilder: (context, index) {
                      final word = filteredWords[index];
                      final text = word['text'] ?? '';
                      final level = word['level'] ?? '';
                      final sentences = List<String>.from(
                        word['sentences'] ?? [],
                      );

                      //Make Cards
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),

                        //Card Expands
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          childrenPadding:
                              EdgeInsets.zero, // remove default padding
                          title: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Level
                                  const Text(
                                    'Level:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getLevelColor(level),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      level,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Example Sentences
                                  const Text(
                                    'Example Sentences:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Bullet point sentences
                                  for (var sentence in sentences)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '• ',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          Expanded(
                                            child: Text(
                                              sentence,
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
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
    );
  }
}

// Old Code - Reading CSV
// class CsvWord {
//   final String word;
//   final String category;
//   final int levelOrder;
//   final List<String> sentences;

//   CsvWord({
//     required this.word,
//     required this.category,
//     this.levelOrder = 0,
//     required this.sentences,
//   });

//   @override
//   String toString (){
//     return 'word: $word\ncategory: $category\n${sentences.join("\n")}';
//   }
// }

// // extract only the words from seed_worlds.csv
// Future <List<String>> loadWords() async {
//   final words = await rootBundle.loadString('data/seed_words.csv');
//   final lines = words.split('\n');
//   return lines.skip(1).map((line) => line.split(',')[0].trim()).toList();
// }

// // extract the full csv into Map<word, CsvWord with details>
// Future<Map<String, CsvWord>> loadCsv() async {
//   final csv = await rootBundle.loadString('data/seed_words.csv');
//   final lines = csv.split('\n');
//   final Map<String, CsvWord> wordMap = {};

//   for (var line in lines.skip(1)) {
//     final pieces = _splitCsv(line);
//     // Expect at least: Word, Category, LevelOrder
//     if (pieces.length < 3) continue;

//     final word = pieces[0].trim();
//     final category = pieces[1].trim();
//     final levelOrder = int.tryParse(pieces[2].trim()) ?? 0;
//     final sentences = pieces.length > 3 ? pieces.sublist(3).map((s) => s.trim()).toList() : <String>[];

//     wordMap[word] = CsvWord(
//       word: word,
//       category: category,
//       levelOrder: levelOrder,
//       sentences: sentences,
//     );
//   }
//   return wordMap;
// }

// List<String> _splitCsv(String line) {
//   // via Microsoft CoPilot:
//   final regex = RegExp(r'''((?:[^,"']|"[^"]*"|'[^']*')+)''');
//   return regex.allMatches(line).map((m) => m.group(0)!.replaceAll('"', '')).toList();
// }

// class TeacherWordDashboardPage extends StatefulWidget {
//   const TeacherWordDashboardPage({super.key});

//   @override
//   State<TeacherWordDashboardPage> createState() => _TeacherWordDashboardPage();
// }

// class _TeacherWordDashboardPage extends State<TeacherWordDashboardPage> {
//   int? expandedIndex;
//   int? editingIndex;

//   final Map<String, TextEditingController> sentenceControllers = {};
//   final TextEditingController categoryController = TextEditingController();

//   Map<String, bool> switchStates = {};

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFCBE2F9),
//       appBar: AppBar(
//         title: const Text('Word Dashboard'),
//         backgroundColor: const Color(0xFFF88843),
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'seed_words.csv',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     // todo: add csv picker logic if/a
//                   },
//                   child: const Text('Add CSV'),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: FutureBuilder<Map<String, CsvWord>>(
//               future: loadCsv(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 } else if (snapshot.hasError) {
//                   return Center(child: Text('Error: ${snapshot.error}'));
//                 } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return const Center(child: Text('Words list is empty'));
//                 }

//                 final wordMap = snapshot.data!;
//                 final words = wordMap.keys.toList();

//                 return ListView.builder(
//                   itemCount: words.length,
//                   itemBuilder: (context, index) {
//                     final word = words[index];
//                     final entry = wordMap[word]!;
//                     final isExpanded = expandedIndex == index;
//                     final isEditing = editingIndex == index;

//                     return Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         ListTile(
//                           leading: Switch(
//                             value: switchStates[word] ?? false,
//                             onChanged: (val) {
//                               // TODO: Add logic later
//                               setState(() {
//                                 switchStates[word] = val;
//                               });
//                             },
//                           ),
//                           title: Text(word),
//                           trailing: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               IconButton(
//                                 icon: Icon(isEditing ? Icons.check : Icons.edit),
//                                 onPressed: () {
//                                   // todo: add writing logic to stored csv
//                                   setState(() {
//                                     if (isEditing) {
//                                       editingIndex = null;
//                                     } else {
//                                       categoryController.text = entry.category;
//                                       for (int i = 0; i < entry.sentences.length; i++) {
//                                         sentenceControllers['$word-$i'] ??= TextEditingController(text: entry.sentences[i]);
//                                       }
//                                       editingIndex = index;
//                                     }
//                                   });
//                                 },
//                               ),
//                               IconButton(
//                                 icon: const Icon(Icons.delete),
//                                 onPressed: () {
//                                   // todo: add delete logic
//                                   debugPrint('Delete ${entry.word}');
//                                 },
//                               ),
//                             ],
//                           ),

//                           onTap: () {
//                             setState(() {
//                               expandedIndex = isExpanded ? null : index;
//                             });
//                           },
//                         ),
//                         if (isExpanded)
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                             child: Container(
//                               width: double.infinity,
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: isEditing
//                                   ? Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   TextField(
//                                     controller: categoryController,
//                                     decoration: const InputDecoration(labelText: 'Category'),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   for (int i = 0; i < entry.sentences.length; i++)
//                                     TextField(
//                                       controller: sentenceControllers['$word-$i'],
//                                       decoration: InputDecoration(labelText: 'Sentence ${i + 1}'),
//                                     ),
//                                 ],
//                               )
//                                   : Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text('Category: ${entry.category}'),
//                                   const SizedBox(height: 8),
//                                   ...entry.sentences.map((s) => Padding(
//                                     padding: const EdgeInsets.only(bottom: 4),
//                                     child: Text('- $s'),
//                                   )),
//                                 ],
//                               ),
//                             ),
//                           ),
//                       ],
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
