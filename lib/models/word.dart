class Word {
  final int? id;
  final int unitId;
  final String word;
  final String pronunciation;
  final String meaning;
  final String sentence;
  final String sentenceCn;

  const Word({
    this.id,
    required this.unitId,
    required this.word,
    required this.pronunciation,
    required this.meaning,
    required this.sentence,
    required this.sentenceCn,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'unit_id': unitId,
        'word': word,
        'pronunciation': pronunciation,
        'meaning': meaning,
        'sentence': sentence,
        'sentence_cn': sentenceCn,
      };

  factory Word.fromMap(Map<String, dynamic> map) => Word(
        id: map['id'] as int?,
        unitId: map['unit_id'] as int? ?? 0,
        word: map['word'] as String,
        pronunciation: map['pronunciation'] as String? ?? '',
        meaning: map['meaning'] as String? ?? '',
        sentence: map['sentence'] as String? ?? '',
        sentenceCn: map['sentence_cn'] as String? ?? '',
      );

  Word copyWith({int? id, int? unitId, String? word, String? pronunciation,
      String? meaning, String? sentence, String? sentenceCn}) =>
      Word(
        id: id ?? this.id,
        unitId: unitId ?? this.unitId,
        word: word ?? this.word,
        pronunciation: pronunciation ?? this.pronunciation,
        meaning: meaning ?? this.meaning,
        sentence: sentence ?? this.sentence,
        sentenceCn: sentenceCn ?? this.sentenceCn,
      );
}
