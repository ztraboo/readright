import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:readright/services/word_respository.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';

import 'package:readright/utils/app_colors.dart';


class ClassStudentDetails extends StatefulWidget {
  final String studentUid;

  const ClassStudentDetails({super.key, required this.studentUid});

  @override
  State<ClassStudentDetails> createState() => _ClassStudentDetailsState();
}

class _ClassStudentDetailsState extends State<ClassStudentDetails> {
  // Word Progress filters
  String _searchText = '';
  String _selectedLevel = 'All';
  String _selectedSort = 'A-Z';

  // Persistent future
  late Future<Map<String, dynamic>> _studentFuture;

  // Per student audio playback
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  // Sort options for dropdown
  final List<String> sortOptions = ['A-Z', 'Z-A'];

  // Custom order used to sort levels consistently
  final List<String> customLevelOrder = [
    'Pre-Primer',
    'Primer',
    'First Grade',
    'Second Grade',
    'Third Grade',
    'Fourth Grade',
    'Fifth Grade',
  ];

  // Colors for each level
  final List<Color> levelColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  // Map Color to Level
  final Map<String, Color> _levelColorMap = {};

  // Returns consistent color per level
  Color getLevelColor(String level) {
    if (_levelColorMap.containsKey(level)) return _levelColorMap[level]!;

    // Assign next color from the list
    final color = levelColors[_levelColorMap.length % levelColors.length];
    _levelColorMap[level] = color;
    return color;
  }

  // Populate and build data for most recent attempt for a given word
  Future<Widget> handlePlayback(String targetWord) async {

    // Fetch Student Information
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('id', isEqualTo: widget.studentUid)
        .limit(1)
        .get();

    // What does this line do?
    final userData = userDoc.docs.isNotEmpty ? userDoc.docs.first.data() : {};


    // Query db for target word details
    final wordDoc = await FirebaseFirestore.instance
        .collection('words')
        .where('text', isEqualTo: targetWord)
        .limit(1)
        .get();

    final wordData =
    wordDoc.docs.isNotEmpty ? wordDoc.docs.first.data() : {};


    // match attempt to target word and user
    final attemptDoc = await FirebaseFirestore.instance
      .collection('attempts')
      .where('userId', isEqualTo: userData['id'])
      .where('wordId', isEqualTo: wordData['id'])
      .orderBy('createdAt', descending: true)
      .limit(1)
      .get();

    final attemptData =
    attemptDoc.docs.isNotEmpty ? attemptDoc.docs.first.data() : {};
    final audioPath = attemptData['audioPath'];


    return Column(
        children: [
          const Text(
            'Last Attempt:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          (audioPath == null)
              ? IconButton(
                  icon: const Icon(Icons.volume_up, size: 24, color: AppColors.bgPrimaryGray),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  onPressed: () async {
                    ScaffoldMessenger.of(context)
                      .showSnackBar(
                        const SnackBar(
                          content: Text('No audio attempt found for this word'),
                          duration: Duration(seconds: 2), // how long it stays visible
                        ),
                      );
                  },
                )
              : IconButton(
                icon: const Icon(Icons.volume_up, size: 24, color: AppColors.buttonSecondaryGreen),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                onPressed: () async {
                  if (audioPath != 'Audio retention is disabled') {
                    await playAudio(audioPath);
                  }
                  else {
                    ScaffoldMessenger.of(context)
                      .showSnackBar(
                        const SnackBar(
                          content: Text('Audio retention was disabled for this attempt'),
                          duration: Duration(seconds: 2), // how long it stays visible
                        ),
                      );
                  }
                },
              ),
          Text(
              attemptData['score'] != null
                  ? 'Score = ${(attemptData['score'] as num).toStringAsFixed(2)}'
                  : 'No attempt',              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )
          )
        ]
    );
  }

