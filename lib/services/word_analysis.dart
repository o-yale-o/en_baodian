/// Word-formation analyzer with prefix/root/suffix database.
class WordSegment {
  final String text;
  final String type; // prefix, root, suffix
  final String meaning; // Chinese + English
  const WordSegment(this.text, this.type, this.meaning);
}

class WordAnalysis {
  final List<WordSegment> segments;
  final String? etymology; // brief origin note

  const WordAnalysis({required this.segments, this.etymology});

  bool get hasBreakdown => segments.isNotEmpty;

  String format() => segments.map((s) => '${s.text}(${s.meaning})').join(' + ');
}

// ── Prefixes ──────────────────────────────────────────────

const _prefixes = <String, String>{
  'a': '不/无 (not/non)',
  'ab': '脱离 (away from)',
  'ad': '朝向 (to/toward)',
  'ante': '前 (before)',
  'anti': '反/抗 (against)',
  'auto': '自己 (self)',
  'be': '使/在…上 (make/on)',
  'bi': '双/二 (two)',
  'circum': '环绕 (around)',
  'co': '共同 (together)',
  'com': '共同 (together)',
  'con': '共同/一起 (together/with)',
  'contra': '反/对 (against)',
  'counter': '反/对 (against)',
  'de': '下/去除 (down/remove)',
  'di': '分离/二 (apart/two)',
  'dia': '穿越/间 (through/across)',
  'dis': '不/相反/除去 (not/opposite)',
  'en': '使/在…中 (make/in)',
  'ex': '出/前 (out/former)',
  'extra': '额外/超 (beyond)',
  'fore': '前/预 (before)',
  'il': '不 (not)',
  'im': '不/向内 (not/in)',
  'in': '不/向内 (not/in)',
  'inter': '相互/之间 (between)',
  'ir': '不 (not)',
  'macro': '大/宏观 (large)',
  'mal': '坏/不良 (bad)',
  'micro': '微 (small)',
  'mid': '中间 (middle)',
  'mis': '错误 (wrong)',
  'mono': '单/一 (one)',
  'multi': '多 (many)',
  'non': '非/无 (not)',
  'ob': '反/朝 (against/toward)',
  'out': '超出/外 (beyond/out)',
  'over': '过度/在上 (too much/over)',
  'per': '贯穿/完全 (through/fully)',
  'poly': '多 (many)',
  'post': '后 (after)',
  'pre': '前/预先 (before)',
  'pro': '向前/赞成 (forward/for)',
  're': '再/重新/回 (again/back)',
  'retro': '向后 (backward)',
  'se': '分离 (apart)',
  'semi': '半 (half)',
  'sub': '下/次/亚 (under)',
  'super': '超/上 (above/beyond)',
  'sur': '超/上 (over)',
  'trans': '横跨/转变 (across/change)',
  'tri': '三 (three)',
  'un': '不/相反 (not/opposite)',
  'under': '不足/在下 (under/below)',
  'up': '向上 (up)',
};

// ── Roots ─────────────────────────────────────────────────

