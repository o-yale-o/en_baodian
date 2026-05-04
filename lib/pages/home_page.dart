import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/db_service.dart';
import '../services/tts_service.dart';
import '../widgets/grade_tree.dart';
import '../widgets/word_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TtsService _tts = TtsService();
  List<Word> _words = [];
  int _currentIndex = 0;
  String _currentUnit = '';
  bool _loading = false;

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _onUnitSelected(int unitId, String unitName) async {
    setState(() {
      _loading = true;
      _currentUnit = unitName;
    });
    final words = await DbService.getWordsByUnit(unitId);
    setState(() {
      _words = words;
      _currentIndex = 0;
      _loading = false;
    });
    if (words.isNotEmpty) {
      _tts.preload(words.first.word);
      _tts.preload(words.first.sentence);
    }
  }

  void _prevWord() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _preloadCurrent();
    }
  }

  void _nextWord() {
    if (_currentIndex < _words.length - 1) {
      setState(() => _currentIndex++);
      _preloadCurrent();
    }
  }

  void _preloadCurrent() {
    if (_words.isEmpty) return;
    final w = _words[_currentIndex];
    _tts.preload(w.word);
    _tts.preload(w.sentence);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('英语宝典'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // ── 左侧：年级-单元树 ──────────────────
          SizedBox(
            width: 220,
            child: Container(
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.blue[50],
                    child: const Text('人教版初中英语',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: GradeTreeWidget(onUnitSelected: _onUnitSelected),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // ── 右侧：单词卡 ──────────────────────────
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('请从左侧选择单元',
                style: TextStyle(fontSize: 16, color: Colors.grey[400])),
          ],
        ),
      );
    }

    final word = _words[_currentIndex];
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == _words.length - 1;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          _currentUnit,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Colors.grey[500]),
        ),
        Expanded(
          child: Center(
            child: WordCardWidget(word: word, tts: _tts),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: isFirst ? null : _prevWord,
                icon: const Icon(Icons.arrow_back),
                label: const Text('上一词'),
              ),
              Text(
                '${_currentIndex + 1} / ${_words.length}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              OutlinedButton.icon(
                onPressed: isLast ? null : _nextWord,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('下一词'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
