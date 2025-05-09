import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'result_screen.dart';

class BattleScreen extends StatefulWidget {
  final String noteId;
  final String noteUrl;
  final String teamCode;
  final String battleId;
  final DateTime startTime;

  const BattleScreen({
    super.key,
    required this.noteId,
    required this.noteUrl,
    required this.teamCode,
    required this.battleId,
    required this.startTime,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> originalQuestions = [];
  Map<int, int?> selectedAnswers = {};
  int remainingSeconds = 60;
  Timer? timer;
  bool isLoading = true;
  String errorMessage = '';
  final uid = FirebaseAuth.instance.currentUser!.uid;

  late final FirebaseFirestore db;
  StreamSubscription<DocumentSnapshot>? _battleSubscription;

  @override
  void initState() {
    super.initState();
    try {
      db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: "cote",
      );
    } catch (e) {
      db = FirebaseFirestore.instance;
      print("Using default Firestore instance: $e");
    }
    
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final battleDoc = await db.collection('quizBattles').doc(widget.battleId).get();
      final data = battleDoc.data();
      
      if (data != null && data.containsKey('questions')) {
        setState(() {
          originalQuestions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
          
          // Create a copy of questions without any indication of correct answer
          questions = originalQuestions.map((q) {
            final newQ = Map<String, dynamic>.from(q);
            // Remove any markers or indicators of correct answer
            newQ.remove('correctAnswer');
            
            // Optionally, remove any '[CORRECT]' or similar markers from options
            final options = List<String>.from(newQ['options']);
            newQ['options'] = options.map((option) {
              // Remove any '[CORRECT]' or similar markers
              return option.replaceAll('[CORRECT]', '').trim();
            }).toList();
            
            return newQ;
          }).toList();
          
          // Initialize selected answers
          for (int i = 0; i < questions.length; i++) {
            selectedAnswers[i] = null;
          }
          
          isLoading = false;
        });
        
        _startTimer();
      } else {
        throw Exception('No questions found');
      }
    } catch (e) {
      print("Error loading questions: $e");
      setState(() {
        isLoading = false;
        errorMessage = "Failed to load questions: ${e.toString()}";
      });
    }
  }

  void _startTimer() {
    if (!mounted) return;
    
    final now = DateTime.now();
    int elapsed = now.difference(widget.startTime).inSeconds;
    remainingSeconds = max(0, 60 - elapsed);

    if (remainingSeconds <= 0) {
      _submit();
      return;
    }

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        t.cancel();
        _submit();
      }
    });
  }

  Future<void> _submit() async {
    timer?.cancel();

    // Calculate score
    int correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == originalQuestions[i]['correctAnswer']) {
        correctCount++;
      }
    }
    
    // Update player data in the battle document
    try {
      final battleRef = db.collection('quizBattles').doc(widget.battleId);
      
      await battleRef.update({
        'playerData.$uid': {
          'score': correctCount,
          'completedAt': FieldValue.serverTimestamp(),
          'answers': selectedAnswers.map((key, value) => MapEntry(key.toString(), value)),
          'submitted': true,
        },
      });

      // Wait for opponent's submission
      _waitForOpponentSubmission();
    } catch (e) {
      print("Error updating player data: $e");
    }
  }

  void _waitForOpponentSubmission() {
    final battleRef = db.collection('quizBattles').doc(widget.battleId);
    
    _battleSubscription = battleRef.snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      
      final data = snapshot.data()!;
      final Map<String, dynamic> playerData = Map<String, dynamic>.from(data['playerData'] ?? {});
      final List<String> players = List<String>.from(data['players'] ?? []);
      
      // Check if both players have submitted
      bool allSubmitted = players.every((playerId) => 
        playerData[playerId] != null && 
        playerData[playerId]['submitted'] == true
      );
      
      if (allSubmitted) {
        _battleSubscription?.cancel();
        
        // Prepare result data with correct answers
        final results = questions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          return {
            'question': q['question'],
            'options': q['options'],
            'correctAnswer': originalQuestions[index]['correctAnswer'],
            'selectedAnswer': selectedAnswers[index],
          };
        }).toList();

        // Navigate to ResultScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                result: results, 
                battleId: widget.battleId,
                uid: uid,
              ),
            ),
          );
        }
      }
    }, onError: (error) {
      print("Error waiting for opponent submission: $error");
    });
  }

  int max(int a, int b) => a > b ? a : b;

  @override
  void dispose() {
    timer?.cancel();
    _battleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Battle"),
        automaticallyImplyLeading: false,
        actions: [
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "$remainingSeconds s",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = '';
                            });
                            _loadQuestions();
                          },
                          child: const Text("Try Again"),
                        ),
                      ],
                    ),
                  ),
                )
              : questions.isEmpty
                  ? const Center(child: Text("No questions could be generated"))
                  : ListView.builder(
                      itemCount: questions.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final q = questions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Q${index + 1}: ${q['question']}", 
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  )
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(q['options'].length, (i) {
                                  final letter = String.fromCharCode(65 + i); // A, B, C, D
                                  return RadioListTile<int>(
                                    value: i,
                                    groupValue: selectedAnswers[index],
                                    title: Text("$letter. ${q['options'][i]}"),
                                    dense: true,
                                    onChanged: (val) {
                                      setState(() {
                                        selectedAnswers[index] = val;
                                      });
                                    },
                                  );
                                })
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      bottomNavigationBar: !isLoading && errorMessage.isEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "Submit Now",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}