/// Simple word-formation analyzer.
/// Identifies prefixes, roots, suffixes from known patterns.

class WordParts {
  final String? prefix;
  final String? prefixMeaning;
  final String? root;
  final String? suffix;
  final String? suffixMeaning;
  final String? note;

  const WordParts({this.prefix, this.prefixMeaning, this.root,
      this.suffix, this.suffixMeaning, this.note});

  bool get hasAnalysis => prefix != null || suffix != null;

  String format() {
    final p = <String>[];
    if (prefix != null) p.add('$prefix-($prefixMeaning)');
    if (root != null) p.add(root!);
    if (suffix != null) p.add('-$suffix($suffixMeaning)');
    String s = p.join(' + ');
    if (note != null) s += '  [$note]';
    return s;
  }
}

const _prefixes = <String, String>{
  'un': '不/相反', 're': '再/重新', 'pre': '前/预先', 'dis': '不/相反/除去',
  'in': '不/向内', 'im': '不/向内', 'ir': '不', 'il': '不',
  'mis': '错误', 'over': '过度/在上', 'under': '不足/在下', 'out': '超出/外',
  'sub': '下/次', 'inter': '相互/之间', 'trans': '横跨/转变', 'super': '超/上',
  'semi': '半', 'anti': '反/抗', 'mid': '中间', 'non': '非/无',
  'ex': '出/前', 'co': '共同', 'counter': '反/对', 'extra': '额外/超',
  'micro': '微', 'multi': '多', 'post': '后', 'auto': '自',
  'bi': '双/二', 'tri': '三', 'mono': '单', 'poly': '多',
  'en': '使/在…中', 'fore': '前/预', 'up': '向上', 'down': '向下',
};

const _suffixes = <String, String>{
  'tion': '名词(动作/状态)', 'sion': '名词(动作/状态)', 'ment': '名词(行为/结果)',
  'ness': '名词(性质/状态)', 'ity': '名词(性质)', 'ance': '名词(状态)',
  'ence': '名词(状态)', 'ship': '名词(关系/状态)', 'hood': '名词(时期/状态)',
  'ful': '形容词(充满)', 'less': '形容词(无/没有)', 'ous': '形容词(具有…性质)',
  'able': '形容词(能够)', 'ible': '形容词(能够)', 'ive': '形容词(有…倾向)',
  'al': '形容词(…的)', 'ic': '形容词(…的)', 'ical': '形容词(…的)',
  'ish': '形容词(有点/…似的)', 'like': '形容词(像…)',
  'ly': '副词/形容词(…地)', 'ward': '副词(向…)', 'wise': '副词(以…方式)',
  'er': '名词(做…的人/物)', 'or': '名词(做…的人/物)', 'ist': '名词(…家/主义者)',
  'ee': '名词(被…的人)', 'ess': '名词(女性)',
  'ize': '动词(使…化)', 'ise': '动词(使…化)', 'ify': '动词(使成为)',
  'ate': '动词/形容词', 'en': '动词(使变得)', 'ed': '形容词(…的/过去)',
  'ing': '名词/形容词(动作/状态)', 'th': '名词(…度/状态)',
  'ure': '名词(动作/结果)', 'age': '名词(集合/状态)',
};

WordParts analyze(String word) {
  final w = word.toLowerCase().trim();

  // Try prefix match (>2 chars, leaving at least 3 chars for root)
  for (final p in _prefixes.keys.where((k) => k.length >= 2)) {
    if (w.startsWith(p) && w.length > p.length + 2) {
      final root = w.substring(p.length);
      // Check suffix on the remaining part
      for (final s in _suffixes.keys.where((k) => k.length >= 2)) {
        if (root.endsWith(s) && root.length > s.length + 1) {
          final core = root.substring(0, root.length - s.length);
          if (core.length >= 2) {
            return WordParts(
              prefix: p, prefixMeaning: _prefixes[p],
              root: core, suffix: s, suffixMeaning: _suffixes[s],
            );
          }
        }
      }
      if (root.length >= 2) {
        return WordParts(
          prefix: p, prefixMeaning: _prefixes[p], root: root,
        );
      }
    }
  }

  // Try suffix match only (leaving at least 2 chars for root)
  for (final s in _suffixes.keys.where((k) => k.length >= 2)) {
    if (w.endsWith(s) && w.length > s.length + 2) {
      final core = w.substring(0, w.length - s.length);
      if (core.length >= 2) {
        return WordParts(root: core, suffix: s, suffixMeaning: _suffixes[s]);
      }
    }
  }

  // Compound words (two known words joined)
  for (final sep in ['man', 'woman', 'ball', 'board', 'book', 'house', 'room',
      'work', 'time', 'day', 'night', 'light', 'ground', 'body', 'thing',
      'where', 'ever', 'self', 'some', 'any', 'every', 'no']) {
    if (w.endsWith(sep) && w.length > sep.length + 2) {
      final first = w.substring(0, w.length - sep.length);
      if (first.length >= 2) {
        return WordParts(note: '复合词: $first + $sep');
      }
    }
  }

  return const WordParts();
}
