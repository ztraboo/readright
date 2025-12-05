import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:readright/utils/firestore_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readright/models/current_user_model.dart';
import 'package:readright/screens/profile_screen.dart';
import 'package:readright/services/attempt_repository.dart';
import 'package:readright/services/class_repository.dart';
import 'package:readright/services/student_progress_repository.dart';
import 'package:readright/services/user_repository.dart';
import 'package:readright/services/word_respository.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'screens/landing_screen.dart';
import 'screens/reader_selection_screen.dart';
import 'screens/student/student_login_screen.dart';
import 'screens/student/student_passcode_verification_screen.dart';
import 'screens/student/student_word_dashboard_screen.dart';
import 'screens/student/student_word_level_completed.dart';
// Defer loading the heavy student practice screen (it pulls in FFmpeg).
import 'screens/student/student_word_practice_screen.dart' deferred as student_practice;
import 'screens/student/student_word_feedback_screen.dart';
import 'screens/teacher/login/teacher_login_screen.dart';
import 'screens/teacher/login/teacher_register_screen.dart';
import 'screens/teacher/login/teacher_password_reset_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/teacher/teacher_word_dashboard_screen.dart';
import 'screens/teacher/class/class_dashboard_screen.dart';
//import 'screens/teacher/class/class_student_details_screen.dart';
import 'utils/app_constants.dart';
import 'utils/online_monitor.dart';

// import 'package:readright/utils/seed_words_uploader.dart';

/// Widget that performs asynchronous initialization (Firebase, Firestore
/// settings) after the first frame has been drawn so app startup is
/// non-blocking. Once Firebase is ready it will initialize repository
/// notifiers that were provided at app start.
class AppInitializer extends StatefulWidget {
  final Widget child;
  const AppInitializer({super.key, required this.child});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();

    _loadSharedPreferences();

