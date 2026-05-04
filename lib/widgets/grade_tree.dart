import 'package:flutter/material.dart';
import '../services/db_service.dart';

class GradeTreeWidget extends StatefulWidget {
  final void Function(int unitId, String unitName) onUnitSelected;

  const GradeTreeWidget({super.key, required this.onUnitSelected});

  @override
  State<GradeTreeWidget> createState() => _GradeTreeWidgetState();
}

class _GradeTreeWidgetState extends State<GradeTreeWidget> {
  List<Map<String, dynamic>> _grades = [];
  Map<int, List<Map<String, dynamic>>> _unitsCache = {};
  int? _selectedUnitId;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    final grades = await DbService.getGrades();
    setState(() => _grades = grades);
  }

  Future<List<Map<String, dynamic>>> _loadUnits(int gradeId) async {
    if (_unitsCache.containsKey(gradeId)) return _unitsCache[gradeId]!;
    final units = await DbService.getUnits(gradeId);
    _unitsCache[gradeId] = units;
    return units;
  }

  @override
  Widget build(BuildContext context) {
    if (_grades.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: _grades.map((grade) {
        final gradeId = grade['id'] as int;
        return ExpansionTile(
          leading: const Icon(Icons.menu_book, size: 20),
          title: Text(
            grade['name'] as String,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadUnits(gradeId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
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
                      contentPadding: const EdgeInsets.only(left: 56, right: 8),
                      selected: isSelected,
                      selectedTileColor: Colors.blue.withAlpha(25),
                      title: Text(unitName,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      onTap: () {
                        setState(() => _selectedUnitId = unitId);
                        widget.onUnitSelected(unitId, unitName);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      }).toList(),
    );
  }
}
