import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:video_player/video_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';

class _PlayInfo {
  final int used;
  final int? max;
  final Duration? remaining;
  const _PlayInfo(this.used, this.max, this.remaining);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scripture Media',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MyHomePage(title: 'Scripture Media Player'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _deviceId = 'Unknown';
  VideoPlayerController? _controller;
  Map<String, dynamic>? _bundleConfig;
  String _status = 'No bundle loaded.';
  bool _isLoading = false;
  static const String _saltConst = 'scripture-media-app-2024';
  // Shared config decryption key (must match desktop)
  static const String _configSharedKey = 'scripture-media-config-v1';
  // Decrypted media discovered from the last import
  List<File> _decryptedFiles = [];
  String? _currentMediaPath;
  // Playback session tracking
  Timer? _playChargeTimer;
  bool _sessionActive = false;
  bool _sessionCharged = false;
  // Persisted auto-charge scheduling
  static const String _pendingPrefix = 'pendingCharge';

  @override
  void initState() {
    super.initState();
    _getDeviceId();
    _loadLastPlayed();
  }

  Future<void> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String? deviceId;
    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceId = android.id; // hardware-backed unique ID
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceId = ios.identifierForVendor;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _deviceId = deviceId ?? 'Unknown');
  }

  Future<void> _pickAndProcessBundle() async {
    setState(() {
      _isLoading = true;
      _status = 'Picking file...';
    });
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['smbundle'],
        );
      } on PlatformException {
        // Some Android document providers don't support custom filters.
        // Fall back to allowing any file and validate the extension ourselves.
        setState(() => _status = 'File filter unsupported; showing all files…');
        result = await FilePicker.platform.pickFiles(type: FileType.any);
      }
      if (result == null || result.files.single.path == null) {
        setState(() => _status = 'File picking cancelled.');
        return;
      }
      final bundlePath = result.files.single.path!;
      if (!bundlePath.toLowerCase().endsWith('.smbundle')) {
        setState(() => _status = 'Please select a .smbundle file.');
        return;
      }
      setState(() => _status = 'Extracting bundle...');

      final tempDir = await getTemporaryDirectory();
      final extractionPath = '${tempDir.path}/bundle_extract';
      await Directory(extractionPath).create(recursive: true);

      // Decompress .tar.gz (.smbundle) using a file stream to reduce peak memory
      final input = InputFileStream(bundlePath);
      final tarBytes = GZipDecoder().decodeBuffer(input);
      input.close();
      final archive = TarDecoder().decodeBytes(tarBytes);
      for (final file in archive) {
        final outPath = '$extractionPath/${file.name}';
        if (file.isFile) {
          final outDir = Directory(File(outPath).parent.path);
          if (!await outDir.exists()) {
            await outDir.create(recursive: true);
          }
          final output = OutputFileStream(outPath);
          file.writeContent(output);
          output.close();
        } else {
          await Directory(outPath).create(recursive: true);
        }
      }

      // Decrypt and validate bundle.smb config with shared key (REQUIRED)
      final cfgFile = File('$extractionPath/bundle.smb');
      Map<String, dynamic>? config;
      if (await cfgFile.exists()) {
        try {
          final rawText = await cfgFile.readAsString();
          final decrypted = _cryptoJsAesDecrypt(rawText, _configSharedKey);
          if (decrypted == null) {
            await _deleteDirectory(Directory(extractionPath));
            setState(() => _status = 'Error: Cannot open bundle config.');
            return;
          }
          config = json.decode(utf8.decode(decrypted)) as Map<String, dynamic>;
          // Do not assign to _bundleConfig here; finalize only after policy checks pass
        } catch (e) {
          await _deleteDirectory(Directory(extractionPath));
          setState(() => _status = 'Error: Cannot open bundle config.');
          return;
        }
      } else {
        await _deleteDirectory(Directory(extractionPath));
        setState(() => _status = 'Error: Missing bundle config.');
        return;
      }

      // Enforce allowedDeviceIds before any media processing
      try {
        final allowed =
            (config['allowedDeviceIds'] as List?)?.cast<String>() ?? <String>[];
        if (allowed.isEmpty || !allowed.contains(_deviceId)) {
          await _deleteDirectory(Directory(extractionPath));
          setState(
            () => _status =
                'Error: This device is not authorized for this bundle.',
          );
          return;
        }
        setState(() => _status = 'Config verified for this device.');
      } catch (e) {
        await _deleteDirectory(Directory(extractionPath));
        setState(() => _status = 'Error: Invalid bundle config.');
        return;
      }

      // Decide import policy based on bundleId and previously seen bundles
      final String bundleId = (config['bundleId'] as String?) ?? 'unknown';
      final prefs = await SharedPreferences.getInstance();
      final String? activeBundleId = prefs.getString('activeBundleId');
      final List<String> seenBundles =
          (prefs.getStringList('seenBundleIds') ?? <String>[]).toList();

      // If attempting to switch back to an older, previously seen bundle, block it
      if (activeBundleId != null &&
          activeBundleId != bundleId &&
          seenBundles.contains(bundleId)) {
        await _deleteDirectory(Directory(extractionPath));
        setState(
          () => _status =
              'This bundle was previously used and cannot be re-imported.',
        );
        return;
      }

      // If attempting to re-import the currently active bundle, do nothing
      if (activeBundleId != null && activeBundleId == bundleId) {
        await _deleteDirectory(Directory(extractionPath));
        setState(() => _status = 'Bundle already active. No changes made.');
        return;
      }

      // Prepare persistent content directory
      final docs = await getApplicationDocumentsDirectory();
      final contentDir = Directory('${docs.path}/content');
      await contentDir.create(recursive: true);

      // If importing a different, new bundle: clear previous content and reset active
      // Clear any pending charges for the previous bundle
      await _clearAllPendingChargesForBundle(activeBundleId);

      final bool importingNewBundle =
          activeBundleId == null || activeBundleId != bundleId;
      if (importingNewBundle) {
        // Clear previous content
        await _deleteDirectory(contentDir);
        await contentDir.create(recursive: true);
      }

      // Decrypt media based on config mapping so filenames match original fileName
      setState(() => _status = 'Decrypting media…');
      final deviceKey = _generateDeviceKey(_deviceId, _saltConst);
      File? firstDecrypted;
      final List<dynamic> mediaList =
          (config['mediaFiles'] as List?) ?? <dynamic>[];
      for (final item in mediaList) {
        if (item is! Map) continue;
        final encPath = item['encryptedPath'] as String?;
        final origName = item['fileName'] as String?;
        if (encPath == null || origName == null) continue;
        final srcFile = File('$extractionPath/$encPath');
        if (!await srcFile.exists()) continue;
        try {
          final encText = await srcFile.readAsString();
          final plainBytes = _cryptoJsAesDecrypt(encText, deviceKey);
          if (plainBytes == null) continue;
          final mediaBytes = base64.decode(utf8.decode(plainBytes));
          final outFile = File('${contentDir.path}/$origName');
          await outFile.writeAsBytes(mediaBytes);
          firstDecrypted ??= outFile;
        } catch (_) {
          // skip bad file
        }
      }

      // Persist bundle state and file list
      // Assign the verified config now that import succeeded
      _bundleConfig = config;
      // Update seen/active bundle tracking
      if (!seenBundles.contains(bundleId)) {
        seenBundles.add(bundleId);
        await prefs.setStringList('seenBundleIds', seenBundles);
      }
      await prefs.setString('activeBundleId', bundleId);

      // Build decrypted file list from persistent content dir
      final files = <File>[];
      if (await contentDir.exists()) {
        await for (final entity in contentDir.list(recursive: false)) {
          if (entity is File) files.add(entity);
        }
      }

      if (firstDecrypted != null) {
        await _saveLastPlayed(firstDecrypted.path, config);
        _initializePlayer(firstDecrypted.path);
        setState(() {
          _decryptedFiles = files..sort((a, b) => a.path.compareTo(b.path));
          _status = 'Imported bundle and ready.';
        });
      } else {
        setState(() {
          _decryptedFiles = files..sort((a, b) => a.path.compareTo(b.path));
          _status = 'No playable media for this device.';
        });
      }

      // Delete extracted temp and original bundle file after successful import
      await _deleteDirectory(Directory(extractionPath));
      try {
        await File(bundlePath).delete();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==== CryptoJS AES(passphrase) compatibility helpers ====

  String _generateDeviceKey(String deviceId, String salt) {
    // Returns hex string, matching CryptoJS.SHA256(...).toString()
    return sha256.convert(utf8.encode(deviceId + salt)).toString();
  }

  Map<String, Uint8List> _evpBytesToKey(
    Uint8List pass,
    Uint8List salt,
    int keyLen,
    int ivLen,
  ) {
    final totalLen = keyLen + ivLen;
    final List<int> buffer = [];
    Uint8List prev = Uint8List(0);
    while (buffer.length < totalLen) {
      final md = md5
          .convert(Uint8List.fromList([...prev, ...pass, ...salt]))
          .bytes;
      buffer.addAll(md);
      prev = Uint8List.fromList(md);
    }
    final key = Uint8List.fromList(buffer.sublist(0, keyLen));
    final iv = Uint8List.fromList(buffer.sublist(keyLen, keyLen + ivLen));
    return {'key': key, 'iv': iv};
  }

  Uint8List? _cryptoJsAesDecrypt(String cipherBase64, String passphrase) {
    try {
      final raw = base64.decode(cipherBase64);
      // Expect 'Salted__' + 8 bytes salt per OpenSSL salted format
      if (raw.length < 16) return null;
      final header = utf8.decode(raw.sublist(0, 8));
      if (header != 'Salted__') return null;
      final salt = raw.sublist(8, 16);
      final data = raw.sublist(16);
      final passBytes = Uint8List.fromList(utf8.encode(passphrase));
      final params = _evpBytesToKey(
        passBytes,
        Uint8List.fromList(salt),
        32,
        16,
      ); // AES-256-CBC
      final key = enc.Key(params['key']!);
      final iv = enc.IV(params['iv']!);
      final aes = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );
      final decrypted = aes.decryptBytes(enc.Encrypted(data), iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (_) {
      return null;
    }
  }

  void _initializePlayer(String mediaPath) {
    // Finalize any active session before switching media
    _finalizePlaySession();
    _controller?.dispose();
    _currentMediaPath = mediaPath;
    _controller = VideoPlayerController.file(File(mediaPath))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _attemptAutoPlay();
      });
  }

  Future<void> _attemptAutoPlay() async {
    if (_controller == null) return;
    // Before deciding, process any overdue pending charges
    await _processPendingCharges();
    if (!await _canPlayCurrent()) {
      final id = _currentMediaId;
      Duration? rem;
      if (id != null) rem = await _remainingBlockTime(id);
      if (id != null) {
        rem = await _remainingBlockTime(id);
      }
      if (id != null) {
        rem = await _remainingBlockTime(id);
      }
      final msg = rem == null
          ? 'Play limit reached for this media.'
          : 'Play limit reached. Resets in ${_fmtDuration(rem)}';
      setState(() {
        _status = msg;
      });
      return;
    }
    _startPlaySession();
    _controller!.play();
    // If there was a persisted pending for this media from a prior run, ensure a timer is armed
    await _scheduleTimerFromPending();
  }

  Future<void> _stopPlayback() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.pause();
      await c.seekTo(Duration.zero);
    } catch (_) {
      // ignore
    }
  }

  // ===== Play-limit, session, and counting logic =====
  String? get _currentMediaId =>
      _currentMediaPath != null ? _basename(_currentMediaPath!) : null;

  Map<String, dynamic>? _findMediaConfig(String fileName) {
    final cfg = _bundleConfig;
    if (cfg == null) return null;
    final List<dynamic>? files = cfg['mediaFiles'] as List<dynamic>?;
    if (files == null) return null;
    for (final f in files) {
      if (f is Map && (f['fileName'] == fileName)) {
        return Map<String, dynamic>.from(f);
      }
    }
    return null;
  }

  int? _maxPlaysFor(String fileName) {
    final m = _findMediaConfig(fileName);
    if (m == null) return null;
    final Map<String, dynamic>? limit = (m['playbackLimit'] as Map?)
        ?.cast<String, dynamic>();
    int? maxPlays = limit?['maxPlays'] as int?;
    if (maxPlays == null) {
      final cfg = _bundleConfig;
      final Map<String, dynamic>? defaults = (cfg?['playbackLimits'] as Map?)
          ?.cast<String, dynamic>();
      final Map<String, dynamic>? def = (defaults?['default'] as Map?)
          ?.cast<String, dynamic>();
      maxPlays = (def?['maxPlays'] as num?)?.toInt();
    }
    return maxPlays;
  }

  int _resetHoursFor(String fileName) {
    final m = _findMediaConfig(fileName);
    int? hours;
    if (m != null) {
      final Map<String, dynamic>? limit = (m['playbackLimit'] as Map?)
          ?.cast<String, dynamic>();
      hours = (limit?['resetIntervalHours'] as num?)?.toInt();
    }
    if (hours == null) {
      final cfg = _bundleConfig;
      final Map<String, dynamic>? defaults = (cfg?['playbackLimits'] as Map?)
          ?.cast<String, dynamic>();
      final Map<String, dynamic>? def = (defaults?['default'] as Map?)
          ?.cast<String, dynamic>();
      hours = (def?['resetIntervalHours'] as num?)?.toInt();
    }
    return hours ?? 24;
  }

  Future<void> _incrementPlaysUsed(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playsUsed:$bundleId:$fileName';
    // Ensure window
    final used = await _ensureWindowAndGetUsed(fileName);
    final current = used;
    await prefs.setInt(key, current + 1);
  }

  Future<bool> _canPlayCurrent() async {
    final id = _currentMediaId;
    if (id == null) return false;
    final maxPlays = _maxPlaysFor(id);
    if (maxPlays == null) return true; // No known limit
    final used = await _ensureWindowAndGetUsed(id);
    return used < maxPlays;
  }

  Future<int> _ensureWindowAndGetUsed(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final usedKey = 'playsUsed:$bundleId:$fileName';
    final winKey = 'playWindowStart:$bundleId:$fileName';
    final now = DateTime.now().millisecondsSinceEpoch;
    final resetMs = _resetHoursFor(fileName) * 3600 * 1000;
    final start = prefs.getInt(winKey);
    int used = prefs.getInt(usedKey) ?? 0;
    if (start == null || (now - start) >= resetMs) {
      await prefs.setInt(usedKey, 0);
      await prefs.setInt(winKey, now);
      used = 0;
    }
    return used;
  }

  Future<Duration?> _remainingBlockTime(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final winKey = 'playWindowStart:$bundleId:$fileName';
    final start = prefs.getInt(winKey);
    if (start == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final resetMs = _resetHoursFor(fileName) * 3600 * 1000;
    final end = start + resetMs;
    final remainingMs = end - now;
    if (remainingMs <= 0) return Duration.zero;
    return Duration(milliseconds: remainingMs);
  }

  Future<_PlayInfo> _getPlayInfo(String fileName) async {
    final used = await _ensureWindowAndGetUsed(fileName);
    final max = _maxPlaysFor(fileName);
    final rem = await _remainingBlockTime(fileName);
    return _PlayInfo(used, max, rem);
  }

  void _startPlaySession() {
    if (_controller == null) return;
    // mark flags
    _sessionActive = true;
    _sessionCharged = false;
    _playChargeTimer?.cancel();
    final duration = _controller!.value.duration;
    if (duration > Duration.zero) {
      final chargeAfter = Duration(
        milliseconds: (duration.inMilliseconds * 1.25).round(),
      );
      // Persist a pending charge deadline so app exit/crash cannot bypass it
      _persistPendingCharge(chargeAfter);
      _playChargeTimer = Timer(chargeAfter, () async {
        await _forceChargeAndStop();
      });
    }
  }

  Future<void> _finalizePlaySession() async {
    _playChargeTimer?.cancel();
    if (_sessionActive) {
      final hadProgress =
          (_controller?.value.position ?? Duration.zero) > Duration.zero;
      if (hadProgress && !_sessionCharged && _currentMediaId != null) {
        await _incrementPlaysUsed(_currentMediaId!);
        await _clearPendingForCurrent();
      }
    }
    _sessionActive = false;
    _sessionCharged = false;
  }

  // ===== Pending charge persistence and enforcement =====
  String _bundleIdOrUnknown() =>
      (_bundleConfig != null
          ? (_bundleConfig!['bundleId'] as String?)
          : null) ??
      'unknown';

  Future<void> _persistPendingCharge(Duration chargeAfter) async {
    final id = _currentMediaId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final chargeAt = now + chargeAfter.inMilliseconds;
    final key = '$_pendingPrefix:${_bundleIdOrUnknown()}:$id';
    await prefs.setInt(key, chargeAt);
  }

  Future<int?> _getPendingFor(String bundleId, String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_pendingPrefix:$bundleId:$fileName';
    return prefs.getInt(key);
  }

  Future<void> _clearPendingForCurrent() async {
    final id = _currentMediaId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_pendingPrefix:${_bundleIdOrUnknown()}:$id';
    await prefs.remove(key);
  }

  Future<void> _scheduleTimerFromPending() async {
    final id = _currentMediaId;
    if (id == null) return;
    final bundleId = _bundleIdOrUnknown();
    final pending = await _getPendingFor(bundleId, id);
    if (pending == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = pending - now;
    _playChargeTimer?.cancel();
    if (remainingMs <= 0) {
      await _forceChargeAndStop();
    } else {
      _playChargeTimer = Timer(Duration(milliseconds: remainingMs), () async {
        await _forceChargeAndStop();
      });
    }
  }

  Future<void> _forceChargeAndStop() async {
    if (_currentMediaId == null) return;
    if (!_sessionCharged) {
      await _incrementPlaysUsed(_currentMediaId!);
      _sessionCharged = true;
    }
    await _clearPendingForCurrent();
    try {
      // Stop playback as part of enforcement
      await _controller?.pause();
      await _controller?.seekTo(Duration.zero);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _processPendingCharges() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    if (keys.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final k in keys) {
      if (!k.startsWith('$_pendingPrefix:')) continue;
      final chargeAt = prefs.getInt(k);
      if (chargeAt == null) continue;
      if (chargeAt <= now) {
        // Parse components: pendingCharge:bundleId:fileName
        final parts = k.split(':');
        if (parts.length >= 3) {
          final fileName = parts.sublist(2).join(':');
          await _incrementPlaysUsed(fileName);
          await prefs.remove(k);
        } else {
          await prefs.remove(k);
        }
      }
    }
  }

  Future<void> _clearAllPendingChargesForBundle(String? bundleId) async {
    if (bundleId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final k in keys) {
      if (k.startsWith('$_pendingPrefix:$bundleId:')) {
        await prefs.remove(k);
      }
    }
  }

  Future<void> _deleteDirectory(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // ignore cleanup errors
    }
  }

  String _fmtDuration(Duration d) {
    if (d.isNegative) return '0s';
    final totalSeconds = d.inSeconds;
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (parts.isEmpty) parts.add('${seconds}s');
    return parts.join(' ');
  }

  Future<void> _saveLastPlayed(
    String videoPath,
    Map<String, dynamic> cfg,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPlayedPath', videoPath);
    await prefs.setString('lastBundleConfig', json.encode(cfg));
  }

  Future<void> _loadLastPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await _processPendingCharges();
    final p = prefs.getString('lastPlayedPath');
    final c = prefs.getString('lastBundleConfig');
    if (p != null && await File(p).exists()) {
      if (c != null) {
        _bundleConfig = json.decode(c) as Map<String, dynamic>;
      }
      // Rehydrate current content list from persistent content dir
      final docs = await getApplicationDocumentsDirectory();
      final contentDir = Directory('${docs.path}/content');
      final files = <File>[];
      if (await contentDir.exists()) {
        await for (final entity in contentDir.list(recursive: false)) {
          if (entity is File) files.add(entity);
        }
      }
      _decryptedFiles = files..sort((a, b) => a.path.compareTo(b.path));
      _initializePlayer(p);
      // If there is a pending for this media, re-arm timer on startup
      await _scheduleTimerFromPending();
      if (!mounted) return;
      setState(() => _status = 'Loaded last played media.');
    }
  }

  @override
  void dispose() {
    _finalizePlaySession();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Device ID'),
                content: SelectableText(_deviceId),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(child: Text(_status)),
            if (_bundleConfig != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Media: ${_bundleConfig!['mediaFile'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Playback area (video preview for video; simple banner for audio)
            if (_controller != null && _controller!.value.isInitialized)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (_isCurrentVideo)
                      AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                    else
                      Container(
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.music_note),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentMediaPath != null
                                    ? _basename(_currentMediaPath!)
                                    : 'Audio',
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Seek bar (scrubber)
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller!,
                      builder: (context, value, _) {
                        final duration = value.duration;
                        final position = value.position;
                        final max = duration.inMilliseconds
                            .clamp(0, 1 << 31)
                            .toDouble();
                        final val = position.inMilliseconds
                            .clamp(0, duration.inMilliseconds)
                            .toDouble();
                        if (duration == Duration.zero) {
                          return const SizedBox.shrink();
                        }
                        return Slider(
                          min: 0,
                          max: max <= 0 ? 1 : max,
                          value: val.isNaN ? 0 : val,
                          onChanged: (v) async {
                            // allow scrubbing
                            await _controller!.seekTo(
                              Duration(milliseconds: v.toInt()),
                            );
                            setState(() {});
                          },
                        );
                      },
                    ),

                    // Basic transport controls
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller!,
                      builder: (context, value, _) {
                        final position = value.position;
                        final duration = value.duration;
                        String fmt(Duration d) {
                          String two(int n) => n.toString().padLeft(2, '0');
                          final h = d.inHours;
                          final m = d.inMinutes.remainder(60);
                          final s = d.inSeconds.remainder(60);
                          return h > 0
                              ? '${two(h)}:${two(m)}:${two(s)}'
                              : '${two(m)}:${two(s)}';
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Play',
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () async {
                                if (!await _canPlayCurrent()) {
                                  final id = _currentMediaId;
                                  Duration? rem;
                                  if (id != null) {
                                    rem = await _remainingBlockTime(id);
                                  }
                                  final msg = rem == null
                                      ? 'Play limit reached for this media.'
                                      : 'Play limit reached. Resets in ${_fmtDuration(rem)}';
                                  setState(() {
                                    _status = msg;
                                  });
                                  return;
                                }
                                _startPlaySession();
                                _controller!.play();
                                setState(() {});
                              },
                            ),
                            IconButton(
                              tooltip: 'Pause',
                              icon: const Icon(Icons.pause),
                              onPressed: () {
                                _controller!.pause();
                                setState(() {});
                              },
                            ),
                            IconButton(
                              tooltip: 'Stop',
                              icon: const Icon(Icons.stop),
                              onPressed: () async {
                                await _stopPlayback();
                                await _finalizePlaySession();
                                setState(() {});
                              },
                            ),
                            const SizedBox(width: 12),
                            Text('${fmt(position)} / ${fmt(duration)}'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              )
            else if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              const SizedBox.shrink(),

            const SizedBox(height: 12),
            // Decrypted file list
            Expanded(
              child: _decryptedFiles.isEmpty
                  ? const Center(child: Text('No decrypted media yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: _decryptedFiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = _decryptedFiles[index];
                        final name = _basename(file.path);
                        final isVideo = _isVideoExtension(name);
                        return FutureBuilder<_PlayInfo>(
                          future: _getPlayInfo(name),
                          builder: (context, snapshot) {
                            final info = snapshot.data;
                            String? subtitle;
                            Widget? trailing;
                            if (info != null) {
                              if (info.max == null) {
                                subtitle = 'No play limit';
                                trailing = const SizedBox.shrink();
                              } else {
                                final left = (info.max! - info.used).clamp(
                                  0,
                                  info.max!,
                                );
                                if (left > 0) {
                                  final resetStr =
                                      (info.remaining != null &&
                                          info.remaining! > Duration.zero)
                                      ? ' · resets in ${_fmtDuration(info.remaining!)}'
                                      : '';
                                  subtitle =
                                      '$left / ${info.max} plays left$resetStr';
                                  trailing = IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () =>
                                        _initializePlayer(file.path),
                                  );
                                } else {
                                  final resetStr =
                                      (info.remaining != null &&
                                          info.remaining! > Duration.zero)
                                      ? ' · resets in ${_fmtDuration(info.remaining!)}'
                                      : '';
                                  subtitle = 'Blocked$resetStr';
                                  trailing = const Icon(
                                    Icons.lock,
                                    color: Colors.redAccent,
                                  );
                                }
                              }
                            }
                            return ListTile(
                              leading: Icon(
                                isVideo
                                    ? Icons.movie
                                    : Icons.audio_file_outlined,
                              ),
                              title: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: subtitle != null
                                  ? Text(subtitle)
                                  : null,
                              onTap: () => _initializePlayer(file.path),
                              trailing:
                                  trailing ??
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () =>
                                        _initializePlayer(file.path),
                                  ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _pickAndProcessBundle,
        tooltip: 'Import Bundle',
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.file_upload),
      ),
    );
  }

  bool get _isCurrentVideo => _isVideoExtension(_currentMediaPath ?? '');

  bool _isVideoExtension(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4');
  }

  String _basename(String path) => path.split(Platform.pathSeparator).last;
}
