import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  final TextEditingController _subjectController = TextEditingController();
  bool _isLoading = true;

  // Quiz Battle Metrics
  int quizBattlesPlayed = 0;
  int quizBattlesWon = 0;
  int quizRating = 1500; // Starting ELO rating

  final firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: "cote",
  );

  @override
  void initState() {
    super.initState();
    _loadUserProfile().then((_) => _fetchUserMetrics());
  }

  Future<void> _loadUserProfile() async {
    try {
      final doc = await firestore.collection('users').doc(_currentUser!.uid).get();
      setState(() {
        _userData = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserMetrics() async {
    try {
      final doc = await firestore.collection('users').doc(_currentUser!.uid).get();
      setState(() {
        quizBattlesPlayed = doc.data()?['quizBattlesPlayed'] ?? 0;
        quizBattlesWon = doc.data()?['quizBattlesWon'] ?? 0;
        quizRating = doc.data()?['quizRating'] ?? 1500;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching user metrics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ELO Rating Calculation Method
  int calculateELOrating(int currentRating, bool won, int opponentRating) {
    // ELO constant (K-factor)
    const int k = 32;

    // Calculate expected score
    double expectedScore = 1 / (1 + pow(10, (opponentRating - currentRating) / 400));

    // Actual score (1 for win, 0 for loss)
    double actualScore = won ? 1.0 : 0.0;

    // Calculate new rating
    int newRating = (currentRating + k * (actualScore - expectedScore)).round();

    // Prevent rating from going below 0
    return max(newRating, 0);
  }

  // Method to update quiz metrics and ELO rating
  Future<void> updateQuizMetrics({
    required bool wonBattle, 
    required int opponentRating
  }) async {
    try {
      final userRef = firestore.collection('users').doc(_currentUser!.uid);
      
      // Calculate new rating
      int newRating = calculateELOrating(quizRating, wonBattle, opponentRating);

      await userRef.update({
        'quizBattlesPlayed': FieldValue.increment(1),
        'quizBattlesWon': wonBattle ? FieldValue.increment(1) : FieldValue.increment(0),
        'quizRating': newRating,
      });

      // Refresh metrics
      _fetchUserMetrics();
    } catch (e) {
      print('Error updating quiz metrics: $e');
    }
  }

  Future<void> _addSubject() async {
    final newSubject = _subjectController.text.trim();
    if (newSubject.isEmpty) return;

    try {
      final updatedSubjects = [...?_userData?['subjects'], newSubject];
      await firestore.collection('users').doc(_currentUser!.uid).update({
        'subjects': updatedSubjects,
      });
      _subjectController.clear();
      _loadUserProfile();
    } catch (e) {
      print('Error adding subject: $e');
    }
  }

  Future<void> _removeSubject(String subject) async {
    try {
      final updatedSubjects = List<String>.from(_userData!['subjects']);
      updatedSubjects.remove(subject);

      await firestore.collection('users').doc(_currentUser!.uid).update({
        'subjects': updatedSubjects,
      });
      _loadUserProfile();
    } catch (e) {
      print('Error removing subject: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Calculate win rate
    double winRate = quizBattlesPlayed > 0 
      ? (quizBattlesWon / quizBattlesPlayed) * 100 
      : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _userData?['username'] ?? 'Student',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _userData?['email'] ?? 'email@example.com',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quiz Performance Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quiz Performance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetricItem(
                            icon: Icons.games,
                            color: Colors.blue,
                            value: quizBattlesPlayed.toString(),
                            label: 'Battles Played',
                          ),
                          _buildMetricItem(
                            icon: Icons.emoji_events,
                            color: Colors.green,
                            value: quizBattlesWon.toString(),
                            label: 'Battles Won',
                          ),
                          _buildMetricItem(
                            icon: Icons.star_rate,
                            color: Colors.orange,
                            value: quizRating.toString(),
                            label: 'Quiz Rating',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Win Rate: ${winRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Subjects Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subjects',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                            onPressed: _showAddSubjectDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      (_userData?['subjects'] == null || _userData!['subjects'].isEmpty)
                      ? Center(
                          child: Text(
                            'No subjects added yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: (_userData?['subjects'] as List<dynamic>).map<Widget>((subject) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.deepPurple.shade100, width: 1),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    subject,
                                    style: TextStyle(
                                      color: Colors.deepPurple.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _removeSubject(subject),
                                    child: Icon(
                                      Icons.close, 
                                      size: 16, 
                                      color: Colors.deepPurple.shade400
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showAddSubjectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subject'),
        content: TextField(
          controller: _subjectController,
          decoration: const InputDecoration(
            hintText: 'Enter subject name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addSubject();
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }
}