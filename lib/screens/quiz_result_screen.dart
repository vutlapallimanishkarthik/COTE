import 'package:flutter/material.dart';
import 'package:cote/screens/StudentNotesPage.dart';

class QuizResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> result;
  final String? battleId;
  final String? uid;

  const QuizResultScreen({
    Key? key, 
    required this.result, 
    this.battleId, 
    this.uid
  }) : super(key: key);

  @override
  _QuizResultScreenState createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  late int totalQuestions;
  late int correctAnswers;
  late double percentageScore;

  @override
  void initState() {
    super.initState();
    _calculateScore();
  }

  void _calculateScore() {
    totalQuestions = widget.result.length;
    correctAnswers = widget.result.where((q) => 
      q['selectedAnswer'] == q['correctAnswer']
    ).length;
    percentageScore = (correctAnswers / totalQuestions) * 100;
  }

  Color _getScoreColor() {
    if (percentageScore >= 80) return Colors.green;
    if (percentageScore >= 60) return Colors.orange;
    if (percentageScore >= 40) return Colors.amber;
    return Colors.red;
  }

  String _getPerformanceText() {
    if (percentageScore >= 90) return 'Excellent!';
    if (percentageScore >= 80) return 'Great Job!';
    if (percentageScore >= 60) return 'Good Effort';
    if (percentageScore >= 40) return 'Needs Improvement';
    return 'Poor Performance';
  }

  void _showDetailedAnswers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView.builder(
                controller: controller,
                itemCount: widget.result.length,
                itemBuilder: (context, index) {
                  final question = widget.result[index];
                  final isCorrect = question['selectedAnswer'] == question['correctAnswer'];
                  
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${index + 1}: ${question['question']}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          ...List.generate(
                            question['options'].length, 
                            (optionIndex) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Icon(
                                    optionIndex == question['correctAnswer'] 
                                      ? Icons.check_circle 
                                      : optionIndex == question['selectedAnswer']
                                        ? Icons.cancel 
                                        : Icons.circle_outlined,
                                    color: optionIndex == question['correctAnswer'] 
                                      ? Colors.green 
                                      : optionIndex == question['selectedAnswer']
                                        ? Colors.red 
                                        : Colors.grey,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      question['options'][optionIndex],
                                      style: TextStyle(
                                        color: optionIndex == question['correctAnswer'] 
                                          ? Colors.green.shade700 
                                          : optionIndex == question['selectedAnswer']
                                            ? Colors.red.shade700 
                                            : Colors.black,
                                        fontWeight: optionIndex == question['correctAnswer'] || 
                                          optionIndex == question['selectedAnswer']
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Result'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Score Circle
              CircleAvatar(
                radius: 100,
                backgroundColor: _getScoreColor().withOpacity(0.2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$correctAnswers/$totalQuestions',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(),
                      ),
                    ),
                    Text(
                      '${percentageScore.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 24,
                        color: _getScoreColor(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Performance Text
              Text(
                _getPerformanceText(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(),
                ),
              ),
              SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _showDetailedAnswers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text('View Answers'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context, 
                      MaterialPageRoute(builder: (context) => const StudentNotesPage()), 
                      (route) => false
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: Text('Back to Notes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}