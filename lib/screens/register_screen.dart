import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'subject_selection_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;

  Future<void> _register() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a role")),
      );
      return;
    }

    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username is required")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: "cote",
      );

      // Check for unique username
      final existing = await firestore
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username already taken")),
        );
        return;
      }

      // Create user
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // Create Firestore profile
      Map<String, dynamic> profileData = {
        'uid': uid,
        'email': _emailController.text.trim(),
        'username': _usernameController.text.trim(),
        'role': _selectedRole,
        'subjects': [],
        'bookmarks': {
          'shorts': [],
          'notes': [],
        },
        'registrationDate': Timestamp.now(),
        'lastActiveDate': Timestamp.now(),
      };

      if (_selectedRole == 'student') {
        profileData.addAll({
          'quizRating': 1200,
          'quizBattlesPlayed': 0,
          'quizBattlesWon': 0,
          'quizBattlesLost': 0,
          'totalMCQsAnswered': 0,
          'correctAnswersCount': 0,
          'totalPointsEarned': 0,
          'currentBattleId': null,
          'lastQuizNoteId': null,
        });
      }

      await firestore.collection('users').doc(uid).set(profileData);

      // Go to subject selection screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectSelectionScreen(role: _selectedRole!),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                hint: const Text("Select Role"),
                items: const [
                  DropdownMenuItem(value: "student", child: Text("Student")),
                  DropdownMenuItem(value: "teacher", child: Text("Teacher")),
                ],
                onChanged: (value) => setState(() => _selectedRole = value),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text("Register"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