const _roots = <String, String>{
  'ac': '尖/酸 (sharp/sour)',
  'act': '做/行动 (to do/drive)',
  'acu': '尖锐 (sharp)',
  'agri': '田地 (field)',
  'alter': '其他 (other)',
  'am': '爱 (love)',
  'anim': '生命/精神 (life/spirit)',
  'ann': '年 (year)',
  'anthrop': '人类 (human)',
  'aqua': '水 (water)',
  'arch': '统治者/首领 (ruler/chief)',
  'aster': '星 (star)',
  'aud': '听 (hear)',
  'bell': '战争 (war)',
  'bio': '生命 (life)',
  'brev': '短 (short)',
  'cad': '落 (fall)',
  'cap': '头/拿 (head/take)',
  'ced': '走/去 (go/yield)',
  'cent': '百 (hundred)',
  'chron': '时间 (time)',
  'cid': '杀/切 (kill/cut)',
  'circ': '环 (ring/circle)',
  'civ': '公民 (citizen)',
  'claim': '喊/叫 (call out)',
  'clar': '清晰 (clear)',
  'clin': '倾斜 (lean)',
  'clud': '关闭 (close/shut)',
  'cogn': '知道 (know)',
  'cord': '心 (heart)',
  'corp': '身体 (body)',
  'cosm': '宇宙 (universe)',
  'cred': '相信 (believe/trust)',
  'cult': '耕耘/培养 (till/grow)',
  'cur': '跑/关心 (run/care)',
  'cycl': '圆/环 (circle/wheel)',
  'dem': '人民 (people)',
  'dent': '牙齿 (tooth)',
  'derm': '皮肤 (skin)',
  'dic': '说 (say/speak)',
  'doc': '教 (teach)',
  'dom': '家/统治 (home/rule)',
  'don': '给 (give)',
  'dorm': '睡 (sleep)',
  'duc': '引导 (lead)',
  'dur': '持久 (last/hard)',
  'equ': '相等 (equal)',
  'fact': '做/制造 (make/do)',
  'feder': '联盟 (league)',
  'fid': '信任 (trust/faith)',
  'fin': '结束/界限 (end/limit)',
  'flect': '弯曲 (bend)',
  'flor': '花 (flower)',
  'flu': '流 (flow)',
  'form': '形状 (shape/form)',
  'fort': '强/坚固 (strong)',
  'fract': '打破 (break)',
  'fug': '逃 (flee)',
  'gen': '产生/种族 (birth/race)',
  'geo': '地 (earth)',
  'grad': '步/级 (step/degree)',
  'graph': '写/画 (write/draw)',
  'grat': '愉悦/感谢 (pleasing/thank)',
  'grav': '重 (heavy)',
  'greg': '群/聚集 (flock/gather)',
  'hydr': '水 (water)',
  'ject': '投/扔 (throw)',
  'jud': '判断 (judge)',
  'junct': '连接 (join)',
  'jur': '发誓/法律 (swear/law)',
  'lect': '选/读 (choose/read)',
  'leg': '法律/送 (law/send)',
  'liber': '自由 (free)',
  'lingu': '语言 (language)',
  'lith': '石头 (stone)',
  'loc': '地方 (place)',
  'log': '说/学 (speech/study)',
  'luc': '光 (light)',
  'magn': '大/伟大 (great)',
  'man': '手 (hand)',
  'mar': '海 (sea)',
  'medi': '中间 (middle)',
  'memor': '记忆 (memory)',
  'ment': '心/思 (mind/think)',
  'merg': '沉/浸 (sink/dip)',
  'meter': '测量 (measure)',
  'migr': '迁移 (move/wander)',
  'milit': '士兵/战斗 (soldier)',
  'min': '小 (small)',
  'mir': '惊奇 (wonder)',
  'miss': '送 (send)',
  'mob': '动 (move)',
  'mort': '死 (death)',
  'nat': '出生 (born)',
  'nau': '船 (ship)',
  'neg': '否定 (deny)',
  'neur': '神经 (nerve)',
  'noc': '伤害 (harm)',
  'nom': '名字/法则 (name/law)',
  'nov': '新 (new)',
  'numer': '数 (number)',
  'ocul': '眼 (eye)',
  'onym': '名 (name)',
  'oper': '工作 (work)',
  'opt': '选择/眼睛 (choose/eye)',
  'ord': '秩序 (order)',
  'orn': '装饰 (decorate)',
  'pac': '和平 (peace)',
  'path': '感觉/病 (feeling/suffering)',
  'ped': '脚/儿童 (foot/child)',
  'pel': '推/驱动 (push/drive)',
  'pend': '悬挂/支付 (hang/pay)',
  'pet': '追求/寻求 (seek)',
  'phil': '爱 (love)',
  'phon': '声音 (sound)',
  'phot': '光 (light)',
  'pict': '画 (paint)',
  'plac': '使满意 (please)',
  'plen': '满 (full)',
  'pli': '折叠 (fold)',
  'poli': '城市/政治 (city)',
  'pon': '放 (put/place)',
  'popul': '人民 (people)',
  'port': '携带/运送 (carry)',
  'potent': '力量 (power)',
  'press': '压 (press)',
  'prim': '第一 (first)',
  'priv': '私人/分开 (private/separate)',
  'prob': '证明/测试 (prove/test)',
  'psych': '心灵 (mind/soul)',
  'puls': '推/击 (push/strike)',
  'punct': '点/刺 (point/prick)',
  'quer': '寻求/问 (seek/ask)',
  'radi': '光线/根 (ray/root)',
  'rect': '直/正 (straight/right)',
  'reg': '统治/规则 (rule/guide)',
  'rupt': '破 (break/burst)',
  'san': '健康 (health)',
  'sci': '知道 (know)',
  'scrib': '写 (write)',
  'sect': '切 (cut)',
  'sens': '感觉 (feel)',
  'sequ': '跟随 (follow)',
  'serv': '服务/保存 (serve/keep)',
  'sign': '标记 (mark/sign)',
  'simil': '相似 (like/similar)',
  'sol': '单独/太阳 (alone/sun)',
  'son': '声音 (sound)',
  'soph': '智慧 (wisdom)',
  'spec': '看 (look/see)',
  'spir': '呼吸 (breathe)',
  'stat': '站立/状态 (stand/state)',
  'string': '绑紧 (bind tight)',
  'struct': '建造 (build)',
  'sum': '拿/取/最高 (take/highest)',
  'tact': '触 (touch)',
  'tech': '技艺 (art/skill)',
  'temper': '调节/适度 (moderate)',
  'tempor': '时间 (time)',
  'ten': '持/握 (hold)',
  'tend': '伸展 (stretch)',
  'terr': '土地/怕 (earth/frighten)',
  'test': '见证 (witness)',
  'the': '神 (god)',
  'therm': '热 (heat)',
  'tort': '扭/转 (twist)',
  'tract': '拉/拖 (pull/draw)',
  'trib': '给予 (give)',
  'turb': '扰乱 (disturb)',
  'umbr': '阴影 (shadow)',
  'urb': '城市 (city)',
  'vac': '空 (empty)',
  'val': '强壮/价值 (strong/worth)',
  'ven': '来 (come)',
  'ver': '真实 (true)',
  'verb': '词 (word)',
  'vert': '转 (turn)',
  'via': '道路 (road/way)',
  'vict': '征服 (conquer)',
  'vid': '看 (see)',
  'vis': '看 (see)',
  'viv': '活 (live)',
  'voc': '声音/呼唤 (voice/call)',
  'vol': '意愿 (will/wish)',
  'volv': '滚/转 (roll/turn)',
  'vor': '吃 (eat)',
};

