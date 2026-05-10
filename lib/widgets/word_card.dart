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
    final analysis = analyze(word.word);
    if (!analysis.hasBreakdown) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText.rich(
        TextSpan(
          style: TextStyle(fontSize: 12, color: Colors.brown[600], fontWeight: FontWeight.w500),
          children: [
            TextSpan(text: '构词: ', style: TextStyle(color: Colors.brown[400])),
            ...analysis.segments.map((seg) {
              final isLast = seg == analysis.segments.last;
              return TextSpan(children: [
                TextSpan(text: seg.text, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8B4513))),
                TextSpan(text: '(${seg.meaning.split(' ').first})${isLast ? '' : ' + '}'),
              ]);
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
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
      ),
    );
  }
}
