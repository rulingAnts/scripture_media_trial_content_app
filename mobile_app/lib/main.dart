import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:video_player/video_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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
        setState(() {
          _custom = normalized;
        });
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
  // Track last saved position (ms) to throttle persistence
  int _lastSavedPosMs = 0;
  // Stream subscriptions for receiving shared files
  late StreamSubscription<List<SharedMediaFile>> _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _getDeviceId();
    _loadLastPlayed();
    _initReceiveSharingIntent();
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
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleSharedFile(value.first.path);
        }
      },
      onError: (err) {
        // Handle error
      },
    );

    // For sharing via share menu or opening from another app while app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
        // Clear the initial shared file to prevent re-processing
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  Future<void> _handleSharedFile(String filePath) async {
    if (!filePath.toLowerCase().endsWith('.smbundle')) {
      setState(() => _status = _t('status_select_smbundle'));
      return;
    }
    // Process the bundle using the existing logic
    await _processBundle(filePath);
  }

  Future<void> _pickAndProcessBundle() async {
    setState(() {
      _isLoading = true;
      _status = _t('status_picking_file');
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
    });
    try {
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
            setState(() => _status = _t('error_open_bundle_config'));
            return;
          }
          config = json.decode(utf8.decode(decrypted)) as Map<String, dynamic>;
          // Do not assign to _bundleConfig here; finalize only after policy checks pass
        } catch (e) {
          await _deleteDirectory(Directory(extractionPath));
          setState(() => _status = _t('error_open_bundle_config'));
          return;
        }
      } else {
        await _deleteDirectory(Directory(extractionPath));
        setState(() => _status = _t('error_missing_bundle_config'));
        return;
      }

      // Enforce allowedDeviceIds before any media processing
      try {
        final allowed =
            (config['allowedDeviceIds'] as List?)?.cast<String>() ?? <String>[];
        if (allowed.isEmpty || !allowed.contains(_deviceId)) {
          await _deleteDirectory(Directory(extractionPath));
          setState(() => _status = _t('error_device_not_authorized'));
          return;
        }
        setState(() => _status = _t('status_config_verified'));
      } catch (e) {
        await _deleteDirectory(Directory(extractionPath));
        setState(() => _status = _t('error_invalid_bundle_config'));
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

      // Decrypt media based on config mapping so filenames match original fileName
      setState(() => _status = _t('status_decrypting_media'));
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _t('status_error_generic', {'message': '$e'}));
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
        // Attach listeners for position persistence and natural-end charging
        _attachControllerListeners();
        // Restore last saved position, if any (forward-only scrubbing still enforced)
        _restoreSavedPosition();
        setState(() {});
        _attemptAutoPlay();
      });
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
    final hadProgress = c.value.position > Duration.zero;
    if (hadProgress && _currentMediaId != null) {
      await _incrementPlaysUsed(_currentMediaId!);
      _sessionCharged = true;
      await _clearSavedPosition(_currentMediaId!);
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
    // No auto-charge timer.
  }

  Future<void> _finalizePlaySession() async {
    _playChargeTimer?.cancel();
    if (_sessionActive) {
      final hadProgress =
          (_controller?.value.position ?? Duration.zero) > Duration.zero;
      if (hadProgress && !_sessionCharged && _currentMediaId != null) {
        await _incrementPlaysUsed(_currentMediaId!);
        await _clearSavedPosition(_currentMediaId!);
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
      // Persist position roughly every second of forward progress
      if (posMs - _lastSavedPosMs >= 1000) {
        _lastSavedPosMs = posMs;
        await _savePosition(name, posMs);
      }
      // Natural end detection: if at/near end and not yet charged for this session
      final dur = value.duration;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = (_myAppKey.currentState?._locale);
    String t(String k) =>
        L10n.t(k, loc, _myAppKey.currentState?._custom ?? const {});
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
            const SizedBox(height: 16),
            Center(child: Text(_status)),
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
                                  trailing = IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () =>
                                        _initializePlayer(file.path),
                                  );
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

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String? _selectedCode;
  Map<String, Map<String, String>> _custom = {};

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
        ],
      ),
    );
  }
}