// ── Suffixes ──────────────────────────────────────────────

const _suffixes = <String, String>{
  'able': '能够的 (able to be)',
  'ible': '能够的 (able to be)',
  'al': '…的/名词 (relating to)',
  'ance': '名词：状态 (state of)',
  'ence': '名词：状态 (state of)',
  'ancy': '名词：性质 (quality of)',
  'ency': '名词：性质 (quality of)',
  'ant': '…的人/物/…的 (one who/that which)',
  'ent': '…的人/物/…的 (one who/that which)',
  'ar': '…的/…的人 (relating to/one who)',
  'ary': '…的/…的场所 (relating to/place)',
  'ate': '动词/形容词：使…/…的 (make/having)',
  'cle': '小 (small)',
  'dom': '状态/领域 (state/domain)',
  'ed': '…的/过去 (past/having)',
  'ee': '被…的人 (one who receives)',
  'eer': '从事…的人 (one who does)',
  'en': '动词：使变得 (make)',
  'er': '做…的人/物 (one who/that which)',
  'or': '做…的人/物 (one who/that which)',
  'ese': '…的/…人/语 (relating to)',
  'ess': '女性 (female)',
  'est': '最… (most)',
  'fold': '…倍 (times)',
  'ful': '充满…的 (full of)',
  'fy': '使…化 (make)',
  'hood': '时期/状态 (state/period)',
  'ial': '…的 (relating to)',
  'ian': '…的/…的人 (relating to/person)',
  'ic': '…的 (relating to)',
  'ical': '…的 (relating to)',
  'ing': '名词/形容词：动作/状态 (act/quality)',
  'ion': '名词：动作/状态 (act/state)',
  'tion': '名词：动作/状态 (act/state)',
  'sion': '名词：动作/状态 (act/state)',
  'ish': '有点儿…的/…似的 (somewhat/like)',
  'ism': '主义/学说 (doctrine/practice)',
  'ist': '…家/主义者 (one who practices)',
  'ity': '名词：性质 (quality/state)',
  'ive': '有…倾向的 (tending to)',
  'ize': '动词：使…化 (make)',
  'ise': '动词：使…化 (make)',
  'less': '无/没有 (without)',
  'like': '像…的 (like)',
  'ling': '小… (small)',
  'ly': '地/…的 (in a manner)',
  'ment': '名词：行为/结果 (act/result)',
  'most': '最… (most)',
  'ness': '名词：性质/状态 (quality/state)',
  'ory': '…的/…的场所 (relating to/place)',
  'ous': '有…性质的 (full of/having)',
  'proof': '防…的 (proof against)',
  'ry': '…学/…业/…的场所 (art/place)',
  'ship': '名词：关系/状态 (state/quality)',
  'some': '有…倾向的 (tending to)',
  'th': '…度/状态 (degree/state)',
  'ty': '名词：性质 (quality)',
  'tude': '名词：状态 (state)',
  'ular': '…的 (relating to)',
  'ure': '名词：动作/结果 (act/result)',
  'ward': '向… (direction)',
  'wards': '向… (direction)',
  'ways': '以…方式 (in a manner)',
  'wise': '以…方式 (in the manner of)',
  'y': '充满…的/…性质 (full of/quality)',
};