    // Run init after the first frame to keep startup fast.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initOnce());

  }

  Future<void> _loadSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _prefs.setBool(AppConstants.prefShowStudentWordDashboardScreen, false);

    // Initialize toggled offline mode to true when you need to debug offline features.
    _prefs.setBool(AppConstants.prefToggledOfflineMode, false);
    debugPrint('SharedPreferences initialized');

    // If offline mode was toggled, set isOnline to false to simulate offline state.
    // Otherwise, start the online monitor to check connectivity.
    if (_prefs.getBool(AppConstants.prefToggledOfflineMode) == true) {
      _prefs.setBool(AppConstants.prefIsOnline, false);
      debugPrint('Offline mode toggled: setting isOnline SharedPreferences to false');
    } else {
      // start centralized online monitor (non-blocking)
      OnlineMonitor.instance.start().catchError((e) {
        debugPrint('OnlineMonitor failed to start: $e');
      });
    }
  }

  Future<void> _initOnce() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized (post-start)');

      // Enable persistence and set cache size; ignore on web where settings may differ.
      // Use large cache for offline support for query indexing and LRU eviction to avoid frequent re-fetching.
      // We previously had Settings.CACHE_SIZE_UNLIMITED but that could lead to storage issues on device or app crashes.
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: 200 * 1024 * 1024, // 200 MB
        );
      } catch (e) {
        debugPrint('Could not apply Firestore settings (platform may not support): $e');
      }

      // Initialize notifiers that were created before init
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;

      // Use mounted check to avoid calling context after dispose
      if (!mounted) return;

      // Initialize repositories with Firestore and Auth instances
      try {
        AttemptRepository(firestore: firestore, auth: auth);
        ClassRepository(firestore: firestore, auth: auth);
        StudentProgressRepository(firestore: firestore, auth: auth);
        UserRepository(firestore: firestore, auth: auth);
        WordRepository(firestore: firestore, auth: auth);
      } catch (e, st) {
        debugPrint('Failed to initialize repository notifiers: $e\n$st');
      }

      // Listen to auth state changes so persistent FirebaseAuth sessions
      // are handled and the corresponding Firestore user document is
      // warmed/cached for the UI after app restart.
      // FirebaseAuth persists the current user on mobile platforms by
      // default; this listener ensures we fetch the associated user
      // document when a session exists.
      auth.authStateChanges().listen((firebaseUser) async {
        if (firebaseUser == null) {
          debugPrint('No signed-in user at authState change');
          return;
        }
        try {
          // Attempt to fetch the user's Firestore document so callers of
          // fetchCurrentUser() or other user-based operations get a warm
          // value and the repository cache (or notifier cache) can be
          // populated.
          final currentUser = await UserRepository().fetchUserByUserUID(firebaseUser.uid);
          if (currentUser == null) {
            debugPrint('No Firestore user document found for uid=${firebaseUser.uid}');
            return;
          }
          // ignore: use_build_context_synchronously
          await context.read<CurrentUserModel>().logIn(currentUser);
          debugPrint('User document fetched for uid=${firebaseUser.uid}');
        } catch (e, st) {
          debugPrint('Failed to fetch current user on auth state change: $e\n$st');
        }

        // Ensure no user is signed in at app start
        // This is for testing purposes to avoid persisting sessions across app restarts.
        // ignore: use_build_context_synchronously
        // await context.read<CurrentUserModel>().logOut();
      });

      // Manually upload seed words from asset on app start
      // We do this here to ensure it's done once when the app starts.
      // This is a one-time operation; in a real app, you'd likely remove this after the initial upload.
      // SeedWordsUploader.uploadFromAsset().then((_) {
      //   debugPrint('Seed words upload completed.');
      // }).catchError((e) {
      //   debugPrint('Seed words upload failed: $e');
      // });

      // FirestoreUtils.renameCollection('students', 'student.progress').then((_) {
      //   debugPrint('Collection rename completed.');
      // }).catchError((e, st) {
      //   debugPrint('Collection rename failed: $e\n$st');
      // });

      // Delete all documents in 'attempts' where userId == current signed-in user.
      // try {
      //   final uid = auth.currentUser?.uid;
      //   if (uid == null) {
      //     debugPrint('No signed-in user; skipping attempts cleanup.');
      //   } else {
      //     const int batchSize = 500;
      //     while (true) {
      //       final query = firestore
      //           .collection('attempts')
      //           .where('userId', isEqualTo: uid)
      //           .limit(batchSize);
      //       final snapshot = await query.get();
      //       if (snapshot.docs.isEmpty) break;

      //       final batch = firestore.batch();
      //       for (final doc in snapshot.docs) {
      //         batch.delete(doc.reference);
      //       }
      //       await batch.commit();
      //       debugPrint('Deleted ${snapshot.docs.length} attempt(s) for uid=$uid');
      //       // Continue looping until no more matching documents remain.
      //     }
      //     debugPrint('Attempt cleanup completed for uid=$uid');
      //   }
      // } catch (e, st) {
      //   debugPrint('Failed to delete attempts for current user: $e\n$st');
      // }

    } catch (e, st) {
      debugPrint('Firebase initialization failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep app startup non-blocking: create notifiers immediately (they are lazy)
  // and initialize Firebase & notifiers after the first frame inside AppInitializer.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CurrentUserModel()),
      ],
      child: AppInitializer(child: const ReadRightApp()),
    ),
  );
}

class ReadRightApp extends StatelessWidget {
  const ReadRightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadRight',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/landing',
      routes: {
        '/landing': (context) => const LandingPage(),
        '/reader-selection': (context) => const ReaderSelectionPage(),
        '/student-login': (context) => const StudentLoginPage(),
        '/student-passcode-verification': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return StudentPasscodeVerificationPage(
            username: args is Map ? args['username'] : null,
            email: args is Map ? args['email'] : null,
          );
        },
        '/student-word-dashboard': (context) => const StudentWordDashboardPage(),
        '/student-word-level-completed': (context) => const StudentWordLevelCompletedPage(),
        '/student-word-practice': (context) => FutureBuilder<void>(
              future: student_practice.loadLibrary(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.done) {
                  return student_practice.StudentWordPracticePage();
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
        '/student-word-feedback': (context) => const StudentWordFeedbackPage(),
        '/teacher-login': (context) => const TeacherLoginPage(),
        '/teacher-register': (context) => const TeacherRegisterPage(),
        '/teacher-password-reset': (context) => const TeacherPasswordResetPage(),
        '/teacher-dashboard': (context) => const TeacherDashboardPage(),
        '/teacher-word-dashboard': (context) =>  TeacherWordDashboardPage(),
        '/class-dashboard': (context) => const ClassDashboard(),
        '/profile-settings': (context) => const ProfilePage(),
//        '/class-student-details': (context) => const ClassStudentDetails(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
