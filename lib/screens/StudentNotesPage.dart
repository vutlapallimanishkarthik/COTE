// IMPORTS SAME AS YOURS
import 'package:cote/screens/PDFViewerPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cote/screens/ExtractTextPage.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:synchronized/synchronized.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentNotesPage extends StatefulWidget {
  const StudentNotesPage({super.key});

  @override
  State<StudentNotesPage> createState() => _StudentNotesPageState();
}

class _StudentNotesPageState extends State<StudentNotesPage> {
  String _searchQuery = '';
  final Map<String, File> _pdfCache = {};
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  final Lock _cacheLock = Lock();
  Set<String> _expandedNotes = {};

  final user = FirebaseAuth.instance.currentUser;
  final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: "cote");

  @override
  void initState() {
    super.initState();
    _loadCachedPDFs();
  }

  Future<void> _loadCachedPDFs() async {
    try {
      await _cacheLock.synchronized(() async {
        final dir = await getApplicationDocumentsDirectory();
        final files = dir.listSync();
        
        for (var file in files) {
          if (file is File && file.path.endsWith('.pdf')) {
            final filename = file.path.split('/').last;
            final url = filename.replaceAll('.pdf', '');
            _pdfCache[url] = file;
          }
        }
      });
    } catch (e) {
      print('Error loading cached PDFs: $e');
    }
  }

  Future<void> _preloadPDF(String url) async {
    if (!_pdfCache.containsKey(url)) {
      try {
        await _cacheLock.synchronized(() async {
          final fileInfo = await _cacheManager.getFileFromCache(url);
          if (fileInfo != null) {
            _pdfCache[url] = fileInfo.file;
          } else {
            final fileInfo2 = await _cacheManager.downloadFile(url);
            _pdfCache[url] = fileInfo2.file;
          }
        });
      } catch (e) {
        print('Error preloading PDF: $e');
      }
    }
  }

  Future<File> _getPDF(String url) async {
    try {
      return await _cacheLock.synchronized(() async {
        if (_pdfCache.containsKey(url)) {
          return _pdfCache[url]!;
        }
        final fileInfo = await _cacheManager.getFileFromCache(url);
        if (fileInfo != null) {
          _pdfCache[url] = fileInfo.file;
          return fileInfo.file;
        }
        final fileInfo2 = await _cacheManager.downloadFile(url);
        _pdfCache[url] = fileInfo2.file;
        return fileInfo2.file;
      });
    } catch (e) {
      print('Error getting PDF: $e');
      rethrow;
    }
  }

  Future<void> _bookmarkNote(String noteId) async {
    if (user == null) return;
    try {
      final userRef = db.collection('users').doc(user!.uid);
      await userRef.update({
        'bookmarks.notes': FieldValue.arrayUnion([noteId])
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note bookmarked successfully!')),
      );
    } catch (e) {
      print('Error bookmarking note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to bookmark note')),
      );
    }
  }

  Future<void> _viewPDF(BuildContext context, String url) async {
    try {
      File? pdfFile = _pdfCache[url];
      
      if (pdfFile == null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );
        pdfFile = await _getPDF(url);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }

      if (context.mounted && pdfFile != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerPage(
              url: url,
              cachedFile: pdfFile!,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error handling PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open PDF')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Student - View Notes"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notes...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                ),
                filled: true,
                fillColor: Colors.white10,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.deepPurple,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('notes').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notes = snapshot.data!.docs.where((doc) {
                  final title = doc['title'].toString().toLowerCase();
                  return title.contains(_searchQuery);
                }).toList();

                // Preload first 5 PDFs
                for (var note in notes.take(5)) {
                  _preloadPDF(note['url']);
                }

                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final title = note['title'];
                    final url = note['url'];
                    final timestamp = (note['timestamp'] as Timestamp).toDate();
                    final noteId = note.id;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (_expandedNotes.contains(noteId)) {
                                _expandedNotes.remove(noteId);
                              } else {
                                _expandedNotes.add(noteId);
                              }
                            });
                          },
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: ListTile(
                                  leading: const Icon(Icons.picture_as_pdf, color: Colors.deepPurple, size: 36),
                                  title: Text(title),
                                  subtitle: Text(
                                    "${timestamp.day}/${timestamp.month}/${timestamp.year}",
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  trailing: RotationTransition(
                                    turns: AlwaysStoppedAnimation(_expandedNotes.contains(noteId) ? 0.5 : 0.0),
                                    child: const Icon(Icons.keyboard_arrow_down),
                                  ),
                                ),
                              ),
                              AnimatedCrossFade(
                                firstChild: Container(),
                                secondChild: Padding(
                                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                                  child: Column(
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.picture_as_pdf),
                                              label: const Text("View PDF"),
                                              onPressed: () => _viewPDF(context, url),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(25),
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.quiz),
                                              label: const Text("Generate Quiz"),
                                              onPressed: () => _generateQuiz(context, url),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(25),
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.bookmark),
                                              label: const Text("Bookmark"),
                                              onPressed: () => _bookmarkNote(noteId),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.deepPurple,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(25),
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                crossFadeState: _expandedNotes.contains(noteId)
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 300),
                              ),
                            ],
                          ),
                        ),
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
  }

  void _generateQuiz(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExtractTextPage(url: url),
      ),
    );
  }

  @override
  void dispose() {
    _cacheManager.dispose();
    super.dispose();
  }
}
