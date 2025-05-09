import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cote/screens/ShortViewerPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cote/screens/ShortViewerPage.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: "cote",
  );

  List<QueryDocumentSnapshot> bookmarkedShorts = [];
  List<DocumentSnapshot> bookmarkedNotes = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (user == null) return;

    final userDoc = await firestore.collection('users').doc(user!.uid).get();
    final bookmarks = userDoc.data()?['bookmarks'] ?? {'shorts': [], 'notes': []};

    final shortIds = List<String>.from(bookmarks['shorts'] ?? []);
    final noteIds = List<String>.from(bookmarks['notes'] ?? []);

    List<QueryDocumentSnapshot> shortsSnap = [];
    List<DocumentSnapshot> notesSnap = [];

    if (shortIds.isNotEmpty) {
      final shortsQuery = await firestore
          .collection('shorts')
          .where(FieldPath.documentId, whereIn: shortIds)
          .get();
      shortsSnap = shortsQuery.docs;
    }

    if (noteIds.isNotEmpty) {
      final notesQuery = await firestore
          .collection('notes')
          .where(FieldPath.documentId, whereIn: noteIds)
          .get();
      notesSnap = notesQuery.docs;
    }

    setState(() {
      bookmarkedShorts = shortsSnap;
      bookmarkedNotes = notesSnap;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bookmarks")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookmarks,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    "📹 Bookmarked Shorts",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (bookmarkedShorts.isEmpty)
                    const Text("No bookmarked shorts yet."),
                  ...bookmarkedShorts.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final index = bookmarkedShorts.indexOf(doc);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.play_circle_fill),
                        title: Text(data['description'] ?? 'Short Video'),
                        subtitle: Text(doc.id),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShortViewerPage(
                                initialIndex: index,
                                docs: bookmarkedShorts,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  const Text(
                    "📚 Bookmarked Notes",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (bookmarkedNotes.isEmpty)
                    const Text("No bookmarked notes yet."),
                  ...bookmarkedNotes.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(data['title'] ?? 'Untitled Note'),
                        subtitle: Text("Subject: ${data['subject'] ?? 'Unknown'}"),
                        onTap: () {
                          // TODO: Optionally open the PDF viewer with this note
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
