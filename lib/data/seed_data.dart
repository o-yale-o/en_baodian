import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../services/db_service.dart';
import '../models/word.dart';

Future<void> seedDatabase() async {
  if (!await DbService.needsSeed()) return;

  // ═══════════════════════════════════════════════════════════
  // 七年级上册 — 硬编码（含课文原句，2024新人教版完整版）
  // ═══════════════════════════════════════════════════════════
  final g7a = await DbService.insertGrade('七年级上册', 1);
  await _h77a(g7a); // detailed data below

  // ═══════════════════════════════════════════════════════════
  // 以下年级从 JSON 资产加载（英美音标 + 例句）
  // ═══════════════════════════════════════════════════════════

  await _loadJsonGrade('assets/PEPChuZhong7_2.json', '七年级下册', 2);
  await _loadJsonGrade('assets/PEPChuZhong8_1.json', '八年级上册', 3);

  // 八下：保留硬编码 U1-U4 + JSON 补充
  final g8b = await DbService.insertGrade('八年级下册', 4);
  await _h8bU1U4(g8b);
  await _loadJsonGrade('assets/PEPChuZhong8_2.json', '', -1, existingGradeId: g8b, startSortOrder: 5);

  await _loadJsonGrade('assets/PEPChuZhong9_1.json', '九年级全一册', 5);

  // ── 高中（PEP 人教版） ───────────────────────────────
  final g10 = await DbService.insertGrade('高一', 6);
  for (int i = 1; i <= 4; i++) {
    await _loadJsonGrade('assets/PEPGaoZhong_$i.json', '', -1, existingGradeId: g10, startSortOrder: 99);
  }
  final g11 = await DbService.insertGrade('高二', 7);
  for (int i = 5; i <= 8; i++) {
    await _loadJsonGrade('assets/PEPGaoZhong_$i.json', '', -1, existingGradeId: g11, startSortOrder: 99);
  }
  final g12 = await DbService.insertGrade('高三', 8);
  for (int i = 9; i <= 11; i++) {
    await _loadJsonGrade('assets/PEPGaoZhong_$i.json', '', -1, existingGradeId: g12, startSortOrder: 99);
  }

  // CET-4 / CET-6
  final cet4 = await DbService.insertGrade('CET-4 四级', 9);
  for (final f in ['assets/CET4_1.json', 'assets/CET4_2.json', 'assets/CET4_3.json']) {
    await _loadJsonGrade(f, '', -1, existingGradeId: cet4, startSortOrder: 99);
  }
  final cet6 = await DbService.insertGrade('CET-6 六级', 10);
  for (final f in ['assets/CET6_1.json', 'assets/CET6_2.json', 'assets/CET6_3.json']) {
    await _loadJsonGrade(f, '', -1, existingGradeId: cet6, startSortOrder: 99);
  }

  // 专八
  final tem8 = await DbService.insertGrade('专八', 11);
  await _loadJsonGrade('assets/Level8_1.json', '', -1, existingGradeId: tem8, startSortOrder: 99);
  await _loadJsonGrade('assets/Level8_2.json', '', -1, existingGradeId: tem8, startSortOrder: 99);
}

// ═══════════════════════════════════════════════════════════════
// JSON 加载器：读取 JSON → 按首字母分单元 → 入库
// ═══════════════════════════════════════════════════════════════

Map<String, int> _letterUnitIds = {};
int _letterSortCounter = 0;

Future<void> _loadJsonGrade(
  String assetPath,
  String gradeName,
  int gradeSort, {
  int? existingGradeId,
  int startSortOrder = 1,
}) async {
  final gradeId = existingGradeId ?? await DbService.insertGrade(gradeName, gradeSort);
  final json = await rootBundle.loadString(assetPath);
  final List<dynamic> entries = jsonDecode(json);
  final Map<String, List<Word>> groups = {};

  for (final e in entries) {
    final word = e['word']?.toString() ?? '';
    if (word.isEmpty) continue;
    String letter = word[0].toUpperCase();
    if (!RegExp(r'[A-Z]').hasMatch(letter)) letter = '#';
    groups.putIfAbsent(letter, () => []);
    groups[letter]!.add(_wordFromJson(e));
  }

  _letterSortCounter = startSortOrder;
  for (final letter in _allLetters) {
    final words = groups[letter];
    if (words == null || words.isEmpty) continue;
    final key = '${gradeId}_$letter';
    int unitId;
    if (_letterUnitIds.containsKey(key)) {
      unitId = _letterUnitIds[key]!;
    } else {
      unitId = await DbService.insertUnit(gradeId, '$letter', _letterSortCounter);
      _letterUnitIds[key] = unitId;
    }
    await DbService.insertWords(words.map((w) => w.copyWith(unitId: unitId)).toList());
    _letterSortCounter++;
  }
}

Word _wordFromJson(dynamic e) {
  final word = e['word']?.toString() ?? '';
  final uk = e['uk']?.toString();
  final us = e['us']?.toString();
  final pronunciation = [if (uk != null && uk.isNotEmpty) '英$uk', if (us != null && us.isNotEmpty) '美$us'].join(' ');
  final translations = (e['translations'] as List<dynamic>?)
      ?.map((t) => '${t['type'] ?? ''} ${t['translation'] ?? ''}'.trim())
      .join('；') ?? '';
  final sentences = e['sentences'] as List<dynamic>?;
  final sentence = sentences?.isNotEmpty == true
      ? sentences!.first['sentence']?.toString() ?? ''
      : '';
  final sentenceCn = sentences?.isNotEmpty == true
      ? sentences!.first['translation']?.toString() ?? ''
      : '';
  return Word(
    unitId: 0,
    word: word,
    pronunciation: pronunciation,
    meaning: translations,
    sentence: sentence,
    sentenceCn: sentenceCn,
  );
}

const _allLetters = [
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z','#',
];

// ═══════════════════════════════════════════════════════════════
// helpers
// ═══════════════════════════════════════════════════════════════

Word _w(String word, String pronunciation, String meaning,
    String sentence, String sentenceCn) {
  return Word(unitId: 0, word: word, pronunciation: pronunciation,
      meaning: meaning, sentence: sentence, sentenceCn: sentenceCn);
}

Future<void> _insertWords(int unitId, List<Word> words) async {
  await DbService.insertWords(
    words.map((w) => w.copyWith(unitId: unitId)).toList(),
  );
}

// ═══════════════════════════════════════════════════════════════
// 七年级上册 硬编码（含课文原句，2024新人教版）
// ═══════════════════════════════════════════════════════════════