  // Use FlutterSoundPlayer to play firestore audio path
  Future<void> playAudio (String audioPath) async {
    final ref = FirebaseStorage.instance.ref().child(audioPath);
    final url = await ref.getDownloadURL();

    debugPrint("audioPath: $audioPath");
    debugPrint("url: $url");

    try {
      await _player.startPlayer(
        fromURI: url,
        codec: Codec.aacMP4,
        whenFinished: () {
          debugPrint("Playback finished (AAC)");
        },
      );
    } catch (e, st) {
      debugPrint("AAC playback failed: $e\n$st -- trying WAV");
      try {
        await _player.startPlayer(
          fromURI: url,
          codec: Codec.pcm16WAV,
          whenFinished: () {
            debugPrint("Playback finished (WAV)");
          },
        );
      } catch (e2, st2) {
        debugPrint("WAV playback also failed: $e2\n$st2");
      }
    }
  }

  // Prevents rebuild loop
  @override
  void initState() {
    super.initState();

    // Load student, class, and user data
    _studentFuture = fetchStudentData();

    // Start audio player
    _player.openPlayer();
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }


  // Fetch student progress + user info + class details
  Future<Map<String, dynamic>> fetchStudentData() async {
    // Fetch student document
    final studentDoc = await FirebaseFirestore.instance
        .collection('student.progress')
        .where('uid', isEqualTo: widget.studentUid)
        .limit(1)
        .get();

    if (studentDoc.docs.isEmpty) return {};

    final studentData = studentDoc.docs.first.data();

    // Fetch fullName
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('id', isEqualTo: widget.studentUid)
        .limit(1)
        .get();

    final userData = userDoc.docs.isNotEmpty ? userDoc.docs.first.data() : {};

    // Fetch class info for student
    final classDoc = await FirebaseFirestore.instance
        .collection('classes')
        .where('studentIds', arrayContains: widget.studentUid)
        .limit(1)
        .get();

    final classData =
        classDoc.docs.isNotEmpty ? classDoc.docs.first.data() : {};

    // Locate the word text from struggled word document IDs
    final List<dynamic> wordStruggledIds = List.from(studentData['wordStruggledIds'] ?? []);
    for (int i = 0; i < wordStruggledIds.length; i++) {
      final wordId = wordStruggledIds[i];
      final wordModel = await WordRepository().fetchWordById(wordId);
      if (wordModel != null) {
        wordStruggledIds[i] = wordModel.text;
      } else {
        wordStruggledIds[i] = '';
      }
    }

    // Mapping returned to the FutureBuilder
    return {
      'fullName': userData['fullName'] ?? 'No Name',
      'username': userData['username'] ?? 'No Username',
      'countWordsCompleted': studentData['countWordsCompleted'] ?? 0,
      'countWordsAttempted': studentData['countWordsAttempted'] ?? 0,
      'averageWordAttemptScore': studentData['averageWordAttemptScore'] ?? 0.0,
      'wordStruggledIds': wordStruggledIds,
      'totalWordsToComplete': classData['totalWordsToComplete'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Tab Builder
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Details'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Student Details'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Word Progress'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Student Details Tab
            FutureBuilder<Map<String, dynamic>>(
              // Uses persistent future
              future: _studentFuture, 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Loading student data
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Firestore or parsing error
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
          

                final data = snapshot.data ?? {};
                final fullName = data['fullName'];
                final username = data['username'];
                final averageWordAttemptScore = double.parse(((data['averageWordAttemptScore'] ?? 0.0) * 100).toStringAsFixed(2));
                final countWordsAttempted = data['countWordsAttempted'] ?? 0;
                final topStruggledWords = data['wordStruggledIds'] ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student Name
                      Text(
                        fullName,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),

                      // Student Username
                      const Text('Username',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(username, style: const TextStyle(fontSize: 16)),
                      const Divider(height: 32, thickness: 1),

                      // Averages Section
                      const Text('Averages',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Average Score: $averageWordAttemptScore%',
                          style: const TextStyle(fontSize: 16)),
                      const Divider(height: 32, thickness: 1),

                      // Attempts Section
                      const Text('Attempts',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Total Attempts: $countWordsAttempted',
                          style: const TextStyle(fontSize: 16)),
                      const Divider(height: 32, thickness: 1),

                      // Top Struggled Words
                      const Text('Top Struggled Words',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: topStruggledWords.isEmpty
                            ? const [Text('None', style: TextStyle(fontSize: 16))]
                            : topStruggledWords
                                .map<Widget>((w) => Text('• $w',
                                    style: const TextStyle(fontSize: 16)))
                                .toList(),
                      ),
                      const Divider(height: 32, thickness: 1),
                    ],
                  ),
                );
              },
            ),
            // Word Progress Tab
            FutureBuilder<Map<String, dynamic>>(
               // Uses same persistent future
              future: _studentFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final data = snapshot.data ?? {};
                final countWordsCompleted = data['countWordsCompleted'];
                final totalWordsToComplete = data['totalWordsToComplete'];

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Section
                      Text(
                        'Words completed: $countWordsCompleted / $totalWordsToComplete',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),

                      // Progress Bar
                      LinearProgressIndicator(
                        value: totalWordsToComplete == 0
                            ? 0
                            : countWordsCompleted / totalWordsToComplete,
                        minHeight: 12,
                        backgroundColor: Colors.grey[300],
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),

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

                      // Level dropdown + Sort dropdown
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('words')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                // Build Level List
                                List<String> levels = ['All'];
                                if (snapshot.hasData) {
                                  levels.addAll(snapshot.data!.docs
                                      .map((doc) =>
                                          (doc.data()
                                                  as Map<String, dynamic>)['level']
                                              .toString())
                                      .toSet()
                                      .toList()
                                    ..sort((a, b) {
                                      // Sort levels using custom order
                                      final indexA = customLevelOrder.indexOf(a);
                                      final indexB = customLevelOrder.indexOf(b);
                                      return indexA.compareTo(indexB);
                                    }));
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
                                      .map((level) => DropdownMenuItem(
                                            value: level,
                                            child: Text(level),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    // Update active filter
                                    setState(() {
                                      _selectedLevel = value ?? 'All';
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedSort,
                              decoration: const InputDecoration(
                                labelText: 'Sort',
                                border: OutlineInputBorder(),
                              ),
                              items: sortOptions
                                  .map((s) =>
                                      DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (value) {
                                // Set sort order and rebuild list
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
                              // Loading word list
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            // Get all words
                            List<Map<String, dynamic>> allWords =
                                snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              data['id'] = doc.id;
                              return data;
                            }).toList();

                            // Apply Search & Level Filter
                            List<Map<String, dynamic>> filteredWords =
                                allWords.where((word) {
                              final matchesSearch = word['text']
                                  .toString()
                                  .toLowerCase()
                                  .contains(_searchText.toLowerCase());

                              final matchesLevel = _selectedLevel == 'All' ||
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
                                  child: Text('No words match your filter.'));
                            }

                            // Build list of Words
                            return ListView.builder(
                              itemCount: filteredWords.length,
                              itemBuilder: (context, index) {
                                final word = filteredWords[index];
                                final text = word['text'];
                                final level = word['level'];

                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    childrenPadding: EdgeInsets.zero,
                                    title: Text(
                                      text,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    // Expanded content section
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          child: Row(
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [
                                                  // Level Label
                                                  const Text(
                                                    'Level:',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),

                                                  // Level Badge
                                                  Container(
                                                    padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: getLevelColor(level),
                                                      borderRadius:
                                                      BorderRadius.circular(8),
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
                                                ],
                                              ),
                                              const Spacer(),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  FutureBuilder<Widget>(
                                                    future: handlePlayback(text), // returns Future<Widget>
                                                    builder: (context, snapshot) {
                                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                                        return const CircularProgressIndicator();
                                                      } else if (snapshot.hasError) {
                                                        return Text('Error: ${snapshot.error}');
                                                      } else if (snapshot.hasData) {
                                                        return snapshot.data!;
                                                      } else if (snapshot == null) {
                                                        return const Text('No attempt yet');
                                                      } else {
                                                        return const Text('No data');
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(height: 12),
                                                ],
                                              )
                                            ]
                                          )
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
