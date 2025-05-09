import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({Key? key}) : super(key: key);

  @override
  LeaderboardPageState createState() => LeaderboardPageState();
}

class LeaderboardPageState extends State<LeaderboardPage> {
  final firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: "cote",
  );

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Rank color based on position
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold color
      case 2:
        return const Color(0xFFC0C0C0); // Silver color
      case 3:
        return const Color(0xFFCD7F32); // Bronze color
      default:
        return Colors.grey;
    }
  }

  // Rating color coding
  Color _getRatingColor(int rating) {
    if (rating < 1000) return Colors.red;
    if (rating < 1200) return Colors.orange;
    if (rating < 1400) return Colors.blue;
    if (rating < 1600) return Colors.green;
    return Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('users')
            .orderBy('quizRating', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No users found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Debug print to understand current user details
          print('Current User UID: ${_currentUser?.uid}');

          // Filter and prepare student users
          final studentUsers = snapshot.data!.docs.where((doc) {
            final userData = doc.data() as Map<String, dynamic>;
            return userData['role'] == 'student';
          }).toList();

          return ListView.builder(
            itemCount: studentUsers.length,
            itemBuilder: (context, index) {
              var userData = studentUsers[index].data() as Map<String, dynamic>;
              
              // Debug print for each user
              print('User UID: ${userData['uid']}');
              print('Username: ${userData['username']}');

              return _buildLeaderboardItem(
                rank: index + 1,
                username: userData['username'] ?? 'Unknown User',
                rating: userData['quizRating'] ?? 1200,
                battlesWon: userData['quizBattlesWon'] ?? 0,
                totalBattles: userData['quizBattlesPlayed'] ?? 0,
                // Change to compare UIDs instead of usernames
                isCurrentUser: userData['uid'] == _currentUser?.uid,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardItem({
    required int rank,
    required String username,
    required int rating,
    required int battlesWon,
    required int totalBattles,
    required bool isCurrentUser,
  }) {
    // Debug print to verify current user highlight
    print('Is Current User: $isCurrentUser for $username');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
          ? Border.all(
              color: Colors.deepPurple.shade300,
              width: 2,
            )
          : Border.all(
              color: Colors.white24,
              width: 1,
            ),
        boxShadow: isCurrentUser
          ? [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.3),
                blurRadius: 5,
                spreadRadius: 1,
              )
            ]
          : [],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRankColor(rank),
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                username,
                style: TextStyle(
                  color: isCurrentUser 
                    ? Colors.white 
                    : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Rating: $rating',
              style: TextStyle(
                color: _getRatingColor(rating),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Battles: $battlesWon/$totalBattles',
          style: TextStyle(
            color: isCurrentUser 
              ? Colors.white 
              : Colors.white54,
          ),
        ),
      ),
    );
  }
}