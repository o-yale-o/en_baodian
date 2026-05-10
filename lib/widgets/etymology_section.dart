import 'package:flutter/material.dart';
import '../services/word_analysis.dart';

class EtymologySection extends StatefulWidget {
  final String word;
  const EtymologySection({super.key, required this.word});

  @override
  State<EtymologySection> createState() => _EtymologySectionState();
}

class _EtymologySectionState extends State<EtymologySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final analysis = analyze(widget.word);
    if (!analysis.hasBreakdown) return const SizedBox.shrink();

    final story = _buildStory(analysis);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16, color: Colors.teal[400]),
                const SizedBox(width: 4),
                Text('词源', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal[600])),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              story,
              style: TextStyle(fontSize: 12, color: Colors.teal[800], height: 1.6),
            ),
          ),
      ],
    );
  }

  String _buildStory(WordAnalysis a) {
    final parts = <String>[];
    for (final seg in a.segments) {
      if (seg.type == '前缀') {
        parts.add('${seg.text}- (${seg.meaning})');
      } else if (seg.type == '词根') {
        parts.add('${seg.text} (${seg.meaning})');
      } else if (seg.type == '后缀') {
        parts.add('-${seg.text} (${seg.meaning})');
      }
    }
    final breakdown = parts.join(' + ');
    final h = _etymologyHints[a.segments.where((s) => s.type == '词根').map((s) => s.text).join()];
    final hint = h != null ? '\n$h' : '';
    return '${widget.word} = $breakdown$hint';
  }
}