class _Match {
  final String text;
  final String meaning;
  final String type;
  const _Match(this.text, this.meaning, this.type);
}

/// Look up root meaning, trying shorter substrings if exact match fails.
String? _findRoot(String core) {
  if (_roots.containsKey(core)) return _roots[core];
  for (int n = core.length - 1; n >= 3; n--) {
    final sub = core.substring(0, n);
    if (_roots.containsKey(sub)) return _roots[sub];
  }
  return null;
}

/// Analyze a word into prefix + root + suffix pieces.
WordAnalysis analyze(String word) {
  final w = word.toLowerCase().trim();
  if (w.length < 3) return const WordAnalysis(segments: []);

  // Try matching prefix + root + suffix (full combo)
  for (final p in _prefixes.keys.where((k) => k.length >= 2)) {
    if (!w.startsWith(p) || w.length <= p.length + 3) continue;
    final rest = w.substring(p.length);
    for (final s in _suffixes.keys.where((k) => k.length >= 2)) {
      if (!rest.endsWith(s) || rest.length <= s.length + 1) continue;
      final core = rest.substring(0, rest.length - s.length);
      if (core.length >= 2) {
        final root = _findRoot(core);
        if (root != null) {
          return WordAnalysis(segments: [
            WordSegment(p, '前缀', _prefixes[p]!),
            WordSegment(core, '词根', root),
            WordSegment(s, '后缀', _suffixes[s]!),
          ]);
        }
      }
    }
  }

  // Try prefix + root only
  for (final p in _prefixes.keys.where((k) => k.length >= 2)) {
    if (!w.startsWith(p) || w.length <= p.length + 2) continue;
    final core = w.substring(p.length);
    if (core.length >= 2) {
      final root = _findRoot(core);
      if (root != null) {
        return WordAnalysis(segments: [
          WordSegment(p, '前缀', _prefixes[p]!),
          WordSegment(core, '词根', root),
        ]);
      }
    }
  }

  // Try root + suffix only
  for (final s in _suffixes.keys.where((k) => k.length >= 2)) {
    if (!w.endsWith(s) || w.length <= s.length + 2) continue;
    final core = w.substring(0, w.length - s.length);
    if (core.length >= 2) {
      final root = _findRoot(core);
      if (root != null) {
        return WordAnalysis(segments: [
          WordSegment(core, '词根', root),
          WordSegment(s, '后缀', _suffixes[s]!),
        ]);
      }
    }
  }

  // Try standalone suffix
  for (final s in _suffixes.keys.where((k) => k.length >= 2)) {
    if (w.endsWith(s) && w.length > s.length + 2) {
      final core = w.substring(0, w.length - s.length);
      if (core.length >= 2) {
        return WordAnalysis(segments: [
          WordSegment(core, '词根', core),
          WordSegment(s, '后缀', _suffixes[s]!),
        ]);
      }
    }
  }

  return const WordAnalysis(segments: []);
}
