import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
  final _treeKey = GlobalKey<GradeTreeWidgetState>();
  List<Word> _words = [];
  int _currentIndex = 0;
  int _initialCount = 0;
  String _currentLabel = '';
  bool _loading = false;
  bool _isHardMode = false;
  int? _currentUnitId;
  bool _autoPlaying = false;
  bool _autoPaused = false;

  bool _isPassed = false;
  bool _isHard = false;

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _onUnitSelected(int unitId, String unitName) async {
    _currentUnitId = unitId;
    _dismissTree();
    await _loadWords(
      () => DbService.getWordsByUnit(unitId, skipPassed: true),
      unitName,
      false,
    );
  }

  Future<void> _onUnitAutoPlay(int unitId, String unitName) async {
    _treeKey.currentState?.selectUnit(unitId);
    _dismissTree();
    await _loadWords(
      () => DbService.getWordsByUnit(unitId, skipPassed: true),
      unitName,
      false,
    );
    if (mounted) _startAutoPlay();
  }

  Future<void> _onGradeAutoPlay(int gradeId, String gradeName) async {
    _dismissTree();
    await _onGradeSelected(gradeId, gradeName);
    if (mounted) _startAutoPlay();
  }

  Future<void> _onHardBookAutoPlay() async {
    _dismissTree();
    await _onHardBookSelected();
    if (mounted) _startAutoPlay();
  }

  Future<void> _onGradeSelected(int gradeId, String gradeName) async {
    _currentUnitId = null;
    await _loadWords(
      () => DbService.getWordsByGrade(gradeId, skipPassed: true),
      '$gradeName — 全部剩余',
      false,
    );
  }

  Future<void> _onHardBookSelected() async {
    _currentUnitId = null;
    _dismissTree();
    await _loadWords(
      () => DbService.getHardWords(),
      '难题本 — 全局',
      true,
    );
  }

  Future<void> _loadWords(
    Future<List<Word>> Function() loader,
    String label,
    bool hardMode,
  ) async {
    setState(() => _loading = true);
    final words = await loader();
    setState(() {
      _words = words;
      _currentIndex = 0;
      _initialCount = words.length;
      _currentLabel = label;
      _isHardMode = hardMode;
      _loading = false;
    });
    _refreshProgress();
    _preloadCurrent();
    _updateTreeFocus();
  }

  Future<void> _autoAdvance() async {
    if (_currentUnitId == null) return;
    final d = await DbService.db;
    // find current unit's grade_id and sort_order
    final current = await d.query('units',
        where: 'id = ?', whereArgs: [_currentUnitId], limit: 1);
    if (current.isEmpty) return;
    final gradeId = current.first['grade_id'] as int;
    final sortOrder = current.first['sort_order'] as int;

    // try next unit in same grade
    var next = await d.query('units',
        where: 'grade_id = ? AND sort_order > ?',
        whereArgs: [gradeId, sortOrder],
        orderBy: 'sort_order',
        limit: 1);

    // try first unit of next grade
    if (next.isEmpty) {
      next = await d.query('units',
          where: 'grade_id > ?',
          whereArgs: [gradeId],
          orderBy: 'grade_id, sort_order',
          limit: 1);
    }

    if (next.isNotEmpty) {
      final nextUnit = next.first;
      final id = nextUnit['id'] as int;
      _treeKey.currentState?.selectUnit(id);
      _onUnitSelected(id, nextUnit['name'] as String);
    }
  }

  Future<void> _goToNextUnit() async {
    await _autoAdvance();
  }

  Future<void> _resetCurrentUnit() async {
    if (_currentUnitId == null) return;
    await DbService.resetUnitPassed(_currentUnitId!);
    _treeKey.currentState?.refreshCounts();
    await _loadWords(
      () => DbService.getWordsByUnit(_currentUnitId!, skipPassed: true),
      _currentLabel,
      false,
    );
  }

  void _updateTreeFocus() {
    if (_words.isNotEmpty && _currentIndex < _words.length) {
      _treeKey.currentState?.selectUnit(_words[_currentIndex].unitId);
    }
  }

  Future<void> _refreshProgress() async {
    if (_words.isEmpty) return;
    final w = _words[_currentIndex];
    if (w.id == null) return;
    final passed = await DbService.isPassed(w.id!);
    final hard = await DbService.isHard(w.id!);
    if (mounted) {
      setState(() {
        _isPassed = passed;
        _isHard = hard;
      });
    }
  }

  void _preloadCurrent() {
    if (_words.isEmpty) return;
    // Preload current + next 3 words and sentences
    for (int i = _currentIndex; i < _currentIndex + 4 && i < _words.length; i++) {
      final w = _words[i];
      _tts.preload(w.word);
      _tts.preload(w.sentence);
    }
  }

  void _prevWord() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _updateTreeFocus();
      _refreshProgress();
      _preloadCurrent();
    }
  }

  Future<void> _nextWord() async {
    if (_currentIndex < _words.length - 1) {
      setState(() => _currentIndex++);
      _updateTreeFocus();
      _refreshProgress();
      _preloadCurrent();
    }
  }

  Future<void> _onPassed() async {
    final w = _words[_currentIndex];
    if (w.id == null) return;
    await DbService.setPassed(w.id!, true);
    if (_isHard) {
      await DbService.setHard(w.id!, false);
    }
    _treeKey.currentState?.refreshCounts();

    // Auto-play mode: just mark, let auto-play control advance
    if (_autoPlaying) {
      setState(() {
        _isPassed = true;
        _isHard = false;
      });
      return;
    }

    // Manual mode: remove from list & advance
    if (!_isHardMode) {
      _words.removeAt(_currentIndex);
      if (_words.isEmpty) {
        setState(() {});
        _autoAdvance();
        return;
      }
      if (_currentIndex >= _words.length) {
        setState(() => _currentIndex = _words.length - 1);
      }
      _refreshProgress();
      _preloadCurrent();
      setState(() {});
    } else {
      setState(() {
        _isPassed = true;
        _isHard = false;
      });
    }
  }

  // ── auto play ────────────────────────────────────────────

  Future<void> _startAutoPlay() async {
    if (_words.isEmpty) return;
    setState(() => _autoPlaying = true);
    WakelockPlus.enable();
    _tts.startForegroundService();
    // Preload first batch of words + sentences before starting
    for (int i = 0; i < _words.length && i < 15; i++) {
      _tts.preload(_words[i].word);
      _tts.preload(_words[i].sentence);
    }
    await Future.delayed(const Duration(seconds: 5)); // let downloads finish
    await _playLoop();
    WakelockPlus.disable();
    _tts.stopForegroundService();
  }

  void _togglePause() {
    setState(() => _autoPaused = !_autoPaused);
  }

  Future<void> _playLoop() async {
    while (_autoPlaying && _words.isNotEmpty && _currentIndex < _words.length) {
      // Pause check
      while (_autoPaused && _autoPlaying) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      if (!_autoPlaying) break;
      final w = _words[_currentIndex];
      _refreshProgress();
      _preloadCurrent();
      _updateTreeFocus();
      setState(() {}); // update UI

      // 1. English word
      await _tts.speakAndWait(w.word);
      if (!_autoPlaying) return;
      await Future.delayed(const Duration(milliseconds: 400));

      // 2. Chinese meaning (strip part-of-speech markers)
      final meaning = w.meaning.replaceAll(RegExp(r'[a-z]+\.[ ]*'), '');
      await _tts.speakChinese(meaning);
      if (!_autoPlaying) return;
      await Future.delayed(const Duration(milliseconds: 400));

      // 3. Sentence
      if (w.sentence.isNotEmpty) {
        await _tts.speakAndWait(w.sentence);
        if (!_autoPlaying) return;
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // 4. Sentence Chinese
      if (w.sentenceCn.isNotEmpty) {
        await _tts.speakChinese(w.sentenceCn);
        if (!_autoPlaying) return;
      }

      // Advance
      if (_currentIndex < _words.length - 1) {
        setState(() => _currentIndex++);
        await Future.delayed(const Duration(milliseconds: 600));
      } else {
        // Done
        setState(() => _autoPlaying = false);
        return;
      }
    }
    if (mounted) setState(() => _autoPlaying = false);
  }

  void _stopAutoPlay() {
    _autoPlaying = false;
    _autoPaused = false;
    _tts.stop();
    WakelockPlus.disable();
    _tts.stopForegroundService();
    setState(() {});
  }

  // ── toggle hard ─────────────────────────────────────────

  Future<void> _onToggleHard() async {
    final w = _words[_currentIndex];
    if (w.id == null) return;
    final newHard = !_isHard;
    await DbService.setHard(w.id!, newHard);
    // 互斥：标为难题 → 清除通过状态
    if (newHard) {
      await DbService.setPassed(w.id!, false);
    }
    setState(() {
      _isHard = newHard;
      if (newHard) _isPassed = false;
    });
    _treeKey.currentState?.refreshCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('单词宝典'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          if (isWide) {
            return Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Container(
                    color: Colors.grey[50],
                    child: _buildTreePanel(),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildContent()),
              ],
            );
          }
          // Mobile: full-screen card
          return Column(
            children: [
              Expanded(child: _buildContent()),
            ],
          );
        },
      ),
      // Mobile bottom bar
      bottomNavigationBar: Builder(
        builder: (context) {
          final isWide = MediaQuery.of(context).size.width >= 600;
          if (isWide) return const SizedBox.shrink();
          return BottomAppBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _showTreeSheet(context),
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: const Text('词汇'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTreePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GradeTreeWidget(
            key: _treeKey,
            onUnitSelected: _onUnitSelected,
            onUnitAutoPlay: _onUnitAutoPlay,
            onGradeSelected: _onGradeAutoPlay,
            onHardBookSelected: _onHardBookSelected,
            onHardBookAutoPlay: _onHardBookAutoPlay,
          ),
        ),
      ],
    );
  }

  void _dismissTree() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _showTreeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: _buildTreePanel(),
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
            Icon(
              _isHardMode ? Icons.star_border : Icons.check_circle_outline,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _isHardMode ? '还没有标记难题' : '本单元已全部过关！',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            if (!_isHardMode) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _resetCurrentUnit,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新开始'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _goToNextUnit,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('下一单元'),
                  ),
                ],
              ),
            ],
            if (_isHardMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '在学习中标为"难题"的单词会出现在这里',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ),
          ],
        ),
      );
    }

    final word = _words[_currentIndex];
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == _words.length - 1;

    return Column(
      children: [
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[500]),
            ),
            if (_isHardWordOverlay())
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.star, size: 14, color: Colors.orange),
              ),
            const Spacer(),
            Text(
              '${_words.length - _currentIndex} / $_initialCount',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black45),
            ),
          ],
        ),
        Expanded(
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (_autoPlaying) return; // no swipe during auto-play
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < -200) {
                _nextWord();
              } else if (details.primaryVelocity! > 200) {
                _prevWord();
              }
            },
            child: Center(
              child: WordCardWidget(
                word: word,
                tts: _tts,
                isPassed: _isPassed,
                isHard: _isHard,
                onPassed: _onPassed,
                onToggleHard: _onToggleHard,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: _autoPlaying
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _togglePause,
                      icon: Icon(_autoPaused ? Icons.play_arrow : Icons.pause,
                          size: 24, color: Colors.blue),
                      tooltip: _autoPaused ? '继续' : '暂停',
                    ),
                    IconButton(
                      onPressed: _stopAutoPlay,
                      icon: const Icon(Icons.stop, color: Colors.red, size: 24),
                      tooltip: '停止',
                    ),
                    IconButton(
                      onPressed: _onPassed,
                      icon: Icon(Icons.check_circle, size: 24,
                          color: _isPassed ? Colors.green : Colors.grey[400]!),
                      tooltip: '通过',
                    ),
                    IconButton(
                      onPressed: _onToggleHard,
                      icon: Icon(_isHard ? Icons.star : Icons.star_border, size: 24,
                          color: _isHard ? Colors.orange : Colors.grey[400]!),
                      tooltip: '标为难题',
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: isFirst ? null : _prevWord,
                      icon: Icon(Icons.arrow_back,
                          color: isFirst ? Colors.grey[300] : null),
                      tooltip: '上一词',
                    ),
                    IconButton(
                      onPressed: _onPassed,
                      icon: Icon(_isPassed ? Icons.check_circle : Icons.check_circle_outline,
                          size: 24,
                          color: _isPassed ? Colors.green : Colors.grey[500]!),
                      tooltip: '通过',
                    ),
                    IconButton(
                      onPressed: _onToggleHard,
                      icon: Icon(_isHard ? Icons.star : Icons.star_border, size: 24,
                          color: _isHard ? Colors.orange : Colors.grey[500]!),
                      tooltip: '标为难题',
                    ),
                    IconButton(
                      onPressed: isLast ? null : _nextWord,
                      icon: Icon(Icons.arrow_forward,
                          color: isLast ? Colors.grey[300] : null),
                      tooltip: '下一词',
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  bool _isHardWordOverlay() {
    // Show when the current word is hard but we're NOT in hard mode
    return !_isHardMode && _isHard;
  }
}
