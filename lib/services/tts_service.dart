import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class TtsService {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _cache = {};
  static const _channel = MethodChannel('com.en_baodian/tts');

  Future<void> startForegroundService() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('startForeground');
    }
  }

  Future<void> stopForegroundService() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('stopForeground');
    }
  }

  // ── public API ─────────────────────────────────────────────

  Future<void> preload(String text) async {
    final key = text.trim().toLowerCase();
    if (_cache.containsKey(key)) return;
    try {
      final path = await _download(text);
      if (path != null) _cache[key] = path;
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    await _player.stop();
    final key = text.trim().toLowerCase();
    String? path = _cache[key];
    if (path == null) {
      path = await _download(text);
      if (path != null) _cache[key] = path;
    }
    if (path != null) {
      await _player.play(DeviceFileSource(path));
    } else {
      await _speakLocal(text);
    }
  }

  /// Speak and wait for completion (used in auto-play)
  Future<void> speakAndWait(String text) async {
    await _player.stop();
    final key = text.trim().toLowerCase();
    String? path = _cache[key];
    if (path == null) {
      path = await (Platform.isAndroid && text.length > 25
          ? _downloadBaidu(text)
          : _download(text));
      if (path != null) _cache[key] = path;
    }

    if (path != null) {
      if (Platform.isAndroid) {
        // Native MediaPlayer: waits for real completion
        try {
          await _channel.invokeMethod('playAudio', {'path': path});
          return;
        } catch (_) {}
      }
      // Windows / fallback
      try { await _player.play(DeviceFileSource(path)); } catch (_) {}
      final dur = Duration(milliseconds: ((text.length / 6.0).clamp(0.8, 20.0) * 1000).toInt());
      await Future.delayed(dur);
      await _player.stop();
      return;
    }
    // Download failed — minimal wait so auto-play doesn't jump
    await Future.delayed(Duration(milliseconds: ((text.length / 5.0).clamp(0.5, 10.0) * 1000).toInt()));
  }

  /// Speak Chinese text (Windows: SAPI, Android: Baidu TTS)
  Future<void> speakChinese(String text) async {
    if (text.isEmpty) return;
    if (Platform.isWindows) {
      final safe = text.replaceAll("'", "''");
      await Process.run('powershell.exe', [
        '-NoProfile', '-Command',
        "Add-Type -AssemblyName System.Speech; "
            "\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
            "\$s.SelectVoice('Microsoft Huihui Desktop'); "
            "\$s.Rate = -2; "
            "\$s.Speak('$safe')",
      ], runInShell: true);
      return;
    }
    if (Platform.isAndroid) {
      final key = 'zh_${text.hashCode}';
      String? path = _cache[key];
      if (path == null) {
        path = await _downloadBaiduZh(text);
        if (path != null) _cache[key] = path;
      }
      if (path != null) {
        try {
          await _channel.invokeMethod('playAudio', {'path': path});
        } catch (_) {}
      }
    }
  }

  Future<String?> _downloadBaiduZh(String text) async {
    final file = File(
        '${Directory.systemTemp.path}/en_baodian_zh_${text.hashCode}.mp3');
    final url =
        'https://fanyi.baidu.com/gettts?lan=zh&text=${Uri.encodeComponent(text)}&spd=3';
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      req.headers.set('Referer', 'https://fanyi.baidu.com/');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) { client.close(); return null; }
      final bytes = await res
          .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
      await file.writeAsBytes(Uint8List.fromList(bytes));
      client.close();
      if (!file.existsSync() || file.lengthSync() < 100) return null;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Speak text via local TTS (Android: native engine)
  Future<void> speakLocalTts(String text, {String lang = 'en'}) async {
    if (text.isEmpty) return;
    if (Platform.isWindows) {
      final safe = text.replaceAll("'", "''");
      await Process.run('powershell.exe', [
        '-NoProfile', '-Command',
        "Add-Type -AssemblyName System.Speech; "
            "\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
            "\$s.SelectVoice('Microsoft Zira Desktop'); "
            "\$s.Rate = -2; "
            "\$s.Speak('$safe')",
      ], runInShell: true);
    } else if (Platform.isAndroid) {
      try {
        await _channel
            .invokeMethod('speak', {'text': text, 'lang': lang})
            .timeout(Duration(seconds: (text.length * 0.3).clamp(2, 20).toInt()));
      } catch (_) {
        // TTS failed, silently continue
      }
    }
  }

  Future<void> stop() async => await _player.stop();
  void dispose() => _player.dispose();

  // ── download ───────────────────────────────────────────────

  Future<String?> _download(String text) async {
    if (Platform.isWindows) return _downloadCurl(text);
    return _downloadHttp(text);
  }

  /// Windows: curl (bypasses V2RayN proxy)
  Future<String?> _downloadCurl(String text) async {
    final file = File(
        '${Directory.systemTemp.path}/en_baodian_${text.hashCode}.mp3');
    final url =
        'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(text)}&type=1';
    try {
      final result = await Process.run('curl.exe', [
        '-s', '-f', '--noproxy', '*',
        '--connect-timeout', '5', '--max-time', '10',
        '-L',
        '-o', file.path,
        url,
      ]);
      if (result.exitCode != 0) return null;
      if (!file.existsSync() || file.lengthSync() < 200) return null;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Android / macOS / Linux: Dart HttpClient
  Future<String?> _downloadHttp(String text) async {
    final file = File(
        '${Directory.systemTemp.path}/en_baodian_${text.hashCode}.mp3');
    final url =
        'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(text)}&type=1';
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final res = await req.close().timeout(const Duration(seconds: 15));
      print('[TTS] HTTP ${res.statusCode} len=${text.length}');
      if (res.statusCode != 200) {
        client.close();
        return null;
      }
      final bytes = await res
          .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
      await file.writeAsBytes(Uint8List.fromList(bytes));
      client.close();
      print('[TTS] Downloaded ${bytes.length} bytes for "${text.substring(0, text.length > 20 ? 20 : text.length)}..."');
      if (!file.existsSync() || file.lengthSync() < 100) return null;
      return file.path;
    } catch (e) {
      print('[TTS] Download error: $e');
      return null;
    }
  }

  // ── Baidu TTS (no length limit, accessible in China) ────

  Future<String?> _downloadBaidu(String text) async {
    final file = File(
        '${Directory.systemTemp.path}/en_baodian_${text.hashCode}_baidu.mp3');
    final url =
        'https://fanyi.baidu.com/gettts?lan=en&text=${Uri.encodeComponent(text)}&spd=3';
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      req.headers.set('Referer', 'https://fanyi.baidu.com/');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        client.close();
        return null;
      }
      final bytes = await res
          .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
      await file.writeAsBytes(Uint8List.fromList(bytes));
      client.close();
      if (!file.existsSync() || file.lengthSync() < 100) return null;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ── local fallback ─────────────────────────────────────────

  Future<void> _speakLocal(String text) async {
    if (Platform.isWindows) {
      await speakLocalTts(text);
    }
    // Android: no local fallback — just skip
  }
}