Future<void> _h77a(int g7a) async {
  // Starter Unit 1-3, Units 1-7 — same as before
  final su1 = await DbService.insertUnit(g7a, 'Starter Unit 1: Hello!', 1);
  await _insertWords(su1, [
    _w('unit', '/ˈjuːnɪt/', 'n. 单元', 'This is Unit 1.', '这是第一单元。'),
    _w('greet', '/ɡriːt/', 'v. 招呼；问候', 'We should greet our teachers politely.', '我们应该礼貌地问候老师。'),
    _w('everyone', '/ˈevriwʌn/', 'pron. 每人；所有人', 'Everyone likes music.', '每个人都喜欢音乐。'),
    _w('start', '/stɑːrt/', 'v. 开始；着手', 'Let\'s start our class.', '我们开始上课吧。'),
    _w('conversation', '/ˌkɑːnvərˈseɪʃn/', 'n. 谈话；交谈', 'How do you start a conversation?', '你如何开始一段对话？'),
    _w('spell', '/spel/', 'v. 用字母拼；拼写', 'Can you spell your name?', '你能拼写你的名字吗？'),
    _w('bell', '/bel/', 'n. 铃(声)；钟(声)', 'The bell rings every day at 8 o\'clock.', '铃声每天八点响。'),
    _w('each', '/iːtʃ/', 'adj.&pron. 每个；各自', 'Each student has a book.', '每个学生都有一本书。'),
    _w('other', '/ˈʌðə(r)/', 'pron.&adj. 另外的；其他的', 'I have two pens. One is red, the other is blue.', '两支笔，一红一蓝。'),
    _w('each other', '/iːtʃ ˈʌðə(r)/', '互相；彼此', 'We learn from each other.', '我们互相学习。'),
    _w('hello', '/həˈloʊ/', 'interj. 你好', 'Hello, everyone!', '大家好！'),
    _w('morning', '/ˈmɔːrnɪŋ/', 'n. 早晨；上午', 'Good morning!', '早上好！'),
    _w('afternoon', '/ˌæftərˈnuːn/', 'n. 下午', 'Good afternoon!', '下午好！'),
    _w('evening', '/ˈiːvnɪŋ/', 'n. 晚上', 'Good evening!', '晚上好！'),
    _w('how', '/haʊ/', 'adv. 怎样；如何', 'How are you?', '你好吗？'),
    _w('fine', '/faɪn/', 'adj. 好的；健康的', 'I\'m fine, thank you.', '我很好，谢谢。'),
    _w('thanks', '/θæŋks/', 'interj.&n. 谢谢', 'Thanks a lot!', '非常感谢！'),
    _w('name', '/neɪm/', 'n. 名字', 'What\'s your name?', '你叫什么名字？'),
    _w('nice', '/naɪs/', 'adj. 令人愉快的', 'Nice to meet you.', '见到你很高兴。'),
    _w('meet', '/miːt/', 'v. 遇见；相逢', 'Nice to meet you, too.', '见到你也很高兴。'),
    _w('Ms', '/mɪz/', 'n. 女士', 'Good morning, Ms Gao.', '早上好，高老师。'),
    _w('class', '/klɑːs/', 'n. 班级；课', 'Good morning, class.', '同学们早上好。'),
    _w('sit down', '/sɪt daʊn/', '坐下', 'Sit down, please.', '请坐。'),
    _w('please', '/pliːz/', 'interj. 请', 'Sit down, please.', '请坐。'),
  ]);

  final su2 = await DbService.insertUnit(g7a, 'Starter Unit 2: Keep Tidy', 2);
  await _insertWords(su2, [
    _w('bottle', '/ˈbɒtl/', 'n. 瓶子', 'I have a bottle.', '我有一个瓶子。'),
    _w('eraser', '/ɪˈreɪzər/', 'n. 橡皮', '', ''),
    _w('key', '/kiː/', 'n. 钥匙；关键', '', ''),
    _w('thing', '/θɪŋ/', 'n. 东西；事情', '', ''),
    _w('need', '/niːd/', 'v.&n. 需要', 'You need to keep your room tidy.', '你要保持房间整洁。'),
    _w('tidy', '/ˈtaɪdi/', 'adj. 整洁的；v. 使整洁', 'Keep your room tidy.', '保持房间整洁。'),
    _w('cap', '/kæp/', 'n. 帽子', 'I have a cap.', '我有一顶帽子。'),
    _w('schoolbag', '/ˈskuːlbæɡ/', 'n. 书包', 'What do you have in your schoolbag?', '你书包里有什么？'),
    _w('ruler', '/ˈruːlər/', 'n. 尺子', 'I have a ruler.', '我有一把尺子。'),
    _w('glasses', '/ˈɡlɑːsɪz/', 'n. 眼镜', 'I can\'t find my new glasses.', '我找不到新眼镜了。'),
    _w('find', '/faɪnd/', 'v. 找到；发现', 'I can\'t find my new cap.', '找不到新帽子。'),
    _w('colour', '/ˈkʌlər/', 'n. 颜色', 'What colour is it?', '它是什么颜色？'),
    _w('red', '/red/', 'adj.&n. 红色', 'It\'s red.', '它是红色的。'),
    _w('blue', '/bluː/', 'adj.&n. 蓝色', '', ''),
    _w('black', '/blæk/', 'adj.&n. 黑色', '', ''),
    _w('white', '/waɪt/', 'adj.&n. 白色', '', ''),
    _w('brown', '/braʊn/', 'adj.&n. 棕色', 'They\'re brown.', '它们是棕色的。'),
    _w('under', '/ˈʌndər/', 'prep. 在…下面', 'It\'s under your desk.', '在你书桌下面。'),
    _w('desk', '/desk/', 'n. 书桌', 'It\'s under your desk.', '在你书桌下面。'),
    _w('room', '/ruːm/', 'n. 房间', 'Keep your room tidy.', '保持房间整洁。'),
    _w('sorry', '/ˈsɒri/', 'interj. 对不起', 'OK. Sorry, Mum.', '好的，对不起，妈妈。'),
    _w('keep', '/kiːp/', 'v. 保持；保留', 'Keep your room tidy.', '保持房间整洁。'),
  ]);

  final su3 = await DbService.insertUnit(g7a, 'Starter Unit 3: Welcome!', 3);
  await _insertWords(su3, [
    _w('fun', '/fʌn/', 'n.&adj. 乐趣；快乐的', '', ''),
    _w('yard', '/jɑːrd/', 'n. 院子；园圃', 'What does Helen see in the yard?', '海伦在院子里看到了什么？'),
    _w('carrot', '/ˈkærət/', 'n. 胡萝卜', '', ''),
    _w('goose', '/ɡuːs/', 'n. 鹅 (pl. geese)', '', ''),
    _w('count', '/kaʊnt/', 'v. 数数', '', ''),
    _w('another', '/əˈnʌðər/', 'adj.&pron. 另一', 'Another duck is behind the tree.', '另一只鸭子在树后。'),
    _w('look at', '/lʊk æt/', '看；瞧', 'Look at the farm!', '看那个农场！'),
    _w('welcome', '/ˈwelkəm/', 'interj.&v. 欢迎', 'Welcome to my house.', '欢迎来我家。'),
    _w('animal', '/ˈænɪml/', 'n. 动物', 'What animal does Helen see?', '海伦看到了什么动物？'),
    _w('plant', '/plɑːnt/', 'n. 植物', 'They\'re carrot plants.', '它们是胡萝卜苗。'),
    _w('behind', '/bɪˈhaɪnd/', 'prep. 在…后面', 'Behind the big tree.', '在大树后面。'),
    _w('house', '/haʊs/', 'n. 房子', 'Welcome to my house.', '欢迎来我家。'),
    _w('show', '/ʃəʊ/', 'v. 给…看；展示', 'Let me show you around.', '让我带你看看。'),
    _w('how many', '/haʊ ˈmeni/', '多少', 'How many apple trees do you have?', '你有多少棵苹果树？'),
    _w('kind', '/kaɪnd/', 'n. 种类', 'Many kinds of animals.', '很多种动物。'),
  ]);

  final u1 = await DbService.insertUnit(g7a, 'Unit 1: You and Me', 4);
  await _insertWords(u1, [
    _w('make friends', '/meɪk frendz/', '交朋友', '', ''),
    _w('full name', '/fʊl neɪm/', '全名', 'What\'s your full name?', '你的全名是什么？'),
    _w('grade', '/ɡreɪd/', 'n. 年级；等级', 'I\'m in Class 1, Grade 7.', '我在七年级一班。'),
    _w('last name', '/lɑːst neɪm/', '姓氏', 'Smith is my last name.', '史密斯是我的姓。'),
    _w('classmate', '/ˈklɑːsmeɪt/', 'n. 同班同学', 'Peter is my classmate.', '彼得是我的同班同学。'),
    _w('class teacher', '/klɑːs ˈtiːtʃər/', '班主任', 'Who\'s your class teacher?', '谁是你们班主任？'),
    _w('first name', '/fɜːrst neɪm/', '名字', 'Her first name is Emma.', '她的名字叫埃玛。'),
    _w('mistake', '/mɪˈsteɪk/', 'n. 错误；失误', 'Everyone makes mistakes.', '每个人都会犯错。'),
    _w('country', '/ˈkʌntri/', 'n. 国家', 'China is a big country.', '中国是一个大国。'),
    _w('same', '/seɪm/', 'adj. 相同的', 'Are they in the same class?', '他们在同一个班吗？'),
    _w('both', '/bəʊθ/', 'adj.&pron. 两个都', 'We are both in the band.', '我们俩都在乐队。'),
    _w('band', '/bænd/', 'n. 乐队', 'Tom and I are both in the school band.', '汤姆和我都在学校乐队。'),
    _w('pot', '/pɒt/', 'n. 锅', '', ''),
    _w('a lot', '/ə lɒt/', '很；非常', 'Thanks a lot!', '非常感谢！'),
    _w('tofu', '/ˈtəʊfuː/', 'n. 豆腐', 'Mapo tofu is delicious.', '麻婆豆腐很好吃。'),
    _w('parrot', '/ˈpærət/', 'n. 鹦鹉', 'The parrot can talk.', '鹦鹉会说话。'),
    _w('guitar', '/ɡɪˈtɑːr/', 'n. 吉他', 'He plays the guitar.', '他弹吉他。'),
    _w('tennis', '/ˈtenɪs/', 'n. 网球', 'I like playing tennis.', '我喜欢打网球。'),
    _w('post', '/pəʊst/', 'n.&v. 帖子；邮寄', 'I saw your post online.', '我看到你的帖子。'),
    _w('would', '/wʊd/', 'modal v. 想；将会', 'Would you like some tea?', '想喝点茶吗？'),
    _w('information', '/ˌɪnfəˈmeɪʃn/', 'n. 信息；消息', 'Can you give me some information?', '能给我一些信息吗？'),
    _w('hobby', '/ˈhɒbi/', 'n. 业余爱好', 'My hobby is reading books.', '我的爱好是读书。'),
    _w('hot pot', '/hɒt pɒt/', '火锅', 'Let\'s eat hot pot!', '我们吃火锅吧！'),
    _w('live', '/lɪv/', 'v. 居住；生活', 'She lives in Chengdu.', '她住在成都。'),
    _w('parent', '/ˈpeərənt/', 'n. 父(母)亲', 'She lives with her parents.', '她和父母住在一起。'),
  ]);

  final u2 = await DbService.insertUnit(g7a, 'Unit 2: We\'re Family!', 5);
  await _insertWords(u2, [
    _w('mean', '/miːn/', 'v. 意思是；打算', '', ''),
    _w('husband', '/ˈhʌzbənd/', 'n. 丈夫', '', ''),
    _w('bat', '/bæt/', 'n. 球棒；球拍', '', ''),
    _w('ping-pong bat', '/ˈpɪŋ pɒŋ bæt/', '乒乓球拍', 'They have nice ping-pong bats.', '他们有好的乒乓球拍。'),
    _w('play ping-pong', '/pleɪ ˈpɪŋ pɒŋ/', '打乒乓球', 'Teng Fei plays ping-pong every week.', '腾飞每周打乒乓球。'),
    _w('every day', '/ˈevri deɪ/', '每天', '', ''),
    _w('together', '/təˈɡeðər/', 'adv. 在一起', '', ''),
    _w('fishing rod', '/ˈfɪʃɪŋ rɒd/', '钓竿', 'Teng Fei\'s father has a fishing rod.', '腾飞爸爸有钓竿。'),
    _w('spend', '/spend/', 'v. 花(时间、钱)', 'Does your father spend a lot of time fishing?', '你爸爸花很多时间钓鱼吗？'),
    _w('a lot of', '/ə lɒt ɒv/', '大量；许多', 'Spend a lot of time.', '花很多时间。'),
    _w('really', '/ˈriːəli/', 'adv. 非常；确实', '', ''),
    _w('activity', '/ækˈtɪvəti/', 'n. 活动', '', ''),
    _w('chess', '/tʃes/', 'n. 国际象棋', '', ''),
    _w('funny', '/ˈfʌni/', 'adj. 好笑的', '', ''),
    _w('laugh', '/lɑːf/', 'v.&n. 笑；笑声', '', ''),
    _w('different', '/ˈdɪfrənt/', 'adj. 不同的', '', ''),
    _w('violin', '/ˌvaɪəˈlɪn/', 'n. 小提琴', '', ''),
    _w('have fun', '/hæv fʌn/', '玩得高兴', '', ''),
    _w('pink', '/pɪŋk/', 'adj.&n. 粉红色', '', ''),
    _w('hat', '/hæt/', 'n. 帽子', '', ''),
    _w('handsome', '/ˈhænsəm/', 'adj. 英俊的', '', ''),
    _w('knee', '/niː/', 'n. 膝盖', '', ''),
    _w('at night', '/æt naɪt/', '在夜晚', '', ''),
    _w('son', '/sʌn/', 'n. 儿子', '', ''),
    _w('next to', '/nekst tə/', '紧邻；在…近旁', '', ''),
    _w('hike', '/haɪk/', 'v.&n. 远足', '', ''),
    _w('go hiking', '/ɡəʊ ˈhaɪkɪŋ/', '远足', '', ''),
    _w('family', '/ˈfæməli/', 'n. 家庭', 'We\'re a big family.', '我们是个大家庭。'),
    _w('grandfather', '/ˈɡrænfɑːðər/', 'n. (外)祖父', 'Teng Fei and his grandfather play every week.', '腾飞和爷爷每周打球。'),
    _w('love', '/lʌv/', 'v.&n. 喜爱', 'Teng Fei\'s grandfather loves sport.', '腾飞爷爷热爱运动。'),
    _w('sport', '/spɔːrt/', 'n. 运动', 'Loves sport.', '热爱运动。'),
    _w('piano', '/piˈænəʊ/', 'n. 钢琴', 'Do you play the piano?', '你会弹钢琴吗？'),
    _w('father', '/ˈfɑːðər/', 'n. 父亲', 'Does your father spend a lot of time fishing?', '你爸爸花很多时间钓鱼吗？'),
    _w('mother', '/ˈmʌðər/', 'n. 母亲', 'Does your mother have a piano?', '你妈妈有钢琴吗？'),
    _w('fish', '/fɪʃ/', 'v.&n. 钓鱼；鱼', '', ''),
  ]);

  final u3 = await DbService.insertUnit(g7a, 'Unit 3: My School', 6);
  await _insertWords(u3, [
    _w('hall', '/hɔːl/', 'n. 礼堂；大厅', '', ''),
    _w('dining hall', '/ˈdaɪnɪŋ hɔːl/', '餐厅', '', ''),
    _w('in front of', '/ɪn frʌnt əv/', '在…前面', 'There are trees in front of the sports field.', '运动场前有树。'),
    _w('building', '/ˈbɪldɪŋ/', 'n. 建筑物；房子', '', ''),
    _w('across', '/əˈkrɒs/', 'prep.&adv. 过；穿过', '', ''),
    _w('across from', '/əˈkrɒs frɒm/', '在对面', '', ''),
    _w('field', '/fiːld/', 'n. 场地；田地', '', ''),
    _w('sports field', '/spɔːrts fiːld/', '运动场', 'In front of the sports field.', '在运动场前面。'),
    _w('gym', '/dʒɪm/', 'n. 体育馆；健身房', '', ''),
    _w('office', '/ˈɒfɪs/', 'n. 办公室', '', ''),
    _w('large', '/lɑːrdʒ/', 'adj. 大的', '', ''),
    _w('special', '/ˈspeʃl/', 'adj. 特别的', '', ''),
    _w('smart', '/smɑːrt/', 'adj. 智能的；聪明的', '', ''),
    _w('whiteboard', '/ˈwaɪtbɔːrd/', 'n. 白板', 'Is there a whiteboard?', '有白板吗？'),
    _w('important', '/ɪmˈpɔːrtnt/', 'adj. 重要的', '', ''),
    _w('locker', '/ˈlɒkər/', 'n. 储物柜', 'Are there any lockers?', '有储物柜吗？'),
    _w('drawer', '/drɔːr/', 'n. 抽屉', '', ''),
    _w('corner', '/ˈkɔːrnər/', 'n. 角；墙角', '', ''),
    _w('bookcase', '/ˈbʊkkeɪs/', 'n. 书架', 'They are next to the window.', '在窗户旁边。'),
    _w('screen', '/skriːn/', 'n. 屏幕', '', ''),
    _w('modern', '/ˈmɒdn/', 'adj. 现代的', '', ''),
    _w('amazing', '/əˈmeɪzɪŋ/', 'adj. 令人惊奇的', '', ''),
    _w('raise', '/reɪz/', 'v. 使升高；提高', '', ''),
    _w('flag', '/flæɡ/', 'n. 旗；旗帜', '', ''),
    _w('change', '/tʃeɪndʒ/', 'v.&n. 改变；变化', '', ''),
    _w('seat', '/siːt/', 'n. 座位', '', ''),
    _w('delicious', '/dɪˈlɪʃəs/', 'adj. 美味的', '', ''),
    _w('yours', '/jɔːrz/', 'pron. 你的；您的', '', ''),
    _w('sound', '/saʊnd/', 'v.&n. 听起来；声音', '', ''),
    _w('bye for now', '/baɪ fə naʊ/', '再见', '', ''),
    _w('library', '/ˈlaɪbrəri/', 'n. 图书馆', 'Where is the library?', '图书馆在哪里？'),
    _w('classroom', '/ˈklɑːsruːm/', 'n. 教室', '', ''),
    _w('between', '/bɪˈtwiːn/', 'prep. 在…之间', 'Between the buildings.', '在两栋楼之间。'),
    _w('window', '/ˈwɪndəʊ/', 'n. 窗', 'Next to the window.', '在窗户旁边。'),
  ]);

  final u4 = await DbService.insertUnit(g7a, 'Unit 4: My Favourite Subject', 7);
  await _insertWords(u4, [
    _w('biology', '/baɪˈɒlədʒi/', 'n. 生物学', 'Biology is difficult but important.', '生物很难但很重要。'),
    _w('IT', '/ˌaɪ ˈtiː/', 'abbr. 信息技术', '', ''),
    _w('geography', '/dʒiˈɒɡrəfi/', 'n. 地理(学)', 'I have art and geography today.', '今天有美术和地理。'),
    _w('history', '/ˈhɪstri/', 'n. 历史；历史课', 'History is my favourite subject.', '历史是我最爱的科目。'),
    _w('boring', '/ˈbɔːrɪŋ/', 'adj. 乏味的', 'Maths is boring to him.', '数学对他来说很无聊。'),
    _w('useful', '/ˈjuːsfl/', 'adj. 有用的', '', ''),
    _w('exciting', '/ɪkˈsaɪtɪŋ/', 'adj. 令人激动的', '', ''),
    _w('past', '/pɑːst/', 'n.&adj.&prep. 过去', '', ''),
    _w('number', '/ˈnʌmbər/', 'n. 数字；号码', '', ''),
    _w('reason', '/ˈriːzn/', 'n. 原因；理由', '', ''),
    _w('listen to', '/ˈlɪsn tə/', '听；倾听', '', ''),
    _w('good at', '/ɡʊd æt/', '擅长', '', ''),
    _w('remember', '/rɪˈmembər/', 'v. 记住；记起', '', ''),
    _w('AM', '/ˌeɪ ˈem/', '上午', '', ''),
    _w('PM', '/ˌpiː ˈem/', '下午', '', ''),
    _w('French', '/frentʃ/', 'n.&adj. 法语', '', ''),
    _w('excellent', '/ˈeksələnt/', 'adj. 优秀的', '', ''),
    _w('instrument', '/ˈɪnstrəmənt/', 'n. 器械；工具', '', ''),
    _w('singer', '/ˈsɪŋər/', 'n. 歌手', '', ''),
    _w('future', '/ˈfjuːtʃər/', 'n. 将来；未来', '', ''),
    _w('term', '/tɜːrm/', 'n. 学期', '', ''),
    _w('problem', '/ˈprɒbləm/', 'n. 难题；困难', '', ''),
    _w('magic', '/ˈmædʒɪk/', 'n.&adj. 魔法', '', ''),
    _w('life', '/laɪf/', 'n. 生活；生命', '', ''),
    _w('scientist', '/ˈsaɪəntɪst/', 'n. 科学家', '', ''),
    _w('favourite', '/ˈfeɪvərɪt/', 'adj. 最喜爱的', 'History is my favourite subject.', '历史是我最爱的科目。'),
    _w('subject', '/ˈsʌbdʒɪkt/', 'n. 科目；学科', 'My favourite subject.', '我最爱的科目。'),
    _w('English', '/ˈɪŋɡlɪʃ/', 'n. 英语', 'English is important.', '英语很重要。'),
    _w('maths', '/mæθs/', 'n. 数学', 'He doesn\'t like maths.', '他不喜欢数学。'),
    _w('Chinese', '/ˌtʃaɪˈniːz/', 'n.&adj. 汉语', 'I like Chinese.', '我喜欢语文。'),
    _w('art', '/ɑːrt/', 'n. 美术；艺术', 'I have art today.', '今天有美术。'),
    _w('music', '/ˈmjuːzɪk/', 'n. 音乐', '', ''),
    _w('teacher', '/ˈtiːtʃər/', 'n. 老师', 'My English teacher is nice.', '英语老师很好。'),
    _w('difficult', '/ˈdɪfɪkəlt/', 'adj. 困难的', 'Biology is difficult.', '生物很难。'),
    _w('because', '/bɪˈkɒz/', 'conj. 因为', 'Because it is fun.', '因为它有趣。'),
  ]);

  final u5 = await DbService.insertUnit(g7a, 'Unit 5: Fun Clubs', 8);
  await _insertWords(u5, [
    _w('club', '/klʌb/', 'n. 俱乐部；社团', '', ''),
    _w('join', '/dʒɔɪn/', 'v. 参加；加入', '', ''),
    _w('choose', '/tʃuːz/', 'v. 选择；挑选', '', ''),
    _w('drama', '/ˈdrɑːmə/', 'n. 戏剧', '', ''),
    _w('play Chinese chess', '/pleɪ tʃaɪˈniːz tʃes/', '下中国象棋', 'Can they play chess?', '他们会下棋吗？'),
    _w('feeling', '/ˈfiːlɪŋ/', 'n. 感觉；情感', '', ''),
    _w('news', '/njuːz/', 'n. 消息；新闻', '', ''),
    _w('musical', '/ˈmjuːzɪkl/', 'adj. 音乐的', '', ''),
    _w('musical instrument', '/ˈmjuːzɪkl ˈɪnstrəmənt/', '乐器', 'Emma can\'t play any musical instruments.', '埃玛不会任何乐器。'),
    _w('drum', '/drʌm/', 'n. 鼓', '', ''),
    _w('ability', '/əˈbɪləti/', 'n. 能力；才能', '', ''),
    _w('paint', '/peɪnt/', 'v.&n. 用颜料画；油漆', '', ''),
    _w('climb', '/klaɪm/', 'v. 攀登；爬', '', ''),
    _w('more', '/mɔːr/', 'adj.&pron. 更多', '', ''),
    _w('act', '/ækt/', 'v.&n. 扮演；行动', '', ''),
    _w('act out', '/ækt aʊt/', '表演', '', ''),
    _w('interested', '/ˈɪntrəstɪd/', 'adj. 感兴趣的', '', ''),
    _w('interested in', '/ˈɪntrəstɪd ɪn/', '对…感兴趣', '', ''),
    _w('nature', '/ˈneɪtʃər/', 'n. 自然界', '', ''),
    _w('beef', '/biːf/', 'n. 牛肉', '', ''),
    _w('soon', '/suːn/', 'adv. 不久；很快', '', ''),
    _w('than', '/ðæn/', 'prep.&conj. 比', '', ''),
    _w('mind', '/maɪnd/', 'n. 头脑；心思', '', ''),
    _w('fall', '/fɔːl/', 'v.&n. 掉落；秋天', '', ''),
    _w('take photos', '/teɪk ˈfəʊtəʊz/', '拍照', '', ''),
    _w('collect', '/kəˈlekt/', 'v. 收集；采集', '', ''),
    _w('insect', '/ˈɪnsekt/', 'n. 昆虫', '', ''),
    _w('discover', '/dɪˈskʌvər/', 'v. 发现；发觉', '', ''),
    _w('wildlife', '/ˈwaɪldlaɪf/', 'n. 野生动物', '', ''),
    _w('can', '/kæn/', 'modal v. 能；会', 'Can you play ping-pong?', '你会打乒乓球吗？'),
    _w('sing', '/sɪŋ/', 'v. 唱歌', 'Emma can sing well.', '埃玛唱得好。'),
    _w('swim', '/swɪm/', 'v. 游泳', 'I can run fast, but I can\'t swim.', '我能跑快但不会游泳。'),
    _w('run', '/rʌn/', 'v. 跑', 'I can run fast.', '我能跑得快。'),
    _w('well', '/wel/', 'adv. 好地', 'Emma can sing well.', '埃玛唱得好。'),
  ]);

  final u6 = await DbService.insertUnit(g7a, 'Unit 6: A Day in the Life', 9);
  await _insertWords(u6, [
    _w('shower', '/ˈʃaʊər/', 'n.&v. 淋浴', 'He takes a shower.', '他洗淋浴。'),
    _w('take a shower', '/teɪk ə ˈʃaʊər/', '淋浴', 'He takes a shower.', '他洗淋浴。'),
    _w('get dressed', '/ɡet drest/', '穿衣服', '', ''),
    _w('brush', '/brʌʃ/', 'v.&n. 刷；刷子', 'He brushes his teeth.', '他刷牙。'),
    _w('tooth', '/tuːθ/', 'n. 牙齿 (pl. teeth)', 'He brushes his teeth.', '他刷牙。'),
    _w('duty', '/ˈdjuːti/', 'n. 值班；职责', '', ''),
    _w('on duty', '/ɒn ˈdjuːti/', '值班', '', ''),
    _w('usually', '/ˈjuːʒuəli/', 'adv. 通常地', 'When do you usually get up?', '你通常几点起床？'),
    _w('get up', '/ɡet ʌp/', '起床', 'I usually get up at 6:30.', '我通常六点半起床。'),
    _w('reporter', '/rɪˈpɔːrtər/', 'n. 记者', '', ''),
    _w('around', '/əˈraʊnd/', 'prep.&adv. 大约', '', ''),
    _w('homework', '/ˈhəʊmwɜːrk/', 'n. 家庭作业', 'I do my homework.', '我做作业。'),
    _w('go to bed', '/ɡəʊ tə bed/', '上床睡觉', 'When does Tom go to bed?', '汤姆几点上床？'),
    _w('stay', '/steɪ/', 'v. 停留；待', '', ''),
    _w('routine', '/ruːˈtiːn/', 'n. 常规', '', ''),
    _w('restaurant', '/ˈrestrɒnt/', 'n. 餐馆', '', ''),
    _w('housework', '/ˈhaʊswɜːrk/', 'n. 家务劳动', '', ''),
    _w('while', '/waɪl/', 'n.&conj. 一段时间', '', ''),
    _w('weekend', '/ˌwiːkˈend/', 'n. 周末', '', ''),
    _w('daily', '/ˈdeɪli/', 'adj. 每日的', '', ''),
    _w('break', '/breɪk/', 'n.&v. 休息', '', ''),
    _w('finish', '/ˈfɪnɪʃ/', 'v. 结束；完成', '', ''),
    _w('hockey', '/ˈhɒki/', 'n. 曲棍球', '', ''),
    _w('already', '/ɔːlˈredi/', 'adv. 已经', '', ''),
    _w('dark', '/dɑːrk/', 'adj. 昏暗的', '', ''),
    _w('outside', '/ˌaʊtˈsaɪd/', 'adv.&adj. 在外面', '', ''),
    _w('prepare', '/prɪˈpeər/', 'v. 准备', '', ''),
    _w('time', '/taɪm/', 'n. 时间', 'What time do you get up?', '你几点起床？'),
    _w('sometimes', '/ˈsʌmtaɪmz/', 'adv. 有时', 'I read books or do homework.', '读书或做作业。'),
    _w('before', '/bɪˈfɔːr/', 'prep. 在…之前', 'Before breakfast.', '早餐前。'),
    _w('after', '/ˈɑːftər/', 'prep. 在…之后', 'After dinner.', '晚饭后。'),
    _w('dinner', '/ˈdɪnər/', 'n. 晚餐；正餐', 'What do you do after dinner?', '晚饭后做什么？'),
    _w('breakfast', '/ˈbrekfəst/', 'n. 早餐', 'Before breakfast.', '早餐前。'),
    _w('read', '/riːd/', 'v. 阅读', 'I read books.', '我读书。'),
  ]);

  final u7 = await DbService.insertUnit(g7a, 'Unit 7: Happy Birthday!', 10);
  await _insertWords(u7, [
    _w('celebrate', '/ˈselɪbreɪt/', 'v. 庆祝', '', ''),
    _w('surprise', '/sərˈpraɪz/', 'n.&v. 惊奇', '', ''),
    _w('something', '/ˈsʌmθɪŋ/', 'pron. 某事', '', ''),
    _w('sale', '/seɪl/', 'n. 出售；销售', '', ''),
    _w('kilo', '/ˈkiːləʊ/', 'n. 千克', 'Six yuan a kilo.', '六元一公斤。'),
    _w('yoghurt', '/ˈjɒɡət/', 'n. 酸奶', '', ''),
    _w('total', '/ˈtəʊtl/', 'n.&adj. 总数', '', ''),
    _w('price', '/praɪs/', 'n. 价格', '', ''),
    _w('balloon', '/bəˈluːn/', 'n. 气球', '', ''),
    _w('chocolate', '/ˈtʃɒklət/', 'n. 巧克力', '', ''),
    _w('pizza', '/ˈpiːtsə/', 'n. 比萨饼', '', ''),
    _w('list', '/lɪst/', 'v.&n. 列表', '', ''),
    _w('own', '/əʊn/', 'adj.&pron. 自己的', '', ''),
    _w('example', '/ɪɡˈzɑːmpl/', 'n. 例子', '', ''),
    _w('for example', '/fɔːr ɪɡˈzɑːmpl/', '例如', '', ''),
    _w('language', '/ˈlæŋɡwɪdʒ/', 'n. 语言', '', ''),
    _w('international', '/ˌɪntərˈnæʃnəl/', 'adj. 国际的', '', ''),
    _w('mark', '/mɑːrk/', 'v.&n. 做记号', '', ''),
    _w('date', '/deɪt/', 'n. 日期', '', ''),
    _w('national', '/ˈnæʃnəl/', 'adj. 国家的', '', ''),
    _w('found', '/faʊnd/', 'v. 创建；创立', '', ''),
    _w('make a wish', '/meɪk ə wɪʃ/', '许愿', '', ''),
    _w('village', '/ˈvɪlɪdʒ/', 'n. 村庄', '', ''),
    _w('grow', '/ɡrəʊ/', 'v. 成长；长大', '', ''),
    _w('blow', '/bləʊ/', 'v. 吹；刮', '', ''),
    _w('blow out', '/bləʊ aʊt/', '吹灭', '', ''),
    _w('enjoy', '/ɪnˈdʒɔɪ/', 'v. 享受', '', ''),
    _w('height', '/haɪt/', 'n. 身高；高度', '', ''),
    _w('later', '/ˈleɪtər/', 'adv.&adj. 以后', '', ''),
    _w('who', '/huː/', 'pron. 谁', '', ''),
    _w('birthday', '/ˈbɜːrθdeɪ/', 'n. 生日', 'When is your birthday?', '你的生日什么时候？'),
    _w('August', '/ˈɔːɡəst/', 'n. 八月', 'It\'s on 2nd August.', '八月二号。'),
    _w('how old', '/haʊ əʊld/', '多大年纪', 'How old are you?', '你多大了？'),
    _w('twelve', '/twelv/', 'num. 十二', 'I\'m twelve.', '我十二岁。'),
    _w('want', '/wɒnt/', 'v. 想要', 'What do you want?', '你想要什么？'),
    _w('song', '/sɒŋ/', 'n. 歌', 'I want to sing a song.', '我想唱首歌。'),
    _w('how much', '/haʊ mʌtʃ/', '多少(钱)', 'How much are those oranges?', '那些橙子多少钱？'),
    _w('yuan', '/juˈɑːn/', 'n. 元', 'Six yuan a kilo.', '六元一公斤。'),
  ]);
}

