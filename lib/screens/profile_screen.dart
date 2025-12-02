import 'package:flutter/material.dart';
import 'package:readright/models/current_user_model.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';


// Stateful for future releases to allow changes to password, email, etc.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();

    // Fetch current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _currentUser = context.read<CurrentUserModel>().user;

        if (_currentUser != null) {
          debugPrint(
            'Found user session for ${_currentUser?.username}',
          );
        } else {
          debugPrint('No existing user session found.');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: AppColors.bgPrimaryLightBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "Username: ${_currentUser?.username ?? 'Unknown'}",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              "Name: ${_currentUser?.username ?? 'Unknown'}",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              "Email: ${_currentUser?.email ?? 'Unknown'}",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text(
                "Log Out",
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgPrimaryRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await context.read<CurrentUserModel>().logOut();
                  debugPrint('Successfully called logOut');
                } catch (e, st) {
                  debugPrint('Failed to log out: $e\n$st');
                }


                // Clear stack and kick back to user selection screen
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/reader-selection',
                      (route) => false,
                );
              },
            ),
            const Spacer(),
            InkWell(
              child: const Text(
                "About",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
              onTap: () async {
                debugPrint("Attempting to open link");
                final Uri url = Uri.parse('https://github.com/ztraboo/readright');
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }
}