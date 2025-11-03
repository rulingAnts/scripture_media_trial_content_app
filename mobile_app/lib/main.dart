import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
// import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart'
    show PlatformException, Clipboard, ClipboardData;
import 'package:flutter/services.dart' as services;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:video_player/video_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:audio_session/audio_session.dart';

// Global app key to allow changing locale from settings page
final GlobalKey<_MyAppState> _myAppKey = GlobalKey<_MyAppState>();

class _PlayInfo {
  final int used;
  final int? max;
  final Duration? remaining;
  final int? totalPlays;
  final int? maxTotal;
  final bool isPermanentlyLocked;
  final String? lockReason;
  const _PlayInfo(
    this.used,
    this.max,
    this.remaining,
    this.totalPlays,
    this.maxTotal,
    this.isPermanentlyLocked,
    this.lockReason,
  );
}

// ===== Streaming AES-CBC (OpenSSL salted) decryptor for large files =====
// Transforms an encrypted byte stream (base64-decoded, starting with 'Salted__'+8 salt)
// into decrypted plaintext bytes (with PKCS7 padding removed) without loading whole content into memory.
class _OpenSslAesCbcPkcs7StreamDecryptor
    extends StreamTransformerBase<List<int>, List<int>> {
  final String passphrase;
  _OpenSslAesCbcPkcs7StreamDecryptor(this.passphrase);

  static const int _blockSize = 16;
  final List<int> _header = [];
  final List<int> _buf = [];
  bool _inited = false;
  late pc.CBCBlockCipher _cbc;

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) async* {
    // Use a controller to sequentially process chunks
    final controller = StreamController<List<int>>();

    void emitDecryptedBlocks() {
      // While we have at least two blocks buffered, decrypt one and emit.
      while (_buf.length >= _blockSize * 2) {
        final block = Uint8List.fromList(_buf.sublist(0, _blockSize));
        final out = Uint8List(_blockSize);
        _cbc.processBlock(block, 0, out, 0);
        controller.add(out);
        _buf.removeRange(0, _blockSize);
      }
    }

    stream.listen(
      (chunk) {
        try {
          if (!_inited) {
            _header.addAll(chunk);
            if (_header.length >= 16) {
              final magic = String.fromCharCodes(_header.sublist(0, 8));
              if (magic != 'Salted__') {
                throw StateError('Invalid OpenSSL salted header');
              }
              final salt = Uint8List.fromList(_header.sublist(8, 16));
              final passBytes = Uint8List.fromList(utf8.encode(passphrase));
              final params = _evpBytesToKeyStatic(passBytes, salt, 32, 16);
              final keyParam = pc.KeyParameter(params['key']!);
              _cbc = pc.CBCBlockCipher(pc.AESEngine())
                ..reset()
                ..init(false, pc.ParametersWithIV(keyParam, params['iv']!));
              _inited = true;
              // Any leftover beyond header goes to buffer
              final remain = _header.length - 16;
              if (remain > 0) {
                _buf.addAll(_header.sublist(16));
              }
            }
          } else {
            _buf.addAll(chunk);
          }
          if (_inited) emitDecryptedBlocks();
        } catch (e) {
          controller.addError(e);
        }
      },
      onError: controller.addError,
      onDone: () {
        try {
          if (!_inited) {
            throw StateError('Missing OpenSSL salted header');
          }
          if (_buf.isEmpty || _buf.length % _blockSize != 0) {
            throw StateError('Ciphertext not aligned to block size');
          }
          // Decrypt remaining blocks
          final out = BytesBuilder(copy: false);
          while (_buf.length >= _blockSize) {
            final block = Uint8List.fromList(_buf.sublist(0, _blockSize));
            final dec = Uint8List(_blockSize);
            _cbc.processBlock(block, 0, dec, 0);
            out.add(dec);
            _buf.removeRange(0, _blockSize);
          }
          final decAll = out.takeBytes();
          if (decAll.isEmpty) {
            controller.close();
            return;
          }
          // Remove PKCS7 padding
          final pad = decAll.last;
          if (pad <= 0 || pad > _blockSize) {
            throw StateError('Invalid PKCS7 padding');
          }
          // Verify padding bytes
          for (int i = 0; i < pad; i++) {
            if (decAll[decAll.length - 1 - i] != pad) {
              throw StateError('Invalid PKCS7 padding');
            }
          }
          final trimmed = decAll.sublist(0, decAll.length - pad);
          if (trimmed.isNotEmpty) controller.add(trimmed);
          controller.close();
        } catch (e) {
          controller.addError(e);
          controller.close();
        }
      },
      cancelOnError: true,
    );

    yield* controller.stream;
  }
}

// Standalone EVP_BytesToKey helper (OpenSSL-compatible), returns key and iv.
Map<String, Uint8List> _evpBytesToKeyStatic(
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

void main() {
  runApp(MyApp(key: _myAppKey));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  // custom translation overlay: { localeCode: { key: translation } }
  Map<String, Map<String, String>> _custom = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('uiLocaleCode');
    if (code != null && code.isNotEmpty) {
      setState(() => _locale = Locale(code));
    }
    final customJson = prefs.getString('customTranslationsJson');
    if (customJson != null && customJson.isNotEmpty) {
      try {
        final dynamic parsed = json.decode(customJson);
        final normalized = <String, Map<String, String>>{};
        if (parsed is Map) {
          // parsed may be either {key:value} or {locale:{key:value}}
          final map = Map<String, dynamic>.from(parsed.cast<String, dynamic>());
          final isFlat = map.values.every((v) => v is String);
          if (isFlat) {
            // apply to currently selected locale (or 'en' fallback)
            final codeToUse = code ?? 'en';
            normalized[codeToUse] = map.map(
              (k, v) => MapEntry(k, (v as String)),
            );
          } else {
            // treat as per-locale map
            for (final entry in map.entries) {
              final localeCode = entry.key;
              final value = entry.value;
              if (value is Map) {
                final strMap = Map<String, dynamic>.from(
                  value.cast<String, dynamic>(),
                );
                normalized[localeCode] = strMap.map(
                  (k, v) => MapEntry(k, (v as String)),
                );
              }
            }
          }
        }
        if (normalized.isNotEmpty) {
          setState(() => _custom = normalized);
        }
      } catch (_) {
        // ignore parse errors
      }
    }
  }

  void setLocaleCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null || code.isEmpty) {
      await prefs.remove('uiLocaleCode');
      setState(() => _locale = null);
    } else {
      await prefs.setString('uiLocaleCode', code);
      setState(() => _locale = Locale(code));
    }
  }

  void updateCustomTranslations(Map<String, Map<String, String>> custom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customTranslationsJson', json.encode(custom));
    setState(() => _custom = custom);
  }

  @override
  Widget build(BuildContext context) {
    final title = L10n.t('app_title', _locale, _custom);
    return MaterialApp(
      title: title,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      locale: _locale,
      localizationsDelegates: const [
        _FallbackMaterialLocalizationsDelegate(),
        _FallbackWidgetsLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('nl'),
        Locale('de'),
        Locale('af'),
        Locale('pt'),
        Locale('id'),
        Locale('ru'),
        Locale('hi'),
        Locale('ar'),
        Locale('zh'), // Simplified
        Locale('tpi'), // Tok Pisin
      ],
      home: MyHomePage(title: title),
    );
  }
}

// Fallback localizations so unsupported locales (e.g., Tok Pisin 'tpi')
// won’t cause a runtime error in Material/Widgets; we fallback to English.
class _FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tpi';
  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return SynchronousFuture(const DefaultMaterialLocalizations());
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<MaterialLocalizations> old,
  ) => false;
}

class _FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _FallbackWidgetsLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tpi';
  @override
  Future<WidgetsLocalizations> load(Locale locale) async {
    return SynchronousFuture(const DefaultWidgetsLocalizations());
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<WidgetsLocalizations> old,
  ) => false;
}

