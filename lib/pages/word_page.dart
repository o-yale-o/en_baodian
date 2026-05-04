import 'package:flutter/material.dart';
import '../data/sample_words.dart';
import '../services/tts_service.dart';

class WordPage extends StatefulWidget {
  const WordPage({super.key});

  @override
  State<WordPage> createState() => _WordPageState();
}

class _WordPageState extends State<WordPage> {
  int _currentIndex = 0;
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _preloadCurrent();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  void _preloadCurrent() {
    final w = sampleWords[_currentIndex];
    _tts.preload(w.word);
    _tts.preload(w.example);
  }

  void _prevWord() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _preloadCurrent();
    }
  }

  void _nextWord() {
    if (_currentIndex < sampleWords.length - 1) {
      setState(() => _currentIndex++);
      _preloadCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = sampleWords[_currentIndex];
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == sampleWords.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('英语宝典'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            '初中英语 · 单词学习',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: _buildWordCard(word, context),
            ),
          ),
          _buildNavigation(isFirst, isLast),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWordCard(dynamic word, BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word.word,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  word.pronunciation,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(width: 12),
                IconButton(
                        onPressed: () => _tts.speak(word.word),
                        icon: const Icon(Icons.volume_up, color: Colors.blue),
                        tooltip: '发音',
                      ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              word.meaning,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    word.example,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[800],
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _tts.speak(word.example),
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
              word.exampleCn,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(bool isFirst, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: isFirst ? null : _prevWord,
            icon: const Icon(Icons.arrow_back),
            label: const Text('上一词'),
          ),
          Text(
            '${_currentIndex + 1} / ${sampleWords.length}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          OutlinedButton.icon(
            onPressed: isLast ? null : _nextWord,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('下一词'),
          ),
        ],
      ),
    );
  }
}
