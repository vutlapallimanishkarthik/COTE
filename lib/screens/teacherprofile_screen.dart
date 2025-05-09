import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({Key? key}) : super(key: key);

  @override
  _TeacherProfileScreenState createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  // Teacher profile variables
  String teacherName = '';
  String email = '';
  String role = 'Teacher';
  List<String> subjects = [];

  // Shorts performance metrics
  int shortsUpvotes = 0;
  int shortsDownvotes = 0;
  int shortsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchTeacherProfile();
    _fetchTeacherMetrics();
  }

  Future<void> _fetchTeacherProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: "cote",
        );

        final teacherDoc = await firestore
            .collection('users')
            .doc(user.uid)
            .get();

        setState(() {
          teacherName = teacherDoc.data()?['username'] ?? '';
          email = user.email ?? '';
          subjects = List<String>.from(teacherDoc.data()?['subjects'] ?? []);
        });
      }
    } catch (e) {
      print('Error fetching teacher profile: $e');
    }
  }

  Future<void> _fetchTeacherMetrics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: "cote",
        );

        // Fetch total upvotes and downvotes across all shorts for this teacher
        final shortsQuery = await firestore
            .collection('shorts')
            .where('teacherId', isEqualTo: user.uid)
            .get();

        int totalUpvotes = 0;
        int totalDownvotes = 0;
        int totalShortsCount = shortsQuery.docs.length;

        for (var doc in shortsQuery.docs) {
          totalUpvotes += (doc.data()['upvotes'] as num?)?.toInt() ?? 0;
          totalDownvotes += (doc.data()['downvotes'] as num?)?.toInt() ?? 0;
        }

        setState(() {
          shortsUpvotes = totalUpvotes;
          shortsDownvotes = totalDownvotes;
          shortsCount = totalShortsCount;
        });
      }
    } catch (e) {
      print('Error fetching shorts metrics: $e');
    }
  }

  void _addSubject() {
    final TextEditingController subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subject'),
        content: TextField(
          controller: subjectController,
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
            onPressed: () async {
              if (subjectController.text.isNotEmpty) {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'subjects': FieldValue.arrayUnion([subjectController.text])
                    });

                    setState(() {
                      subjects.add(subjectController.text);
                    });

                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  print('Error adding subject: $e');
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate approval rate
    int totalVotes = shortsUpvotes + shortsDownvotes;
    double approvalRate = totalVotes > 0 
      ? (shortsUpvotes / totalVotes) * 100 
      : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Profile'),
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
                      teacherName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Shorts Performance Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shorts Performance',
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
                            icon: Icons.thumb_up,
                            color: Colors.green,
                            value: shortsUpvotes.toString(),
                            label: 'Upvotes',
                          ),
                          _buildMetricItem(
                            icon: Icons.thumb_down,
                            color: Colors.red,
                            value: shortsDownvotes.toString(),
                            label: 'Downvotes',
                          ),
                          _buildMetricItem(
                            icon: Icons.video_library,
                            color: Colors.blue,
                            value: shortsCount.toString(),
                            label: 'Shorts',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Approval Rate: ${approvalRate.toStringAsFixed(1)}%',
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
                            onPressed: _addSubject,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      subjects.isEmpty
                      ? Center(
                          child: Text(
                            'No subjects added yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: subjects.map((subject) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.deepPurple.shade100, width: 1),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                subject,
                                style: TextStyle(
                                  color: Colors.deepPurple.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
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
}