class L10n {
  static const _base = <String, Map<String, String>>{
    'en': {
      'app_title': 'Scripture Demo Player',
      'device_id': 'Device ID',
      'close': 'Close',
      'import_bundle': 'Import Bundle',
      'play': 'Play',
      'pause': 'Pause',
      'stop': 'Stop',
      'no_decrypted_media_yet': 'No decrypted media yet.',
      // Status & messages
      'status_initial': 'No bundle loaded.',
      'status_picking_file': 'Picking file…',
      'status_file_filter_unsupported':
          'File filter unsupported; showing all files…',
      'status_file_picking_cancelled': 'File picking cancelled.',
      'status_select_smbundle': 'Please select a .smbundle file.',
      'status_extracting_bundle': 'Extracting bundle…',
      'error_open_bundle_config': 'Error: Cannot open bundle config.',
      'error_missing_bundle_config': 'Error: Missing bundle config.',
      'error_invalid_bundle_config': 'Error: Invalid bundle config.',
      'error_device_not_authorized':
          'Error: This device is not authorized for this bundle.',
      'status_config_verified': 'Config verified for this device.',
      'status_bundle_previously_used':
          'This bundle was previously used and cannot be re-imported.',
      'status_bundle_already_active': 'Bundle already active. No changes made.',
      'status_decrypting_media': 'Decrypting media…',
      'status_import_ready': 'Imported bundle and ready.',
      'status_no_playable_media': 'No playable media for this device.',
      'status_error_generic': 'Error: {message}',
      'status_no_media_selected': 'No media selected.',
      'status_time_tamper_lock':
          'Time tampering detected. Bundle is permanently locked.',
      'status_bundle_expired_lock':
          'Bundle expired on {date}. Permanently locked.',
      'status_max_total_lock':
          'Maximum lifetime plays ({max}) reached. Permanently locked.',
      'status_must_wait': 'Must wait {duration} between plays.',
      'status_play_limit_reached': 'Play limit reached for this media.',
      'status_play_limit_reached_with_reset':
          'Play limit reached. Resets in {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'Playlist expired on {date}. Permanently locked.',
      'status_playlist_max_items_lock':
          'Maximum unique items ({max}) from playlist already played. Permanently locked.',
      'status_must_wait_between_items':
          'Must wait {duration} between playing different items.',
      'status_playlist_session_limit':
          'Session limit reached: {max} items per session. Resets in {duration}',
      'status_playlist_session_limit_no_reset':
          'Session limit reached: {max} items per session.',
      // UI labels
      'ui_media_label': 'Media: {name}',
      'ui_no_play_limit': 'No play limit',
      'ui_resets_in': ' · resets in {duration}',
      'ui_blocked': 'Blocked',
      'loaded_last_played': 'Loaded last played media.',
      'audio': 'Audio',
      'ui_locked_reason': 'Locked: {reason}',
      'lock_reason_time_tamper': 'Time tampering detected',
      'lock_reason_expired': 'Bundle expired',
      'lock_reason_lifetime_limit': 'Lifetime limit reached',
      'ui_total_suffix': ' total',
      'ui_plays_left': ' plays left',
      'ui_session_usage': 'Session: {used} / {max}',
      'ui_total_usage': 'Total: {used} / {max}',
      // Duration unit abbreviations
      'abbr_day': 'd',
      'abbr_hour': 'h',
      'abbr_minute': 'm',
      'abbr_second': 's',
      'language_settings_title': 'Language',
      'system_default': 'System default',
      'custom_translations': 'Custom translations',
      'add_custom_translations': 'Add custom JSON',
      'remove_custom_translations': 'Remove custom translations',
      'choose_json_file': 'Choose JSON file',
      'ui_demo_warning':
          'Demo content — not for distribution. This Scripture audio/video is an unfinished draft in the local language. We are still reviewing it. Please help us test and correct these recordings so we can share the final version with everyone.',
      // Confirm play dialog
      'confirm_play_title': 'Start playback?',
      'confirm_window_left': 'Window: {left} / {max} plays left',
      'confirm_window_unlimited': 'Window: unlimited',
      'confirm_lifetime_left': 'Lifetime: {left} / {max} plays left',
      'confirm_lifetime_unlimited': 'Lifetime: unlimited',
      'confirm_preview_free':
          'The first {seconds}s are free before a play is charged.',
      'start_playback': 'Start',
      'cancel': 'Cancel',
      // New UI
      'fullscreen': 'Fullscreen',
      'import_diagnostics': 'Import diagnostics',
      'import_diagnostics_subtitle':
          'Verbose import logs can help troubleshoot slow or failing imports',
      'verbose_import_logs': 'Verbose import logs',
      'view_last_import_log': 'View last import log',
      'last_import_log': 'Last import log',
      'copy': 'Copy',
      'clear_logs': 'Clear logs',
      'auto_fullscreen_on_rotate': 'Auto fullscreen on rotate',
      'auto_fullscreen_on_rotate_desc':
          'Automatically enter fullscreen when rotating device to landscape during video playback',
      'allow_landscape': 'Allow landscape rotation',
      'allow_landscape_desc':
          'Let the app rotate to landscape outside fullscreen; videos in landscape will still enter fullscreen if enabled',
    },
    'es': {
      'app_title': 'Reproductor de demostración de Escrituras',
      'device_id': 'ID del dispositivo',
      'close': 'Cerrar',
      'import_bundle': 'Importar paquete',
      'play': 'Reproducir',
      'pause': 'Pausar',
      'stop': 'Detener',
      'no_decrypted_media_yet': 'Aún no hay medios descifrados.',
      // Mensajes de estado
      'status_initial': 'No se ha cargado ningún paquete.',
      'status_picking_file': 'Seleccionando archivo…',
      'status_file_filter_unsupported':
          'Filtro de archivos no compatible; mostrando todos los archivos…',
      'status_file_picking_cancelled': 'Selección de archivo cancelada.',
      'status_select_smbundle': 'Selecciona un archivo .smbundle.',
      'status_extracting_bundle': 'Extrayendo paquete…',
      'error_open_bundle_config':
          'Error: No se puede abrir la configuración del paquete.',
      'error_missing_bundle_config':
          'Error: Falta la configuración del paquete.',
      'error_invalid_bundle_config':
          'Error: Configuración del paquete inválida.',
      'error_device_not_authorized':
          'Error: Este dispositivo no está autorizado para este paquete.',
      'status_config_verified':
          'Configuración verificada para este dispositivo.',
      'status_bundle_previously_used':
          'Este paquete se usó previamente y no se puede volver a importar.',
      'status_bundle_already_active':
          'El paquete ya está activo. No se realizaron cambios.',
      'status_decrypting_media': 'Descifrando medios…',
      'status_import_ready': 'Paquete importado y listo.',
      'status_no_playable_media':
          'No hay medios reproducibles para este dispositivo.',
      'status_error_generic': 'Error: {message}',
      'status_no_media_selected': 'Ningún medio seleccionado.',
      'status_time_tamper_lock':
          'Se detectó manipulación de tiempo. El paquete está bloqueado permanentemente.',
      'status_bundle_expired_lock':
          'El paquete expiró el {date}. Bloqueado permanentemente.',
      'status_max_total_lock':
          'Se alcanzó el máximo de reproducciones de por vida ({max}). Bloqueado permanentemente.',
      'status_must_wait': 'Debes esperar {duration} entre reproducciones.',
      'status_play_limit_reached':
          'Se alcanzó el límite de reproducciones para este medio.',
      'status_play_limit_reached_with_reset':
          'Se alcanzó el límite de reproducciones. Se restablece en {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'La lista de reproducción expiró el {date}. Bloqueado permanentemente.',
      'status_playlist_max_items_lock':
          'Ya se reprodujeron los elementos únicos máximos ({max}) de la lista. Bloqueado permanentemente.',
      'status_must_wait_between_items':
          'Debes esperar {duration} entre reproducir diferentes elementos.',
      'status_playlist_session_limit':
          'Límite de sesión alcanzado: {max} elementos por sesión. Se restablece en {duration}',
      'status_playlist_session_limit_no_reset':
          'Límite de sesión alcanzado: {max} elementos por sesión.',
      // Etiquetas UI
      'ui_media_label': 'Medio: {name}',
      'ui_no_play_limit': 'Sin límite de reproducciones',
      'ui_resets_in': ' · se restablece en {duration}',
      'ui_blocked': 'Bloqueado',
      'loaded_last_played': 'Se cargó el último medio reproducido.',
      'audio': 'Audio',
      'ui_locked_reason': 'Bloqueado: {reason}',
      'lock_reason_time_tamper': 'Se detectó manipulación de tiempo',
      'lock_reason_expired': 'Paquete expirado',
      'lock_reason_lifetime_limit': 'Se alcanzó el límite de por vida',
      'ui_total_suffix': ' total',
      'ui_plays_left': ' reproducciones restantes',
      'ui_session_usage': 'Sesión: {used} / {max}',
      'ui_total_usage': 'Total: {used} / {max}',
      // Abreviaturas de duración
      'abbr_day': 'd',
      'abbr_hour': 'h',
      'abbr_minute': 'm',
      'abbr_second': 's',
      'language_settings_title': 'Idioma',
      'system_default': 'Predeterminado del sistema',
      'custom_translations': 'Traducciones personalizadas',
      'add_custom_translations': 'Agregar JSON personalizado',
      'remove_custom_translations': 'Quitar traducciones personalizadas',
      'choose_json_file': 'Elegir archivo JSON',
      'ui_demo_warning':
          'Contenido de demostración — no para distribución. Este audio/video de las Escrituras es un borrador sin terminar en el idioma local. Aún lo estamos revisando. Por favor ayúdanos a probar y corregir estas grabaciones para poder compartir la versión final con todos.',
      // Diálogo de confirmación de reproducción
      'confirm_play_title': '¿Iniciar reproducción?',
      'confirm_window_left': 'Ventana: {left} / {max} restantes',
      'confirm_window_unlimited': 'Ventana: sin límite',
      'confirm_lifetime_left': 'De por vida: {left} / {max} restantes',
      'confirm_lifetime_unlimited': 'De por vida: sin límite',
      'confirm_preview_free':
          'Los primeros {seconds}s son gratis antes de cobrar una reproducción.',
      'start_playback': 'Iniciar',
      'cancel': 'Cancelar',
      // New UI
      'fullscreen': 'Pantalla completa',
      'import_diagnostics': 'Diagnósticos de importación',
      'import_diagnostics_subtitle':
          'Los registros detallados de importación pueden ayudar a solucionar importaciones lentas o fallidas',
      'verbose_import_logs': 'Registros de importación detallados',
      'view_last_import_log': 'Ver el último registro de importación',
      'last_import_log': 'Último registro de importación',
      'copy': 'Copiar',
      'clear_logs': 'Borrar registros',
      'auto_fullscreen_on_rotate': 'Pantalla completa automática al girar',
      'auto_fullscreen_on_rotate_desc':
          'Entrar automáticamente en pantalla completa al girar el dispositivo a horizontal durante la reproducción de video',
      'allow_landscape': 'Permitir rotación horizontal',
      'allow_landscape_desc':
          'Permitir que la app gire a horizontal fuera del modo de pantalla completa; los videos en horizontal entrarán en pantalla completa si está activado',
    },
    'fr': {
      'app_title': 'Lecteur de démo des Écritures',
      'device_id': 'ID de l’appareil',
      'close': 'Fermer',
      'import_bundle': 'Importer le lot',
      'play': 'Lire',
      'pause': 'Pause',
      'stop': 'Arrêter',
      'no_decrypted_media_yet': 'Aucun média déchiffré pour le moment.',
      'status_initial': 'Aucun lot chargé.',
      'status_picking_file': 'Sélection du fichier…',
      'status_file_filter_unsupported':
          'Filtre de fichiers non pris en charge ; affichage de tous les fichiers…',
      'status_file_picking_cancelled': 'Sélection du fichier annulée.',
      'status_select_smbundle': 'Veuillez sélectionner un fichier .smbundle.',
      'status_extracting_bundle': 'Extraction du lot…',
      'error_open_bundle_config':
          'Erreur : impossible d’ouvrir la configuration du lot.',
      'error_missing_bundle_config': 'Erreur : configuration du lot manquante.',
      'error_invalid_bundle_config': 'Erreur : configuration du lot invalide.',
      'error_device_not_authorized':
          'Erreur : cet appareil n’est pas autorisé pour ce lot.',
      'status_config_verified': 'Configuration vérifiée pour cet appareil.',
      'status_bundle_previously_used':
          'Ce lot a déjà été utilisé et ne peut pas être réimporté.',
      'status_bundle_already_active':
          'Lot déjà actif. Aucune modification effectuée.',
      'status_decrypting_media': 'Déchiffrement des médias…',
      'status_import_ready': 'Lot importé et prêt.',
      'status_no_playable_media': 'Aucun média lisible pour cet appareil.',
      'status_error_generic': 'Erreur : {message}',
      'status_no_media_selected': 'Aucun média sélectionné.',
      'status_time_tamper_lock':
          'Altération de l’heure détectée. Lot verrouillé définitivement.',
      'status_bundle_expired_lock':
          'Le lot a expiré le {date}. Verrouillé définitivement.',
      'status_max_total_lock':
          'Nombre total de lectures ({max}) atteint. Verrouillé définitivement.',
      'status_must_wait': 'Vous devez attendre {duration} entre les lectures.',
      'status_play_limit_reached': 'Limite de lectures atteinte pour ce média.',
      'status_play_limit_reached_with_reset':
          'Limite de lectures atteinte. Réinitialisation dans {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'La liste de lecture a expiré le {date}. Verrouillé définitivement.',
      'status_playlist_max_items_lock':
          'Nombre maximum d\'éléments uniques ({max}) de la liste déjà joués. Verrouillé définitivement.',
      'status_must_wait_between_items':
          'Vous devez attendre {duration} entre la lecture de différents éléments.',
      'status_playlist_session_limit':
          'Limite de session atteinte : {max} éléments par session. Réinitialisation dans {duration}',
      'status_playlist_session_limit_no_reset':
          'Limite de session atteinte : {max} éléments par session.',
      'ui_media_label': 'Média : {name}',
      'ui_no_play_limit': 'Aucune limite de lectures',
      'ui_resets_in': ' · se réinitialise dans {duration}',
      'ui_blocked': 'Bloqué',
      'loaded_last_played': 'Dernier média lu chargé.',
      'audio': 'Audio',
      'ui_locked_reason': 'Verrouillé : {reason}',
      'lock_reason_time_tamper': 'Altération de l’heure détectée',
      'lock_reason_expired': 'Lot expiré',
      'lock_reason_lifetime_limit': 'Limite à vie atteinte',
      'ui_total_suffix': ' au total',
      'ui_plays_left': ' lectures restantes',
      'ui_session_usage': 'Session : {used} / {max}',
      'ui_total_usage': 'Total : {used} / {max}',
      'abbr_day': 'j',
      'abbr_hour': 'h',
      'abbr_minute': 'min',
      'abbr_second': 's',
      'language_settings_title': 'Langue',
      'system_default': 'Langue du système',
      'custom_translations': 'Traductions personnalisées',
      'add_custom_translations': 'Ajouter un JSON personnalisé',
      'remove_custom_translations': 'Supprimer les traductions personnalisées',
      'choose_json_file': 'Choisir un fichier JSON',
      'ui_demo_warning':
          'Contenu de démonstration — ne pas distribuer. Cet audio/vidéo des Écritures est un brouillon non finalisé dans la langue locale. Nous sommes encore en relecture. Aidez‑nous à tester et corriger ces enregistrements afin de partager la version finale avec tous.',
      // Dialogue de confirmation de lecture
      'confirm_play_title': 'Démarrer la lecture ?',
      'confirm_window_left': 'Fenêtre : {left} / {max} restantes',
      'confirm_window_unlimited': 'Fenêtre : illimité',
      'confirm_lifetime_left': 'À vie : {left} / {max} restantes',
      'confirm_lifetime_unlimited': 'À vie : illimité',
      'confirm_preview_free':
          'Les {seconds}s premières sont gratuites avant la facturation d’une lecture.',
      'start_playback': 'Commencer',
      'cancel': 'Annuler',
      // New UI
      'fullscreen': 'Plein écran',
      'import_diagnostics': 'Diagnostics d’importation',
      'import_diagnostics_subtitle':
          'Les journaux d’importation détaillés peuvent aider à diagnostiquer des importations lentes ou en échec',
      'verbose_import_logs': 'Journaux d’importation détaillés',
      'view_last_import_log': 'Afficher le dernier journal d’importation',
      'last_import_log': 'Dernier journal d’importation',
      'copy': 'Copier',
      'clear_logs': 'Effacer les journaux',
      'auto_fullscreen_on_rotate': 'Plein écran automatique à la rotation',
      'auto_fullscreen_on_rotate_desc':
          'Passer automatiquement en plein écran lors de la rotation de l’appareil en paysage pendant la lecture vidéo',
      'allow_landscape': 'Autoriser l’orientation paysage',
      'allow_landscape_desc':
          'Autoriser l’app à passer en paysage hors plein écran ; les vidéos en paysage passeront en plein écran si activé',
    },
    'de': {
      'app_title': 'Schrift Demo-Player',
      'device_id': 'Geräte-ID',
      'close': 'Schließen',
      'import_bundle': 'Paket importieren',
      'play': 'Abspielen',
      'pause': 'Pause',
      'stop': 'Stopp',
      'no_decrypted_media_yet': 'Noch keine entschlüsselten Medien.',
      'status_initial': 'Kein Paket geladen.',
      'status_picking_file': 'Datei wird ausgewählt…',
      'status_file_filter_unsupported':
          'Dateifilter nicht unterstützt; zeige alle Dateien…',
      'status_file_picking_cancelled': 'Dateiauswahl abgebrochen.',
      'status_select_smbundle': 'Bitte eine .smbundle-Datei auswählen.',
      'status_extracting_bundle': 'Paket wird entpackt…',
      'error_open_bundle_config':
          'Fehler: Paketkonfiguration kann nicht geöffnet werden.',
      'error_missing_bundle_config': 'Fehler: Paketkonfiguration fehlt.',
      'error_invalid_bundle_config': 'Fehler: Ungültige Paketkonfiguration.',
      'error_device_not_authorized':
          'Fehler: Dieses Gerät ist für dieses Paket nicht autorisiert.',
      'status_config_verified': 'Konfiguration für dieses Gerät verifiziert.',
      'status_bundle_previously_used':
          'Dieses Paket wurde zuvor verwendet und kann nicht erneut importiert werden.',
      'status_bundle_already_active':
          'Paket bereits aktiv. Keine Änderungen vorgenommen.',
      'status_decrypting_media': 'Medien werden entschlüsselt…',
      'status_import_ready': 'Paket importiert und bereit.',
      'status_no_playable_media': 'Keine abspielbaren Medien für dieses Gerät.',
      'status_error_generic': 'Fehler: {message}',
      'status_no_media_selected': 'Kein Medium ausgewählt.',
      'status_time_tamper_lock':
          'Zeitmanipulation erkannt. Paket dauerhaft gesperrt.',
      'status_bundle_expired_lock':
          'Paket ist am {date} abgelaufen. Dauerhaft gesperrt.',
      'status_max_total_lock':
          'Maximale Lebenszeitwiedergaben ({max}) erreicht. Dauerhaft gesperrt.',
      'status_must_wait':
          'Zwischen den Wiedergaben müssen {duration} vergehen.',
      'status_play_limit_reached':
          'Wiedergabelimit für dieses Medium erreicht.',
      'status_play_limit_reached_with_reset':
          'Wiedergabelimit erreicht. Setzt sich zurück in {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'Wiedergabeliste ist am {date} abgelaufen. Dauerhaft gesperrt.',
      'status_playlist_max_items_lock':
          'Maximale eindeutige Elemente ({max}) der Wiedergabeliste bereits abgespielt. Dauerhaft gesperrt.',
      'status_must_wait_between_items':
          'Zwischen dem Abspielen verschiedener Elemente müssen {duration} vergehen.',
      'status_playlist_session_limit':
          'Sitzungslimit erreicht: {max} Elemente pro Sitzung. Setzt sich zurück in {duration}',
      'status_playlist_session_limit_no_reset':
          'Sitzungslimit erreicht: {max} Elemente pro Sitzung.',
      'ui_media_label': 'Medium: {name}',
      'ui_no_play_limit': 'Kein Wiedergabelimit',
      'ui_resets_in': ' · setzt sich zurück in {duration}',
      'ui_blocked': 'Gesperrt',
      'loaded_last_played': 'Zuletzt abgespieltes Medium geladen.',
      'audio': 'Audio',
      'ui_locked_reason': 'Gesperrt: {reason}',
      'lock_reason_time_tamper': 'Zeitmanipulation erkannt',
      'lock_reason_expired': 'Paket abgelaufen',
      'lock_reason_lifetime_limit': 'Lebenszeitlimit erreicht',
      'ui_total_suffix': ' gesamt',
      'ui_plays_left': ' Wiedergaben übrig',
      'ui_session_usage': 'Sitzung: {used} / {max}',
      'ui_total_usage': 'Gesamt: {used} / {max}',
      'abbr_day': 'T',
      'abbr_hour': 'h',
      'abbr_minute': 'm',
      'abbr_second': 's',
      'language_settings_title': 'Sprache',
      'system_default': 'Systemstandard',
      'custom_translations': 'Benutzerdefinierte Übersetzungen',
      'add_custom_translations': 'Benutzerdefiniertes JSON hinzufügen',
      'remove_custom_translations':
          'Benutzerdefinierte Übersetzungen entfernen',
      'choose_json_file': 'JSON-Datei auswählen',
      'ui_demo_warning':
          'Demo-Inhalt — nicht zur Verbreitung. Dieses Schrift‑Audio/Video ist ein unfertiger Entwurf in der lokalen Sprache. Wir prüfen es noch. Bitte hilf uns, diese Aufnahmen zu testen und zu korrigieren, damit wir die endgültige Fassung mit allen teilen können.',
      // Bestätigungsdialog Wiedergabe
      'confirm_play_title': 'Wiedergabe starten?',
      'confirm_window_left': 'Fenster: {left} / {max} Wiedergaben übrig',
      'confirm_window_unlimited': 'Fenster: unbegrenzt',
      'confirm_lifetime_left': 'Lebenszeit: {left} / {max} übrig',
      'confirm_lifetime_unlimited': 'Lebenszeit: unbegrenzt',
      'confirm_preview_free':
          'Die ersten {seconds}s sind kostenlos, bevor eine Wiedergabe gezählt wird.',
      'start_playback': 'Starten',
      'cancel': 'Abbrechen',
      // New UI
      'fullscreen': 'Vollbild',
      'import_diagnostics': 'Importdiagnose',
      'import_diagnostics_subtitle':
          'Ausführliche Importprotokolle können bei der Fehlersuche bei langsamen oder fehlschlagenden Importen helfen',
      'verbose_import_logs': 'Ausführliche Importprotokolle',
      'view_last_import_log': 'Letztes Importprotokoll anzeigen',
      'last_import_log': 'Letztes Importprotokoll',
      'copy': 'Kopieren',
      'clear_logs': 'Protokolle löschen',
      'auto_fullscreen_on_rotate': 'Automatisches Vollbild bei Drehen',
      'auto_fullscreen_on_rotate_desc':
          'Bei Drehung ins Querformat während der Videowiedergabe automatisch in den Vollbildmodus wechseln',
      'allow_landscape': 'Querformat in der App erlauben',
      'allow_landscape_desc':
          'Erlaube der App, außerhalb des Vollbilds ins Querformat zu drehen; Videos im Querformat wechseln weiterhin in den Vollbildmodus (falls aktiviert)',
    },
    'nl': {
      'app_title': 'Schrift Demo-speler',
      'device_id': 'Apparaat-ID',
      'close': 'Sluiten',
      'import_bundle': 'Bundel importeren',
      'play': 'Afspelen',
      'pause': 'Pauzeren',
      'stop': 'Stoppen',
      'no_decrypted_media_yet': 'Nog geen ontsleutelde media.',
      'status_initial': 'Geen bundel geladen.',
      'status_picking_file': 'Bestand selecteren…',
      'status_file_filter_unsupported':
          'Bestandsfilter niet ondersteund; alle bestanden worden getoond…',
      'status_file_picking_cancelled': 'Bestandsselectie geannuleerd.',
      'status_select_smbundle': 'Selecteer een .smbundle-bestand.',
      'status_extracting_bundle': 'Bundel uitpakken…',
      'error_open_bundle_config': 'Fout: kan bundelconfiguratie niet openen.',
      'error_missing_bundle_config': 'Fout: bundelconfiguratie ontbreekt.',
      'error_invalid_bundle_config': 'Fout: ongeldige bundelconfiguratie.',
      'error_device_not_authorized':
          'Fout: dit apparaat is niet gemachtigd voor deze bundel.',
      'status_config_verified': 'Configuratie geverifieerd voor dit apparaat.',
      'status_bundle_previously_used':
          'Deze bundel is eerder gebruikt en kan niet opnieuw worden geïmporteerd.',
      'status_bundle_already_active': 'Bundel al actief. Geen wijzigingen.',
      'status_decrypting_media': 'Media worden ontsleuteld…',
      'status_import_ready': 'Bundel geïmporteerd en klaar.',
      'status_no_playable_media': 'Geen afspeelbare media voor dit apparaat.',
      'status_error_generic': 'Fout: {message}',
      'status_no_media_selected': 'Geen media geselecteerd.',
      'status_time_tamper_lock':
          'Tijdmanipulatie gedetecteerd. Bundel permanent vergrendeld.',
      'status_bundle_expired_lock':
          'Bundel is verlopen op {date}. Permanent vergrendeld.',
      'status_max_total_lock':
          'Maximaal aantal levenslange weergaven ({max}) bereikt. Permanent vergrendeld.',
      'status_must_wait': 'Wacht {duration} tussen weergaven.',
      'status_play_limit_reached': 'Afspeellimiet voor dit medium bereikt.',
      'status_play_limit_reached_with_reset':
          'Afspeellimiet bereikt. Herstelt over {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'Afspeellijst is verlopen op {date}. Permanent vergrendeld.',
      'status_playlist_max_items_lock':
          'Maximum unieke items ({max}) van afspeellijst al afgespeeld. Permanent vergrendeld.',
      'status_must_wait_between_items':
          'Wacht {duration} tussen het afspelen van verschillende items.',
      'status_playlist_session_limit':
          'Sessielimiet bereikt: {max} items per sessie. Herstelt over {duration}',
      'status_playlist_session_limit_no_reset':
          'Sessielimiet bereikt: {max} items per sessie.',
      'ui_media_label': 'Media: {name}',
      'ui_no_play_limit': 'Geen afspeellimiet',
      'ui_resets_in': ' · herstelt over {duration}',
      'ui_blocked': 'Geblokkeerd',
      'loaded_last_played': 'Laatst afgespeelde media geladen.',
      'audio': 'Audio',
      'ui_locked_reason': 'Geblokkeerd: {reason}',
      'lock_reason_time_tamper': 'Tijdmanipulatie gedetecteerd',
      'lock_reason_expired': 'Bundel verlopen',
      'lock_reason_lifetime_limit': 'Levenslimiet bereikt',
      'ui_total_suffix': ' totaal',
      'ui_plays_left': ' weergaven over',
      'ui_session_usage': 'Sessie: {used} / {max}',
      'ui_total_usage': 'Totaal: {used} / {max}',
      'abbr_day': 'd',
      'abbr_hour': 'u',
      'abbr_minute': 'm',
      'abbr_second': 's',
      'language_settings_title': 'Taal',
      'system_default': 'Systeemstandaard',
      'custom_translations': 'Aangepaste vertalingen',
      'add_custom_translations': 'Aangepaste JSON toevoegen',
      'remove_custom_translations': 'Aangepaste vertalingen verwijderen',
      'choose_json_file': 'JSON-bestand kiezen',
      'ui_demo_warning':
          'Demo-inhoud — niet voor verspreiding. Deze Schrift‑audio/video is een onvolledige conceptversie in de lokale taal. We beoordelen dit nog. Help ons testen en corrigeren zodat we de definitieve versie met iedereen kunnen delen.',
      // Bevestigingsdialoog afspelen
      'confirm_play_title': 'Weergave starten?',
      'confirm_window_left': 'Venster: {left} / {max} over',
      'confirm_window_unlimited': 'Venster: onbeperkt',
      'confirm_lifetime_left': 'Levenslang: {left} / {max} over',
      'confirm_lifetime_unlimited': 'Levenslang: onbeperkt',
      'confirm_preview_free':
          'De eerste {seconds}s zijn gratis voordat een weergave wordt geteld.',
      'start_playback': 'Starten',
      'cancel': 'Annuleren',
      // New UI
      'fullscreen': 'Volledig scherm',
      'import_diagnostics': 'Importdiagnostiek',
      'import_diagnostics_subtitle':
          'Uitgebreide importlogs kunnen helpen bij het oplossen van trage of mislukte importen',
      'verbose_import_logs': 'Uitgebreide importlogs',
      'view_last_import_log': 'Laatste importlog bekijken',
      'last_import_log': 'Laatste importlog',
      'copy': 'Kopiëren',
      'clear_logs': 'Logs wissen',
      'auto_fullscreen_on_rotate': 'Automatisch volledig scherm bij draaien',
      'auto_fullscreen_on_rotate_desc':
          'Automatisch naar volledig scherm bij draaien naar landschap tijdens videoweergave',
      'allow_landscape': 'Landschapstand toestaan',
      'allow_landscape_desc':
          'Laat de app buiten volledig scherm naar landschap draaien; video’s in landschap gaan nog steeds naar volledig scherm indien ingeschakeld',
    },
    'af': {
      'app_title': 'Skrif Demo Speler',
      'device_id': 'Toestel-ID',
      'close': 'Sluit',
      'import_bundle': 'Voeg bondel in',
      'play': 'Speel',
      'pause': 'Pouseer',
      'stop': 'Stop',
      'no_decrypted_media_yet': 'Nog geen gedekripteerde media.',
      'status_initial': 'Geen bondel gelaai.',
      'status_picking_file': 'Kies tans ’n lêer…',
      'status_file_filter_unsupported':
          'Lêerfilter nie ondersteun nie; wys alle lêers…',
      'status_file_picking_cancelled': 'Lêerkeuse gekanselleer.',
      'status_select_smbundle': 'Kies asseblief ’n .smbundle-lêer.',
      'status_extracting_bundle': 'Pak bondel uit…',
      'error_open_bundle_config':
          'Fout: Kan nie bondelkonfigurasie oopmaak nie.',
      'error_missing_bundle_config': 'Fout: Bondelkonfigurasie ontbreek.',
      'error_invalid_bundle_config': 'Fout: Ongeldige bondelkonfigurasie.',
      'error_device_not_authorized':
          'Fout: Hierdie toestel is nie gemagtig vir hierdie bondel nie.',
      'status_config_verified': 'Konfigurasie vir hierdie toestel geverifieer.',
      'status_bundle_previously_used':
          'Hierdie bondel was vroeër gebruik en kan nie weer ingevoer word nie.',
      'status_bundle_already_active':
          'Bondel reeds aktief. Geen wysigings nie.',
      'status_decrypting_media': 'Dekripteer media…',
      'status_import_ready': 'Bondel ingevoer en gereed.',
      'status_no_playable_media':
          'Geen speelbare media vir hierdie toestel nie.',
      'status_error_generic': 'Fout: {message}',
      'status_no_media_selected': 'Geen media gekies nie.',
      'status_time_tamper_lock':
          'Tydpeutery opgespoor. Bondel permanent gesluit.',
      'status_bundle_expired_lock':
          'Bondel het op {date} verval. Permanent gesluit.',
      'status_max_total_lock':
          'Maksimum lewenslange spele ({max}) bereik. Permanent gesluit.',
      'status_must_wait': 'Moet {duration} wag tussen spele.',
      'status_play_limit_reached': 'Speelbeperking vir hierdie media bereik.',
      'status_play_limit_reached_with_reset':
          'Speelbeperking bereik. Stel terug oor {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'Speellys het op {date} verval. Permanent gesluit.',
      'status_playlist_max_items_lock':
          'Maksimum unieke items ({max}) van speellys reeds gespeel. Permanent gesluit.',
      'status_must_wait_between_items':
          'Moet {duration} wag tussen verskillende items te speel.',
      'status_playlist_session_limit':
          'Sessiebeperking bereik: {max} items per sessie. Stel terug oor {duration}',
      'status_playlist_session_limit_no_reset':
          'Sessiebeperking bereik: {max} items per sessie.',
      'ui_media_label': 'Media: {name}',
      'ui_no_play_limit': 'Geen speelbeperking',
      'ui_resets_in': ' · stel terug oor {duration}',
      'ui_blocked': 'Geblokkeer',
      'loaded_last_played': 'Laaste gespeelde media gelaai.',
      'audio': 'Klank',
      'ui_locked_reason': 'Gesluit: {reason}',
      'lock_reason_time_tamper': 'Tydpeutery opgespoor',
      'lock_reason_expired': 'Bondel verval',
      'lock_reason_lifetime_limit': 'Lewenslimiet bereik',
      'ui_total_suffix': ' totaal',
      'ui_plays_left': ' spele oor',
      'ui_session_usage': 'Sessie: {used} / {max}',
      'ui_total_usage': 'Totaal: {used} / {max}',
      'abbr_day': 'd',
      'abbr_hour': 'u',
      'abbr_minute': 'm',
      'abbr_second': 's',
      'language_settings_title': 'Taal',
      'system_default': 'Stelselverstek',
      'custom_translations': 'Pasgemaakte vertalings',
      'add_custom_translations': 'Voeg pasgemaakte JSON by',
      'remove_custom_translations': 'Verwyder pasgemaakte vertalings',
      'choose_json_file': 'Kies JSON-lêer',
      'ui_demo_warning':
          'Demo-inhoud — nie vir verspreiding nie. Hierdie Skrif‑klank/video is ’n onvoltooide konsep in die plaaslike taal. Ons hersien dit nog. Help ons asseblief om te toets en reg te stel sodat ons die finale weergawe met almal kan deel.',
      // Bevestigingsdialoog vir afspeel
      'confirm_play_title': 'Begin afspeel?',
      'confirm_window_left': 'Venster: {left} / {max} oor',
      'confirm_window_unlimited': 'Venster: onbeperk',
      'confirm_lifetime_left': 'Lewenstyd: {left} / {max} oor',
      'confirm_lifetime_unlimited': 'Lewenstyd: onbeperk',
      'confirm_preview_free':
          'Die eerste {seconds}s is gratis voordat ’n spel getel word.',
      'start_playback': 'Begin',
      'cancel': 'Kanselleer',
      // New UI
      'fullscreen': 'Volskerm',
      'import_diagnostics': 'Invoerdiagnostiek',
      'import_diagnostics_subtitle':
          'Uitvoerige invoerlogboeke kan help om stadig of mislukte invoere reg te maak',
      'verbose_import_logs': 'Uitvoerige invoerlogboeke',
      'view_last_import_log': 'Sien laaste invoerlogboek',
      'last_import_log': 'Laaste invoerlogboek',
      'copy': 'Kopieer',
      'clear_logs': 'Vee logboeke uit',
      'auto_fullscreen_on_rotate': 'Outo-volskerm wanneer gedraai',
      'auto_fullscreen_on_rotate_desc':
          'Gaan outomaties na volskerm wanneer die toestel na landskap gedraai word tydens videoterugspeel',
      'allow_landscape': 'Laat landskap-rotasie toe',
      'allow_landscape_desc':
          'Laat die app buite volskerm na landskap draai; video’s in landskap sal steeds volskerm ingaan indien geaktiveer',
    },
    'pt': {
      'app_title': 'Reprodutor de Demonstração das Escrituras',
      'device_id': 'ID do dispositivo',
      'close': 'Fechar',
      'import_bundle': 'Importar pacote',
      'play': 'Reproduzir',
      'pause': 'Pausar',
      'stop': 'Parar',
      'no_decrypted_media_yet': 'Ainda não há mídia descriptografada.',
      'status_initial': 'Nenhum pacote carregado.',
      'status_picking_file': 'Selecionando arquivo…',
      'status_file_filter_unsupported':
          'Filtro de arquivos não compatível; mostrando todos os arquivos…',
      'status_file_picking_cancelled': 'Seleção de arquivo cancelada.',
      'status_select_smbundle': 'Selecione um arquivo .smbundle.',
      'status_extracting_bundle': 'Extraindo pacote…',
      'error_open_bundle_config':
          'Erro: não foi possível abrir a configuração do pacote.',
      'error_missing_bundle_config': 'Erro: configuração do pacote ausente.',
      'error_invalid_bundle_config': 'Erro: configuração do pacote inválida.',
      'error_device_not_authorized':
          'Erro: este dispositivo não está autorizado para este pacote.',
      'status_config_verified':
          'Configuração verificada para este dispositivo.',
      'status_bundle_previously_used':
          'Este pacote já foi usado e não pode ser reimportado.',
      'status_bundle_already_active':
          'Pacote já ativo. Nenhuma alteração feita.',
      'status_decrypting_media': 'Descriptografando mídia…',
      'status_import_ready': 'Pacote importado e pronto.',
      'status_no_playable_media':
          'Não há mídia reproduzível para este dispositivo.',
      'status_error_generic': 'Erro: {message}',
      'status_no_media_selected': 'Nenhuma mídia selecionada.',
      'status_time_tamper_lock':
          'Manipulação de horário detectada. Pacote bloqueado permanentemente.',
      'status_bundle_expired_lock':
          'O pacote expirou em {date}. Bloqueado permanentemente.',
      'status_max_total_lock':
          'Número máximo de reproduções vitalícias ({max}) atingido. Bloqueado permanentemente.',
      'status_must_wait': 'Aguarde {duration} entre as reproduções.',
      'status_play_limit_reached':
          'Limite de reproduções atingido para esta mídia.',
      'status_play_limit_reached_with_reset':
          'Limite de reproduções atingido. Redefine em {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'Lista de reprodução expirou em {date}. Bloqueado permanentemente.',
      'status_playlist_max_items_lock':
          'Número máximo de itens únicos ({max}) da lista já reproduzidos. Bloqueado permanentemente.',
      'status_must_wait_between_items':
          'Aguarde {duration} entre reproduzir diferentes itens.',
      'status_playlist_session_limit':
          'Limite de sessão atingido: {max} itens por sessão. Redefine em {duration}',
      'status_playlist_session_limit_no_reset':
          'Limite de sessão atingido: {max} itens por sessão.',
      'ui_media_label': 'Mídia: {name}',
      'ui_no_play_limit': 'Sem limite de reproduções',
      'ui_resets_in': ' · redefine em {duration}',
      'ui_blocked': 'Bloqueado',
      'loaded_last_played': 'Última mídia reproduzida carregada.',
      'audio': 'Áudio',
      'ui_locked_reason': 'Bloqueado: {reason}',
      'lock_reason_time_tamper': 'Manipulação de horário detectada',
      'lock_reason_expired': 'Pacote expirado',
      'lock_reason_lifetime_limit': 'Limite vitalício atingido',
      'ui_total_suffix': ' no total',
      'ui_plays_left': ' reproduções restantes',
      'ui_session_usage': 'Sessão: {used} / {max}',
      'ui_total_usage': 'Total: {used} / {max}',
      'abbr_day': 'd',
      'abbr_hour': 'h',
      'abbr_minute': 'min',
      'abbr_second': 's',
      'language_settings_title': 'Idioma',
      'system_default': 'Padrão do sistema',
      'custom_translations': 'Traduções personalizadas',
      'add_custom_translations': 'Adicionar JSON personalizado',
      'remove_custom_translations': 'Remover traduções personalizadas',
      'choose_json_file': 'Escolher arquivo JSON',
      'ui_demo_warning':
          'Conteúdo de demonstração — não para distribuição. Este áudio/vídeo das Escrituras é um rascunho inacabado no idioma local. Ainda estamos revisando. Ajude-nos a testar e corrigir estas gravações para que possamos compartilhar a versão final com todos.',
      // Diálogo de confirmação de reprodução
      'confirm_play_title': 'Iniciar reprodução?',
      'confirm_window_left': 'Janela: {left} / {max} restantes',
      'confirm_window_unlimited': 'Janela: sem limite',
      'confirm_lifetime_left': 'Vitalício: {left} / {max} restantes',
      'confirm_lifetime_unlimited': 'Vitalício: sem limite',
      'confirm_preview_free':
          'Os primeiros {seconds}s são gratuitos antes de contar uma reprodução.',
      'start_playback': 'Iniciar',
      'cancel': 'Cancelar',
      // New UI
      'fullscreen': 'Tela cheia',
      'import_diagnostics': 'Diagnósticos de importação',
      'import_diagnostics_subtitle':
          'Logs detalhados de importação podem ajudar a solucionar importações lentas ou com falha',
      'verbose_import_logs': 'Logs detalhados de importação',
      'view_last_import_log': 'Ver o último log de importação',
      'last_import_log': 'Último log de importação',
      'copy': 'Copiar',
      'clear_logs': 'Limpar logs',
      'auto_fullscreen_on_rotate': 'Tela cheia automática ao girar',
      'auto_fullscreen_on_rotate_desc':
          'Entrar automaticamente em tela cheia ao girar o dispositivo para paisagem durante a reprodução de vídeo',
      'allow_landscape': 'Permitir rotação para paisagem',
      'allow_landscape_desc':
          'Permitir que o app gire para paisagem fora do modo de tela cheia; vídeos em paisagem ainda entram em tela cheia se ativado',
    },
    'id': {
      'app_title': 'Pemutar Demo Kitab Suci',
      'device_id': 'ID Perangkat',
      'close': 'Tutup',
      'import_bundle': 'Impor Bundel',
      'play': 'Putar',
      'pause': 'Jeda',
      'stop': 'Berhenti',
      'no_decrypted_media_yet': 'Belum ada media yang didekripsi.',
      // Status & messages
      'status_initial': 'Tidak ada bundel yang dimuat.',
      'status_picking_file': 'Memilih file…',
      'status_file_filter_unsupported':
          'Filter file tidak didukung; menampilkan semua file…',
      'status_file_picking_cancelled': 'Pemilihan file dibatalkan.',
      'status_select_smbundle': 'Silakan pilih file .smbundle.',
      'status_extracting_bundle': 'Mengekstrak bundel…',
      'error_open_bundle_config':
          'Kesalahan: Tidak dapat membuka konfigurasi bundel.',
      'error_missing_bundle_config': 'Kesalahan: Konfigurasi bundel hilang.',
      'error_invalid_bundle_config':
          'Kesalahan: Konfigurasi bundel tidak valid.',
      'error_device_not_authorized':
          'Kesalahan: Perangkat ini tidak diizinkan untuk bundel ini.',
      'status_config_verified':
          'Konfigurasi terverifikasi untuk perangkat ini.',
      'status_bundle_previously_used':
          'Bundel ini telah digunakan sebelumnya dan tidak dapat diimpor ulang.',
      'status_bundle_already_active':
          'Bundel sudah aktif. Tidak ada perubahan.',
      'status_decrypting_media': 'Mendekripsi media…',
      'status_import_ready': 'Bundel diimpor dan siap.',
      'status_no_playable_media':
          'Tidak ada media yang dapat diputar untuk perangkat ini.',
      'status_error_generic': 'Kesalahan: {message}',
      'status_no_media_selected': 'Tidak ada media yang dipilih.',
      'status_time_tamper_lock':
          'Terjadi pengubahan waktu. Bundel terkunci permanen.',
      'status_bundle_expired_lock':
          'Bundel kedaluwarsa pada {date}. Terkunci permanen.',
      'status_max_total_lock':
          'Jumlah putar seumur hidup maksimum ({max}) tercapai. Terkunci permanen.',
      'status_must_wait': 'Harus menunggu {duration} antar pemutaran.',
      'status_play_limit_reached': 'Batas pemutaran untuk media ini tercapai.',
      'status_play_limit_reached_with_reset':
          'Batas pemutaran tercapai. Akan disetel ulang dalam {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'Daftar putar kedaluwarsa pada {date}. Terkunci permanen.',
      'status_playlist_max_items_lock':
          'Item unik maksimum ({max}) dari daftar putar sudah diputar. Terkunci permanen.',
      'status_must_wait_between_items':
          'Harus menunggu {duration} antara memutar item yang berbeda.',
      'status_playlist_session_limit':
          'Batas sesi tercapai: {max} item per sesi. Akan disetel ulang dalam {duration}',
      'status_playlist_session_limit_no_reset':
          'Batas sesi tercapai: {max} item per sesi.',
      // UI labels
      'ui_media_label': 'Media: {name}',
      'ui_no_play_limit': 'Tidak ada batas pemutaran',
      'ui_resets_in': ' · disetel ulang dalam {duration}',
      'ui_blocked': 'Diblokir',
      'loaded_last_played': 'Media terakhir yang diputar telah dimuat.',
      'audio': 'Audio',
      'ui_locked_reason': 'Terkunci: {reason}',
      'lock_reason_time_tamper': 'Terjadi pengubahan waktu',
      'lock_reason_expired': 'Bundel kedaluwarsa',
      'lock_reason_lifetime_limit': 'Batas seumur hidup tercapai',
      'ui_total_suffix': ' total',
      'ui_plays_left': ' sisa putar',
      'ui_session_usage': 'Sesi: {used} / {max}',
      'ui_total_usage': 'Total: {used} / {max}',
      // Duration unit abbreviations (compact)
      'abbr_day': 'h',
      'abbr_hour': 'j',
      'abbr_minute': 'm',
      'abbr_second': 'd',
      'language_settings_title': 'Bahasa',
      'system_default': 'Bawaan sistem',
      'custom_translations': 'Terjemahan kustom',
      'add_custom_translations': 'Tambahkan JSON kustom',
      'remove_custom_translations': 'Hapus terjemahan kustom',
      'choose_json_file': 'Pilih file JSON',
      'ui_demo_warning':
          'Konten demo — tidak untuk distribusi. Audio/video Kitab Suci ini masih draf dalam bahasa setempat. Kami masih meninjau. Mohon bantu kami menguji dan memperbaiki rekaman ini agar versi finalnya bisa dibagikan kepada semua orang.',
      // Dialog konfirmasi pemutaran
      'confirm_play_title': 'Mulai pemutaran?',
      'confirm_window_left': 'Jendela: sisa {left} / {max}',
      'confirm_window_unlimited': 'Jendela: tanpa batas',
      'confirm_lifetime_left': 'Seumur hidup: sisa {left} / {max}',
      'confirm_lifetime_unlimited': 'Seumur hidup: tanpa batas',
      'confirm_preview_free':
          'Detik {seconds} pertama gratis sebelum dihitung sebagai 1 kali putar.',
      'start_playback': 'Mulai',
      'cancel': 'Batal',
      // New UI
      'fullscreen': 'Layar penuh',
      'import_diagnostics': 'Diagnostik impor',
      'import_diagnostics_subtitle':
          'Log impor terperinci dapat membantu menelusuri impor yang lambat atau gagal',
      'verbose_import_logs': 'Log impor terperinci',
      'view_last_import_log': 'Lihat log impor terakhir',
      'last_import_log': 'Log impor terakhir',
      'copy': 'Salin',
      'clear_logs': 'Hapus log',
      'auto_fullscreen_on_rotate': 'Layar penuh otomatis saat diputar',
      'auto_fullscreen_on_rotate_desc':
          'Masuk otomatis ke layar penuh saat memutar perangkat ke mode lanskap selama pemutaran video',
      'allow_landscape': 'Izinkan rotasi lanskap',
      'allow_landscape_desc':
          'Izinkan aplikasi berputar ke lanskap di luar layar penuh; video lanskap tetap masuk layar penuh jika diaktifkan',
    },
    'ru': {
      'app_title': 'Демонстрационный плеер Писания',
      'device_id': 'ID устройства',
      'close': 'Закрыть',
      'import_bundle': 'Импортировать пакет',
      'play': 'Воспроизвести',
      'pause': 'Пауза',
      'stop': 'Стоп',
      'no_decrypted_media_yet': 'Пока нет расшифрованных медиа.',
      'status_initial': 'Пакет не загружен.',
      'status_picking_file': 'Выбор файла…',
      'status_file_filter_unsupported':
          'Фильтр файлов не поддерживается; показаны все файлы…',
      'status_file_picking_cancelled': 'Выбор файла отменен.',
      'status_select_smbundle': 'Выберите файл .smbundle.',
      'status_extracting_bundle': 'Распаковка пакета…',
      'error_open_bundle_config':
          'Ошибка: невозможно открыть конфигурацию пакета.',
      'error_missing_bundle_config': 'Ошибка: отсутствует конфигурация пакета.',
      'error_invalid_bundle_config': 'Ошибка: неверная конфигурация пакета.',
      'error_device_not_authorized':
          'Ошибка: это устройство не авторизовано для этого пакета.',
      'status_config_verified':
          'Конфигурация для этого устройства подтверждена.',
      'status_bundle_previously_used':
          'Этот пакет ранее использовался и не может быть повторно импортирован.',
      'status_bundle_already_active': 'Пакет уже активен. Изменений нет.',
      'status_decrypting_media': 'Расшифровка медиа…',
      'status_import_ready': 'Пакет импортирован и готов.',
      'status_no_playable_media':
          'Нет воспроизводимых медиа для этого устройства.',
      'status_error_generic': 'Ошибка: {message}',
      'status_no_media_selected': 'Медиа не выбрано.',
      'status_time_tamper_lock':
          'Обнаружено изменение времени. Пакет навсегда заблокирован.',
      'status_bundle_expired_lock':
          'Пакет истек {date}. Навсегда заблокирован.',
      'status_max_total_lock':
          'Достигнут максимум пожизненных воспроизведений ({max}). Навсегда заблокирован.',
      'status_must_wait': 'Нужно подождать {duration} между воспроизведениями.',
      'status_play_limit_reached':
          'Достигнут лимит воспроизведений для этого медиа.',
      'status_play_limit_reached_with_reset':
          'Лимит воспроизведений достигнут. Сброс через {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'Плейлист истек {date}. Навсегда заблокирован.',
      'status_playlist_max_items_lock':
          'Достигнут максимум уникальных элементов ({max}) из плейлиста. Навсегда заблокирован.',
      'status_must_wait_between_items':
          'Нужно подождать {duration} между воспроизведением разных элементов.',
      'status_playlist_session_limit':
          'Достигнут лимит сессии: {max} элементов за сессию. Сброс через {duration}',
      'status_playlist_session_limit_no_reset':
          'Достигнут лимит сессии: {max} элементов за сессию.',
      'ui_media_label': 'Медиа: {name}',
      'ui_no_play_limit': 'Без лимита воспроизведений',
      'ui_resets_in': ' · сброс через {duration}',
      'ui_blocked': 'Заблокировано',
      'loaded_last_played': 'Загружено последнее воспроизведённое медиа.',
      'audio': 'Аудио',
      'ui_locked_reason': 'Заблокировано: {reason}',
      'lock_reason_time_tamper': 'Обнаружено изменение времени',
      'lock_reason_expired': 'Пакет истёк',
      'lock_reason_lifetime_limit': 'Достигнут пожизненный лимит',
      'ui_total_suffix': ' всего',
      'ui_plays_left': ' воспроизведений осталось',
      'ui_session_usage': 'Сессия: {used} / {max}',
      'ui_total_usage': 'Итого: {used} / {max}',
      'abbr_day': 'д',
      'abbr_hour': 'ч',
      'abbr_minute': 'м',
      'abbr_second': 'с',
      'language_settings_title': 'Язык',
      'system_default': 'Системный по умолчанию',
      'custom_translations': 'Пользовательские переводы',
      'add_custom_translations': 'Добавить пользовательский JSON',
      'remove_custom_translations': 'Удалить пользовательские переводы',
      'choose_json_file': 'Выбрать файл JSON',
      'ui_demo_warning':
          'Демонстрационный материал — не для распространения. Это аудио/видео Писания — черновик на местном языке. Мы всё ещё его проверяем. Пожалуйста, помогите нам тестировать и исправлять записи, чтобы потом поделиться финальной версией со всеми.',
      // Диалог подтверждения воспроизведения
      'confirm_play_title': 'Начать воспроизведение?',
      'confirm_window_left': 'Окно: осталось {left} из {max}',
      'confirm_window_unlimited': 'Окно: без ограничений',
      'confirm_lifetime_left': 'За всю жизнь: осталось {left} из {max}',
      'confirm_lifetime_unlimited': 'За всю жизнь: без ограничений',
      'confirm_preview_free':
          'Первые {seconds} с бесплатны, прежде чем засчитывается воспроизведение.',
      'start_playback': 'Начать',
      'cancel': 'Отмена',
      // Новые элементы интерфейса
      'fullscreen': 'Полноэкранный режим',
      'import_diagnostics': 'Диагностика импорта',
      'import_diagnostics_subtitle':
          'Подробные журналы импорта помогают устранять проблемы медленного или неудачного импорта',
      'verbose_import_logs': 'Подробные журналы импорта',
      'view_last_import_log': 'Посмотреть последний журнал импорта',
      'last_import_log': 'Последний журнал импорта',
      'copy': 'Копировать',
      'clear_logs': 'Очистить журналы',
      'auto_fullscreen_on_rotate': 'Авто полноэкранный при повороте',
      'auto_fullscreen_on_rotate_desc':
          'Автоматически переходить в полноэкранный режим при повороте устройства в ландшафтный режим во время воспроизведения видео',
      'allow_landscape': 'Разрешить альбомную ориентацию',
      'allow_landscape_desc':
          'Разрешить приложению поворачиваться в альбомную ориентацию вне полноэкранного режима; видео в альбомной ориентации будут открываться на весь экран, если включено',
    },
    'hi': {
      'app_title': 'शास्त्र डेमो प्लेयर',
      'device_id': 'डिवाइस आईडी',
      'close': 'बंद करें',
      'import_bundle': 'बंडल आयात करें',
      'play': 'चलाएँ',
      'pause': 'रोकें',
      'stop': 'बंद करें',
      'no_decrypted_media_yet': 'अभी तक कोई डिक्रिप्टेड मीडिया नहीं।',
      'status_initial': 'कोई बंडल लोड नहीं है।',
      'status_picking_file': 'फ़ाइल चुनी जा रही है…',
      'status_file_filter_unsupported':
          'फ़ाइल फ़िल्टर समर्थित नहीं; सभी फ़ाइलें दिखा रहे हैं…',
      'status_file_picking_cancelled': 'फ़ाइल चयन रद्द किया गया।',
      'status_select_smbundle': 'कृपया एक .smbundle फ़ाइल चुनें।',
      'status_extracting_bundle': 'बंडल निकाला जा रहा है…',
      'error_open_bundle_config': 'त्रुटि: बंडल कॉन्फ़िग नहीं खोली जा सकी।',
      'error_missing_bundle_config': 'त्रुटि: बंडल कॉन्फ़िग गायब है।',
      'error_invalid_bundle_config': 'त्रुटि: अमान्य बंडल कॉन्फ़िग।',
      'error_device_not_authorized':
          'त्रुटि: यह डिवाइस इस बंडल के लिए अधिकृत नहीं है।',
      'status_config_verified': 'इस डिवाइस के लिए कॉन्फ़िग सत्यापित।',
      'status_bundle_previously_used':
          'इस बंडल का पहले उपयोग हुआ है और इसे पुनः आयात नहीं किया जा सकता।',
      'status_bundle_already_active':
          'बंडल पहले से सक्रिय है। कोई परिवर्तन नहीं।',
      'status_decrypting_media': 'मीडिया डिक्रिप्ट किया जा रहा है…',
      'status_import_ready': 'बंडल आयात किया गया और तैयार है।',
      'status_no_playable_media':
          'इस डिवाइस के लिए कोई चलने योग्य मीडिया नहीं।',
      'status_error_generic': 'त्रुटि: {message}',
      'status_no_media_selected': 'कोई मीडिया चयनित नहीं।',
      'status_time_tamper_lock':
          'समय से छेड़छाड़ पाई गई। बंडल स्थायी रूप से लॉक है।',
      'status_bundle_expired_lock':
          'बंडल {date} को समाप्त हो गया। स्थायी रूप से लॉक।',
      'status_max_total_lock':
          'कुल जीवनकाल प्ले ({max}) पूरे हो गए। स्थायी रूप से लॉक।',
      'status_must_wait': 'प्ले के बीच {duration} प्रतीक्षा करें।',
      'status_play_limit_reached': 'इस मीडिया के लिए प्ले सीमा पूरी हो गई है।',
      'status_play_limit_reached_with_reset':
          'प्ले सीमा पूरी हुई। {duration} में रीसेट होगा',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'प्लेलिस्ट {date} को समाप्त हुई। स्थायी रूप से लॉक।',
      'status_playlist_max_items_lock':
          'प्लेलिस्ट से अधिकतम अनूठे आइटम ({max}) पहले ही चलाए गए। स्थायी रूप से लॉक।',
      'status_must_wait_between_items':
          'विभिन्न आइटम चलाने के बीच {duration} प्रतीक्षा करें।',
      'status_playlist_session_limit':
          'सत्र सीमा पूरी हुई: प्रति सत्र {max} आइटम। {duration} में रीसेट होगा',
      'status_playlist_session_limit_no_reset':
          'सत्र सीमा पूरी हुई: प्रति सत्र {max} आइटम।',
      'ui_media_label': 'मीडिया: {name}',
      'ui_no_play_limit': 'कोई प्ले सीमा नहीं',
      'ui_resets_in': ' · {duration} में रीसेट होता है',
      'ui_blocked': 'अवरोधित',
      'loaded_last_played': 'अंतिम चलाया गया मीडिया लोड किया गया।',
      'audio': 'ऑडियो',
      'ui_locked_reason': 'लॉक: {reason}',
      'lock_reason_time_tamper': 'समय से छेड़छाड़ पाई गई',
      'lock_reason_expired': 'बंडल समाप्त',
      'lock_reason_lifetime_limit': 'आजीवन सीमा पूरी हुई',
      'ui_total_suffix': ' कुल',
      'ui_plays_left': ' प्ले शेष',
      'ui_session_usage': 'सत्र: {used} / {max}',
      'ui_total_usage': 'कुल: {used} / {max}',
      'abbr_day': 'दिन',
      'abbr_hour': 'घं',
      'abbr_minute': 'मि',
      'abbr_second': 'से',
      'language_settings_title': 'भाषा',
      'system_default': 'सिस्टम डिफ़ॉल्ट',
      'custom_translations': 'कस्टम अनुवाद',
      'add_custom_translations': 'कस्टम JSON जोड़ें',
      'remove_custom_translations': 'कस्टम अनुवाद हटाएँ',
      'choose_json_file': 'JSON फ़ाइल चुनें',
      'ui_demo_warning':
          'डेमो सामग्री — वितरण के लिए नहीं। यह शास्त्र का ऑडियो/वीडियो स्थानीय भाषा में अधूरा मसौदा है। हम अभी इसकी समीक्षा कर रहे हैं। कृपया इन रिकॉर्डिंग्स का परीक्षण और संशोधन करने में हमारी मदद करें, ताकि अंतिम संस्करण हम सभी के साथ बाँट सकें।',
      // पुष्टि संवाद — प्लेबैक
      'confirm_play_title': 'प्लेबैक शुरू करें?',
      'confirm_window_left': 'विंडो: {left} / {max} शेष',
      'confirm_window_unlimited': 'विंडो: असीमित',
      'confirm_lifetime_left': 'आजीवन: {left} / {max} शेष',
      'confirm_lifetime_unlimited': 'आजीवन: असीमित',
      'confirm_preview_free':
          'पहले {seconds} सेकंड मुफ़्त हैं, उसके बाद प्ले गिना जाएगा।',
      'start_playback': 'शुरू करें',
      'cancel': 'रद्द करें',
      // नए UI
      'fullscreen': 'पूर्ण स्क्रीन',
      'import_diagnostics': 'आयात निदान',
      'import_diagnostics_subtitle':
          'विस्तृत आयात लॉग धीमे या असफल आयात की समस्या निवारण में मदद कर सकते हैं',
      'verbose_import_logs': 'विस्तृत आयात लॉग',
      'view_last_import_log': 'अंतिम आयात लॉग देखें',
      'last_import_log': 'अंतिम आयात लॉग',
      'copy': 'कॉपी',
      'clear_logs': 'लॉग साफ़ करें',
      'auto_fullscreen_on_rotate': 'घुमाने पर स्वतः पूर्ण स्क्रीन',
      'auto_fullscreen_on_rotate_desc':
          'वीडियो चलने के दौरान डिवाइस को लैंडस्केप घुमाने पर स्वतः पूर्ण स्क्रीन में जाएँ',
      'allow_landscape': 'लैंडस्केप घुमाव की अनुमति दें',
      'allow_landscape_desc':
          'ऐप को फुल-स्क्रीन के बाहर लैंडस्केप में घूमने दें; लैंडस्केप में वीडियो सक्षम होने पर फुल-स्क्रीन में जाएंगे',
    },
    'ar': {
      'app_title': 'مشغل عرض الكتاب المقدس',
      'device_id': 'معرّف الجهاز',
      'close': 'إغلاق',
      'import_bundle': 'استيراد الحزمة',
      'play': 'تشغيل',
      'pause': 'إيقاف مؤقت',
      'stop': 'إيقاف',
      'no_decrypted_media_yet': 'لا توجد وسائط مفكوكة التشفير بعد.',
      'status_initial': 'لم يتم تحميل أي حزمة.',
      'status_picking_file': 'جارٍ اختيار الملف…',
      'status_file_filter_unsupported':
          'عامل تصفية الملفات غير مدعوم؛ يتم عرض جميع الملفات…',
      'status_file_picking_cancelled': 'تم إلغاء اختيار الملف.',
      'status_select_smbundle': 'يرجى اختيار ملف ‎.smbundle',
      'status_extracting_bundle': 'جارٍ استخراج الحزمة…',
      'error_open_bundle_config': 'خطأ: لا يمكن فتح إعدادات الحزمة.',
      'error_missing_bundle_config': 'خطأ: إعدادات الحزمة مفقودة.',
      'error_invalid_bundle_config': 'خطأ: إعدادات الحزمة غير صالحة.',
      'error_device_not_authorized': 'خطأ: هذا الجهاز غير مخول لهذه الحزمة.',
      'status_config_verified': 'تم التحقق من الإعدادات لهذا الجهاز.',
      'status_bundle_previously_used':
          'تم استخدام هذه الحزمة مسبقًا ولا يمكن إعادة استيرادها.',
      'status_bundle_already_active':
          'الحزمة نشطة بالفعل. لم يتم إجراء تغييرات.',
      'status_decrypting_media': 'جارٍ فك تشفير الوسائط…',
      'status_import_ready': 'تم استيراد الحزمة وجاهزة.',
      'status_no_playable_media': 'لا توجد وسائط قابلة للتشغيل لهذا الجهاز.',
      'status_error_generic': 'خطأ: {message}',
      'status_no_media_selected': 'لم يتم تحديد وسائط.',
      'status_time_tamper_lock': 'تم اكتشاف عبث بالوقت. الحزمة مقفلة نهائيًا.',
      'status_bundle_expired_lock':
          'انتهت صلاحية الحزمة في {date}. مقفلة نهائيًا.',
      'status_max_total_lock':
          'تم بلوغ الحد الأقصى لعدد مرات التشغيل مدى الحياة ({max}). مقفلة نهائيًا.',
      'status_must_wait': 'يجب الانتظار {duration} بين مرات التشغيل.',
      'status_play_limit_reached': 'تم بلوغ حد التشغيل لهذه الوسائط.',
      'status_play_limit_reached_with_reset':
          'تم بلوغ حد التشغيل. سيتم إعادة التعيين خلال {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'انتهت صلاحية قائمة التشغيل في {date}. مقفلة نهائيًا.',
      'status_playlist_max_items_lock':
          'تم بلوغ الحد الأقصى للعناصر الفريدة ({max}) من قائمة التشغيل. مقفلة نهائيًا.',
      'status_must_wait_between_items':
          'يجب الانتظار {duration} بين تشغيل عناصر مختلفة.',
      'status_playlist_session_limit':
          'تم بلوغ حد الجلسة: {max} عناصر لكل جلسة. سيتم إعادة التعيين خلال {duration}',
      'status_playlist_session_limit_no_reset':
          'تم بلوغ حد الجلسة: {max} عناصر لكل جلسة.',
      'ui_media_label': 'الوسائط: {name}',
      'ui_no_play_limit': 'لا يوجد حد للتشغيل',
      'ui_resets_in': ' · يعاد التعيين خلال {duration}',
      'ui_blocked': 'محظور',
      'loaded_last_played': 'تم تحميل آخر وسائط تم تشغيلها.',
      'audio': 'صوت',
      'ui_locked_reason': 'مقفل: {reason}',
      'lock_reason_time_tamper': 'تم اكتشاف عبث بالوقت',
      'lock_reason_expired': 'انتهت صلاحية الحزمة',
      'lock_reason_lifetime_limit': 'تم بلوغ الحد مدى الحياة',
      'ui_total_suffix': ' الإجمالي',
      'ui_plays_left': ' مرات تشغيل متبقية',
      'ui_session_usage': 'الجلسة: {used} / {max}',
      'ui_total_usage': 'الإجمالي: {used} / {max}',
      'abbr_day': 'ي',
      'abbr_hour': 'س',
      'abbr_minute': 'د',
      'abbr_second': 'ث',
      'language_settings_title': 'اللغة',
      'system_default': 'افتراضي النظام',
      'custom_translations': 'ترجمات مخصصة',
      'add_custom_translations': 'إضافة JSON مخصص',
      'remove_custom_translations': 'إزالة الترجمات المخصصة',
      'choose_json_file': 'اختر ملف JSON',
      'ui_demo_warning':
          'محتوى تجريبي — غير مخصّص للتوزيع. هذا صوت/فيديو للكتاب المقدّس هو مسودة غير مكتملة باللغة المحلية. ما زلنا نراجعه. الرجاء مساعدتنا في اختبار هذه التسجيلات وتصحيحها لكي نشارك النسخة النهائية مع الجميع.',
      // مربع حوار التأكيد للتشغيل
      'confirm_play_title': 'بدء التشغيل؟',
      'confirm_window_left': 'النافذة: متبقٍ {left} من {max}',
      'confirm_window_unlimited': 'النافذة: غير محدود',
      'confirm_lifetime_left': 'مدى الحياة: متبقٍ {left} من {max}',
      'confirm_lifetime_unlimited': 'مدى الحياة: غير محدود',
      'confirm_preview_free':
          'الثواني الأولى {seconds} مجانية قبل احتساب تشغيل واحد.',
      'start_playback': 'ابدأ',
      'cancel': 'إلغاء',
      // واجهة جديدة
      'fullscreen': 'وضع ملء الشاشة',
      'import_diagnostics': 'تشخيص الاستيراد',
      'import_diagnostics_subtitle':
          'يمكن أن تساعد سجلات الاستيراد المفصلة في استكشاف أخطاء الاستيراد البطيء أو الفاشل',
      'verbose_import_logs': 'سجلات الاستيراد المفصلة',
      'view_last_import_log': 'عرض آخر سجل استيراد',
      'last_import_log': 'آخر سجل استيراد',
      'copy': 'نسخ',
      'clear_logs': 'مسح السجلات',
      'auto_fullscreen_on_rotate': 'ملء الشاشة تلقائيًا عند التدوير',
      'auto_fullscreen_on_rotate_desc':
          'الانتقال تلقائيًا إلى وضع ملء الشاشة عند تدوير الجهاز إلى الوضع الأفقي أثناء تشغيل الفيديو',
      'allow_landscape': 'السماح بالوضع الأفقي',
      'allow_landscape_desc':
          'السماح للتطبيق بالدوران إلى الوضع الأفقي خارج ملء الشاشة؛ ستنتقل مقاطع الفيديو إلى ملء الشاشة في الوضع الأفقي إذا كان ذلك مفعّلًا',
    },
    'zh': {
      'app_title': '经文演示播放器',
      'device_id': '设备 ID',
      'close': '关闭',
      'import_bundle': '导入包',
      'play': '播放',
      'pause': '暂停',
      'stop': '停止',
      'no_decrypted_media_yet': '尚无已解密媒体。',
      'status_initial': '尚未加载任何包。',
      'status_picking_file': '正在选择文件…',
      'status_file_filter_unsupported': '不支持文件筛选；显示所有文件…',
      'status_file_picking_cancelled': '已取消文件选择。',
      'status_select_smbundle': '请选择 .smbundle 文件。',
      'status_extracting_bundle': '正在解压包…',
      'error_open_bundle_config': '错误：无法打开包配置。',
      'error_missing_bundle_config': '错误：缺少包配置。',
      'error_invalid_bundle_config': '错误：包配置无效。',
      'error_device_not_authorized': '错误：此设备未被授权使用此包。',
      'status_config_verified': '已为此设备验证配置。',
      'status_bundle_previously_used': '此包已使用过，无法重新导入。',
      'status_bundle_already_active': '包已处于活动状态。未进行更改。',
      'status_decrypting_media': '正在解密媒体…',
      'status_import_ready': '包已导入并准备就绪。',
      'status_no_playable_media': '此设备没有可播放的媒体。',
      'status_error_generic': '错误：{message}',
      'status_no_media_selected': '未选择媒体。',
      'status_time_tamper_lock': '检测到时间篡改。包已被永久锁定。',
      'status_bundle_expired_lock': '包已于 {date} 过期。永久锁定。',
      'status_max_total_lock': '已达到终身播放次数上限（{max}）。永久锁定。',
      'status_must_wait': '播放之间需等待 {duration}。',
      'status_play_limit_reached': '已达到此媒体的播放限制。',
      'status_play_limit_reached_with_reset': '已达到播放限制。将在 {duration} 后重置',
      // Playlist-level limit messages
      'status_playlist_expired_lock': '播放列表已于 {date} 过期。永久锁定。',
      'status_playlist_max_items_lock': '已播放播放列表中的最大唯一项目数（{max}）。永久锁定。',
      'status_must_wait_between_items': '播放不同项目之间需等待 {duration}。',
      'status_playlist_session_limit':
          '已达到会话限制：每个会话 {max} 个项目。将在 {duration} 后重置',
      'status_playlist_session_limit_no_reset': '已达到会话限制：每个会话 {max} 个项目。',
      'ui_media_label': '媒体：{name}',
      'ui_no_play_limit': '无限制播放',
      'ui_resets_in': ' · 将在 {duration} 后重置',
      'ui_blocked': '已阻止',
      'loaded_last_played': '已加载上次播放的媒体。',
      'audio': '音频',
      'ui_locked_reason': '已锁定：{reason}',
      'lock_reason_time_tamper': '检测到时间篡改',
      'lock_reason_expired': '包已过期',
      'lock_reason_lifetime_limit': '达到终身限制',
      'ui_total_suffix': ' 总计',
      'ui_plays_left': ' 次播放剩余',
      'ui_session_usage': '会话：{used} / {max}',
      'ui_total_usage': '总计：{used} / {max}',
      'abbr_day': '天',
      'abbr_hour': '小时',
      'abbr_minute': '分',
      'abbr_second': '秒',
      'language_settings_title': '语言',
      'system_default': '系统默认',
      'custom_translations': '自定义翻译',
      'add_custom_translations': '添加自定义 JSON',
      'remove_custom_translations': '移除自定义翻译',
      'choose_json_file': '选择 JSON 文件',
      'ui_demo_warning':
          '演示内容——请勿传播。此本地语言的经文音频/视频尚未定稿，我们仍在审校。请帮助我们测试并修订这些录音，以便将最终版本与大家分享。',
      // 播放确认对话框
      'confirm_play_title': '开始播放？',
      'confirm_window_left': '窗口：剩余 {left} / {max}',
      'confirm_window_unlimited': '窗口：无限制',
      'confirm_lifetime_left': '终身：剩余 {left} / {max}',
      'confirm_lifetime_unlimited': '终身：无限制',
      'confirm_preview_free': '前 {seconds} 秒免费，之后计为一次播放。',
      'start_playback': '开始',
      'cancel': '取消',
      // 新增 UI
      'fullscreen': '全屏',
      'import_diagnostics': '导入诊断',
      'import_diagnostics_subtitle': '详细导入日志有助于排查导入缓慢或失败的问题',
      'verbose_import_logs': '详细导入日志',
      'view_last_import_log': '查看最近一次导入日志',
      'last_import_log': '最近一次导入日志',
      'copy': '复制',
      'clear_logs': '清除日志',
      'auto_fullscreen_on_rotate': '旋转时自动全屏',
      'auto_fullscreen_on_rotate_desc': '设备在视频播放时旋转到横屏将自动进入全屏',
      'allow_landscape': '允许横屏旋转',
      'allow_landscape_desc': '允许应用在非全屏时横屏旋转；若启用，横屏视频仍会进入全屏',
    },
    'tpi': {
      'app_title': 'Scripture Demo Pleya',
      'device_id': 'Divais ID',
      'close': 'Klosim',
      'import_bundle': 'Karim bunld i kam insait',
      'play': 'Pilay',
      'pause': 'Stoppim liklik',
      'stop': 'Stop',
      'no_decrypted_media_yet': 'I no gat media i rausim pas yet.',
      'status_initial': 'Nogat bunld i lusim yet.',
      'status_picking_file': 'Yusim fail…',
      'status_file_filter_unsupported':
          'Fail fila i no sapot; soim olgeta fail…',
      'status_file_picking_cancelled': 'Makim fail i bin stop.',
      'status_select_smbundle': 'Plis makim wanpela .smbundle fail.',
      'status_extracting_bundle': 'Kisim bunld i kam aut…',
      'error_open_bundle_config': 'Sot: Inap nogat opim bunld config.',
      'error_missing_bundle_config': 'Sot: Bunld config i lus.',
      'error_invalid_bundle_config': 'Sot: Bunld config i no stret.',
      'error_device_not_authorized':
          'Sot: Dispela divais i no gat loa long dispela bunld.',
      'status_config_verified': 'Makim stretpela seting bilong dispela divais.',
      'status_bundle_previously_used':
          'Dispela bunld i bin yusim pinis na i no inap kam bek gen.',
      'status_bundle_already_active': 'Bunld i stap redi pinis. Nogat senis.',
      'status_decrypting_media': 'Rausim pas bilong media…',
      'status_import_ready': 'Bunld i kam insait na i redi.',
      'status_no_playable_media': 'Nogat media inap pilai long dispela divais.',
      'status_error_generic': 'Sot: {message}',
      'status_no_media_selected': 'Nogat media yu makim.',
      'status_time_tamper_lock': 'Taim i giaman i painim. Bunld i pas strong.',
      'status_bundle_expired_lock': 'Bunld i pinis long {date}. I pas strong.',
      'status_max_total_lock':
          'Makisim olgeta taim pilai ({max}) i kamap. I pas strong.',
      'status_must_wait': 'Mas wet {duration} namel long ol pilai.',
      'status_play_limit_reached':
          'Mak bilong pilai i kamap pinis long dispela media.',
      'status_play_limit_reached_with_reset':
          'Mak bilong pilai i kamap pinis. Bai stret gen long {duration}',
      // Playlist-level limit messages
      'status_playlist_expired_lock':
          'Plelist i pinis taim long {date}. I pas strong.',
      'status_playlist_max_items_lock':
          'Maksimum samting ({max}) long plelist i pilai pinis. I pas strong.',
      'status_must_wait_between_items':
          'Mas wet {duration} namel long pilai narapela samting.',
      'status_playlist_session_limit':
          'Mak bilong sesen i kamap: {max} samting long wan sesen. Bai stret gen long {duration}',
      'status_playlist_session_limit_no_reset':
          'Mak bilong sesen i kamap: {max} samting long wan sesen.',
      'ui_media_label': 'Media: {name}',
      'ui_no_play_limit': 'Nogat mak bilong pilai',
      'ui_resets_in': ' · bai stret gen long {duration}',
      'ui_blocked': 'Pas',
      'loaded_last_played': 'Las media yu bin pilai i kamap.',
      'audio': 'Audio',
      'ui_locked_reason': 'I pas: {reason}',
      'lock_reason_time_tamper': 'Taim giaman i painim',
      'lock_reason_expired': 'Bunld i pinis taim',
      'lock_reason_lifetime_limit': 'Mak long olgeta taim i kamap',
      'ui_total_suffix': ' olgeta',
      'ui_plays_left': ' pilai i stap yet',
      'ui_session_usage': 'Sesen: {used} / {max}',
      'ui_total_usage': 'Olgeta: {used} / {max}',
      'abbr_day': 'dei',
      'abbr_hour': 'aua',
      'abbr_minute': 'min',
      'abbr_second': 'sek',
      'language_settings_title': 'Tokples',
      'system_default': 'Sistem i save yusim',
      'custom_translations': 'Kastom translesen',
      'add_custom_translations': 'Putim kastom JSON',
      'remove_custom_translations': 'Rausim kastom translesen',
      'choose_json_file': 'Makim JSON fail',
      'ui_demo_warning':
          'Demosain samting — no bilong givaut. Dispela Tok Baibel audio/vidio em i draf yet long tokples. Mipela yet wok long skelim. Plis helpim mipela long traim na stretim ol rekoding olsem bai mipela ken kisim pinis na salim wantaim olgeta.',
      // Tokaut bipo long pilai
      'confirm_play_title': 'Statim pilai?',
      'confirm_window_left': 'Win: {left} / {max} i stap yet',
      'confirm_window_unlimited': 'Win: i no gat mak',
      'confirm_lifetime_left': 'Olgeta taim: {left} / {max} i stap yet',
      'confirm_lifetime_unlimited': 'Olgeta taim: i no gat mak',
      'confirm_preview_free':
          'Fes {seconds}s em fri pastaim bipo yumi kaunim wanpela pilai.',
      'start_playback': 'Stat',
      'cancel': 'Kanselim',
      // Nupela UI
      'fullscreen': 'Fulskrin',
      'import_diagnostics': 'Diagnostiks bilong import',
      'import_diagnostics_subtitle':
          'Bigpela ripot bilong import inap helpim long stretim hevi bilong slos o poret import',
      'verbose_import_logs': 'Bigpela ripot bilong import',
      'view_last_import_log': 'Lukim las ripot bilong import',
      'last_import_log': 'Las ripot bilong import',
      'copy': 'Kopi',
      'clear_logs': 'Klinim ol ripot',
      'auto_fullscreen_on_rotate': 'Fulskrin wantaim tanim nating',
      'auto_fullscreen_on_rotate_desc':
          'Taim yu tanim telefon i go long sait long taim video i plei, em bai go long fulskrin yet',
      'allow_landscape': 'Larim tanim i go long sait',
      'allow_landscape_desc':
          'Larim app i tanim i go long sait taim i no stap long fulskrin; sapos seting i stap, video long sait bai go long fulskrin yet',
    },
  };
  // Interpolation with {placeholders}
  static String f(
    String key,
    Map<String, String> params,
    Locale? locale,
    Map<String, Map<String, String>> custom,
  ) {
    final template = t(key, locale, custom);
    var out = template;
    params.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }

  static String formatDuration(
    Duration d,
    Locale? locale,
    Map<String, Map<String, String>> custom,
  ) {
    if (d.isNegative) return '0${t('abbr_second', locale, custom)}';
    final totalSeconds = d.inSeconds;
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final parts = <String>[];
    final dA = t('abbr_day', locale, custom);
    final hA = t('abbr_hour', locale, custom);
    final mA = t('abbr_minute', locale, custom);
    final sA = t('abbr_second', locale, custom);
    if (days > 0) parts.add('$days$dA');
    if (hours > 0) parts.add('$hours$hA');
    if (minutes > 0) parts.add('$minutes$mA');
    if (parts.isEmpty) parts.add('$seconds$sA');
    return parts.join(' ');
  }

  static String t(
    String key,
    Locale? locale,
    Map<String, Map<String, String>> custom,
  ) {
    final code =
        locale?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final base = _base[code] ?? _base['en']!;
    final overlay = custom[code] ?? const <String, String>{};
    return overlay[key] ?? base[key] ?? _base['en']![key] ?? key;
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
  String _status = L10n.t(
    'status_initial',
    _myAppKey.currentState?._locale,
    _myAppKey.currentState?._custom ?? const {},
  );
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
  // Free preview period before any play is charged (from bundle config; default 5s)
  Duration _freePreviewFor(String fileName) {
    try {
      final cfg = _bundleConfig;
      int? seconds;
      if (cfg != null) {
        // Per-file override
        final m = _findMediaConfig(fileName);
        if (m != null) {
          final Map<String, dynamic>? limit = (m['playbackLimit'] as Map?)
              ?.cast<String, dynamic>();
          seconds = (limit?['freePreviewSeconds'] as num?)?.toInt();
        }
        // Default fallback
        if (seconds == null) {
          final Map<String, dynamic>? defaults = (cfg['playbackLimits'] as Map?)
              ?.cast<String, dynamic>();
          final Map<String, dynamic>? def = (defaults?['default'] as Map?)
              ?.cast<String, dynamic>();
          seconds = (def?['freePreviewSeconds'] as num?)?.toInt();
        }
      }
      seconds ??= 5;
      if (seconds < 0) seconds = 0;
      return Duration(seconds: seconds);
    } catch (_) {
      return const Duration(seconds: 5);
    }
  }

  // Playlist reservation: counters reserved at play start and fulfilled on progress
  bool _playlistCountersReserved = false;
  bool _playlistReservationFulfilled = false;
  // Import progress UI
  bool _importInProgress = false;
  double _importProgress = 0.0; // 0..1
  String? _importLabel;
  // Track last saved position (ms) to throttle persistence
  int _lastSavedPosMs = 0;
  // Stream subscriptions for receiving shared files
  late StreamSubscription<List<SharedMediaFile>> _intentDataStreamSubscription;
  // UI ticker to refresh countdowns in list and headers
  Timer? _uiTicker;
  // Verbose import logging
  bool _verboseImportLogs = false;
  IOSink? _importLogSink;
  DateTime? _logStartTime;
  // Track fullscreen route to avoid re-entrancy on orientation changes
  bool _inFullscreen = false;
  // Preference: auto-enter fullscreen on landscape rotation
  bool _autoFullscreenOnRotate = true;
  // Throttle auto-fullscreen triggers to avoid rapid re-entry on bouncy rotations
  DateTime? _lastFullscreenTriggerAt;
  // If user exits fullscreen while still in landscape, suppress auto re-entry
  // until the device returns to portrait.
  bool _suppressAutoFullscreenUntilPortrait = false;
  // Preference: allow landscape rotation in main UI (outside fullscreen)
  bool _allowLandscapeInApp = false;
  bool _initialShareHandled = false;
  // Tooltip control for warning banner
  final GlobalKey<TooltipState> _warningTooltipKey = GlobalKey<TooltipState>();

  @override
  void initState() {
    super.initState();
    _getDeviceId();
    _loadLastPlayed();
    _configureAudioSession();
    _initReceiveSharingIntent();
    // Start a lightweight UI ticker so countdowns update live
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadVerbosePref();
    _loadAutoFullscreenPref();
    _loadAllowLandscapePref();
  }

  Future<void> _loadVerbosePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _verboseImportLogs = prefs.getBool('verboseImportLogs') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _loadAutoFullscreenPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _autoFullscreenOnRotate =
            prefs.getBool('autoFullscreenOnRotate') ?? true;
      });
    } catch (_) {}
  }

  Future<void> _loadAllowLandscapePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final allow = prefs.getBool('allowLandscapeInApp') ?? false;
      setState(() {
        _allowLandscapeInApp = allow;
      });
      // Apply default orientations based on preference
      await _applyDefaultOrientations();
    } catch (_) {}
  }

  Future<void> _applyDefaultOrientations() async {
    try {
      if (_inFullscreen) return; // fullscreen manages its own orientations
      if (_allowLandscapeInApp) {
        await services.SystemChrome.setPreferredOrientations(const [
          services.DeviceOrientation.portraitUp,
          services.DeviceOrientation.landscapeLeft,
          services.DeviceOrientation.landscapeRight,
        ]);
      } else {
        await services.SystemChrome.setPreferredOrientations(const [
          services.DeviceOrientation.portraitUp,
        ]);
      }
    } catch (_) {}
  }

  Future<Directory> _logsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/logs');
    await dir.create(recursive: true);
    return dir;
  }

  String _ts() => DateTime.now().toIso8601String();

  Future<void> _openImportLog(String bundlePath) async {
    if (!_verboseImportLogs) return;
    try {
      final dir = await _logsDir();
      final name = 'import-${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${dir.path}/$name');
      _importLogSink = file.openWrite(mode: FileMode.writeOnlyAppend);
      _logStartTime = DateTime.now();
      _vlog('=== Import started ${_ts()} ===');
      _vlog('Device: $_deviceId');
      _vlog('Bundle: $bundlePath');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastImportLogPath', file.path);
    } catch (_) {}
  }

  void _vlog(String line) {
    try {
      // ignore: avoid_print
      print('[IMPORT] $line');
      final s = _importLogSink;
      if (s != null) s.writeln('${_ts()} | $line');
    } catch (_) {}
  }

  Future<void> _closeImportLog({bool success = true, String? error}) async {
    if (_importLogSink == null) return;
    try {
      final dur = _logStartTime != null
          ? DateTime.now().difference(_logStartTime!)
          : null;
      if (success) {
        _vlog(
          '=== Import finished OK. Duration: ${dur?.inMilliseconds} ms ===',
        );
      } else {
        _vlog(
          '=== Import failed. ${error ?? ''} Duration: ${dur?.inMilliseconds} ms ===',
        );
      }
      await _importLogSink!.flush();
      await _importLogSink!.close();
    } catch (_) {}
    _importLogSink = null;
    _logStartTime = null;
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // Optional: listen for interruptions and handle gracefully
      session.interruptionEventStream.listen((event) async {
        final c = _controller;
        if (c == null) return;
        if (event.begin) {
          // Pause on interruption start
          try {
            await c.pause();
          } catch (_) {}
        } else {
          // Interruption ended; do not auto-resume to respect user context
        }
      });
      session.becomingNoisyEventStream.listen((_) async {
        // Headphones disconnected; pause playback to avoid blasting on speakers
        final c = _controller;
        if (c != null) {
          try {
            await c.pause();
          } catch (_) {}
        }
      });
    } catch (_) {
      // Best-effort only; ignore if audio session not available
    }
  }

  String _t(String key, [Map<String, String>? params]) {
    final loc = _myAppKey.currentState?._locale;
    final custom = _myAppKey.currentState?._custom ?? const {};
    if (params == null || params.isEmpty) return L10n.t(key, loc, custom);
    return L10n.f(key, params, loc, custom);
  }

  String _fmtDur(Duration d) {
    final loc = _myAppKey.currentState?._locale;
    final custom = _myAppKey.currentState?._custom ?? const {};
    return L10n.formatDuration(d, loc, custom);
  }

  // If the current status text is the built-in "initial" message in any locale,
  // translate it to the newly selected locale.
  void _relocalizeStatusIfInitial() {
    final cur = _status.trim();
    for (final base in L10n._base.values) {
      final s = base['status_initial'];
      if (s != null && s.trim() == cur) {
        _status = _t('status_initial');
        break;
      }
    }
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

  void _initReceiveSharingIntent() {
    // For sharing via share menu or opening from another app while app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              if (_importInProgress) return;
              final p = value.first.path;
              if (p.isNotEmpty) {
                _handleSharedFile(p);
              }
            }
          },
          onError: (err) {
            // Log error and show user-friendly message
            if (mounted) {
              setState(() {
                _status = _t('status_error_generic', {
                  'message': 'Failed to receive shared file',
                });
              });
            }
          },
        );

    // For sharing via share menu or opening from another app while app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty && !_initialShareHandled) {
        _initialShareHandled = true;
        // Defer handling until first frame to avoid layout/white screen issues
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          if (_importInProgress) return;
          final p = value.first.path;
          if (p.isNotEmpty) {
            await _handleSharedFile(p);
          }
          // Clear the initial shared file to prevent re-processing
          try {
            await ReceiveSharingIntent.instance.reset();
          } catch (_) {}
        });
      }
    });
  }

  Future<void> _handleSharedFile(String filePath) async {
    try {
      if (_importInProgress) return;
      if (!filePath.toLowerCase().endsWith('.smbundle')) {
        setState(() => _status = _t('status_select_smbundle'));
        return;
      }
      // Process the bundle using the existing logic
      await _processBundle(filePath);
    } catch (e) {
      if (mounted) {
        setState(() => _status = _t('status_error_generic', {'message': '$e'}));
      }
    }
  }

  Future<void> _pickAndProcessBundle() async {
    setState(() {
      _isLoading = true;
      _status = _t('status_picking_file');
      _importInProgress = false;
      _importProgress = 0.0;
      _importLabel = null;
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
        setState(() => _status = _t('status_file_filter_unsupported'));
        result = await FilePicker.platform.pickFiles(type: FileType.any);
      }
      if (result == null || result.files.single.path == null) {
        setState(() => _status = _t('status_file_picking_cancelled'));
        return;
      }
      final bundlePath = result.files.single.path!;
      if (!bundlePath.toLowerCase().endsWith('.smbundle')) {
        setState(() => _status = _t('status_select_smbundle'));
        return;
      }
      await _processBundle(bundlePath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _t('status_error_generic', {'message': '$e'}));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processBundle(String bundlePath) async {
    setState(() {
      _isLoading = true;
      _status = _t('status_extracting_bundle');
      _importInProgress = true;
      _importProgress = 0.0;
      _importLabel = _t('status_extracting_bundle');
    });
    await _openImportLog(bundlePath);
    _vlog('Begin import.');
    // Watchdog to detect stalls and cancel long-running operations on very slow devices
    bool cancelled = false;
    String? cancelMsg;
    DateTime lastActivity = DateTime.now();
    Timer? watchdog;
    void startWatchdog() {
      watchdog?.cancel();
      watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!cancelled &&
            DateTime.now().difference(lastActivity) >
                const Duration(minutes: 2)) {
          cancelled = true;
          cancelMsg =
              'Extraction stalled. Please retry after checking device storage and permissions.';
        }
      });
    }

    void stopWatchdog() {
      watchdog?.cancel();
      watchdog = null;
    }

    startWatchdog();
    try {
      final tempDir = await getTemporaryDirectory();
      final extractionPath = '${tempDir.path}/bundle_extract';
      await Directory(extractionPath).create(recursive: true);

      // Decompress .tar.gz (.smbundle) to a temporary .tar file using async streams (non-blocking)
      final tarOutPath = '$extractionPath/.tmp_bundle.tar';
      try {
        final inFile = File(bundlePath);
        final totalCompressed = await inFile.length().catchError((_) => 0);
        _vlog('Phase: decompress (.gz -> .tar), size=$totalCompressed bytes');
        int readCompressed = 0;
        DateTime lastUi = DateTime.now();

        // Wrap the input stream to count bytes read for progress
        final countingStream = inFile
            .openRead()
            .transform(
              StreamTransformer<List<int>, List<int>>.fromHandlers(
                handleData: (data, sink) {
                  if (cancelled) {
                    sink.addError(StateError('cancelled'));
                    return;
                  }
                  readCompressed += data.length;
                  sink.add(data);
                  lastActivity = DateTime.now();
                  // Throttle UI updates to ~10 per second
                  final now = DateTime.now();
                  if (mounted &&
                      totalCompressed > 0 &&
                      now.difference(lastUi).inMilliseconds >= 100) {
                    lastUi = now;
                    final pct = (readCompressed / totalCompressed).clamp(
                      0.0,
                      1.0,
                    );
                    setState(() {
                      _importProgress = pct.toDouble();
                      _importLabel =
                          '${_t('status_extracting_bundle')} (decompressing ${(pct * 100).toStringAsFixed(0)}%)';
                    });
                  }
                },
              ),
            )
            .timeout(const Duration(minutes: 2));

        final outSink = File(tarOutPath).openWrite();
        try {
          await countingStream.transform(gzip.decoder).pipe(outSink);
        } on TimeoutException {
          cancelled = true;
          cancelMsg =
              'Extraction timed out while decompressing. Please try again.';
          rethrow;
        } on StateError catch (se) {
          if (se.message.contains('cancelled')) {
            rethrow;
          }
          rethrow;
        } finally {
          await outSink.close();
        }

        // Ensure progress reaches 100% for the decompress stage
        if (mounted && totalCompressed > 0) {
          setState(() {
            _importProgress = 1.0;
            _importLabel =
                '${_t('status_extracting_bundle')} (decompressing 100%)';
          });
          _vlog('Decompress complete.');
        }
      } catch (e) {
        final msg = cancelled
            ? (cancelMsg ?? 'Extraction cancelled due to inactivity.')
            : 'Corrupt or unsupported gzip archive';
        _vlog('Decompress failed: $e');
        setState(() => _status = _t('status_error_generic', {'message': msg}));
        await _closeImportLog(success: false, error: msg);
        return;
      }

      // Decrypt and validate bundle.smb config with shared key (REQUIRED)
      // First pass: read only bundle.smb from tar into memory and decrypt config
      Map<String, dynamic>? config;
      try {
        final cfgBytes = await _readTarEntryBytes(
          tarOutPath,
          (name) => name.split('/').last == 'bundle.smb',
        );
        if (cfgBytes == null) {
          await _deleteDirectory(Directory(extractionPath));
          setState(() => _status = _t('error_missing_bundle_config'));
          _vlog('Missing bundle.smb in tar.');
          await _closeImportLog(success: false, error: 'missing config');
          return;
        }
        final rawText = utf8.decode(cfgBytes);
        final decrypted = _cryptoJsAesDecrypt(rawText, _configSharedKey);
        if (decrypted == null) {
          await _deleteDirectory(Directory(extractionPath));
          setState(() => _status = _t('error_open_bundle_config'));
          _vlog('Failed to decrypt bundle.smb with shared key.');
          await _closeImportLog(success: false, error: 'config decrypt failed');
          return;
        }
        config = json.decode(utf8.decode(decrypted)) as Map<String, dynamic>;
        _vlog('Config decrypted OK.');
      } catch (e) {
        await _deleteDirectory(Directory(extractionPath));
        setState(() => _status = _t('error_open_bundle_config'));
        _vlog('Config read/decode error: $e');
        await _closeImportLog(success: false, error: 'config open error');
        return;
      }

      // Enforce allowedDeviceIds before any media processing
      try {
        final allowed =
            (config['allowedDeviceIds'] as List?)?.cast<String>() ?? <String>[];
        if (allowed.isEmpty || !allowed.contains(_deviceId)) {
          await _deleteDirectory(Directory(extractionPath));
          setState(() => _status = _t('error_device_not_authorized'));
          _vlog('Unauthorized device.');
          await _closeImportLog(success: false, error: 'unauthorized device');
          return;
        }
        setState(() => _status = _t('status_config_verified'));
        _vlog('Device authorization OK.');
      } catch (e) {
        await _deleteDirectory(Directory(extractionPath));
        setState(() => _status = _t('error_invalid_bundle_config'));
        _vlog('Invalid bundle config: $e');
        await _closeImportLog(success: false, error: 'invalid config');
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
        setState(() => _status = _t('status_bundle_previously_used'));
        return;
      }

      // If attempting to re-import the currently active bundle, do nothing
      if (activeBundleId != null && activeBundleId == bundleId) {
        await _deleteDirectory(Directory(extractionPath));
        setState(() => _status = _t('status_bundle_already_active'));
        return;
      }

      // Prepare persistent content directory
      final docs = await getApplicationDocumentsDirectory();
      final contentDir = Directory('${docs.path}/content');
      await contentDir.create(recursive: true);

      // If importing a different, new bundle: clear previous content and reset active
      final bool importingNewBundle =
          activeBundleId == null || activeBundleId != bundleId;
      if (importingNewBundle) {
        // Clear previous content
        await _deleteDirectory(contentDir);
        await contentDir.create(recursive: true);
      }

      // Determine effective decryption key: unwrap per-device bundle key if present
      final deviceKey = _generateDeviceKey(_deviceId, _saltConst);
      String effectiveKey = deviceKey;
      try {
        final Map<String, dynamic>? wrappedMap =
            (config['bundleKeyEncryptedForDevices'] as Map?)
                ?.cast<String, dynamic>();
        if (wrappedMap != null) {
          final wrapped = wrappedMap[_deviceId] as String?;
          if (wrapped == null) {
            await _deleteDirectory(Directory(extractionPath));
            setState(() => _status = _t('error_device_not_authorized'));
            return;
          }
          final unwrapped = _cryptoJsAesDecrypt(wrapped, deviceKey);
          if (unwrapped == null) {
            await _deleteDirectory(Directory(extractionPath));
            setState(() => _status = _t('error_device_not_authorized'));
            return;
          }
          effectiveKey = utf8.decode(unwrapped);
        }
      } catch (_) {
        // Fallback to deviceKey if mapping missing/unexpected
      }

      // Second pass: selectively extract only the encrypted media files we need
      try {
        final mediaPaths = <String>{};
        final List<dynamic> mediaList =
            (config['mediaFiles'] as List?) ?? <dynamic>[];
        for (final item in mediaList) {
          if (item is! Map) continue;
          final encPath = item['encryptedPath'] as String?;
          if (encPath != null && encPath.isNotEmpty) {
            mediaPaths.add(encPath);
          }
        }
        // Estimate total bytes to extract and show it
        final totalBytes = await _estimateTarEntriesSize(
          tarOutPath,
          mediaPaths,
        );
        _vlog(
          'Phase: tar extract (selective). files=${mediaPaths.length}, totalBytes~$totalBytes',
        );
        if (mounted) {
          setState(() {
            _importProgress = 0.0;
            _importLabel =
                '${_t('status_extracting_bundle')} (~${_formatBytes(totalBytes)} needed)';
          });
        }
        int extractedBytes = 0;
        DateTime lastUiTick = DateTime.now();
        await _extractTarEntries(
          tarOutPath,
          mediaPaths,
          extractionPath,
          onProgress: (int wrote, int total, String currentName) {
            extractedBytes += wrote;
            final prog = total > 0 ? extractedBytes / total : 0.0;
            lastActivity = DateTime.now();
            if (!mounted) return;
            // Throttle UI updates to ~10/s or update on completion
            final now = DateTime.now();
            if (now.difference(lastUiTick).inMilliseconds >= 100 ||
                prog >= 1.0) {
              lastUiTick = now;
              setState(() {
                _importProgress = prog.clamp(0.0, 1.0);
                _importLabel =
                    '${_t('status_extracting_bundle')} ${(_importProgress * 100).toStringAsFixed(0)}%';
              });
            }
          },
          isCancelled: () => cancelled,
          totalBytes: totalBytes,
        );
        _vlog('Tar extract complete.');
      } catch (e) {
        await _deleteDirectory(Directory(extractionPath));
        final msg =
            '$e'.toLowerCase().contains('no space') || '$e'.contains('ENOSPC')
            ? 'Insufficient storage space. Please free up space and try again.'
            : (cancelMsg ?? 'Failed to extract media files');
        _vlog('Tar extract failed: $e');
        setState(() => _status = _t('status_error_generic', {'message': msg}));
        await _closeImportLog(success: false, error: msg);
        return;
      } finally {
        // Remove temp tar
        try {
          await File(tarOutPath).delete();
        } catch (_) {}
      }

      // Decrypt/Deobfuscate media based on config mapping so filenames match original fileName
      setState(() {
        _status = _t('status_decrypting_media');
        _importProgress = 0.0;
        _importLabel = _t('status_decrypting_media');
      });
      _vlog('Phase: media decode/deobfuscate.');
      File? firstDecrypted;
      final List<dynamic> mediaList =
          (config['mediaFiles'] as List?) ?? <dynamic>[];
      int decIdx = 0;
      final decTotal = mediaList.length;
      for (final item in mediaList) {
        if (item is! Map) continue;
        final encPath = item['encryptedPath'] as String?;
        final origName = item['fileName'] as String?;
        if (encPath == null || origName == null) continue;
        final srcFile = File('$extractionPath/$encPath');
        if (!await srcFile.exists()) continue;
        try {
          final outPath = '${contentDir.path}/$origName';
          final Map<String, dynamic>? protection = (item['protection'] as Map?)
              ?.cast<String, dynamic>();
          final scheme = protection?['scheme'] as String?;
          if (scheme == 'xor-v1') {
            final saltB64 = protection?['salt'] as String?;
            final salt = (saltB64 != null && saltB64.isNotEmpty)
                ? base64.decode(saltB64)
                : Uint8List(0);
            _vlog('Deobfuscate xor-v1: $encPath -> $origName');
            await _deobfuscateFileStreaming(
              srcFile.path,
              outPath,
              effectiveKey,
              salt,
            );
          } else {
            _vlog('Legacy AES decrypt: $encPath -> $origName');
            // Default legacy AES(CryptoJS) path
            await _decryptEncFileToFileStreaming(
              srcFile.path,
              outPath,
              effectiveKey,
              onProgress: (_) {},
            );
          }
          firstDecrypted ??= File(outPath);
        } on FileSystemException catch (fe) {
          final msg =
              (fe.osError?.errorCode == 28 ||
                  '${fe.osError}'.toLowerCase().contains('no space'))
              ? 'Insufficient storage space. Please free up space and try again.'
              : 'Failed to write media file';
          _vlog('Write error: ${fe.osError}');
          setState(
            () => _status = _t('status_error_generic', {'message': msg}),
          );
          await _closeImportLog(success: false, error: msg);
          return;
        } catch (e) {
          // Corrupt or unexpected encryption format; skip this item
          _vlog('Decode error for $encPath: $e');
        }
        decIdx++;
        if (mounted && decTotal > 0) {
          setState(() {
            _importProgress = decIdx / decTotal;
            _importLabel =
                '${_t('status_decrypting_media')} ${(_importProgress * 100).toStringAsFixed(0)}%';
          });
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
          _status = _t('status_import_ready');
        });
      } else {
        setState(() {
          _decryptedFiles = files..sort((a, b) => a.path.compareTo(b.path));
          _status = _t('status_no_playable_media');
        });
      }

      // Delete extracted temp and original bundle file after successful import
      await _deleteDirectory(Directory(extractionPath));
      try {
        await File(bundlePath).delete();
      } catch (_) {}
      _vlog('Cleanup complete.');
      await _closeImportLog(success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _t('status_error_generic', {'message': '$e'}));
      _vlog('Unhandled error: $e');
      await _closeImportLog(success: false, error: '$e');
    } finally {
      stopWatchdog();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _importInProgress = false;
          _importProgress = 0.0;
          _importLabel = null;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double b = bytes.toDouble();
    int i = 0;
    while (b >= 1024 && i < units.length - 1) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
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

  // Stream a large encrypted base64 file -> decrypt (OpenSSL salted AES-256-CBC, PKCS7) -> decode base64 -> write to dst
  Future<void> _decryptEncFileToFileStreaming(
    String srcEncPath,
    String dstPath,
    String passphrase, {
    void Function(int wroteBytes)? onProgress,
  }) async {
    // Write to a temp path then atomically replace
    final outTmp = File('$dstPath.part');
    try {
      final outSink = outTmp.openWrite();
      try {
        // file (text base64) -> utf8 -> base64.decode -> encrypted bytes
        final encryptedBytes = File(
          srcEncPath,
        ).openRead().transform(utf8.decoder).transform(base64.decoder);

        // Decrypt encrypted bytes stream (handles Salted__ header + PKCS7)
        final decryptedPlaintextBytes = encryptedBytes.transform(
          _OpenSslAesCbcPkcs7StreamDecryptor(passphrase),
        );

        // Decrypted plaintext is base64 text of the media; decode to binary
        // bytes and pipe to file.
        final mediaBytes = decryptedPlaintextBytes
            .transform(utf8.decoder)
            .transform(base64.decoder);

        // Pipe with optional progress callback
        await mediaBytes
            .map((chunk) {
              if (onProgress != null) onProgress(chunk.length);
              return chunk;
            })
            .pipe(outSink);
      } finally {
        await outSink.close();
      }
      // Replace existing file
      final dstFile = File(dstPath);
      try {
        if (await dstFile.exists()) await dstFile.delete();
      } catch (_) {}
      await outTmp.rename(dstPath);
    } catch (e) {
      try {
        if (await outTmp.exists()) await outTmp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  // Lightweight XOR-based deobfuscation (not cryptographically secure)
  // Mirrors desktop bundler's xor-v1 protection scheme.
  Future<void> _deobfuscateFileStreaming(
    String srcPath,
    String dstPath,
    String keyHex,
    Uint8List salt,
  ) async {
    final outTmp = File('$dstPath.part');
    RandomAccessFile? inFile;
    IOSink? outSink;
    try {
      inFile = await File(srcPath).open();
      outSink = outTmp.openWrite();
      final key = _hexToBytes(keyHex);
      if (key.isEmpty) {
        throw StateError('Invalid key');
      }
      int offset = 0;
      const chunkSize = 128 * 1024;
      while (true) {
        final data = await inFile.read(chunkSize);
        if (data.isEmpty) break;
        final out = Uint8List(data.length);
        for (int i = 0; i < data.length; i++) {
          final pos = offset + i;
          final k = key[pos % key.length];
          final s = salt.isNotEmpty ? salt[pos % salt.length] : 0;
          final mask = (k ^ s ^ ((pos * 31) & 0xff)) & 0xff;
          out[i] = data[i] ^ mask;
        }
        outSink.add(out);
        offset += data.length;
      }
      await outSink.close();
      try {
        if (await File(dstPath).exists()) await File(dstPath).delete();
      } catch (_) {}
      await outTmp.rename(dstPath);
    } catch (e) {
      try {
        await outSink?.close();
      } catch (_) {}
      try {
        if (await outTmp.exists()) await outTmp.delete();
      } catch (_) {}
      rethrow;
    } finally {
      try {
        await inFile?.close();
      } catch (_) {}
    }
  }

  Uint8List _hexToBytes(String hex) {
    final clean = hex.trim();
    final len = clean.length;
    if (len % 2 != 0) return Uint8List(0);
    final out = Uint8List(len ~/ 2);
    for (int i = 0; i < len; i += 2) {
      out[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return out;
  }

  void _initializePlayer(String mediaPath, {bool autoPlay = false}) {
    // Finalize any active session before switching media
    _finalizePlaySession();
    _controller?.dispose();
    _currentMediaPath = mediaPath;
    _controller = VideoPlayerController.file(File(mediaPath))
      ..initialize().then((_) {
        if (!mounted) return;
        // Attach listeners for position persistence and natural-end charging
        _attachControllerListeners();
        // Restore last saved position, if any (forward-only scrubbing still enforced)
        _restoreSavedPosition();
        setState(() {});
        if (autoPlay) {
          _attemptAutoPlay();
        }
      });
  }

  Future<void> _goFullscreen({
    bool explicitEntry = false,
    Orientation? initialOrientation,
  }) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_inFullscreen) return;
    _inFullscreen = true;
    _lastFullscreenTriggerAt = DateTime.now();
    try {
      await services.SystemChrome.setEnabledSystemUIMode(
        services.SystemUiMode.immersiveSticky,
      );
      // Allow portraitUp as well so we can detect a portrait rotation
      // and gracefully exit fullscreen when user flips the device back.
      await services.SystemChrome.setPreferredOrientations(const [
        services.DeviceOrientation.landscapeLeft,
        services.DeviceOrientation.landscapeRight,
        services.DeviceOrientation.portraitUp,
      ]);
    } catch (_) {}

    if (!mounted) return;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullscreenVideoPage(
            controller: c,
            explicitEntry: explicitEntry,
            initialOrientation:
                initialOrientation ?? MediaQuery.of(context).orientation,
          ),
        ),
      );
    } finally {
      _inFullscreen = false;
    }

    // Restore UI and portrait orientation on exit
    // If we exited while still in landscape (e.g., via close button),
    // suppress auto re-entry until we see portrait again and add a short cooldown.
    try {
      Orientation? ori;
      if (mounted) {
        ori = MediaQuery.of(context).orientation;
      }
      if (ori == Orientation.landscape) {
        _suppressAutoFullscreenUntilPortrait = true;
      }
      // Short cooldown to avoid bounce on immediate orientation callbacks
      _lastFullscreenTriggerAt = DateTime.now();
    } catch (_) {}

    try {
      await services.SystemChrome.setEnabledSystemUIMode(
        services.SystemUiMode.edgeToEdge,
      );
      // Respect the user's default orientation preference outside fullscreen
      await _applyDefaultOrientations();
    } catch (_) {}
  }

  Future<void> _attemptAutoPlay() async {
    if (_controller == null) return;

    if (!await _canPlayCurrent()) {
      final id = _currentMediaId;
      if (id == null) {
        setState(() {
          _status = _t('status_no_media_selected');
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final bundleId = _bundleConfig != null
          ? (_bundleConfig!['bundleId'] ?? 'unknown')
          : 'unknown';

      // Check time tampering
      final lastKnownTimeKey = 'lastKnownTime';
      final lastKnownTimeMs = prefs.getInt(lastKnownTimeKey);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastKnownTimeMs != null && now < lastKnownTimeMs) {
        setState(() {
          _status = _t('status_time_tamper_lock');
        });
        return;
      }

      // Check bundle expiration
      final expirationDateStr = _bundleExpirationDate();
      if (expirationDateStr != null) {
        final expirationDate = DateTime.parse(expirationDateStr);
        if (DateTime.now().isAfter(expirationDate)) {
          setState(() {
            _status = _t('status_bundle_expired_lock', {
              'date': expirationDate.toLocal().toString(),
            });
          });
          return;
        }
      }

      // === Playlist-level checks ===
      await _ensurePlaylistSession();

      // Check playlist expiration
      final playlistExpirationStr = _playlistExpirationDate();
      if (playlistExpirationStr != null) {
        final playlistExpiration = DateTime.parse(playlistExpirationStr);
        if (DateTime.now().isAfter(playlistExpiration)) {
          setState(() {
            _status = _t('status_playlist_expired_lock', {
              'date': playlistExpiration.toLocal().toString(),
            });
          });
          return;
        }
      }

      // Check total unique items played
      final maxTotalItems = _maxTotalItemsPlayed();
      if (maxTotalItems != null) {
        final totalItems = await _getTotalItemsPlayed();
        if (totalItems.length >= maxTotalItems && !totalItems.contains(id)) {
          setState(() {
            _status = _t('status_playlist_max_items_lock', {
              'max': '$maxTotalItems',
            });
          });
          return;
        }
      }

      // Check minimum interval between items
      final minIntervalBetweenItems = _minIntervalBetweenItemsMs();
      if (minIntervalBetweenItems != null && minIntervalBetweenItems > 0) {
        final lastItemPlayTime = await _getLastItemPlayTime();
        if (lastItemPlayTime != null) {
          final timeSinceLastItem = now - lastItemPlayTime;
          if (timeSinceLastItem < minIntervalBetweenItems) {
            final remaining = Duration(
              milliseconds: minIntervalBetweenItems - timeSinceLastItem,
            );
            setState(() {
              _status = _t('status_must_wait_between_items', {
                'duration': _fmtDur(remaining),
              });
            });
            return;
          }
        }
      }

      // Check max items per session
      final maxItems = _maxItemsPerSession();
      if (maxItems != null) {
        final sessionItems = await _getPlayedItemsInSession();
        if (sessionItems.length >= maxItems && !sessionItems.contains(id)) {
          final sessionResetMs = _sessionResetIntervalMs();
          if (sessionResetMs != null) {
            final sessionStartKey = 'playlistSession:$bundleId:start';
            final sessionStart = prefs.getInt(sessionStartKey);
            if (sessionStart != null) {
              final elapsed = now - sessionStart;
              final remaining = Duration(
                milliseconds: sessionResetMs - elapsed,
              );
              setState(() {
                _status = _t('status_playlist_session_limit', {
                  'max': '$maxItems',
                  'duration': _fmtDur(remaining),
                });
              });
              return;
            }
          }
          setState(() {
            _status = _t('status_playlist_session_limit_no_reset', {
              'max': '$maxItems',
            });
          });
          return;
        }
      }

      // === Per-file checks ===
      // Check total plays limit
      final maxPlaysTotal = _maxPlaysTotalFor(id);
      if (maxPlaysTotal != null) {
        final totalKey = 'playsTotal:$bundleId:$id';
        final totalPlays = prefs.getInt(totalKey) ?? 0;
        if (totalPlays >= maxPlaysTotal) {
          setState(() {
            _status = _t('status_max_total_lock', {'max': '$maxPlaysTotal'});
          });
          return;
        }
      }

      // Check minimum interval between plays
      final minIntervalMs = _minIntervalMsFor(id);
      if (minIntervalMs != null && minIntervalMs > 0) {
        final lastPlayKey = 'lastPlay:$bundleId:$id';
        final lastPlayMs = prefs.getInt(lastPlayKey);
        if (lastPlayMs != null) {
          final timeSinceLastPlay = now - lastPlayMs;
          if (timeSinceLastPlay < minIntervalMs) {
            final remaining = Duration(
              milliseconds: minIntervalMs - timeSinceLastPlay,
            );
            setState(() {
              _status = _t('status_must_wait', {
                'duration': _fmtDur(remaining),
              });
            });
            return;
          }
        }
      }

      // Check windowed plays limit
      final rem = await _remainingBlockTime(id);
      final msg = rem == null
          ? _t('status_play_limit_reached')
          : _t('status_play_limit_reached_with_reset', {
              'duration': _fmtDur(rem),
            });
      setState(() {
        _status = msg;
      });
      return;
    }
    _startPlaySession();
    _controller!.play();
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

  Future<void> _stopAndCharge() async {
    final c = _controller;
    if (c == null) return;
    final pos = c.value.position;
    final dur = c.value.duration;
    final name = _currentMediaId;
    final preview = name != null
        ? _freePreviewFor(name)
        : const Duration(seconds: 5);
    final meetsThreshold =
        pos >= preview ||
        (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 250));
    if (meetsThreshold && _currentMediaId != null) {
      await _incrementPlaysUsed(_currentMediaId!);
      _sessionCharged = true;
      await _clearSavedPosition(_currentMediaId!);
    } else {
      // Release reserved playlist counters if no progress
      await _releasePlaylistCountersIfUnfulfilled();
    }
    await _stopPlayback();
    _sessionActive = false;
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

  int _resetMsFor(String fileName) {
    final m = _findMediaConfig(fileName);
    int? resetMs;
    if (m != null) {
      final Map<String, dynamic>? limit = (m['playbackLimit'] as Map?)
          ?.cast<String, dynamic>();
      resetMs = (limit?['resetIntervalMs'] as num?)?.toInt();
      // Legacy support for resetIntervalHours
      if (resetMs == null) {
        final hours = (limit?['resetIntervalHours'] as num?)?.toInt();
        if (hours != null) {
          resetMs = hours * 3600 * 1000;
        }
      }
    }
    if (resetMs == null) {
      final cfg = _bundleConfig;
      final Map<String, dynamic>? defaults = (cfg?['playbackLimits'] as Map?)
          ?.cast<String, dynamic>();
      final Map<String, dynamic>? def = (defaults?['default'] as Map?)
          ?.cast<String, dynamic>();
      resetMs = (def?['resetIntervalMs'] as num?)?.toInt();
      // Legacy support
      if (resetMs == null) {
        final hours = (def?['resetIntervalHours'] as num?)?.toInt();
        if (hours != null) {
          resetMs = hours * 3600 * 1000;
        }
      }
    }
    return resetMs ?? 24 * 3600 * 1000;
  }

  int? _minIntervalMsFor(String fileName) {
    final m = _findMediaConfig(fileName);
    int? minIntervalMs;
    if (m != null) {
      final Map<String, dynamic>? limit = (m['playbackLimit'] as Map?)
          ?.cast<String, dynamic>();
      minIntervalMs = (limit?['minIntervalBetweenPlaysMs'] as num?)?.toInt();
    }
    if (minIntervalMs == null) {
      final cfg = _bundleConfig;
      final Map<String, dynamic>? defaults = (cfg?['playbackLimits'] as Map?)
          ?.cast<String, dynamic>();
      final Map<String, dynamic>? def = (defaults?['default'] as Map?)
          ?.cast<String, dynamic>();
      minIntervalMs = (def?['minIntervalBetweenPlaysMs'] as num?)?.toInt();
    }
    return minIntervalMs;
  }

  int? _maxPlaysTotalFor(String fileName) {
    final m = _findMediaConfig(fileName);
    int? maxPlaysTotal;
    if (m != null) {
      final Map<String, dynamic>? limit = (m['playbackLimit'] as Map?)
          ?.cast<String, dynamic>();
      maxPlaysTotal = (limit?['maxPlaysTotal'] as num?)?.toInt();
    }
    if (maxPlaysTotal == null) {
      final cfg = _bundleConfig;
      final Map<String, dynamic>? defaults = (cfg?['playbackLimits'] as Map?)
          ?.cast<String, dynamic>();
      final Map<String, dynamic>? def = (defaults?['default'] as Map?)
          ?.cast<String, dynamic>();
      maxPlaysTotal = (def?['maxPlaysTotal'] as num?)?.toInt();
    }
    return maxPlaysTotal;
  }

  String? _bundleExpirationDate() {
    return _bundleConfig?['expirationDate'] as String?;
  }

  // ===== Playlist-level limit helpers =====
  Map<String, dynamic>? _getPlaylistLimits() {
    final cfg = _bundleConfig;
    if (cfg == null) return null;
    final limits = cfg['playlistLimits'] as Map?;
    return limits?.cast<String, dynamic>();
  }

  int? _maxItemsPerSession() {
    final limits = _getPlaylistLimits();
    return (limits?['maxItemsPerSession'] as num?)?.toInt();
  }

  int? _sessionResetIntervalMs() {
    final limits = _getPlaylistLimits();
    return (limits?['sessionResetIntervalMs'] as num?)?.toInt();
  }

  int? _minIntervalBetweenItemsMs() {
    final limits = _getPlaylistLimits();
    return (limits?['minIntervalBetweenItemsMs'] as num?)?.toInt();
  }

  int? _maxTotalItemsPlayed() {
    final limits = _getPlaylistLimits();
    return (limits?['maxTotalItemsPlayed'] as num?)?.toInt();
  }

  String? _playlistExpirationDate() {
    final limits = _getPlaylistLimits();
    return limits?['expirationDate'] as String?;
  }

  Future<Set<String>> _getPlayedItemsInSession() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistSession:$bundleId:items';
    final items = prefs.getStringList(key) ?? [];
    return items.toSet();
  }

  Future<void> _addItemToSession(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistSession:$bundleId:items';
    final items = (prefs.getStringList(key) ?? []).toSet();
    items.add(fileName);
    await prefs.setStringList(key, items.toList());

    // Update session start time if not set
    final sessionStartKey = 'playlistSession:$bundleId:start';
    if (!prefs.containsKey(sessionStartKey)) {
      await prefs.setInt(
        sessionStartKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _ensurePlaylistSession() async {
    final resetIntervalMs = _sessionResetIntervalMs();
    if (resetIntervalMs == null) return; // No session reset configured

    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final sessionStartKey = 'playlistSession:$bundleId:start';
    final sessionItemsKey = 'playlistSession:$bundleId:items';
    final sessionCountKey = 'playlistSession:$bundleId:count';

    final sessionStart = prefs.getInt(sessionStartKey);
    if (sessionStart == null) return; // No session started yet

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - sessionStart;

    if (elapsed >= resetIntervalMs) {
      // Session expired, reset
      await prefs.remove(sessionStartKey);
      await prefs.remove(sessionItemsKey);
      await prefs.remove(sessionCountKey);
    }
  }

  Future<Set<String>> _getTotalItemsPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistTotal:$bundleId:items';
    final items = prefs.getStringList(key) ?? [];
    return items.toSet();
  }

  Future<void> _addItemToTotalPlayed(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistTotal:$bundleId:items';
    final items = (prefs.getStringList(key) ?? []).toSet();
    items.add(fileName);
    await prefs.setStringList(key, items.toList());
  }

  // Playlist-level counters (count every play, including repeats)
  Future<int> _getSessionPlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistSession:$bundleId:count';
    return prefs.getInt(key) ?? 0;
  }

  Future<void> _incSessionPlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistSession:$bundleId:count';
    final cur = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, cur + 1);
  }

  Future<void> _decSessionPlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistSession:$bundleId:count';
    final cur = prefs.getInt(key) ?? 0;
    if (cur > 0) {
      await prefs.setInt(key, cur - 1);
    }
  }

  Future<int> _getTotalPlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistTotal:$bundleId:count';
    return prefs.getInt(key) ?? 0;
  }

  Future<void> _incTotalPlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistTotal:$bundleId:count';
    final cur = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, cur + 1);
  }

  Future<void> _decTotalPlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistTotal:$bundleId:count';
    final cur = prefs.getInt(key) ?? 0;
    if (cur > 0) {
      await prefs.setInt(key, cur - 1);
    }
  }

  // Reserve/release playlist counters around play sessions
  Future<void> _reservePlaylistCounters() async {
    if (_playlistCountersReserved) return;
    await _incSessionPlayCount();
    await _incTotalPlayCount();
    _playlistCountersReserved = true;
    _playlistReservationFulfilled = false;
  }

  Future<void> _releasePlaylistCountersIfUnfulfilled() async {
    if (_playlistCountersReserved && !_playlistReservationFulfilled) {
      await _decSessionPlayCount();
      await _decTotalPlayCount();
    }
    _playlistCountersReserved = false;
    _playlistReservationFulfilled = false;
  }

  Future<int?> _getLastItemPlayTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistLastItemPlay:$bundleId';
    return prefs.getInt(key);
  }

  Future<void> _updateLastItemPlayTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playlistLastItemPlay:$bundleId';
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _incrementPlaysUsed(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final key = 'playsUsed:$bundleId:$fileName';
    final totalKey = 'playsTotal:$bundleId:$fileName';
    final lastPlayKey = 'lastPlay:$bundleId:$fileName';

    // Ensure window
    final used = await _ensureWindowAndGetUsed(fileName);
    final current = used;
    await prefs.setInt(key, current + 1);

    // Increment total plays
    final currentTotal = prefs.getInt(totalKey) ?? 0;
    await prefs.setInt(totalKey, currentTotal + 1);

    // Update last play time
    await prefs.setInt(lastPlayKey, DateTime.now().millisecondsSinceEpoch);

    // Track playlist-level plays (unique sets and last-item time)
    await _addItemToSession(fileName);
    await _addItemToTotalPlayed(fileName);
    await _updateLastItemPlayTime();
  }

  Future<bool> _canPlayCurrent() async {
    final id = _currentMediaId;
    if (id == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';

    // Check for time tampering
    final lastKnownTimeKey = 'lastKnownTime';
    final lastKnownTimeMs = prefs.getInt(lastKnownTimeKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastKnownTimeMs != null && now < lastKnownTimeMs) {
      // Time went backward - possible tampering
      return false;
    }
    await prefs.setInt(lastKnownTimeKey, now);

    // Check bundle expiration
    final expirationDateStr = _bundleExpirationDate();
    if (expirationDateStr != null) {
      final expirationDate = DateTime.parse(expirationDateStr);
      if (DateTime.now().isAfter(expirationDate)) {
        return false;
      }
    }

    // === Playlist-level checks ===
    // Ensure session window
    await _ensurePlaylistSession();

    // Check playlist expiration
    final playlistExpirationStr = _playlistExpirationDate();
    if (playlistExpirationStr != null) {
      final playlistExpiration = DateTime.parse(playlistExpirationStr);
      if (DateTime.now().isAfter(playlistExpiration)) {
        return false;
      }
    }

    // Check total items played across lifetime (counting repeats)
    final maxTotalItems = _maxTotalItemsPlayed();
    if (maxTotalItems != null) {
      final totalCount = await _getTotalPlayCount();
      if (totalCount >= maxTotalItems) {
        return false;
      }
    }

    // Check minimum interval between playing different items
    final minIntervalBetweenItems = _minIntervalBetweenItemsMs();
    if (minIntervalBetweenItems != null && minIntervalBetweenItems > 0) {
      final lastItemPlayTime = await _getLastItemPlayTime();
      if (lastItemPlayTime != null) {
        final timeSinceLastItem = now - lastItemPlayTime;
        if (timeSinceLastItem < minIntervalBetweenItems) {
          return false;
        }
      }
    }

    // Check max items per session (counting repeats)
    final maxItems = _maxItemsPerSession();
    if (maxItems != null) {
      final sessionCount = await _getSessionPlayCount();
      if (sessionCount >= maxItems) {
        return false;
      }
    }

    // === Per-file checks ===
    // Check total plays limit
    final maxPlaysTotal = _maxPlaysTotalFor(id);
    if (maxPlaysTotal != null) {
      final totalKey = 'playsTotal:$bundleId:$id';
      final totalPlays = prefs.getInt(totalKey) ?? 0;
      if (totalPlays >= maxPlaysTotal) {
        return false;
      }
    }

    // Check minimum interval between plays
    final minIntervalMs = _minIntervalMsFor(id);
    if (minIntervalMs != null && minIntervalMs > 0) {
      final lastPlayKey = 'lastPlay:$bundleId:$id';
      final lastPlayMs = prefs.getInt(lastPlayKey);
      if (lastPlayMs != null) {
        final timeSinceLastPlay = now - lastPlayMs;
        if (timeSinceLastPlay < minIntervalMs) {
          return false;
        }
      }
    }

    // Check windowed plays limit
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
    final resetMs = _resetMsFor(fileName);
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
    final resetMs = _resetMsFor(fileName);
    final end = start + resetMs;
    final remainingMs = end - now;
    if (remainingMs <= 0) return Duration.zero;
    return Duration(milliseconds: remainingMs);
  }

  // Playlist-level remaining cooldown between items
  Future<Duration?> _remainingBetweenItems() async {
    final minIntervalBetweenItems = _minIntervalBetweenItemsMs();
    if (minIntervalBetweenItems == null || minIntervalBetweenItems <= 0) {
      return null;
    }
    final lastItemPlayTime = await _getLastItemPlayTime();
    if (lastItemPlayTime == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastItemPlayTime;
    final remain = minIntervalBetweenItems - elapsed;
    if (remain <= 0) return Duration.zero;
    return Duration(milliseconds: remain);
  }

  // Playlist-level remaining time until session reset
  Future<Duration?> _remainingSessionReset() async {
    final resetMs = _sessionResetIntervalMs();
    if (resetMs == null || resetMs <= 0) return null;
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';
    final sessionStartKey = 'playlistSession:$bundleId:start';
    final start = prefs.getInt(sessionStartKey);
    if (start == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final end = start + resetMs;
    final remain = end - now;
    if (remain <= 0) return Duration.zero;
    return Duration(milliseconds: remain);
  }

  Future<_PlayInfo> _getPlayInfo(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final bundleId = _bundleConfig != null
        ? (_bundleConfig!['bundleId'] ?? 'unknown')
        : 'unknown';

    // Check for permanent locks
    final lastKnownTimeKey = 'lastKnownTime';
    final lastKnownTimeMs = prefs.getInt(lastKnownTimeKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastKnownTimeMs != null && now < lastKnownTimeMs) {
      return _PlayInfo(0, 0, null, 0, 0, true, _t('lock_reason_time_tamper'));
    }

    final expirationDateStr = _bundleExpirationDate();
    if (expirationDateStr != null) {
      final expirationDate = DateTime.parse(expirationDateStr);
      if (DateTime.now().isAfter(expirationDate)) {
        return _PlayInfo(0, 0, null, 0, 0, true, _t('lock_reason_expired'));
      }
    }

    final used = await _ensureWindowAndGetUsed(fileName);
    final max = _maxPlaysFor(fileName);
    final rem = await _remainingBlockTime(fileName);

    final totalKey = 'playsTotal:$bundleId:$fileName';
    final totalPlays = prefs.getInt(totalKey) ?? 0;
    final maxTotal = _maxPlaysTotalFor(fileName);

    if (maxTotal != null && totalPlays >= maxTotal) {
      return _PlayInfo(
        used,
        max,
        rem,
        totalPlays,
        maxTotal,
        true,
        _t('lock_reason_lifetime_limit'),
      );
    }

    return _PlayInfo(used, max, rem, totalPlays, maxTotal, false, null);
  }

  void _startPlaySession() {
    if (_controller == null) return;
    // mark flags
    _sessionActive = true;
    _sessionCharged = false;
    _playChargeTimer?.cancel();
    // Reserve playlist counters at play start
    unawaited(_reservePlaylistCounters());
    // No auto-charge timer.
  }

  Future<void> _finalizePlaySession() async {
    _playChargeTimer?.cancel();
    if (_sessionActive) {
      final pos = _controller?.value.position ?? Duration.zero;
      final dur = _controller?.value.duration ?? Duration.zero;
      final name = _currentMediaId;
      final preview = name != null
          ? _freePreviewFor(name)
          : const Duration(seconds: 5);
      final meetsThreshold =
          pos >= preview ||
          (dur > Duration.zero &&
              pos >= dur - const Duration(milliseconds: 250));
      if (meetsThreshold && !_sessionCharged && _currentMediaId != null) {
        await _incrementPlaysUsed(_currentMediaId!);
        await _clearSavedPosition(_currentMediaId!);
      } else if (pos <= Duration.zero) {
        await _releasePlaylistCountersIfUnfulfilled();
      }
    }
    _sessionActive = false;
    _sessionCharged = false;
  }

  // ===== Position persistence & natural-end charging =====
  String _bundleIdOrUnknown() =>
      (_bundleConfig != null
          ? (_bundleConfig!['bundleId'] as String?)
          : null) ??
      'unknown';

  String? get _currentFileName => _currentMediaId;

  Future<void> _savePosition(String fileName, int posMs) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'pos:${_bundleIdOrUnknown()}:$fileName';
    await prefs.setInt(key, posMs);
  }

  Future<int> _loadSavedPositionMs(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'pos:${_bundleIdOrUnknown()}:$fileName';
    return prefs.getInt(key) ?? 0;
  }

  Future<void> _clearSavedPosition(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'pos:${_bundleIdOrUnknown()}:$fileName';
    await prefs.remove(key);
  }

  Future<void> _restoreSavedPosition() async {
    final c = _controller;
    final name = _currentFileName;
    if (c == null || name == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    final savedMs = await _loadSavedPositionMs(name);
    if (savedMs <= 0) return;
    final clamped = savedMs.clamp(0, dur.inMilliseconds - 1);
    if (clamped > 0) {
      await c.seekTo(Duration(milliseconds: clamped));
      _lastSavedPosMs = clamped;
    }
  }

  void _attachControllerListeners() {
    final c = _controller;
    if (c == null) return;
    c.addListener(() async {
      if (!mounted) return;
      final value = c.value;
      if (!value.isInitialized) return;
      final name = _currentFileName;
      if (name == null) return;
      final posMs = value.position.inMilliseconds;
      final dur = value.duration;
      final durMs = dur.inMilliseconds;
      final freeMs = _freePreviewFor(name).inMilliseconds;
      // Mark playlist reservation fulfilled on first forward progress
      if (_playlistCountersReserved && !_playlistReservationFulfilled) {
        final reachedThreshold =
            posMs >= freeMs || (dur > Duration.zero && posMs >= durMs - 250);
        if (reachedThreshold) {
          _playlistReservationFulfilled = true;
        }
      }
      // Persist position roughly every second of forward progress
      if (posMs - _lastSavedPosMs >= 1000) {
        _lastSavedPosMs = posMs;
        await _savePosition(name, posMs);
      }
      // Natural end detection: if at/near end and not yet charged for this session
      if (dur > Duration.zero) {
        final nearEnd =
            value.position >= dur - const Duration(milliseconds: 250);
        if (nearEnd && _sessionActive && !_sessionCharged) {
          await _incrementPlaysUsed(name);
          _sessionCharged = true;
          await _clearSavedPosition(name);
        }
      }
    });
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

  // ===== Conservative tar helpers (no full in-memory decode) =====
  Future<Uint8List?> _readTarEntryBytes(
    String tarPath,
    bool Function(String name) match,
  ) async {
    RandomAccessFile? raf;
    try {
      raf = await File(tarPath).open();
      while (true) {
        final header = await raf.read(512);
        if (header.isEmpty) break;
        final allZero = header.every((b) => b == 0);
        if (allZero) break; // end of archive

        String fieldToString(Uint8List bytes) {
          // Trim at first null and whitespace
          int end = bytes.length;
          for (int i = 0; i < bytes.length; i++) {
            if (bytes[i] == 0) {
              end = i;
              break;
            }
          }
          return ascii.decode(bytes.sublist(0, end)).trim();
        }

        final name = fieldToString(Uint8List.fromList(header.sublist(0, 100)));
        final sizeStr = fieldToString(
          Uint8List.fromList(header.sublist(124, 136)),
        );
        final typeflag = header[156];

        int size = 0;
        try {
          final cleaned = sizeStr.replaceAll(RegExp(r'[^0-7]'), '');
          if (cleaned.isNotEmpty) {
            size = int.parse(cleaned, radix: 8);
          }
        } catch (_) {
          size = 0;
        }

        final isFile = (typeflag == 0x30 /* '0' */ ) || (typeflag == 0);
        final blocks = (size + 511) ~/ 512;

        bool nameMatches(String n) {
          if (match(n)) return true;
          // Also try without leading './'
          if (n.startsWith('./') && match(n.substring(2))) return true;
          return false;
        }

        if (isFile) {
          if (nameMatches(name)) {
            // Read content bytes into memory (config is small)
            final out = BytesBuilder(copy: false);
            int remaining = size;
            const chunk = 64 * 1024;
            while (remaining > 0) {
              final toRead = remaining > chunk ? chunk : remaining;
              final data = await raf.read(toRead);
              if (data.isEmpty) break;
              out.add(data);
              remaining -= data.length;
            }
            // Skip padding
            final padding = (512 - (size % 512)) % 512;
            if (padding > 0) {
              await raf.read(padding);
            }
            return out.takeBytes();
          } else {
            // Skip file content + padding
            final skipBytes = blocks * 512;
            final currentPos = await raf.position();
            await raf.setPosition(currentPos + skipBytes);
          }
        } else {
          // Directory or other entry, no content; continue
        }
      }
    } catch (_) {
      return null;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
    return null;
  }

  Future<void> _extractTarEntries(
    String tarPath,
    Set<String> entryNames,
    String destRoot, {
    void Function(int wrote, int totalBytes, String currentName)? onProgress,
    bool Function()? isCancelled,
    int totalBytes = 0,
  }) async {
    if (entryNames.isEmpty) return;
    // Normalize names to also accept without leading './'
    final targets = <String>{...entryNames};
    for (final n in entryNames) {
      if (!n.startsWith('./')) targets.add('./$n');
    }
    RandomAccessFile? raf;
    try {
      raf = await File(tarPath).open();
      while (true) {
        if (isCancelled?.call() == true) {
          throw StateError('cancelled');
        }
        final header = await raf.read(512);
        if (header.isEmpty) break;
        final allZero = header.every((b) => b == 0);
        if (allZero) break;

        String fieldToString(Uint8List bytes) {
          int end = bytes.length;
          for (int i = 0; i < bytes.length; i++) {
            if (bytes[i] == 0) {
              end = i;
              break;
            }
          }
          return ascii.decode(bytes.sublist(0, end)).trim();
        }

        final name = fieldToString(Uint8List.fromList(header.sublist(0, 100)));
        final sizeStr = fieldToString(
          Uint8List.fromList(header.sublist(124, 136)),
        );
        final typeflag = header[156];

        int size = 0;
        try {
          final cleaned = sizeStr.replaceAll(RegExp(r'[^0-7]'), '');
          if (cleaned.isNotEmpty) size = int.parse(cleaned, radix: 8);
        } catch (_) {
          size = 0;
        }
        final blocks = (size + 511) ~/ 512;
        final isFile = (typeflag == 0x30 /* '0' */ ) || (typeflag == 0);

        bool shouldExtract(String n) => targets.contains(n);

        if (isFile && shouldExtract(name)) {
          final outPath = '$destRoot/$name';
          final parent = Directory(File(outPath).parent.path);
          if (!await parent.exists()) {
            await parent.create(recursive: true);
          }
          final outFile = await File(outPath).open(mode: FileMode.write);
          try {
            int remaining = size;
            const chunk = 128 * 1024;
            while (remaining > 0) {
              if (isCancelled?.call() == true) {
                throw StateError('cancelled');
              }
              final toRead = remaining > chunk ? chunk : remaining;
              final data = await raf.read(toRead);
              if (data.isEmpty) break;
              try {
                await outFile.writeFrom(data);
              } on FileSystemException catch (fe) {
                if (fe.osError?.errorCode == 28 ||
                    '${fe.osError}'.toLowerCase().contains('no space')) {
                  rethrow;
                }
                rethrow;
              }
              remaining -= data.length;
              if (onProgress != null) {
                onProgress(data.length, totalBytes, name);
              }
            }
          } finally {
            await outFile.close();
          }
          // Skip padding
          final padding = (512 - (size % 512)) % 512;
          if (padding > 0) {
            await raf.read(padding);
          }
        } else {
          // Skip content for non-target entries
          final skipBytes = blocks * 512;
          final current = await raf.position();
          await raf.setPosition(current + skipBytes);
        }
      }
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  Future<int> _estimateTarEntriesSize(
    String tarPath,
    Set<String> entryNames,
  ) async {
    if (entryNames.isEmpty) return 0;
    final targets = <String>{...entryNames};
    for (final n in entryNames) {
      if (!n.startsWith('./')) targets.add('./$n');
    }
    RandomAccessFile? raf;
    int total = 0;
    try {
      raf = await File(tarPath).open();
      while (true) {
        final header = await raf.read(512);
        if (header.isEmpty) break;
        final allZero = header.every((b) => b == 0);
        if (allZero) break;

        int end = 100;
        for (int i = 0; i < 100; i++) {
          if (header[i] == 0) {
            end = i;
            break;
          }
        }
        final name = ascii.decode(header.sublist(0, end)).trim();
        int end2 = 136;
        for (int i = 124; i < 136; i++) {
          if (header[i] == 0) {
            end2 = i;
            break;
          }
        }
        final sizeStr = ascii.decode(header.sublist(124, end2)).trim();
        int size = 0;
        try {
          final cleaned = sizeStr.replaceAll(RegExp(r'[^0-7]'), '');
          if (cleaned.isNotEmpty) size = int.parse(cleaned, radix: 8);
        } catch (_) {}
        final blocks = (size + 511) ~/ 512;
        if (targets.contains(name)) {
          total += size;
        }
        final current = await raf.position();
        await raf.setPosition(current + blocks * 512);
      }
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
    return total;
  }

  // Legacy duration formatter removed in favor of localized _fmtDur

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
    // No auto-charge on startup; position will be restored instead
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
      // No pending timers to re-arm.
      if (!mounted) return;
      setState(() => _status = _t('loaded_last_played'));
    }
  }

  @override
  void dispose() {
    _finalizePlaySession();
    _controller?.dispose();
    _intentDataStreamSubscription.cancel();
    _uiTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = (_myAppKey.currentState?._locale);
    String t(String k) =>
        L10n.t(k, loc, _myAppKey.currentState?._custom ?? const {});
    // Auto-enter fullscreen if user rotates device to landscape while a video is selected
    try {
      final ori = MediaQuery.of(context).orientation;
      final isLandscape = ori == Orientation.landscape;
      // Clear any suppression once we observe portrait again
      if (ori == Orientation.portrait && _suppressAutoFullscreenUntilPortrait) {
        _suppressAutoFullscreenUntilPortrait = false;
      }
      final now = DateTime.now();
      final recentlyTriggered =
          _lastFullscreenTriggerAt != null &&
          now.difference(_lastFullscreenTriggerAt!).inMilliseconds < 800;
      if (isLandscape &&
          _isCurrentVideo &&
          _controller?.value.isInitialized == true &&
          !_inFullscreen &&
          _autoFullscreenOnRotate &&
          !_suppressAutoFullscreenUntilPortrait &&
          !recentlyTriggered) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_inFullscreen) return;
          // Record the trigger time to avoid rapid re-entry loops
          _lastFullscreenTriggerAt = DateTime.now();
          _goFullscreen(explicitEntry: false, initialOrientation: ori);
        });
      }
    } catch (_) {}
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(t('device_id')),
                content: SelectableText(_deviceId),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(t('close')),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: t('language_settings_title'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LanguageSettingsPage()),
              );
              // After changing language, relocalize initial status if shown
              await _loadAutoFullscreenPref();
              setState(() {
                _relocalizeStatusIfInitial();
              });
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Tooltip(
                key: _warningTooltipKey,
                message: _t('ui_demo_warning'),
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 6),
                waitDuration: const Duration(milliseconds: 0),
                preferBelow: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      _warningTooltipKey.currentState?.ensureTooltipVisible(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _t('ui_demo_warning'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _warningTooltipKey.currentState
                              ?.ensureTooltipVisible(),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: Colors.black54,
                              semanticLabel: 'Show full message',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(child: Text(_status)),
            if (_importInProgress) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      value: _importProgress > 0 && _importProgress <= 1.0
                          ? _importProgress
                          : null,
                    ),
                    if (_importLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _importLabel!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_bundleConfig != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _t('ui_media_label', {
                    'name': '${_bundleConfig!['mediaFile'] ?? ''}',
                  }),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Playlist-level live indicators (cooldowns, session usage)
            if (_bundleConfig != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cooldown between items
                    FutureBuilder<Duration?>(
                      future: _remainingBetweenItems(),
                      builder: (context, snap) {
                        final rem = snap.data;
                        if (rem == null || rem <= Duration.zero) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          _t('status_must_wait', {'duration': _fmtDur(rem)}),
                        );
                      },
                    ),
                    // Session usage and reset timer
                    if (_maxItemsPerSession() != null) ...[
                      const SizedBox(height: 2),
                      FutureBuilder<int>(
                        future: _getSessionPlayCount(),
                        builder: (context, snap) {
                          final used = snap.data ?? 0;
                          final max = _maxItemsPerSession()!;
                          return FutureBuilder<Duration?>(
                            future: _remainingSessionReset(),
                            builder: (context, s2) {
                              final rem = s2.data;
                              final resetStr =
                                  (rem != null && rem > Duration.zero)
                                  ? _t('ui_resets_in', {
                                      'duration': _fmtDur(rem),
                                    })
                                  : '';
                              final base = _t('ui_session_usage', {
                                'used': '$used',
                                'max': '$max',
                              });
                              return Text('$base$resetStr');
                            },
                          );
                        },
                      ),
                    ],
                    // Lifetime total usage
                    if (_maxTotalItemsPlayed() != null) ...[
                      const SizedBox(height: 2),
                      FutureBuilder<int>(
                        future: _getTotalPlayCount(),
                        builder: (context, snap) {
                          final used = snap.data ?? 0;
                          final max = _maxTotalItemsPlayed()!;
                          return Text(
                            _t('ui_total_usage', {
                              'used': '$used',
                              'max': '$max',
                            }),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

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
                                    : _t('audio'),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Seek bar (scrubber) - forward-only (no backward scrubbing)
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
                            // clamp backward scrubs to current position
                            final currentMs = position.inMilliseconds;
                            final target = v < currentMs
                                ? currentMs.toDouble()
                                : v;
                            await _controller!.seekTo(
                              Duration(milliseconds: target.toInt()),
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
                              tooltip: t('play'),
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () async {
                                if (!await _canPlayCurrent()) {
                                  await _attemptAutoPlay(); // Will set proper error message
                                  return;
                                }
                                if (!mounted) return;
                                final name = _currentMediaId;
                                if (name == null) return;
                                final info = await _getPlayInfo(name);
                                if (!mounted) return;
                                final previewSec = _freePreviewFor(
                                  name,
                                ).inSeconds;
                                final windowLeft = (info.max == null)
                                    ? null
                                    : (info.max! - info.used).clamp(
                                        0,
                                        info.max!,
                                      );
                                final lifetimeLeft = (info.maxTotal == null)
                                    ? null
                                    : (info.maxTotal! - info.totalPlays!).clamp(
                                        0,
                                        info.maxTotal!,
                                      );
                                // ignore: use_build_context_synchronously
                                final confirmed =
                                    await showDialog<bool>(
                                      // ignore: use_build_context_synchronously
                                      context: context,
                                      builder: (ctx) {
                                        String line1;
                                        if (windowLeft != null &&
                                            info.max != null) {
                                          line1 = _t('confirm_window_left', {
                                            'left': '$windowLeft',
                                            'max': '${info.max!}',
                                          });
                                        } else {
                                          line1 = _t(
                                            'confirm_window_unlimited',
                                          );
                                        }
                                        String line2;
                                        if (lifetimeLeft != null &&
                                            info.maxTotal != null) {
                                          line2 = _t('confirm_lifetime_left', {
                                            'left': '$lifetimeLeft',
                                            'max': '${info.maxTotal!}',
                                          });
                                        } else {
                                          line2 = _t(
                                            'confirm_lifetime_unlimited',
                                          );
                                        }
                                        final line3 = _t(
                                          'confirm_preview_free',
                                          {'seconds': '$previewSec'},
                                        );
                                        return AlertDialog(
                                          title: Text(_t('confirm_play_title')),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(line1),
                                              const SizedBox(height: 4),
                                              Text(line2),
                                              const SizedBox(height: 8),
                                              Text(line3),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: Text(_t('cancel')),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: Text(_t('start_playback')),
                                            ),
                                          ],
                                        );
                                      },
                                    ) ??
                                    false;
                                if (!confirmed) return;
                                _startPlaySession();
                                _controller!.play();
                                setState(() {});
                              },
                            ),
                            IconButton(
                              tooltip: t('pause'),
                              icon: const Icon(Icons.pause),
                              onPressed: () {
                                _controller!.pause();
                                setState(() {});
                              },
                            ),
                            IconButton(
                              tooltip: t('stop'),
                              icon: const Icon(Icons.stop),
                              onPressed: () async {
                                await _stopAndCharge();
                                setState(() {});
                              },
                            ),
                            if (_isCurrentVideo) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: t('fullscreen'),
                                icon: const Icon(Icons.fullscreen),
                                onPressed: () {
                                  final ori = MediaQuery.of(
                                    context,
                                  ).orientation;
                                  _goFullscreen(
                                    explicitEntry: true,
                                    initialOrientation: ori,
                                  );
                                },
                              ),
                            ],
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
                  ? Center(child: Text(t('no_decrypted_media_yet')))
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
                              if (info.isPermanentlyLocked) {
                                trailing = const Icon(
                                  Icons.lock,
                                  color: Colors.redAccent,
                                );
                                subtitle = _t('ui_locked_reason', {
                                  'reason': info.lockReason ?? '',
                                });
                              } else if (info.max == null) {
                                subtitle = _t('ui_no_play_limit');
                                trailing = const SizedBox.shrink();
                              } else {
                                final left = (info.max! - info.used).clamp(
                                  0,
                                  info.max!,
                                );
                                String totalInfo = '';
                                if (info.maxTotal != null) {
                                  final totalLeft =
                                      (info.maxTotal! - info.totalPlays!).clamp(
                                        0,
                                        info.maxTotal!,
                                      );
                                  totalInfo =
                                      ' · $totalLeft / ${info.maxTotal}${_t('ui_total_suffix')}';
                                }

                                if (left > 0) {
                                  final resetStr =
                                      (info.remaining != null &&
                                          info.remaining! > Duration.zero)
                                      ? _t('ui_resets_in', {
                                          'duration': _fmtDur(info.remaining!),
                                        })
                                      : '';
                                  subtitle =
                                      '$left / ${info.max}${_t('ui_plays_left')}$resetStr$totalInfo';
                                  trailing = const SizedBox.shrink();
                                } else {
                                  final resetStr =
                                      (info.remaining != null &&
                                          info.remaining! > Duration.zero)
                                      ? _t('ui_resets_in', {
                                          'duration': _fmtDur(info.remaining!),
                                        })
                                      : '';
                                  subtitle = _t('ui_blocked') + resetStr;
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
                              onTap: () =>
                                  _initializePlayer(file.path, autoPlay: false),
                              trailing: trailing,
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
        tooltip: t('import_bundle'),
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

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final bool explicitEntry;
  final Orientation initialOrientation;
  const _FullscreenVideoPage({
    required this.controller,
    required this.explicitEntry,
    required this.initialOrientation,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _exiting = false;
  Timer? _exitTimer;

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    // If device rotates back to portrait, schedule a graceful exit.
    try {
      final ori = MediaQuery.of(context).orientation;
      final shouldAutoExitOnPortrait =
          !widget.explicitEntry ||
          (widget.explicitEntry &&
              widget.initialOrientation == Orientation.landscape);
      if (shouldAutoExitOnPortrait) {
        if (ori == Orientation.portrait && !_exiting) {
          _exitTimer?.cancel();
          _exitTimer = Timer(const Duration(milliseconds: 300), () {
            if (!mounted || _exiting) return;
            final nowOri = MediaQuery.of(context).orientation;
            if (nowOri == Orientation.portrait) {
              _exiting = true;
              Navigator.of(context).maybePop();
            }
          });
        } else if (ori == Orientation.landscape) {
          // Cancel any pending exit if user rotated back to landscape quickly.
          _exitTimer?.cancel();
        }
      } else {
        // Explicit portrait fullscreen: never auto-exit based on orientation.
        _exitTimer?.cancel();
      }
    } catch (_) {}
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: c.value.isInitialized && c.value.aspectRatio > 0
                    ? c.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(c),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (context, value, _) {
                    final isPlaying = value.isPlaying;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_circle : Icons.play_circle,
                            color: Colors.white,
                            size: 36,
                          ),
                          onPressed: () async {
                            if (isPlaying) {
                              await c.pause();
                            } else {
                              await c.play();
                            }
                            setState(() {});
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String? _selectedCode;
  Map<String, Map<String, String>> _custom = {};
  bool _verboseImportLogs = false;
  String? _lastLogPath;
  bool _autoFullscreenOnRotate = true;
  bool _allowLandscapeInApp = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCode = prefs.getString('uiLocaleCode');
      final raw = prefs.getString('customTranslationsJson');
      if (raw != null && raw.isNotEmpty) {
        try {
          final obj = json.decode(raw) as Map<String, dynamic>;
          _custom = obj.map(
            (k, v) => MapEntry(
              k,
              Map<String, String>.from((v as Map).cast<String, String>()),
            ),
          );
        } catch (_) {}
      }
      _verboseImportLogs = prefs.getBool('verboseImportLogs') ?? false;
      _lastLogPath = prefs.getString('lastImportLogPath');
      _autoFullscreenOnRotate = prefs.getBool('autoFullscreenOnRotate') ?? true;
      _allowLandscapeInApp = prefs.getBool('allowLandscapeInApp') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = (_myAppKey.currentState?._locale);
    String t(String k) =>
        L10n.t(k, loc, _myAppKey.currentState?._custom ?? const {});
    final items = const [
      ['en', 'English'],
      ['es', 'Español'],
      ['fr', 'Français'],
      ['nl', 'Nederlands'],
      ['de', 'Deutsch'],
      ['af', 'Afrikaans'],
      ['pt', 'Português'],
      ['id', 'Bahasa Indonesia'],
      ['ru', 'Русский'],
      ['hi', 'हिन्दी'],
      ['ar', 'العربية'],
      ['zh', '中文'],
      ['tpi', 'Tok Pisin'],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t('language_settings_title'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(t('system_default')),
            leading: Icon(
              _selectedCode == null
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            onTap: () {
              setState(() => _selectedCode = null);
              _myAppKey.currentState?.setLocaleCode(null);
            },
          ),
          const Divider(height: 1),
          for (final it in items)
            ListTile(
              title: Text(it[1]),
              leading: Icon(
                _selectedCode == it[0]
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              onTap: () {
                setState(() => _selectedCode = it[0]);
                _myAppKey.currentState?.setLocaleCode(it[0]);
              },
            ),
          const Divider(height: 16),
          // Orientation settings
          SwitchListTile(
            title: Text(t('allow_landscape')),
            subtitle: Text(t('allow_landscape_desc')),
            value: _allowLandscapeInApp,
            onChanged: (v) async {
              setState(() => _allowLandscapeInApp = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('allowLandscapeInApp', v);
              try {
                if (v) {
                  await services.SystemChrome.setPreferredOrientations(const [
                    services.DeviceOrientation.portraitUp,
                    services.DeviceOrientation.landscapeLeft,
                    services.DeviceOrientation.landscapeRight,
                  ]);
                } else {
                  await services.SystemChrome.setPreferredOrientations(const [
                    services.DeviceOrientation.portraitUp,
                  ]);
                }
              } catch (_) {}
            },
          ),
          const Divider(height: 16),
          ListTile(
            title: Text(t('custom_translations')),
            subtitle: Text(
              _custom.isEmpty
                  ? '-'
                  : _custom.keys
                        .map((k) => '$k(${_custom[k]!.length})')
                        .join(', '),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(t('add_custom_translations')),
                  onPressed: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                      );
                      if (result != null && result.files.single.path != null) {
                        final p = result.files.single.path!;
                        final txt = await File(p).readAsString();
                        final parsed = json.decode(txt);
                        final normalized = <String, Map<String, String>>{};
                        if (parsed is Map) {
                          final map = Map<String, dynamic>.from(
                            parsed.cast<String, dynamic>(),
                          );
                          final isFlat = map.values.every((v) => v is String);
                          if (isFlat) {
                            final code = _selectedCode ?? 'en';
                            normalized[code] = map.map(
                              (k, v) => MapEntry(k, (v as String)),
                            );
                          } else {
                            for (final entry in map.entries) {
                              final loc = entry.key;
                              if (entry.value is Map) {
                                final inner = Map<String, dynamic>.from(
                                  (entry.value as Map).cast<String, dynamic>(),
                                );
                                normalized[loc] = inner.map(
                                  (k, v) => MapEntry(k, (v as String)),
                                );
                              }
                            }
                          }
                        }
                        final merged = Map<String, Map<String, String>>.from(
                          _myAppKey.currentState?._custom ?? {},
                        );
                        for (final e in normalized.entries) {
                          merged[e.key] = {...?merged[e.key], ...e.value};
                        }
                        _myAppKey.currentState?.updateCustomTranslations(
                          merged,
                        );
                        setState(() => _custom = merged);
                      }
                    } catch (_) {}
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(t('remove_custom_translations')),
                  onPressed: () async {
                    _myAppKey.currentState?.updateCustomTranslations({});
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('customTranslationsJson');
                    setState(() => _custom = {});
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          // Diagnostics section
          ListTile(
            title: Text(t('import_diagnostics')),
            subtitle: Text(t('import_diagnostics_subtitle')),
          ),
          // Playback behavior section
          SwitchListTile(
            title: Text(t('auto_fullscreen_on_rotate')),
            subtitle: Text(t('auto_fullscreen_on_rotate_desc')),
            value: _autoFullscreenOnRotate,
            onChanged: (v) async {
              setState(() => _autoFullscreenOnRotate = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('autoFullscreenOnRotate', v);
            },
          ),
          SwitchListTile(
            title: Text(t('verbose_import_logs')),
            value: _verboseImportLogs,
            onChanged: (v) async {
              setState(() => _verboseImportLogs = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('verboseImportLogs', v);
            },
          ),
          ListTile(
            title: Text(t('view_last_import_log')),
            subtitle: Text(_lastLogPath ?? '-'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (_lastLogPath == null) return;
              try {
                final f = File(_lastLogPath!);
                if (!await f.exists()) return;
                final txt = await f.readAsString();
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t('last_import_log')),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(child: SelectableText(txt)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: txt));
                          Navigator.of(ctx).pop();
                        },
                        child: Text(t('copy')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(t('close')),
                      ),
                    ],
                  ),
                );
              } catch (_) {}
            },
          ),
          ListTile(
            title: Text(t('clear_logs')),
            onTap: () async {
              try {
                final docs = await getApplicationDocumentsDirectory();
                final dir = Directory('${docs.path}/logs');
                if (await dir.exists()) {
                  await dir.delete(recursive: true);
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('lastImportLogPath');
                setState(() => _lastLogPath = null);
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }
}
