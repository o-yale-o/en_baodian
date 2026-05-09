import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/tts_service.dart';
import '../services/word_analysis.dart';

class WordCardWidget extends StatelessWidget {
  final Word word;
  final TtsService tts;
  final bool isPassed;
  final bool isHard;
  final VoidCallback onPassed;
  final VoidCallback onToggleHard;

  const WordCardWidget({
    super.key,
    required this.word,
    required this.tts,
    this.isPassed = false,
    this.isHard = false,
    required this.onPassed,
    required this.onToggleHard,
  });

  Widget _buildAnalysis(BuildContext context) {
    final parts = analyze(word.word);
    if (!parts.hasAnalysis) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '构词: ${parts.format()}',
        style: TextStyle(fontSize: 11, color: Colors.brown[600]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Word
            Text(
              word.word,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 12),

            // Pronunciation
            Text(
              word.pronunciation,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            // Speaker button on its own line
            IconButton(
              onPressed: () => tts.speak(word.word),
              icon: const Icon(Icons.volume_up, color: Colors.blue, size: 22),
              tooltip: '发音',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // Meaning
            Text(
              word.meaning,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black87,
                  ),
            ),
            // Word formation analysis
            _buildAnalysis(context),
            const SizedBox(height: 12),

            // Sentence + speaker
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    word.sentence,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => tts.speak(word.sentence),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.volume_up, color: Colors.blue, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              word.sentenceCn,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),

          ],
        ),
      ),
    );
  }
}
