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
  final _treeKey = GlobalKey<GradeTreeWidgetState>();
  List<Word> _words = [];
  int _currentIndex = 0;
  int _initialCount = 0;
  String _currentLabel = '';
  bool _loading = false;
  bool _isHardMode = false;
  int? _currentUnitId;
  bool _autoPlaying = false;

  bool _isPassed = false;
  bool _isHard = false;

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _onUnitSelected(int unitId, String unitName) async {
    _currentUnitId = unitId;
    await _loadWords(
      () => DbService.getWordsByUnit(unitId, skipPassed: true),
      unitName,
      false,
    );
  }

  Future<void> _onUnitAutoPlay(int unitId, String unitName) async {
    _treeKey.currentState?.selectUnit(unitId);
    await _onUnitSelected(unitId, unitName);
    if (mounted) _startAutoPlay();
  }

  Future<void> _onGradeAutoPlay(int gradeId, String gradeName) async {
    await _onGradeSelected(gradeId, gradeName);
    if (mounted) _startAutoPlay();
  }

  Future<void> _onHardBookAutoPlay() async {
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
    final w = _words[_currentIndex];
    _tts.preload(w.word);
    _tts.preload(w.sentence);
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
    await _playLoop();
  }

  Future<void> _playLoop() async {
    while (_autoPlaying && _words.isNotEmpty && _currentIndex < _words.length) {
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

  Widget _smallActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: active ? color : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
          color: active ? color.withAlpha(20) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? color : Colors.grey[500]),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? color : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  void _stopAutoPlay() {
    _autoPlaying = false;
    _tts.stop();
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
        title: const Text('英语宝典'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // ── 左侧 ──────────────────────────
          SizedBox(
            width: 220,
            child: Container(
              color: Colors.grey[50],
              child: Column(
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
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // ── 右侧 ──────────────────────────
          Expanded(child: _buildContent()),
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
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentLabel,
              style:
                  Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[500]),
            ),
            if (_isHardWordOverlay())
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.star, size: 14, color: Colors.orange),
              ),
          ],
        ),
        Expanded(
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: _autoPlaying
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _stopAutoPlay,
                      icon: const Icon(Icons.stop, size: 16),
                      label: const Text('停止', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _smallActionBtn(
                      icon: Icons.check_circle_outline,
                      label: _isPassed ? '已通过' : '通过',
                      color: Colors.green,
                      active: _isPassed,
                      onTap: _onPassed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_words.length - _currentIndex} / $_initialCount',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(width: 4),
                    _smallActionBtn(
                      icon: _isHard ? Icons.star : Icons.star_border,
                      label: _isHard ? '已标难' : '标难',
                      color: Colors.orange,
                      active: _isHard,
                      onTap: _onToggleHard,
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isFirst ? null : _prevWord,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('上一词'),
                    ),
                    // Pass button
                    _smallActionBtn(
                      icon: Icons.check_circle_outline,
                      label: _isPassed ? '已通过' : '通过',
                      color: Colors.green,
                      active: _isPassed,
                      onTap: _onPassed,
                    ),
                    Text(
                      '${_words.length - _currentIndex} / $_initialCount',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    // Hard button
                    _smallActionBtn(
                      icon: _isHard ? Icons.star : Icons.star_border,
                      label: _isHard ? '已标难' : '标为难题',
                      color: Colors.orange,
                      active: _isHard,
                      onTap: _onToggleHard,
                    ),
                    OutlinedButton.icon(
                      onPressed: isLast ? null : _nextWord,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('下一词'),
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
