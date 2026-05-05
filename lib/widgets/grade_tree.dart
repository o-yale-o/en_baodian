import 'package:flutter/material.dart';
import '../services/db_service.dart';

class GradeTreeWidget extends StatefulWidget {
  final void Function(int unitId, String unitName) onUnitSelected;
  final void Function(int unitId, String unitName) onUnitAutoPlay;
  final void Function(int gradeId, String gradeName) onGradeSelected;
  final VoidCallback onHardBookSelected;

  const GradeTreeWidget({
    super.key,
    required this.onUnitSelected,
    required this.onUnitAutoPlay,
    required this.onGradeSelected,
    required this.onHardBookSelected,
  });

  @override
  State<GradeTreeWidget> createState() => GradeTreeWidgetState();
}

class GradeTreeWidgetState extends State<GradeTreeWidget> {
  List<Map<String, dynamic>> _grades = [];
  Map<int, List<Map<String, dynamic>>> _unitsCache = {};
  Map<int, int> _wordCounts = {};
  Map<int, int> _passedCounts = {};
  Map<int, int> _gradeCounts = {};
  Map<int, int> _gradePassed = {};
  int? _selectedUnitId;
  bool _hardBookSelected = false;
  int _hardCount = 0;

  @override
  void initState() {
    super.initState();
    refreshCounts();
  }

  Future<void> refreshCounts() async {
    final grades = await DbService.getGrades();
    final counts = await DbService.getWordCounts();
    final passed = await DbService.getPassedCounts();
    final gradeCounts = <int, int>{};
    final gradePassed = <int, int>{};
    for (final g in grades) {
      final gid = g['id'] as int;
      gradeCounts[gid] = await DbService.getGradeWordCount(gid);
      gradePassed[gid] = await DbService.getGradePassedCount(gid);
    }
    final hard = await DbService.countHardWords();
    if (mounted) {
      setState(() {
        _grades = grades;
        _wordCounts = counts;
        _passedCounts = passed;
        _gradeCounts = gradeCounts;
        _gradePassed = gradePassed;
        _hardCount = hard;
      });
    }
  }

  String _rem(int total, int passed) => '${total - passed}/$total';

  Future<void> refreshHardCount() async {
    final count = await DbService.countHardWords();
    if (mounted) setState(() => _hardCount = count);
  }

  Future<List<Map<String, dynamic>>> _loadUnits(int gradeId) async {
    if (_unitsCache.containsKey(gradeId)) return _unitsCache[gradeId]!;
    final units = await DbService.getUnits(gradeId);
    _unitsCache[gradeId] = units;
    return units;
  }

  void selectUnit(int unitId) {
    setState(() {
      _selectedUnitId = unitId;
      _hardBookSelected = false;
    });
  }

  void _selectHardBook() {
    setState(() {
      _hardBookSelected = true;
      _selectedUnitId = null;
    });
    widget.onHardBookSelected();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── 难题本（全局） ──────────────
        ListTile(
          dense: true,
          selected: _hardBookSelected,
          selectedTileColor: Colors.orange.withAlpha(25),
          leading: Icon(Icons.star, size: 20, color: Colors.orange[700]),
          title: Text(
            '难题本 ($_hardCount)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: _hardBookSelected ? FontWeight.bold : FontWeight.w500,
              color: _hardBookSelected ? Colors.orange[800] : null,
            ),
          ),
          onTap: _selectHardBook,
        ),
        const Divider(height: 1),

        // ── 年级列表 ──────────────────
        if (_grades.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ..._grades.map((grade) {
            final gradeId = grade['id'] as int;
            return ExpansionTile(
              leading: const Icon(Icons.menu_book, size: 20),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${grade['name']} (${_rem(_gradeCounts[grade['id']] ?? 0, _gradePassed[grade['id']] ?? 0)})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  InkWell(
                    onTap: () => widget.onGradeSelected(
                        grade['id'] as int, grade['name'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.play_circle_outline, size: 20, color: Colors.blue),
                    ),
                  ),
                ],
              ),
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadUnits(gradeId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return Column(
                      children: snapshot.data!.map((unit) {
                        final unitId = unit['id'] as int;
                        final unitName = unit['name'] as String;
                        final isSelected = unitId == _selectedUnitId;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 56, right: 4),
                          selected: isSelected,
                          selectedTileColor: Colors.blue.withAlpha(25),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    '$unitName (${_rem(_wordCounts[unitId] ?? 0, _passedCounts[unitId] ?? 0)})',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            isSelected ? FontWeight.bold : FontWeight.normal)),
                              ),
                              InkWell(
                                onTap: () => widget.onUnitAutoPlay(unitId, unitName),
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.play_circle_outline,
                                      size: 17, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _selectedUnitId = unitId;
                              _hardBookSelected = false;
                            });
                            widget.onUnitSelected(unitId, unitName);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          }),
      ],
    );
  }
}