// ═══════════════════════════════════════════════════════════════
// 八下 Unit 1-4 硬编码（来自 xjhjtz 词库，暂无音标）
// ═══════════════════════════════════════════════════════════════

Future<void> _h8bU1U4(int g8b) async {
  final u1 = await DbService.insertUnit(g8b, 'Unit 1: Learning New Things', 1);
  await _insertWords(u1, [
    _w('calligraphy', '', 'n. 书法', '', ''),
    _w('ski', '', 'v. 滑雪', '', ''),
    _w('program', '', 'v. 编写程序；n. 节目', '', ''),
    _w('express', '', 'v. 表达', '', ''),
    _w('instructor', '', 'n. 教练；指导者', '', ''),
    _w('scared', '', 'adj. 害怕的', '', ''),
    _w('fear', '', 'n.&v. 害怕；担忧', '', ''),
    _w('poem', '', 'n. 诗', '', ''),
    _w('single', '', 'adj. 单个的；单身的', '', ''),
    _w('stroke', '', 'n. 笔画；击球', '', ''),
    _w('ink', '', 'n. 墨水', '', ''),
    _w('return', '', 'v.&n. 回来；归还', '', ''),
    _w('deal', '', 'n. 协议；交易', '', ''),
    _w('manage', '', 'v. 完成；管理', '', ''),
    _w('ice-skate', '', 'v. 滑冰', '', ''),
    _w('push', '', 'v. 鞭策；推', '', ''),
    _w('chat', '', 'v.&n. 聊天', '', ''),
    _w('outing', '', 'n. 远足', '', ''),
    _w('reduce', '', 'v. 减少', '', ''),
    _w('stress', '', 'n. 精神压力', '', ''),
    _w('yoga', '', 'n. 瑜伽', '', ''),
    _w('object', '', 'n. 物品；宾语', '', ''),
    _w('Italian', '', 'adj.&n. 意大利的', '', ''),
    _w('programmer', '', 'n. 程序设计员', '', ''),
    _w('allow', '', 'v. 使…成为可能；允许', '', ''),
    _w('achievement', '', 'n. 成就', '', ''),
    _w('coin', '', 'n. 硬币', '', ''),
    _w('stamp', '', 'n. 邮票', '', ''),
    _w('teenage', '', 'adj. 青少年的', '', ''),
    _w('postcard', '', 'n. 明信片', '', ''),
    _w('rather', '', 'adv. 相当', '', ''),
    _w('old-fashioned', '', 'adj. 过时的', '', ''),
    _w('foreign', '', 'adj. 外国的', '', ''),
    _w('suggestion', '', 'n. 建议', '', ''),
    _w('failure', '', 'n. 失败', '', ''),
    _w('inspiration', '', 'n. 灵感', '', ''),
    _w('strict', '', 'adj. 严格的', '', ''),
    _w('surprisingly', '', 'adv. 惊人地', '', ''),
    _w('stage', '', 'n. 阶段；舞台', '', ''),
    _w('importantly', '', 'adv. 重要地', '', ''),
    _w('give up', '', '放弃', '', ''),
    _w('get over', '', '克服；解决', '', ''),
    _w('get into', '', '开始做', '', ''),
    _w('give it a go', '', '试一试', '', ''),
    _w('kung fu', '', 'n. 功夫', '', ''),
    _w('once in a while', '', '偶尔', '', ''),
    _w('dream of', '', '梦想；向往', '', ''),
    _w('so far', '', '到目前为止', '', ''),
  ]);

  final u2 = await DbService.insertUnit(g8b, 'Unit 2: Health & First Aid', 2);
  await _insertWords(u2, [
    _w('throat', '', 'n. 喉咙', '', ''),
    _w('stomachache', '', 'n. 胃痛', '', ''),
    _w('headache', '', 'n. 头痛', '', ''),
    _w('toothache', '', 'n. 牙痛', '', ''),
    _w('nosebleed', '', 'n. 鼻出血', '', ''),
    _w('fever', '', 'n. 发烧', '', ''),
    _w('stomach', '', 'n. 胃；腹部', '', ''),
    _w('ache', '', 'n.&v. 疼痛', '', ''),
    _w('X-ray', '', 'n. X射线检查', '', ''),
    _w('cough', '', 'n.&v. 咳嗽', '', ''),
    _w('flu', '', 'n. 流感', '', ''),
    _w('medicine', '', 'n. 药；医学', '', ''),
    _w('mask', '', 'n. 口罩', '', ''),
    _w('virus', '', 'n. 病毒', '', ''),
    _w('patient', '', 'n.&adj. 病人；有耐心的', '', ''),
    _w('injury', '', 'n. 伤害；损伤', '', ''),
    _w('illness', '', 'n. 疾病', '', ''),
    _w('knife', '', 'n. 刀', '', ''),
    _w('pain', '', 'n. 疼痛；痛苦', '', ''),
    _w('sore', '', 'adj. 疼痛的', '', ''),
    _w('careless', '', 'adj. 粗心的', '', ''),
    _w('runny', '', 'adj. 流鼻涕的', '', ''),
    _w('bruised', '', 'adj. 瘀伤的', '', ''),
    _w('clear', '', 'adj. 清晰的；v. 清理', '', ''),
    _w('quick', '', 'adj.&adv. 快的', '', ''),
    _w('tight', '', 'adj. 憋气的；紧的', '', ''),
    _w('allergic', '', 'adj. 过敏的', '', ''),
    _w('harmful', '', 'adj. 有害的', '', ''),
    _w('nervous', '', 'adj. 紧张的', '', ''),
    _w('press', '', 'v. 压；按', '', ''),
    _w('avoid', '', 'v. 避免', '', ''),
    _w('cross', '', 'v. 穿越', '', ''),
    _w('fry', '', 'v. 油炸', '', ''),
    _w('burn', '', 'v. 燃烧；n. 烧伤', '', ''),
    _w('throw', '', 'v. 扔；抛', '', ''),
    _w('roll', '', 'v. 翻滚', '', ''),
    _w('aid', '', 'n.&v. 帮助', '', ''),
    _w('hit', '', 'v. 碰撞；击打', '', ''),
    _w('shock', '', 'n.&v. 震惊', '', ''),
    _w('bleed', '', 'v. 流血', '', ''),
    _w('check', '', 'v.&n. 检查', '', ''),
    _w('panic', '', 'n. 恐慌', '', ''),
    _w('harm', '', 'n.&v. 伤害', '', ''),
    _w('safety', '', 'n. 安全', '', ''),
    _w('gas', '', 'n. 气体；燃气', '', ''),
    _w('environment', '', 'n. 环境', '', ''),
    _w('peanut', '', 'n. 花生', '', ''),
    _w('pill', '', 'n. 药丸', '', ''),
    _w('stove', '', 'n. 炉子', '', ''),
    _w('flame', '', 'n. 火焰', '', ''),
    _w('extinguisher', '', 'n. 灭火器', '', ''),
    _w('smoke', '', 'n. 烟；v. 吸烟', '', ''),
    _w('happily', '', 'adv. 快乐地', '', ''),
    _w('sadly', '', 'adv. 伤心地', '', ''),
    _w('luckily', '', 'adv. 幸运地', '', ''),
    _w('badly', '', 'adv. 严重地', '', ''),
    _w('nervously', '', 'adv. 紧张不安地', '', ''),
    _w('take a seat', '', '坐下', '', ''),
    _w('catch fire', '', '着火', '', ''),
    _w('first aid', '', '急救', '', ''),
    _w('what\'s more', '', '更为重要的是', '', ''),
  ]);

  final u3 = await DbService.insertUnit(g8b, 'Unit 3: Emotions & Relationships', 3);
  await _insertWords(u3, [
    _w('emotion', '', 'n. 情感；情绪', '', ''),
    _w('upset', '', 'adj. 难过的', '', ''),
    _w('lonely', '', 'adj. 孤独的', '', ''),
    _w('shocked', '', 'adj. 震惊的', '', ''),
    _w('advise', '', 'v. 建议；劝告', '', ''),
    _w('hurtful', '', 'adj. 伤感情的', '', ''),
    _w('control', '', 'v.&n. 控制', '', ''),
    _w('anger', '', 'n. 怒火', '', ''),
    _w('forgive', '', 'v. 原谅；宽恕', '', ''),
    _w('fault', '', 'n. 过错；责任', '', ''),
    _w('present', '', 'n. 礼物；现在', '', ''),
    _w('standard', '', 'n.&adj. 标准(的)', '', ''),
    _w('award', '', 'n. 奖；奖品', '', ''),
    _w('pressure', '', 'n. 压力', '', ''),
    _w('purpose', '', 'n. 目的；意图', '', ''),
    _w('shut', '', 'v. 关闭；合上', '', ''),
    _w('lastly', '', 'adv. 最后', '', ''),
    _w('plenty', '', 'pron. 充足；丰富', '', ''),
    _w('ring', '', 'v. 发出铃声；n. 戒指', '', ''),
    _w('enter', '', 'v. 进入', '', ''),
    _w('dare', '', 'v. 敢于', '', ''),
    _w('everybody', '', 'pron. 每人', '', ''),
    _w('player', '', 'n. 运动员', '', ''),
    _w('referee', '', 'n. 裁判', '', ''),
    _w('decision', '', 'n. 决定', '', ''),
    _w('score', '', 'n.&v. 得分', '', ''),
    _w('proud', '', 'adj. 骄傲的', '', ''),
    _w('coach', '', 'n. 教练', '', ''),
    _w('bit', '', 'n. 有点儿', '', ''),
    _w('repeat', '', 'v. 重复', '', ''),
    _w('though', '', 'conj. 虽然', '', ''),
    _w('joyful', '', 'adj. 高兴的', '', ''),
    _w('thankful', '', 'adj. 感谢的', '', ''),
    _w('negative', '', 'adj. 消极的', '', ''),
    _w('bully', '', 'v. 霸凌；n. 恶霸', '', ''),
    _w('behave', '', 'v. 表现', '', ''),
    _w('differently', '', 'adv. 不同地', '', ''),
    _w('physics', '', 'n. 物理', '', ''),
    _w('lie', '', 'v. 平躺；说谎', '', ''),
    _w('awake', '', 'adj. 醒着的', '', ''),
    _w('normal', '', 'adj. 正常的', '', ''),
    _w('mad', '', 'adj. 疯狂的', '', ''),
    _w('mean', '', 'adj. 刻薄的；v. 意味着', '', ''),
    _w('deep', '', 'adj. 深的', '', ''),
    _w('remain', '', 'v. 保持不变', '', ''),
    _w('deal with', '', '处理；对付', '', ''),
    _w('so that', '', '为了；因此', '', ''),
    _w('clear the air', '', '尽释前嫌', '', ''),
    _w('get across', '', '解释清楚', '', ''),
    _w('on purpose', '', '故意', '', ''),
    _w('let down', '', '使失望', '', ''),
    _w('take back', '', '撤回；收回', '', ''),
    _w('proud of', '', '为…感到骄傲', '', ''),
    _w('as well', '', '也；又', '', ''),
    _w('pull together', '', '齐心协力', '', ''),
    _w('even though', '', '即使；虽然', '', ''),
    _w('shout at', '', '冲某人喊叫', '', ''),
    _w('take a deep breath', '', '深呼吸', '', ''),
    _w('pass away', '', '去世', '', ''),
    _w('not only... but also', '', '不但…而且…', '', ''),
  ]);

  final u4 = await DbService.insertUnit(g8b, 'Unit 4: Natural Wonders', 4);
  await _insertWords(u4, [
    _w('wonder', '', 'n. 奇观；v. 想知道', '', ''),
    _w('desert', '', 'n. 沙漠', '', ''),
    _w('measurement', '', 'n. 数量；测量', '', ''),
    _w('below', '', 'prep.&adv. 在…下面', '', ''),
    _w('level', '', 'n. 高度；水平', '', ''),
    _w('surface', '', 'n. 表面', '', ''),
    _w('depth', '', 'n. 深度', '', ''),
    _w('dive', '', 'v.&n. 潜水', '', ''),
    _w('submersible', '', 'n. 潜水艇', '', ''),
    _w('unusual', '', 'adj. 特别的', '', ''),
    _w('bottom', '', 'n. 底部', '', ''),
    _w('waterfall', '', 'n. 瀑布', '', ''),
    _w('civilization', '', 'n. 文明', '', ''),
    _w('development', '', 'n. 发展', '', ''),
    _w('cubic', '', 'adj. 立方的', '', ''),
    _w('mile', '', 'n. 英里', '', ''),
    _w('pool', '', 'n. 池塘', '', ''),
    _w('climber', '', 'n. 攀登者', '', ''),
    _w('northern', '', 'adj. 北部的', '', ''),
    _w('distance', '', 'n. 距离', '', ''),
    _w('survive', '', 'v. 生存；存活', '', ''),
    _w('condition', '', 'n. 环境；条件', '', ''),
    _w('degree', '', 'n. 度；度数', '', ''),
    _w('cliff', '', 'n. 悬崖', '', ''),
    _w('changeable', '', 'adj. 易变的', '', ''),
    _w('death', '', 'n. 死亡', '', ''),
    _w('determined', '', 'adj. 有决心的', '', ''),
    _w('above', '', 'prep. 在…上面', '', ''),
    _w('teammate', '', 'n. 队友', '', ''),
    _w('shoulder', '', 'n. 肩膀', '', ''),
    _w('ladder', '', 'n. 梯子', '', ''),
    _w('measure', '', 'v. 测量', '', ''),
    _w('successfully', '', 'adv. 成功地', '', ''),
    _w('risk', '', 'n.&v. 风险；冒风险', '', ''),
    _w('curiosity', '', 'n. 好奇心', '', ''),
    _w('ambition', '', 'n. 野心；雄心', '', ''),
    _w('explorer', '', 'n. 探险者', '', ''),
    _w('simply', '', 'adv. 仅仅', '', ''),
    _w('risky', '', 'adj. 有危险的', '', ''),
    _w('southern', '', 'adj. 南部的', '', ''),
    _w('located', '', 'adj. 位于', '', ''),
    _w('freshwater', '', 'adj. 淡水的', '', ''),
    _w('type', '', 'n. 类型', '', ''),
    _w('attract', '', 'v. 吸引', '', ''),
    _w('curious', '', 'adj. 好奇的', '', ''),
    _w('traveller', '', 'n. 旅行者', '', ''),
    _w('natural', '', 'adj. 自然的', '', ''),
    _w('reef', '', 'n. 礁', '', ''),
    _w('underwater', '', 'adj.&adv. 水下的', '', ''),
    _w('northeastern', '', 'adj. 东北的', '', ''),
    _w('coast', '', 'n. 海岸', '', ''),
    _w('coral', '', 'n. 珊瑚', '', ''),
    _w('include', '', 'v. 包含', '', ''),
    _w('sand', '', 'n. 沙子', '', ''),
    _w('alive', '', 'adj. 活着', '', ''),
    _w('structure', '', 'n. 结构', '', ''),
    _w('turtle', '', 'n. 海龟', '', ''),
    _w('lifetime', '', 'n. 一生', '', ''),
    _w('bit by bit', '', '一点一点地', '', ''),
  ]);
}