const _etymologyHints = <String, String>{
  'spect': '拉丁语 specere (看) → 古法语 espect → 中古英语。与 spy (间谍)、spectacle (景象) 同源。',
  'vidvis': '拉丁语 videre (看) → 古法语。与 video (视频)、vision (视野)、wise (明智) 同源。',
  'dictdic': '拉丁语 dicere (说) → 古法语。与 predict (预言)、indicate (指示) 同源。',
  'port': '拉丁语 portare (携带) → 古法语。与 import (进口)、portable (便携) 同源。',
  'tract': '拉丁语 trahere (拉/拖) → 古法语。与 tractor (拖拉机)、attract (吸引) 同源。',
  'ject': '拉丁语 jacere (投/扔) → 古法语。与 eject (弹出)、project (投射) 同源。',
  'missmit': '拉丁语 mittere (送/发出) → 古法语。与 mission (任务)、admit (接纳) 同源。',
  'ductduc': '拉丁语 ducere (引导) → 古法语。与 conduct (指挥)、educate (教育) 同源。',
  'scribscript': '拉丁语 scribere (写) → 古法语。与 describe (描述)、script (手稿) 同源。',
  'struct': '拉丁语 struere (建造) → 古法语。与 construction (建造)、destroy (摧毁) 同源。',
  'phon': '希腊语 phone (声音) → 拉丁语 → 古法语。与 telephone (电话)、symphony (交响乐) 同源。',
  'bio': '希腊语 bios (生命) → 拉丁语。与 biology (生物学)、biography (传记) 同源。',
  'graph': '希腊语 graphein (写/画) → 拉丁语。与 photograph (照片)、autograph (签名) 同源。',
  'log': '希腊语 logos (话语/学说) → 拉丁语。与 dialogue (对话)、logic (逻辑) 同源。',
  'ped': '拉丁语 pes/pedis (脚) → 古法语。与 pedal (踏板)、pedestrian (行人) 同源。',
  'rupt': '拉丁语 rumpere (打破) → 古法语。与 interrupt (打断)、erupt (爆发) 同源。',
  'voc': '拉丁语 vocare (呼唤) → 古法语。与 voice (声音)、advocate (倡导) 同源。',
  'cred': '拉丁语 credere (相信) → 古法语。与 credit (信用)、incredible (难以置信) 同源。',
  'factfect': '拉丁语 facere (做/制造) → 古法语。与 factory (工厂)、effect (效果) 同源。',
  'tendtens': '拉丁语 tendere (伸展) → 古法语。与 extend (延伸)、tense (紧张) 同源。',
  'cedcess': '拉丁语 cedere (走/让步) → 古法语。与 proceed (前进)、success (成功) 同源。',
  'venvent': '拉丁语 venire (来) → 古法语。与 event (事件)、invent (发明) 同源。',
  'capcep': '拉丁语 capere (拿/取) → 古法语。与 capture (捕获)、receive (接收) 同源。',
  'flu': '拉丁语 fluere (流动) → 古法语。与 fluid (流体)、influence (影响) 同源。',
  'magn': '拉丁语 magnus (大的/伟大的) → 古法语。与 magnificent (壮丽的)、major (较大的) 同源。',
  'min': '拉丁语 minus (较小的) → 古法语。与 minor (较小的)、minute (分钟/微小) 同源。',
  'mort': '拉丁语 mors/mortis (死亡) → 古法语。与 mortal (凡人的)、mortgage (抵押) 同源。',
  'nat': '拉丁语 natus (出生) → 古法语。与 nature (自然)、native (本地的) 同源。',
  'nov': '拉丁语 novus (新的) → 古法语。与 novel (小说/新颖的)、innovate (创新) 同源。',
  'senssent': '拉丁语 sentire (感觉) → 古法语。与 sense (感觉)、consent (同意) 同源。',
  'spir': '拉丁语 spirare (呼吸) → 古法语。与 spirit (精神)、inspire (启发) 同源。',
  'statstit': '拉丁语 stare/stituere (站立) → 古法语。与 station (站)、institute (建立) 同源。',
  'vertvers': '拉丁语 vertere (转动) → 古法语。与 convert (转变)、reverse (反转) 同源。',
  'cur': '拉丁语 currere (跑) → 古法语。与 current (当前的/水流)、occur (发生) 同源。',
  'gen': '拉丁语 genus (种族/出生) → 古法语。与 generate (产生)、gene (基因) 同源。',
  'fin': '拉丁语 finis (结束/边界) → 古法语。与 finish (完成)、infinite (无限) 同源。',
  'form': '拉丁语 formare (形成/塑造) → 古法语。与 inform (通知)、transform (转变) 同源。',
  'fort': '拉丁语 fortis (强壮的) → 古法语。与 effort (努力)、fortress (堡垒) 同源。',
  'loc': '拉丁语 locus (地方) → 古法语。与 location (位置)、local (本地) 同源。',
  'man': '拉丁语 manus (手) → 古法语。与 manual (手册/手工的)、manage (管理) 同源。',
  'pelpuls': '拉丁语 pellere (推/驱动) → 古法语。与 compel (强迫)、pulse (脉冲) 同源。',
  'ponpos': '拉丁语 ponere (放置) → 古法语。与 position (位置)、compose (组成) 同源。',
  'press': '拉丁语 premere (压) → 古法语。与 express (表达)、compress (压缩) 同源。',
  'quer': '拉丁语 quaerere (寻求/问) → 古法语。与 question (问题)、require (需要) 同源。',
  'sci': '拉丁语 scire (知道) → 古法语。与 science (科学)、conscious (有意识的) 同源。',
  'sequsec': '拉丁语 sequi (跟随) → 古法语。与 sequence (序列)、second (第二/秒) 同源。',
  'serv': '拉丁语 servire (服务/保存) → 古法语。与 service (服务)、preserve (保存) 同源。',
  'sol': '拉丁语 solus (单独的) 或 sol (太阳) → 古法语。与 solo (独奏)、solar (太阳的) 同源。',
  'tact': '拉丁语 tangere (触/摸) → 古法语。与 contact (接触)、tangible (可触摸的) 同源。',
  'ten': '拉丁语 tenere (持/握) → 古法语。与 contain (包含)、maintain (维持) 同源。',
  'vac': '拉丁语 vacuus (空的) → 古法语。与 vacant (空的)、vacuum (真空) 同源。',
  'val': '拉丁语 valere (强壮/有价值) → 古法语。与 value (价值)、valid (有效的) 同源。',
  'volvvol': '拉丁语 volvere (滚/转) → 古法语。与 revolve (旋转)、involve (卷入) 同源。',
};
