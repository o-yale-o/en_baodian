import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

class TtsService {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _cache = {};

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

  /// Speak and wait for completion
  Future<void> speakAndWait(String text) async {
    await _player.stop();
    final key = text.trim().toLowerCase();
    String? path = _cache[key];
    if (path == null) {
      path = await _download(text);
      if (path != null) _cache[key] = path;
    }
    if (path != null) {
      try {
        final c = Completer<void>();
        StreamSubscription? sub;
        sub = _player.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.completed) {
            sub?.cancel();
            if (!c.isCompleted) c.complete();
          }
        });
        await _player.play(DeviceFileSource(path));
        final timeoutSec = (text.length * 0.5).clamp(3, 30).toInt();
        await c.future.timeout(Duration(seconds: timeoutSec));
        sub?.cancel();
        return;
      } catch (_) {
        // audioplayers failed – fall through to SAPI
      }
    }
    await _speakLocal(text);
  }

  /// Speak Chinese text using local SAPI
  Future<void> speakChinese(String text) async {
    if (text.isEmpty) return;
    final safe = text.replaceAll("'", "''");
    await Process.run('powershell.exe', [
      '-NoProfile', '-Command',
      "Add-Type -AssemblyName System.Speech; "
          "\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
          "\$s.SelectVoice('Microsoft Huihui Desktop'); "
          "\$s.Rate = -2; "
          "\$s.Speak('$safe')",
    ], runInShell: true);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }

  // ── download via curl ──────────────────────────────────────

  Future<String?> _download(String text) async {
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

  // ── local fallback (SAPI) ──────────────────────────────────

  Future<void> _speakLocal(String text) async {
    final safe = text.replaceAll("'", "''");
    await Process.run('powershell.exe', [
      '-NoProfile', '-Command',
      "Add-Type -AssemblyName System.Speech; "
          "\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
          "\$s.SelectVoice('Microsoft Zira Desktop'); "
          "\$s.Rate = -2; "
          "\$s.Speak('$safe')",
    ], runInShell: true);
  }
}
