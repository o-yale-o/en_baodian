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

            // Pronunciation + speaker
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  word.pronunciation,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => tts.speak(word.word),
                  icon: const Icon(Icons.volume_up, color: Colors.blue),
                  tooltip: '发音',
                ),
              ],
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
                          fontStyle: FontStyle.italic,
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

            const SizedBox(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pass button
                _ActionButton(
                  icon: Icons.check_circle_outline,
                  label: '通过',
                  color: Colors.green,
                  active: isPassed,
                  onTap: onPassed,
                ),
                // Hard button
                _ActionButton(
                  icon: isHard ? Icons.star : Icons.star_border,
                  label: isHard ? '已标难' : '标为难题',
                  color: Colors.orange,
                  active: isHard,
                  onTap: onToggleHard,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: active ? color : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: active ? color.withAlpha(25) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? color : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: active ? color : Colors.grey[600],
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
