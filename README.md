# 单词宝典 (English Word Guide)

跨平台英语单词学习应用，支持 Windows 桌面与 Android 手机。

## 开发背景

### 痛点

- **被动翻页**：传统背单词 App 需要手动点"下一个"，不能解放双手
- **缺乏进度感**：不知道哪些会了、哪些还不会，眉毛胡子一把抓
- **发音机械**：很多 App 用系统自带 TTS，声音生硬不自然
- **数据不完整**：课本词汇 + 考级词汇分散在各处，没有一个统一入口

### 优点

- **自动播放**：点 ▶ 自动连播（单词→释义→例句→句译），锁屏也不断
- **越学越少**："通过"机制让已掌握的单词不再出现，专注薄弱环节
- **难题本**：标难单词跨单元收集，集中攻克
- **丝滑发音**：Windows 走有道 API，Android 句子走百度翻译 API
- **一套代码双平台**：Flutter 开发，Windows + Android 同时输出

## 已实现功能

| 模块 | 功能 |
|------|------|
| 单词学习 | 卡片式展示（单词、音标、释义、课文原句、句译） |
| 自动播放 | 单词→中文释义→英文句→中文句译，自动连播 |
| 发音 | 英文：有道TTS（短词）+ 百度TTS（长句）；中文：百度TTS / Windows SAPI |
| 过关系统 | "通过"按钮从列表移除；"标为难题"全局收集 |
| 难题本 | 跨单元所有标难单词，独立自动播放 |
| 进度跟踪 | 树节点显示 `未通过/总数`，底部进度递减 |
| 年级-单元树 | 初中→高中→四级→六级→专八→计算机英语 |
| 构词法分析 | 自动识别前缀/词根/后缀（如 un-comfort-able） |
| 响应式布局 | 宽屏左右分栏，手机全屏+底部弹窗 |
| 锁屏播放 | Android 前台服务通知，锁屏不中断 |
| 手势操作 | 上下滑翻页，暂停/继续一键控制 |

## 词汇库

| 类别 | 词量 | 来源 |
|------|------|------|
| 七年级上册 | 296 | 手工整理（含课文原句） |
| 七年级下册 | 492 | PEP 人教版 JSON |
| 八年级上册 | 419 | PEP 人教版 JSON |
| 八年级下册 | 694 | 混合（手工 + JSON） |
| 九年级全册 | 551 | PEP 人教版 JSON |
| 高一~高三 | 3,877 | PEP 人教版 JSON |
| CET-4 四级 | 7,508 | 分字母 A-Z |
| CET-6 六级 | 5,651 | 分字母 A-Z |
| 专八 | 12,881 | 分字母 A-Z |
| 计算机英语 | 1,694 | 软考词汇 |
| **合计** | **~32,369** | |

## 技术栈

| 层 | 技术 |
|------|------|
| 框架 | Flutter 3.35.5 / Dart 3.9.2 |
| 数据库 | SQLite（sqflite + sqflite_common_ffi） |
| 音频 | audioplayers（Windows）/ Android MediaPlayer（原生 MethodChannel） |
| TTS | 有道词典API / 百度翻译API / Windows SAPI |
| 状态管理 | StatefulWidget setState |
| 后台 | Android Foreground Service / wakelock_plus |

## 开发环境

```bash
# 必需
Flutter SDK 3.35.5+
Dart 3.9.2+
Android Studio (含 NDK)
Visual Studio 2022+ (Windows 桌面开发)

# Windows 构建
flutter run -d windows

# Android 构建
flutter build apk --debug

# 发布 Windows
flutter build windows --release
cp -r build/windows/x64/runner/Release/* build/publish/win/
```

## 待完善

- [ ] 七下/八上/九年级的课文原句（当前仅七上有）
- [ ] 计算机英语的计算机场景例句
- [ ] 高中/专八词汇的按单元分组（当前按首字母 A-Z）
- [ ] 刷题模式（选择题、拼写测试）
- [ ] 单词学习统计（每日打卡、学习时长）
- [ ] iOS 支持
- [ ] 中文发音未覆盖的 Android 设备（需安装 Google TTS 中文语音包）

## 项目结构

```
lib/
├── main.dart                  # 入口
├── models/word.dart           # 单词数据模型
├── services/
│   ├── db_service.dart        # SQLite 数据库封装
│   ├── tts_service.dart       # TTS 发音服务（跨平台分支）
│   └── word_analysis.dart    # 构词法分析
├── data/
│   └── seed_data.dart         # 数据库种子数据
├── pages/
│   └── home_page.dart         # 主页（树+卡片+自动播放）
└── widgets/
    ├── grade_tree.dart        # 年级-单元树组件
    └── word_card.dart         # 单词卡片组件
android/app/src/main/kotlin/   # Android 原生代码
  ├── MainActivity.kt          # TTS + MediaPlayer MethodChannel
  ├── AudioService.kt          # 前台服务（锁屏播放）
  └── MyApp.kt                 # Application 类
assets/                        # 词汇 JSON 资产（~28MB）
```

## 致谢

- 词汇数据来源：[KyleBing/english-vocabulary](https://github.com/KyleBing/english-vocabulary)
- 计算机词汇：[JumpX/ZZ-1700-Words-Of-Computer](https://github.com/JumpX/ZZ-1700-Words-Of-Computer)
- 课文数据：国家中小学智慧教育平台（人教版 PEP 教材）
