const { ipcRenderer } = require('electron');

// --- i18n: simple localization system (renderer only) ---
const SUPPORTED_LOCALES = ['en','es','fr','nl','af','de','pt','id','ru','hi','ar','zh','tpi'];
const LOCALE_STORAGE_KEY = 'uiLocaleCode';

const i18n = {
  strings: {
    en: {
      app_title: 'Scripture Media Bundler',
      app_subtitle: 'Create secure media bundles for authorized devices',
      language_settings_title: 'Language',
      system_default: 'System default',
      section_bundle_config: 'Bundle Configuration',
      label_bundle_name: 'Bundle Name *',
      placeholder_bundle_name: 'e.g., Luke_Gospel_Trial',
      label_device_ids: 'Authorized Device IDs * (one per line)',
      placeholder_device_ids: 'Enter device IDs, one per line',
      section_playback_limits: 'Playback Limits',
      label_max_plays: 'Maximum Plays per Reset Period *',
      help_max_plays: 'Number of times media can be played before waiting for reset',
      label_free_preview: 'Free Preview Seconds',
      help_free_preview: 'How many seconds users can play before a play is charged (0 to disable)',
      label_reset_interval: 'Reset Interval *',
      label_days: 'Days',
      label_hours: 'Hours',
      label_minutes: 'Minutes',
      label_min_interval_between_plays: 'Minimum Interval Between Plays (Optional)',
      help_min_interval_between_plays: 'Required waiting time between each play (leave at 0 for no minimum)',
      label_max_plays_total: 'Maximum Total Plays Ever (Optional)',
      placeholder_no_limit: 'Leave empty for no limit',
      help_max_plays_total: 'Absolute lifetime limit - media becomes permanently locked after this many plays',
      label_expiration: 'Bundle Expiration Date & Time (Optional)',
      help_expiration: 'Bundle becomes permanently locked after this date/time',
      section_playlist_limits: 'Playlist-Level Limits (Optional)',
      paragraph_playlist_limits: 'These limits apply to the entire playlist, controlling overall usage across all files.',
      label_playlist_max_items_session: 'Max Items Per Session (Optional)',
      help_playlist_max_items_session: 'Maximum number of unique files that can be played within a session',
  label_session_reset_interval: 'Session Reset Interval (Optional)',
  help_playlist_session_reset: 'How long until the session resets and users can play new items (leave at 0 for no reset)',
      label_playlist_min_interval_between_items: 'Minimum Interval Between Items (Optional)',
      help_playlist_min_interval_between_items: 'Required waiting time between playing different files (leave at 0 for no minimum)',
      label_playlist_max_total_items: 'Maximum Total Items Played Ever (Optional)',
      help_playlist_max_total_items: 'Absolute lifetime limit on unique files - playlist becomes permanently locked after this many unique files are played',
      label_playlist_expiration: 'Playlist Expiration Date & Time (Optional)',
      help_playlist_expiration: 'Playlist becomes permanently locked after this date/time (can differ from bundle expiration)',
      section_media_files: 'Media Files',
      button_add_media: 'Add Media Files',
      empty_no_media: 'No media files added yet',
      loading_creating_bundle: 'Creating bundle...',
      button_create_bundle: 'Create Bundle',
      button_reset_settings: 'Reset Settings',
      tooltip_reset_settings: 'Reset all settings to defaults',
      button_reset_form: 'Clear Files & Name',
      tooltip_reset_form: 'Clear selected files and bundle name only',
      device_id_badge: 'Device ID',
      details_max_plays: 'Max plays',
      details_reset: 'Reset',
      details_interval: 'Interval',
      details_none: 'None',
      details_max_total_prefix: 'Max total:',
      details_no_lifetime_limit: 'No lifetime limit',
      details_free_preview_prefix: 'Free preview:',
      remove: 'Remove',
      err_failed_add_media_prefix: 'Failed to add media files: ',
      err_max_items_session_min: 'Max items per session must be at least 1',
      err_max_total_items_min: 'Max total items played must be at least 1',
      err_invalid_playlist_expiration: 'Invalid playlist expiration date',
      err_please_enter_bundle_name: 'Please enter a bundle name',
      err_please_enter_device_id: 'Please enter at least one device ID',
      err_please_add_media: 'Please add at least one media file',
      err_max_plays_at_least: 'Maximum plays must be at least 1',
      err_reset_interval_min: 'Reset interval must be at least 1 minute',
      err_expiration_future: 'Expiration date must be in the future',
      success_title: 'Success!',
      error_title: 'Error!',
      bundle_created_title: 'Bundle created successfully!',
      location: 'Location:',
      bundle_id: 'Bundle ID:',
      files_processed: 'Files processed:',
      archive: 'Archive:',
      transfer_line1: 'You can now transfer this secure .smbundle file to authorized devices.',
      transfer_line2: 'The bundle is protected and compressed for security.',
      failed_create_prefix: 'Failed to create bundle: ',
      ok: 'OK'
    }
  }
};

// Additional locales
i18n.strings.es = {
  app_title: 'Empaquetador de Medios de Escrituras',
  app_subtitle: 'Crea paquetes de medios seguros para dispositivos autorizados',
  language_settings_title: 'Idioma',
  system_default: 'Predeterminado del sistema',
  section_bundle_config: 'Configuración del paquete',
  label_bundle_name: 'Nombre del paquete *',
  placeholder_bundle_name: 'p. ej., Luke_Gospel_Trial',
  label_device_ids: 'ID de dispositivos autorizados * (uno por línea)',
  placeholder_device_ids: 'Ingresa IDs de dispositivo, uno por línea',
  section_playback_limits: 'Límites de reproducción',
  label_max_plays: 'Reproducciones máximas por período de reinicio *',
  help_max_plays: 'Número de veces que se puede reproducir antes de esperar al reinicio',
  label_free_preview: 'Segundos de vista previa gratuita',
  help_free_preview: 'Cuántos segundos pueden reproducir antes de cobrar (0 para desactivar)',
  label_reset_interval: 'Intervalo de reinicio *',
  label_days: 'Días',
  label_hours: 'Horas',
  label_minutes: 'Minutos',
  label_min_interval_between_plays: 'Intervalo mínimo entre reproducciones (Opcional)',
  help_min_interval_between_plays: 'Tiempo de espera requerido entre cada reproducción (0 para sin mínimo)',
  label_max_plays_total: 'Máximo total de reproducciones (Opcional)',
  placeholder_no_limit: 'Dejar vacío para sin límite',
  help_max_plays_total: 'Límite de por vida: el medio queda bloqueado permanentemente después de tantas reproducciones',
  label_expiration: 'Fecha y hora de expiración del paquete (Opcional)',
  help_expiration: 'El paquete queda bloqueado permanentemente después de esta fecha/hora',
  section_playlist_limits: 'Límites a nivel de lista (Opcional)',
  paragraph_playlist_limits: 'Estos límites se aplican a toda la lista, controlando el uso general en todos los archivos.',
  label_playlist_max_items_session: 'Máx. elementos por sesión (Opcional)',
  help_playlist_max_items_session: 'Número máximo de archivos únicos que se pueden reproducir en una sesión',
  label_session_reset_interval: 'Intervalo de reinicio de sesión (Opcional)',
  help_playlist_session_reset: 'Tiempo hasta que la sesión se reinicia y los usuarios pueden reproducir nuevos elementos (dejar en 0 para no reiniciar)',
  label_playlist_min_interval_between_items: 'Intervalo mínimo entre elementos (Opcional)',
  help_playlist_min_interval_between_items: 'Tiempo de espera requerido entre reproducir archivos diferentes (0 para sin mínimo)',
  label_playlist_max_total_items: 'Máximo total de elementos reproducidos (Opcional)',
  help_playlist_max_total_items: 'Límite de por vida de archivos únicos — la lista se bloquea permanentemente después de alcanzar este número',
  label_playlist_expiration: 'Fecha y hora de expiración de la lista (Opcional)',
  help_playlist_expiration: 'La lista queda bloqueada permanentemente después de esta fecha/hora (puede diferir de la expiración del paquete)',
  section_media_files: 'Archivos multimedia',
  button_add_media: 'Agregar archivos multimedia',
  empty_no_media: 'Aún no se agregaron archivos',
  loading_creating_bundle: 'Creando paquete...',
  button_create_bundle: 'Crear paquete',
  button_reset_settings: 'Restablecer ajustes',
  tooltip_reset_settings: 'Restablecer todos los ajustes a los valores predeterminados',
  button_reset_form: 'Borrar archivos y nombre',
  tooltip_reset_form: 'Borrar solo archivos seleccionados y nombre del paquete',
  device_id_badge: 'ID del dispositivo',
  details_max_plays: 'Reprods. máx.',
  details_reset: 'Reinicio',
  details_interval: 'Intervalo',
  details_none: 'Ninguno',
  details_max_total_prefix: 'Máx. total:',
  details_no_lifetime_limit: 'Sin límite de por vida',
  details_free_preview_prefix: 'Vista previa:',
  remove: 'Quitar',
  err_failed_add_media_prefix: 'Error al agregar archivos: ',
  err_max_items_session_min: 'Los elementos por sesión deben ser al menos 1',
  err_max_total_items_min: 'El total de elementos reproducidos debe ser al menos 1',
  err_invalid_playlist_expiration: 'Fecha de expiración de lista no válida',
  err_please_enter_bundle_name: 'Ingresa un nombre de paquete',
  err_please_enter_device_id: 'Ingresa al menos un ID de dispositivo',
  err_please_add_media: 'Agrega al menos un archivo multimedia',
  err_max_plays_at_least: 'Las reproducciones máximas deben ser al menos 1',
  err_reset_interval_min: 'El intervalo de reinicio debe ser al menos 1 minuto',
  err_expiration_future: 'La fecha de expiración debe estar en el futuro',
  success_title: '¡Éxito!',
  error_title: '¡Error!',
  bundle_created_title: '¡Paquete creado exitosamente!',
  location: 'Ubicación:',
  bundle_id: 'ID del paquete:',
  files_processed: 'Archivos procesados:',
  archive: 'Archivo:',
  transfer_line1: 'Ahora puedes transferir este archivo .smbundle seguro a dispositivos autorizados.',
  transfer_line2: 'El paquete está protegido y comprimido por seguridad.',
  failed_create_prefix: 'Error al crear el paquete: ',
  ok: 'Aceptar'
};

i18n.strings.fr = {
  app_title: 'Assembleur de médias des Écritures',
  app_subtitle: 'Créez des lots sécurisés pour des appareils autorisés',
  language_settings_title: 'Langue',
  system_default: 'Langue du système',
  section_bundle_config: 'Configuration du lot',
  label_bundle_name: 'Nom du lot *',
  placeholder_bundle_name: 'ex. : Luke_Gospel_Trial',
  label_device_ids: 'ID d’appareils autorisés * (un par ligne)',
  placeholder_device_ids: 'Saisir des ID d’appareil, un par ligne',
  section_playback_limits: 'Limites de lecture',
  label_max_plays: 'Lectures max par période de réinitialisation *',
  help_max_plays: 'Nombre de lectures avant d’attendre la réinitialisation',
  label_free_preview: 'Secondes d’aperçu gratuit',
  help_free_preview: 'Nombre de secondes gratuites avant facturation (0 pour désactiver)',
  label_reset_interval: 'Intervalle de réinitialisation *',
  label_days: 'Jours',
  label_hours: 'Heures',
  label_minutes: 'Minutes',
  label_min_interval_between_plays: 'Intervalle minimum entre lectures (Optionnel)',
  help_min_interval_between_plays: 'Temps d’attente entre chaque lecture (0 pour aucun minimum)',
  label_max_plays_total: 'Nombre total de lectures à vie (Optionnel)',
  placeholder_no_limit: 'Laisser vide pour aucun',
  help_max_plays_total: 'Limite à vie — le média est verrouillé définitivement après ce nombre',
  label_expiration: 'Date et heure d’expiration du lot (Optionnel)',
  help_expiration: 'Le lot est verrouillé définitivement après cette date/heure',
  section_playlist_limits: 'Limites au niveau de la liste (Optionnel)',
  paragraph_playlist_limits: 'Ces limites s’appliquent à toute la liste et contrôlent l’utilisation globale sur tous les fichiers.',
  label_playlist_max_items_session: 'Éléments max par session (Optionnel)',
  help_playlist_max_items_session: 'Nombre maximum de fichiers uniques pouvant être lus dans une session',
  label_session_reset_interval: 'Intervalle de réinitialisation de session (Optionnel)',
  help_playlist_session_reset: 'Délai avant la réinitialisation de la session et la possibilité de lire de nouveaux éléments (laisser à 0 pour aucune réinitialisation)',
  label_playlist_min_interval_between_items: 'Intervalle minimum entre éléments (Optionnel)',
  help_playlist_min_interval_between_items: 'Temps d’attente requis entre la lecture de fichiers différents (0 pour aucun minimum)',
  label_playlist_max_total_items: 'Nombre total d’éléments lus (Optionnel)',
  help_playlist_max_total_items: 'Limite à vie d’éléments uniques — la liste est verrouillée définitivement après l’atteinte de ce nombre',
  label_playlist_expiration: 'Date et heure d’expiration de la liste (Optionnel)',
  help_playlist_expiration: 'La liste est verrouillée définitivement après cette date/heure (peut différer de l’expiration du lot)',
  section_media_files: 'Fichiers médias',
  button_add_media: 'Ajouter des fichiers médias',
  empty_no_media: 'Aucun fichier ajouté pour le moment',
  loading_creating_bundle: 'Création du lot…',
  button_create_bundle: 'Créer le lot',
  button_reset_settings: 'Réinitialiser les réglages',
  tooltip_reset_settings: 'Réinitialiser tous les réglages',
  button_reset_form: 'Effacer fichiers et nom',
  tooltip_reset_form: 'Effacer uniquement les fichiers et le nom du lot',
  device_id_badge: 'ID de l’appareil',
  details_max_plays: 'Lectures max',
  details_reset: 'Réinit.',
  details_interval: 'Intervalle',
  details_none: 'Aucun',
  details_max_total_prefix: 'Max total :',
  details_no_lifetime_limit: 'Sans limite à vie',
  details_free_preview_prefix: 'Aperçu :',
  remove: 'Supprimer',
  err_failed_add_media_prefix: 'Échec de l’ajout de fichiers : ',
  err_max_items_session_min: 'Les éléments par session doivent être au moins 1',
  err_max_total_items_min: 'Le total d’éléments lus doit être au moins 1',
  err_invalid_playlist_expiration: 'Date d’expiration de liste invalide',
  err_please_enter_bundle_name: 'Veuillez saisir un nom de lot',
  err_please_enter_device_id: 'Veuillez saisir au moins un ID d’appareil',
  err_please_add_media: 'Veuillez ajouter au moins un fichier média',
  err_max_plays_at_least: 'Les lectures max doivent être au moins à 1',
  err_reset_interval_min: 'L’intervalle de réinitialisation doit être d’au moins 1 minute',
  err_expiration_future: 'La date d’expiration doit être dans le futur',
  success_title: 'Succès !',
  error_title: 'Erreur !',
  bundle_created_title: 'Lot créé avec succès !',
  location: 'Emplacement :',
  bundle_id: 'ID du lot :',
  files_processed: 'Fichiers traités :',
  archive: 'Archive :',
  transfer_line1: 'Vous pouvez maintenant transférer ce fichier .smbundle sécurisé vers les appareils autorisés.',
  transfer_line2: 'Le lot est protégé et compressé pour la sécurité.',
  failed_create_prefix: 'Échec de création du lot : ',
  ok: 'OK'
};

i18n.strings.nl = {
  app_title: 'Schrift Media Bundelaar',
  app_subtitle: 'Maak veilige mediabundels voor gemachtigde apparaten',
  language_settings_title: 'Taal',
  system_default: 'Systeemstandaard',
  section_bundle_config: 'Bundelconfiguratie',
  label_bundle_name: 'Bundelnaam *',
  placeholder_bundle_name: 'bijv. Luke_Gospel_Trial',
  label_device_ids: 'Geautoriseerde apparaat-ID’s * (één per regel)',
  placeholder_device_ids: 'Voer apparaat-ID’s in, één per regel',
  section_playback_limits: 'Afspeellimieten',
  label_max_plays: 'Max. weergaven per resetperiode *',
  help_max_plays: 'Aantal keren dat kan worden afgespeeld vóór reset',
  label_free_preview: 'Gratis voorbeeld seconden',
  help_free_preview: 'Aantal seconden gratis voor er wordt geteld (0 om uit te schakelen)',
  label_reset_interval: 'Resetinterval *',
  label_days: 'Dagen',
  label_hours: 'Uren',
  label_minutes: 'Minuten',
  label_min_interval_between_plays: 'Minimale interval tussen weergaven (Optioneel)',
  help_min_interval_between_plays: 'Vereiste wachttijd tussen weergaven (0 voor geen minimum)',
  label_max_plays_total: 'Maximaal totaal aantal weergaven (Optioneel)',
  placeholder_no_limit: 'Leeg laten voor geen limiet',
  help_max_plays_total: 'Levenslange limiet — media worden permanent geblokkeerd na dit aantal',
  label_expiration: 'Vervaltijd en -datum van bundel (Optioneel)',
  help_expiration: 'Bundel wordt permanent geblokkeerd na deze datum/tijd',
  section_playlist_limits: 'Afspeellijst-limieten (Optioneel)',
  paragraph_playlist_limits: 'Deze limieten gelden voor de hele afspeellijst en bepalen het totale gebruik.',
  label_playlist_max_items_session: 'Max items per sessie (Optioneel)',
  help_playlist_max_items_session: 'Maximaal aantal unieke bestanden per sessie',
  label_session_reset_interval: 'Sessie-resetinterval (Optioneel)',
  help_playlist_session_reset: 'Tijd totdat de sessie wordt gereset en gebruikers nieuwe items kunnen afspelen (laat op 0 voor geen reset)',
  label_playlist_min_interval_between_items: 'Minimaal interval tussen items (Optioneel)',
  help_playlist_min_interval_between_items: 'Wachttijd tussen verschillende bestanden (0 voor geen minimum)',
  label_playlist_max_total_items: 'Maximaal totaal aantal items ooit (Optioneel)',
  help_playlist_max_total_items: 'Levenslange limiet op unieke bestanden — lijst wordt definitief geblokkeerd na dit aantal',
  label_playlist_expiration: 'Vervaldatum & tijd van afspeellijst (Optioneel)',
  help_playlist_expiration: 'Lijst wordt permanent geblokkeerd na deze datum/tijd (kan verschillen van bundel)',
  section_media_files: 'Mediabestanden',
  button_add_media: 'Mediabestanden toevoegen',
  empty_no_media: 'Nog geen mediabestanden toegevoegd',
  loading_creating_bundle: 'Bundel maken...',
  button_create_bundle: 'Bundel maken',
  button_reset_settings: 'Instellingen resetten',
  tooltip_reset_settings: 'Alle instellingen terugzetten naar standaard',
  button_reset_form: 'Bestanden en naam wissen',
  tooltip_reset_form: 'Alleen geselecteerde bestanden en naam wissen',
  device_id_badge: 'Apparaat-ID',
  details_max_plays: 'Max weergaven',
  details_reset: 'Reset',
  details_interval: 'Interval',
  details_none: 'Geen',
  details_max_total_prefix: 'Max totaal:',
  details_no_lifetime_limit: 'Geen levenslange limiet',
  details_free_preview_prefix: 'Voorbeeld:',
  remove: 'Verwijderen',
  err_failed_add_media_prefix: 'Kan bestanden niet toevoegen: ',
  err_max_items_session_min: 'Items per sessie moeten minstens 1 zijn',
  err_max_total_items_min: 'Totaal aantal items moet minstens 1 zijn',
  err_invalid_playlist_expiration: 'Ongeldige vervaldatum voor afspeellijst',
  err_please_enter_bundle_name: 'Voer een bundelnaam in',
  err_please_enter_device_id: 'Voer minstens één apparaat-ID in',
  err_please_add_media: 'Voeg minstens één mediabestand toe',
  err_max_plays_at_least: 'Max weergaven moet minstens 1 zijn',
  err_reset_interval_min: 'Resetinterval moet minstens 1 minuut zijn',
  err_expiration_future: 'Vervaldatum moet in de toekomst liggen',
  success_title: 'Gelukt!',
  error_title: 'Fout!',
  bundle_created_title: 'Bundel succesvol gemaakt!',
  location: 'Locatie:',
  bundle_id: 'Bundel-ID:',
  files_processed: 'Bestanden verwerkt:',
  archive: 'Archief:',
  transfer_line1: 'Je kunt dit beveiligde .smbundle-bestand nu overzetten naar gemachtigde apparaten.',
  transfer_line2: 'De bundel is beschermd en gecomprimeerd voor veiligheid.',
  failed_create_prefix: 'Kan bundel niet maken: ',
  ok: 'OK'
};

i18n.strings.af = {
  app_title: 'Skrif Media Bondelaar',
  app_subtitle: 'Skep veilige mediabondels vir gemagtigde toestelle',
  language_settings_title: 'Taal',
  system_default: 'Stelselverstek',
  section_bundle_config: 'Bondelkonfigurasie',
  label_bundle_name: 'Bondelnaam *',
  placeholder_bundle_name: 'bv. Luke_Gospel_Trial',
  label_device_ids: 'Gemagtigde Toestel-ID’s * (een per lyn)',
  placeholder_device_ids: 'Voer Toestel-ID’s in, een per lyn',
  section_playback_limits: 'Afspeelgrense',
  label_max_plays: 'Maksimum spele per herstelperiode *',
  help_max_plays: 'Hoeveel keer media kan speel voor jy moet wag vir herstel',
  label_free_preview: 'Gratis voorskou sekondes',
  help_free_preview: 'Hoeveel sekondes gratis voor ’n spel getel word (0 om af te skakel)',
  label_reset_interval: 'Herstelinterval *',
  label_days: 'Dae',
  label_hours: 'Ure',
  label_minutes: 'Minute',
  label_min_interval_between_plays: 'Minimum interval tussen spele (Opsioneel)',
  help_min_interval_between_plays: 'Vereiste wachttyd tussen elke spel (0 vir geen minimum)',
  label_max_plays_total: 'Maksimum totale spele ooit (Opsioneel)',
  placeholder_no_limit: 'Los leeg vir geen limiet',
  help_max_plays_total: 'Lewenstyd limiet — media word permanent gesluit na soveel spele',
  label_expiration: 'Bondel vervaltyd en -datum (Opsioneel)',
  help_expiration: 'Bondel word permanent gesluit ná hierdie datum/tyd',
  section_playlist_limits: 'Speellys-vlak grense (Opsioneel)',
  paragraph_playlist_limits: 'Hierdie grense geld vir die hele speellys en beheer die totale gebruik.',
  label_playlist_max_items_session: 'Maks items per sessie (Opsioneel)',
  help_playlist_max_items_session: 'Maksimum aantal unieke lêers per sessie',
  label_session_reset_interval: 'Sessie-herstelinterval (Opsioneel)',
  help_playlist_session_reset: 'Hoe lank voor die sessie herstel en gebruikers nuwe items kan speel (los op 0 vir geen herstel)',
  label_playlist_min_interval_between_items: 'Minimum interval tussen items (Opsioneel)',
  help_playlist_min_interval_between_items: 'Wachttyd tussen verskillende lêers (0 vir geen minimum)',
  label_playlist_max_total_items: 'Maksimum totale items ooit (Opsioneel)',
  help_playlist_max_total_items: 'Lewenstyd limiet op unieke lêers — speellys word permanent gesluit na hierdie aantal',
  label_playlist_expiration: 'Sperdatum & tyd van speellys (Opsioneel)',
  help_playlist_expiration: 'Speellys word permanent gesluit ná hierdie datum/tyd (kan verskil van bondel)',
  section_media_files: 'Mediabestande',
  button_add_media: 'Voeg mediabestande by',
  empty_no_media: 'Nog geen mediabestande bygevoeg nie',
  loading_creating_bundle: 'Skep tans bondel...',
  button_create_bundle: 'Skep bondel',
  button_reset_settings: 'Stel instellings terug',
  tooltip_reset_settings: 'Stel alle instellings terug na verstek',
  button_reset_form: 'Vee lêers en naam uit',
  tooltip_reset_form: 'Vee slegs geselekteerde lêers en bondelnaam uit',
  device_id_badge: 'Toestel-ID',
  details_max_plays: 'Maks spele',
  details_reset: 'Herstel',
  details_interval: 'Interval',
  details_none: 'Geen',
  details_max_total_prefix: 'Maks totaal:',
  details_no_lifetime_limit: 'Geen lewenstydlimiet',
  details_free_preview_prefix: 'Voorskou:',
  remove: 'Verwyder',
  err_failed_add_media_prefix: 'Kon nie lêers byvoeg nie: ',
  err_max_items_session_min: 'Items per sessie moet ten minste 1 wees',
  err_max_total_items_min: 'Totale items gespeel moet ten minste 1 wees',
  err_invalid_playlist_expiration: 'Ongeldige vervaldatum vir speellys',
  err_please_enter_bundle_name: 'Voer ’n bondelnaam in',
  err_please_enter_device_id: 'Voer ten minste een Toestel-ID in',
  err_please_add_media: 'Voeg ten minste een mediabestand by',
  err_max_plays_at_least: 'Maksimum spele moet minstens 1 wees',
  err_reset_interval_min: 'Herstelinterval moet minstens 1 minuut wees',
  err_expiration_future: 'Vervaldatum moet in die toekoms wees',
  success_title: 'Sukses!',
  error_title: 'Fout!',
  bundle_created_title: 'Bondel suksesvol geskep!',
  location: 'Ligging:',
  bundle_id: 'Bondel-ID:',
  files_processed: 'Lêers verwerk:',
  archive: 'Argief:',
  transfer_line1: 'Jy kan hierdie veilige .smbundle-lêer nou oorsit na gemagtigde toestelle.',
  transfer_line2: 'Die bondel is beskerm en saamgepers vir veiligheid.',
  failed_create_prefix: 'Kon nie bondel skep nie: ',
  ok: 'OK'
};

i18n.strings.de = {
  app_title: 'Schrift Medien-Bündler',
  app_subtitle: 'Erstelle sichere Medienpakete für autorisierte Geräte',
  language_settings_title: 'Sprache',
  system_default: 'Systemstandard',
  section_bundle_config: 'Paketkonfiguration',
  label_bundle_name: 'Paketname *',
  placeholder_bundle_name: 'z. B. Luke_Gospel_Trial',
  label_device_ids: 'Autorisierte Geräte-IDs * (eine pro Zeile)',
  placeholder_device_ids: 'Geräte-IDs eingeben, eine pro Zeile',
  section_playback_limits: 'Wiedergabebeschränkungen',
  label_max_plays: 'Maximale Wiedergaben pro Resetzeitraum *',
  help_max_plays: 'Anzahl der Wiedergaben vor dem Warten auf den Reset',
  label_free_preview: 'Kostenlose Vorschau-Sekunden',
  help_free_preview: 'Wie viele Sekunden vor der Berechnung (0 zum Deaktivieren)',
  label_reset_interval: 'Reset-Intervall *',
  label_days: 'Tage',
  label_hours: 'Stunden',
  label_minutes: 'Minuten',
  label_min_interval_between_plays: 'Mindestintervall zwischen Wiedergaben (Optional)',
  help_min_interval_between_plays: 'Erforderliche Wartezeit zwischen Wiedergaben (0 für kein Minimum)',
  label_max_plays_total: 'Maximale Gesamtwiedergaben (Optional)',
  placeholder_no_limit: 'Leer lassen für kein Limit',
  help_max_plays_total: 'Lebenslanges Limit — Medien werden permanent gesperrt nach dieser Anzahl',
  label_expiration: 'Ablaufdatum & -zeit des Pakets (Optional)',
  help_expiration: 'Paket wird nach diesem Datum/Uhrzeit dauerhaft gesperrt',
  section_playlist_limits: 'Playlist-Grenzen (Optional)',
  paragraph_playlist_limits: 'Diese Grenzen gelten für die gesamte Playlist und steuern die Gesamtnutzung.',
  label_playlist_max_items_session: 'Max. Elemente pro Sitzung (Optional)',
  help_playlist_max_items_session: 'Maximale Anzahl eindeutiger Dateien pro Sitzung',
  label_session_reset_interval: 'Sitzungs-Resetintervall (Optional)',
  help_playlist_session_reset: 'Wie lange bis die Sitzung zurückgesetzt wird und Nutzer neue Elemente abspielen können (bei 0 kein Zurücksetzen)',
  label_playlist_min_interval_between_items: 'Mindestintervall zwischen Elementen (Optional)',
  help_playlist_min_interval_between_items: 'Wartezeit zwischen verschiedenen Dateien (0 für kein Minimum)',
  label_playlist_max_total_items: 'Maximale Gesamtanzahl gespielter Elemente (Optional)',
  help_playlist_max_total_items: 'Lebenslanges Limit für eindeutige Dateien — Liste wird dauerhaft gesperrt',
  label_playlist_expiration: 'Ablaufdatum & -zeit der Playlist (Optional)',
  help_playlist_expiration: 'Playlist wird nach diesem Zeitpunkt dauerhaft gesperrt (kann abweichen)',
  section_media_files: 'Mediendateien',
  button_add_media: 'Mediendateien hinzufügen',
  empty_no_media: 'Noch keine Mediendateien hinzugefügt',
  loading_creating_bundle: 'Paket wird erstellt...',
  button_create_bundle: 'Paket erstellen',
  button_reset_settings: 'Einstellungen zurücksetzen',
  tooltip_reset_settings: 'Alle Einstellungen auf Standard zurücksetzen',
  button_reset_form: 'Dateien & Name löschen',
  tooltip_reset_form: 'Nur ausgewählte Dateien und Paketname löschen',
  device_id_badge: 'Geräte-ID',
  details_max_plays: 'Max. Wiedergaben',
  details_reset: 'Reset',
  details_interval: 'Intervall',
  details_none: 'Keins',
  details_max_total_prefix: 'Max gesamt:',
  details_no_lifetime_limit: 'Kein lebenslanges Limit',
  details_free_preview_prefix: 'Vorschau:',
  remove: 'Entfernen',
  err_failed_add_media_prefix: 'Fehler beim Hinzufügen von Dateien: ',
  err_max_items_session_min: 'Max. Elemente pro Sitzung müssen mindestens 1 sein',
  err_max_total_items_min: 'Gesamtanzahl der Elemente muss mindestens 1 sein',
  err_invalid_playlist_expiration: 'Ungültiges Ablaufdatum für Playlist',
  err_please_enter_bundle_name: 'Bitte einen Paketnamen eingeben',
  err_please_enter_device_id: 'Bitte mindestens eine Geräte-ID eingeben',
  err_please_add_media: 'Bitte mindestens eine Mediendatei hinzufügen',
  err_max_plays_at_least: 'Maximale Wiedergaben müssen mindestens 1 sein',
  err_reset_interval_min: 'Resetintervall muss mindestens 1 Minute sein',
  err_expiration_future: 'Ablaufdatum muss in der Zukunft liegen',
  success_title: 'Erfolg!',
  error_title: 'Fehler!',
  bundle_created_title: 'Paket erfolgreich erstellt!',
  location: 'Speicherort:',
  bundle_id: 'Paket-ID:',
  files_processed: 'Dateien verarbeitet:',
  archive: 'Archiv:',
  transfer_line1: 'Sie können diese sichere .smbundle-Datei nun auf autorisierte Geräte übertragen.',
  transfer_line2: 'Das Paket ist zum Schutz komprimiert und gesichert.',
  failed_create_prefix: 'Paket konnte nicht erstellt werden: ',
  ok: 'OK'
};

i18n.strings.pt = {
  app_title: 'Empacotador de Mídia das Escrituras',
  app_subtitle: 'Crie pacotes de mídia seguros para dispositivos autorizados',
  language_settings_title: 'Idioma',
  system_default: 'Padrão do sistema',
  section_bundle_config: 'Configuração do pacote',
  label_bundle_name: 'Nome do pacote *',
  placeholder_bundle_name: 'ex.: Luke_Gospel_Trial',
  label_device_ids: 'IDs de dispositivos autorizados * (um por linha)',
  placeholder_device_ids: 'Insira IDs de dispositivos, um por linha',
  section_playback_limits: 'Limites de reprodução',
  label_max_plays: 'Reproduções máximas por período de redefinição *',
  help_max_plays: 'Número de reproduções antes de aguardar a redefinição',
  label_free_preview: 'Segundos de prévia gratuita',
  help_free_preview: 'Quantos segundos antes de cobrar (0 para desativar)',
  label_reset_interval: 'Intervalo de redefinição *',
  label_days: 'Dias',
  label_hours: 'Horas',
  label_minutes: 'Minutos',
  label_min_interval_between_plays: 'Intervalo mínimo entre reproduções (Opcional)',
  help_min_interval_between_plays: 'Tempo de espera entre cada reprodução (0 para sem mínimo)',
  label_max_plays_total: 'Total máximo de reproduções (Opcional)',
  placeholder_no_limit: 'Deixe em branco para sem limite',
  help_max_plays_total: 'Limite vitalício — mídia bloqueada permanentemente após esse número',
  label_expiration: 'Data e hora de expiração do pacote (Opcional)',
  help_expiration: 'Pacote fica permanentemente bloqueado após essa data/hora',
  section_playlist_limits: 'Limites de playlist (Opcional)',
  paragraph_playlist_limits: 'Esses limites se aplicam à playlist inteira e controlam o uso total.',
  label_playlist_max_items_session: 'Máx. itens por sessão (Opcional)',
  help_playlist_max_items_session: 'Número máximo de arquivos únicos por sessão',
  label_session_reset_interval: 'Intervalo de redefinição da sessão (Opcional)',
  help_playlist_session_reset: 'Quanto tempo até a sessão redefinir e os usuários poderem tocar novos itens (deixe 0 para sem redefinição)',
  label_playlist_min_interval_between_items: 'Intervalo mínimo entre itens (Opcional)',
  help_playlist_min_interval_between_items: 'Tempo de espera entre arquivos diferentes (0 para sem mínimo)',
  label_playlist_max_total_items: 'Máximo total de itens reproduzidos (Opcional)',
  help_playlist_max_total_items: 'Limite vitalício de arquivos únicos — playlist fica bloqueada permanentemente após esse número',
  label_playlist_expiration: 'Data e hora de expiração da playlist (Opcional)',
  help_playlist_expiration: 'Playlist fica permanentemente bloqueada após essa data/hora (pode diferir da expiração do pacote)',
  section_media_files: 'Arquivos de mídia',
  button_add_media: 'Adicionar arquivos de mídia',
  empty_no_media: 'Nenhum arquivo adicionado ainda',
  loading_creating_bundle: 'Criando pacote...',
  button_create_bundle: 'Criar pacote',
  button_reset_settings: 'Redefinir configurações',
  tooltip_reset_settings: 'Redefinir todas as configurações para o padrão',
  button_reset_form: 'Limpar arquivos e nome',
  tooltip_reset_form: 'Limpar apenas arquivos selecionados e o nome do pacote',
  device_id_badge: 'ID do dispositivo',
  details_max_plays: 'Reprod. máx.',
  details_reset: 'Redefinição',
  details_interval: 'Intervalo',
  details_none: 'Nenhum',
  details_max_total_prefix: 'Máx. total:',
  details_no_lifetime_limit: 'Sem limite vitalício',
  details_free_preview_prefix: 'Prévia:',
  remove: 'Remover',
  err_failed_add_media_prefix: 'Falha ao adicionar arquivos: ',
  err_max_items_session_min: 'Itens por sessão devem ser pelo menos 1',
  err_max_total_items_min: 'Total de itens reproduzidos deve ser pelo menos 1',
  err_invalid_playlist_expiration: 'Data de expiração da playlist inválida',
  err_please_enter_bundle_name: 'Insira um nome de pacote',
  err_please_enter_device_id: 'Insira pelo menos um ID de dispositivo',
  err_please_add_media: 'Adicione pelo menos um arquivo de mídia',
  err_max_plays_at_least: 'Reproduções máximas devem ser pelo menos 1',
  err_reset_interval_min: 'O intervalo de redefinição deve ser de pelo menos 1 minuto',
  err_expiration_future: 'A data de expiração deve estar no futuro',
  success_title: 'Sucesso!',
  error_title: 'Erro!',
  bundle_created_title: 'Pacote criado com sucesso!',
  location: 'Local:',
  bundle_id: 'ID do pacote:',
  files_processed: 'Arquivos processados:',
  archive: 'Arquivo:',
  transfer_line1: 'Agora você pode transferir este arquivo .smbundle seguro para dispositivos autorizados.',
  transfer_line2: 'O pacote está protegido e comprimido para segurança.',
  failed_create_prefix: 'Falha ao criar o pacote: ',
  ok: 'OK'
};

i18n.strings.id = {
  app_title: 'Pembuat Bundel Media Kitab Suci',
  app_subtitle: 'Buat bundel media aman untuk perangkat yang diizinkan',
  language_settings_title: 'Bahasa',
  system_default: 'Bawaan sistem',
  section_bundle_config: 'Konfigurasi bundel',
  label_bundle_name: 'Nama bundel *',
  placeholder_bundle_name: 'mis. Luke_Gospel_Trial',
  label_device_ids: 'ID Perangkat yang Diizinkan * (satu per baris)',
  placeholder_device_ids: 'Masukkan ID perangkat, satu per baris',
  section_playback_limits: 'Batas pemutaran',
  label_max_plays: 'Putar maksimum per periode reset *',
  help_max_plays: 'Berapa kali dapat diputar sebelum menunggu reset',
  label_free_preview: 'Detik pratinjau gratis',
  help_free_preview: 'Berapa detik sebelum dihitung (0 untuk menonaktifkan)',
  label_reset_interval: 'Interval reset *',
  label_days: 'Hari',
  label_hours: 'Jam',
  label_minutes: 'Menit',
  label_min_interval_between_plays: 'Interval minimum antar pemutaran (Opsional)',
  help_min_interval_between_plays: 'Waktu tunggu di antara pemutaran (0 untuk tanpa minimum)',
  label_max_plays_total: 'Total putar maksimum (Opsional)',
  placeholder_no_limit: 'Kosongkan untuk tanpa batas',
  help_max_plays_total: 'Batas seumur hidup — media terkunci permanen setelah jumlah ini',
  label_expiration: 'Tanggal & waktu kedaluwarsa bundel (Opsional)',
  help_expiration: 'Bundel terkunci permanen setelah tanggal/waktu ini',
  section_playlist_limits: 'Batas tingkat daftar putar (Opsional)',
  paragraph_playlist_limits: 'Batasan ini berlaku untuk seluruh daftar putar dan mengontrol penggunaan total.',
  label_playlist_max_items_session: 'Maks item per sesi (Opsional)',
  help_playlist_max_items_session: 'Jumlah maksimum file unik per sesi',
  label_session_reset_interval: 'Interval reset sesi (Opsional)',
  help_playlist_session_reset: 'Berapa lama hingga sesi direset dan pengguna dapat memutar item baru (biarkan 0 untuk tanpa reset)',
  label_playlist_min_interval_between_items: 'Interval minimum antar item (Opsional)',
  help_playlist_min_interval_between_items: 'Waktu tunggu antar file yang berbeda (0 untuk tanpa minimum)',
  label_playlist_max_total_items: 'Total item diputar maksimum (Opsional)',
  help_playlist_max_total_items: 'Batas seumur hidup file unik — daftar putar terkunci permanen setelah jumlah ini',
  label_playlist_expiration: 'Tanggal & waktu kedaluwarsa daftar putar (Opsional)',
  help_playlist_expiration: 'Daftar putar terkunci permanen setelah tanggal/waktu ini (bisa berbeda dari kedaluwarsa bundel)',
  section_media_files: 'Berkas media',
  button_add_media: 'Tambahkan berkas media',
  empty_no_media: 'Belum ada berkas ditambahkan',
  loading_creating_bundle: 'Membuat bundel...',
  button_create_bundle: 'Buat bundel',
  button_reset_settings: 'Atur ulang setelan',
  tooltip_reset_settings: 'Atur ulang semua setelan ke bawaan',
  button_reset_form: 'Hapus berkas & nama',
  tooltip_reset_form: 'Hapus hanya berkas yang dipilih dan nama bundel',
  device_id_badge: 'ID Perangkat',
  details_max_plays: 'Putar maks',
  details_reset: 'Atur ulang',
  details_interval: 'Interval',
  details_none: 'Tidak ada',
  details_max_total_prefix: 'Maks total:',
  details_no_lifetime_limit: 'Tanpa batas seumur hidup',
  details_free_preview_prefix: 'Pratinjau:',
  remove: 'Hapus',
  err_failed_add_media_prefix: 'Gagal menambahkan berkas: ',
  err_max_items_session_min: 'Item per sesi harus minimal 1',
  err_max_total_items_min: 'Total item diputar harus minimal 1',
  err_invalid_playlist_expiration: 'Tanggal kedaluwarsa daftar putar tidak valid',
  err_please_enter_bundle_name: 'Masukkan nama bundel',
  err_please_enter_device_id: 'Masukkan minimal satu ID perangkat',
  err_please_add_media: 'Tambahkan minimal satu berkas media',
  err_max_plays_at_least: 'Putar maksimum harus minimal 1',
  err_reset_interval_min: 'Interval reset harus minimal 1 menit',
  err_expiration_future: 'Tanggal kedaluwarsa harus di masa depan',
  success_title: 'Berhasil!',
  error_title: 'Galat!',
  bundle_created_title: 'Bundel berhasil dibuat!',
  location: 'Lokasi:',
  bundle_id: 'ID Bundel:',
  files_processed: 'Berkas diproses:',
  archive: 'Arsip:',
  transfer_line1: 'Anda dapat mentransfer berkas .smbundle aman ini ke perangkat yang diizinkan.',
  transfer_line2: 'Bundel dilindungi dan dikompresi untuk keamanan.',
  failed_create_prefix: 'Gagal membuat bundel: ',
  ok: 'OK'
};

i18n.strings.ru = {
  app_title: 'Пакетировщик медиа Писания',
  app_subtitle: 'Создавайте защищённые медиапакеты для авторизованных устройств',
  language_settings_title: 'Язык',
  system_default: 'Системный по умолчанию',
  section_bundle_config: 'Настройка пакета',
  label_bundle_name: 'Имя пакета *',
  placeholder_bundle_name: 'например Luke_Gospel_Trial',
  label_device_ids: 'Разрешённые ID устройств * (по одному в строке)',
  placeholder_device_ids: 'Введите ID устройств, по одному в строке',
  section_playback_limits: 'Ограничения воспроизведения',
  label_max_plays: 'Макс. воспроизведений за период *',
  help_max_plays: 'Сколько раз можно воспроизвести до ожидания сброса',
  label_free_preview: 'Секунды бесплатного предпросмотра',
  help_free_preview: 'Сколько секунд бесплатно до начисления (0 — отключено)',
  label_reset_interval: 'Интервал сброса *',
  label_days: 'Дни',
  label_hours: 'Часы',
  label_minutes: 'Минуты',
  label_min_interval_between_plays: 'Минимальный интервал между воспроизведениями (Опционально)',
  help_min_interval_between_plays: 'Время ожидания между воспроизведениями (0 — без минимума)',
  label_max_plays_total: 'Максимум за всю жизнь (Опционально)',
  placeholder_no_limit: 'Оставьте пустым для без лимита',
  help_max_plays_total: 'Пожизненный лимит — медиа блокируется навсегда после этого числа',
  label_expiration: 'Дата и время истечения пакета (Опционально)',
  help_expiration: 'Пакет блокируется навсегда после этой даты/времени',
  section_playlist_limits: 'Ограничения плейлиста (Опционально)',
  paragraph_playlist_limits: 'Эти ограничения применяются ко всему плейлисту и регулируют общее использование.',
  label_playlist_max_items_session: 'Макс. элементов за сессию (Опционально)',
  help_playlist_max_items_session: 'Максимальное число уникальных файлов за сессию',
  label_session_reset_interval: 'Интервал сброса сессии (Опционально)',
  help_playlist_session_reset: 'Через сколько сбрасывается сессия и можно воспроизводить новые элементы (оставьте 0, чтобы не сбрасывать)',
  label_playlist_min_interval_between_items: 'Минимальный интервал между элементами (Опционально)',
  help_playlist_min_interval_between_items: 'Время ожидания между разными файлами (0 — без минимума)',
  label_playlist_max_total_items: 'Максимум уникальных элементов за всё время (Опционально)',
  help_playlist_max_total_items: 'Пожизненный лимит уникальных файлов — плейлист будет навсегда заблокирован',
  label_playlist_expiration: 'Дата и время истечения плейлиста (Опционально)',
  help_playlist_expiration: 'Плейлист навсегда блокируется после этой даты/времени (может отличаться от пакета)',
  section_media_files: 'Медиафайлы',
  button_add_media: 'Добавить медиафайлы',
  empty_no_media: 'Медиафайлы ещё не добавлены',
  loading_creating_bundle: 'Создание пакета...',
  button_create_bundle: 'Создать пакет',
  button_reset_settings: 'Сбросить настройки',
  tooltip_reset_settings: 'Сбросить все настройки к значениям по умолчанию',
  button_reset_form: 'Очистить файлы и имя',
  tooltip_reset_form: 'Очистить только выбранные файлы и имя пакета',
  device_id_badge: 'ID устройства',
  details_max_plays: 'Макс. воспроизвед.',
  details_reset: 'Сброс',
  details_interval: 'Интервал',
  details_none: 'Нет',
  details_max_total_prefix: 'Макс. всего:',
  details_no_lifetime_limit: 'Без пожизненного лимита',
  details_free_preview_prefix: 'Предпросмотр:',
  remove: 'Удалить',
  err_failed_add_media_prefix: 'Не удалось добавить файлы: ',
  err_max_items_session_min: 'Элементов за сессию должно быть как минимум 1',
  err_max_total_items_min: 'Всего элементов должно быть как минимум 1',
  err_invalid_playlist_expiration: 'Неверная дата истечения списка',
  err_please_enter_bundle_name: 'Введите имя пакета',
  err_please_enter_device_id: 'Введите хотя бы один ID устройства',
  err_please_add_media: 'Добавьте хотя бы один медиафайл',
  err_max_plays_at_least: 'Макс. воспроизведений должно быть как минимум 1',
  err_reset_interval_min: 'Интервал сброса должен быть не менее 1 минуты',
  err_expiration_future: 'Дата истечения должна быть в будущем',
  success_title: 'Успех!',
  error_title: 'Ошибка!',
  bundle_created_title: 'Пакет успешно создан!',
  location: 'Расположение:',
  bundle_id: 'ID пакета:',
  files_processed: 'Файлов обработано:',
  archive: 'Архив:',
  transfer_line1: 'Теперь вы можете передать этот защищенный файл .smbundle на авторизованные устройства.',
  transfer_line2: 'Пакет защищён и сжат в целях безопасности.',
  failed_create_prefix: 'Не удалось создать пакет: ',
  ok: 'ОК'
};

i18n.strings.hi = {
  app_title: 'धर्मग्रंथ मीडिया बंडलर',
  app_subtitle: 'अधिकृत डिवाइसों के लिए सुरक्षित मीडिया बंडल बनाएँ',
  language_settings_title: 'भाषा',
  system_default: 'सिस्टम डिफ़ॉल्ट',
  section_bundle_config: 'बंडल कॉन्फ़िगरेशन',
  label_bundle_name: 'बंडल नाम *',
  placeholder_bundle_name: 'उदा. Luke_Gospel_Trial',
  label_device_ids: 'अधिकृत डिवाइस IDs * (प्रति पंक्ति एक)',
  placeholder_device_ids: 'डिवाइस ID दर्ज करें, प्रति पंक्ति एक',
  section_playback_limits: 'प्लेबैक सीमाएँ',
  label_max_plays: 'रीसेट अवधि प्रति अधिकतम प्ले *',
  help_max_plays: 'रीसेट का इंतजार करने से पहले कितनी बार प्ले कर सकते हैं',
  label_free_preview: 'नि:शुल्क पूर्वावलोकन सेकंड',
  help_free_preview: 'चार्ज लगने से पहले सेकंड (0 से अक्षम)',
  label_reset_interval: 'रीसेट अंतराल *',
  label_days: 'दिन',
  label_hours: 'घंटे',
  label_minutes: 'मिनट',
  label_min_interval_between_plays: 'प्ले के बीच न्यूनतम अंतराल (वैकल्पिक)',
  help_min_interval_between_plays: 'हर प्ले के बीच प्रतीक्षा समय (0 से कोई न्यूनतम नहीं)',
  label_max_plays_total: 'कुल अधिकतम प्ले (वैकल्पिक)',
  placeholder_no_limit: 'सीमा न होने पर खाली छोड़ें',
  help_max_plays_total: 'जीवनकाल सीमा — इस संख्या के बाद मीडिया स्थायी रूप से लॉक',
  label_expiration: 'बंडल समाप्ति दिनांक/समय (वैकल्पिक)',
  help_expiration: 'इस दिनांक/समय के बाद बंडल स्थायी रूप से लॉक',
  section_playlist_limits: 'प्लेलिस्ट-स्तरीय सीमाएँ (वैकल्पिक)',
  paragraph_playlist_limits: 'ये सीमाएँ पूरी प्लेलिस्ट पर लागू होती हैं और कुल उपयोग नियंत्रित करती हैं।',
  label_playlist_max_items_session: 'प्रति सत्र अधिकतम आइटम (वैकल्पिक)',
  help_playlist_max_items_session: 'प्रति सत्र अधिकतम अद्वितीय फाइलें',
  label_session_reset_interval: 'सत्र रीसेट अंतराल (वैकल्पिक)',
  help_playlist_session_reset: 'कितनी देर में सत्र रीसेट होगा और उपयोगकर्ता नए आइटम चला सकेंगे (रीसेट न करने के लिए 0 छोड़ें)',
  label_playlist_min_interval_between_items: 'आइटम के बीच न्यूनतम अंतराल (वैकल्पिक)',
  help_playlist_min_interval_between_items: 'अलग फाइलों के बीच प्रतीक्षा समय (0 से कोई न्यूनतम नहीं)',
  label_playlist_max_total_items: 'कुल अधिकतम चलाए गए आइटम (वैकल्पिक)',
  help_playlist_max_total_items: 'अद्वितीय फाइलों की जीवनकाल सीमा — इस संख्या के बाद प्लेलिस्ट स्थायी रूप से लॉक',
  label_playlist_expiration: 'प्लेलिस्ट समाप्ति दिनांक/समय (वैकल्पिक)',
  help_playlist_expiration: 'इस दिनांक/समय के बाद प्लेलिस्ट स्थायी रूप से लॉक (बंडल से भिन्न हो सकती है)',
  section_media_files: 'मीडिया फाइलें',
  button_add_media: 'मीडिया फाइलें जोड़ें',
  empty_no_media: 'अभी तक कोई फाइल नहीं जोड़ी गई',
  loading_creating_bundle: 'बंडल बनाया जा रहा है...',
  button_create_bundle: 'बंडल बनाएँ',
  button_reset_settings: 'सेटिंग्स रीसेट करें',
  tooltip_reset_settings: 'सारी सेटिंग्स को डिफ़ॉल्ट पर रीसेट करें',
  button_reset_form: 'फाइलें और नाम साफ करें',
  tooltip_reset_form: 'सिर्फ चुनी गई फाइलें और बंडल नाम साफ करें',
  device_id_badge: 'डिवाइस ID',
  details_max_plays: 'अधिक. प्ले',
  details_reset: 'रीसेट',
  details_interval: 'अंतराल',
  details_none: 'कोई नहीं',
  details_max_total_prefix: 'कुल अधिकतम:',
  details_no_lifetime_limit: 'जीवनकाल सीमा नहीं',
  details_free_preview_prefix: 'पूर्वावलोकन:',
  remove: 'हटाएँ',
  err_failed_add_media_prefix: 'फाइलें जोड़ने में विफल: ',
  err_max_items_session_min: 'प्रति सत्र आइटम कम-से-कम 1 होना चाहिए',
  err_max_total_items_min: 'कुल आइटम कम-से-कम 1 होना चाहिए',
  err_invalid_playlist_expiration: 'प्लेलिस्ट समाप्ति दिनांक अमान्य है',
  err_please_enter_bundle_name: 'कृपया बंडल नाम दर्ज करें',
  err_please_enter_device_id: 'कम-से-कम एक डिवाइस ID दर्ज करें',
  err_please_add_media: 'कम-से-कम एक मीडिया फाइल जोड़ें',
  err_max_plays_at_least: 'अधिकतम प्ले कम-से-कम 1 होना चाहिए',
  err_reset_interval_min: 'रीसेट अंतराल कम-से-कम 1 मिनट होना चाहिए',
  err_expiration_future: 'समाप्ति दिनांक भविष्य में होना चाहिए',
  success_title: 'सफल!',
  error_title: 'त्रुटि!',
  bundle_created_title: 'बंडल सफलतापूर्वक बनाया गया!',
  location: 'स्थान:',
  bundle_id: 'बंडल ID:',
  files_processed: 'प्रोसेस की गई फाइलें:',
  archive: 'आर्काइव:',
  transfer_line1: 'अब आप इस सुरक्षित .smbundle फाइल को अधिकृत डिवाइसों में ट्रांसफर कर सकते हैं।',
  transfer_line2: 'बंडल सुरक्षा के लिए संरक्षित और संपीड़ित है।',
  failed_create_prefix: 'बंडल बनाने में विफल: ',
  ok: 'ठीक'
};

i18n.strings.ar = {
  app_title: 'حزمة وسائط الكتاب المقدس',
  app_subtitle: 'أنشئ حزم وسائط آمنة للأجهزة المصرح بها',
  language_settings_title: 'اللغة',
  system_default: 'افتراضي النظام',
  section_bundle_config: 'إعدادات الحزمة',
  label_bundle_name: 'اسم الحزمة *',
  placeholder_bundle_name: 'مثال: Luke_Gospel_Trial',
  label_device_ids: 'معرّفات الأجهزة المصرح بها * (واحد في كل سطر)',
  placeholder_device_ids: 'أدخل معرّفات الأجهزة، واحد في كل سطر',
  section_playback_limits: 'حدود التشغيل',
  label_max_plays: 'الحد الأقصى للتشغيل لكل فترة إعادة تعيين *',
  help_max_plays: 'عدد مرات التشغيل قبل انتظار إعادة التعيين',
  label_free_preview: 'ثوانٍ للمعاينة المجانية',
  help_free_preview: 'عدد الثواني قبل الاحتساب (0 للتعطيل)',
  label_reset_interval: 'فترة إعادة التعيين *',
  label_days: 'أيام',
  label_hours: 'ساعات',
  label_minutes: 'دقائق',
  label_min_interval_between_plays: 'الحد الأدنى بين مرات التشغيل (اختياري)',
  help_min_interval_between_plays: 'مدة الانتظار بين كل تشغيل (0 بدون حد أدنى)',
  label_max_plays_total: 'الحد الأقصى لإجمالي التشغيل (اختياري)',
  placeholder_no_limit: 'اتركه فارغًا لعدم وجود حد',
  help_max_plays_total: 'حد طوال العمر — تُقفل الوسائط نهائيًا بعد هذا العدد',
  label_expiration: 'تاريخ ووقت انتهاء الحزمة (اختياري)',
  help_expiration: 'تُقفل الحزمة نهائيًا بعد هذا التاريخ/الوقت',
  section_playlist_limits: 'قيود قائمة التشغيل (اختياري)',
  paragraph_playlist_limits: 'تنطبق هذه القيود على القائمة كاملة وتتحكم بالاستخدام الكلي.',
  label_playlist_max_items_session: 'الحد الأقصى للعناصر في الجلسة (اختياري)',
  help_playlist_max_items_session: 'الحد الأقصى للملفات الفريدة لكل جلسة',
  label_session_reset_interval: 'فترة إعادة تعيين الجلسة (اختياري)',
  help_playlist_session_reset: 'المدة حتى تُعاد تهيئة الجلسة ويتمكن المستخدمون من تشغيل عناصر جديدة (اتركها 0 لعدم إعادة التهيئة)',
  label_playlist_min_interval_between_items: 'أدنى فترة بين العناصر (اختياري)',
  help_playlist_min_interval_between_items: 'مدة الانتظار بين الملفات المختلفة (0 بدون حد أدنى)',
  label_playlist_max_total_items: 'الحد الأقصى لإجمالي العناصر المشغلة (اختياري)',
  help_playlist_max_total_items: 'حد طوال العمر للملفات الفريدة — تُقفل القائمة نهائيًا بعد هذا العدد',
  label_playlist_expiration: 'تاريخ ووقت انتهاء قائمة التشغيل (اختياري)',
  help_playlist_expiration: 'تُقفل القائمة نهائيًا بعد هذا التاريخ/الوقت (قد يختلف عن الحزمة)',
  section_media_files: 'ملفات الوسائط',
  button_add_media: 'إضافة ملفات وسائط',
  empty_no_media: 'لا توجد ملفات مضافة بعد',
  loading_creating_bundle: 'جارٍ إنشاء الحزمة...',
  button_create_bundle: 'إنشاء الحزمة',
  button_reset_settings: 'إعادة ضبط الإعدادات',
  tooltip_reset_settings: 'إعادة جميع الإعدادات إلى الوضع الافتراضي',
  button_reset_form: 'مسح الملفات والاسم',
  tooltip_reset_form: 'مسح الملفات المحددة واسم الحزمة فقط',
  device_id_badge: 'معرّف الجهاز',
  details_max_plays: 'أقصى تشغيل',
  details_reset: 'إعادة',
  details_interval: 'الفترة',
  details_none: 'لا يوجد',
  details_max_total_prefix: 'الحد الإجمالي:',
  details_no_lifetime_limit: 'لا يوجد حد طوال العمر',
  details_free_preview_prefix: 'معاينة:',
  remove: 'إزالة',
  err_failed_add_media_prefix: 'فشل في إضافة الملفات: ',
  err_max_items_session_min: 'يجب أن يكون عدد العناصر في الجلسة 1 على الأقل',
  err_max_total_items_min: 'يجب أن يكون إجمالي العناصر 1 على الأقل',
  err_invalid_playlist_expiration: 'تاريخ انتهاء قائمة التشغيل غير صالح',
  err_please_enter_bundle_name: 'يرجى إدخال اسم الحزمة',
  err_please_enter_device_id: 'أدخل معرّف جهاز واحد على الأقل',
  err_please_add_media: 'أضف ملف وسائط واحدًا على الأقل',
  err_max_plays_at_least: 'يجب أن يكون الحد الأقصى للتشغيل 1 على الأقل',
  err_reset_interval_min: 'يجب أن تكون فترة إعادة التعيين دقيقة واحدة على الأقل',
  err_expiration_future: 'يجب أن يكون تاريخ الانتهاء في المستقبل',
  success_title: 'تم بنجاح!',
  error_title: 'خطأ!',
  bundle_created_title: 'تم إنشاء الحزمة بنجاح!',
  location: 'الموقع:',
  bundle_id: 'معرف الحزمة:',
  files_processed: 'الملفات المعالجة:',
  archive: 'الأرشيف:',
  transfer_line1: 'يمكنك الآن نقل ملف ‎.smbundle الآمن هذا إلى الأجهزة المصرح بها.',
  transfer_line2: 'الحزمة محمية ومضغوطة من أجل الأمان.',
  failed_create_prefix: 'فشل إنشاء الحزمة: ',
  ok: 'حسنًا'
};

i18n.strings.zh = {
  app_title: '经文媒体打包器',
  app_subtitle: '为已授权设备创建安全的媒体包',
  language_settings_title: '语言',
  system_default: '系统默认',
  section_bundle_config: '包配置',
  label_bundle_name: '包名称 *',
  placeholder_bundle_name: '例如：Luke_Gospel_Trial',
  label_device_ids: '授权设备 ID *（每行一个）',
  placeholder_device_ids: '输入设备 ID，每行一个',
  section_playback_limits: '播放限制',
  label_max_plays: '每个重置期最大播放次数 *',
  help_max_plays: '在等待重置前可播放的次数',
  label_free_preview: '免费预览秒数',
  help_free_preview: '计费前的秒数（0 表示禁用）',
  label_reset_interval: '重置间隔 *',
  label_days: '天',
  label_hours: '小时',
  label_minutes: '分钟',
  label_min_interval_between_plays: '播放之间的最小间隔（可选）',
  help_min_interval_between_plays: '每次播放之间的等待时间（0 表示无最小值）',
  label_max_plays_total: '总最大播放次数（可选）',
  placeholder_no_limit: '无上限请留空',
  help_max_plays_total: '终身限制——达到此次数后媒体将被永久锁定',
  label_expiration: '包到期日期时间（可选）',
  help_expiration: '到此日期/时间后包将永久锁定',
  section_playlist_limits: '播放列表级别限制（可选）',
  paragraph_playlist_limits: '这些限制适用于整个播放列表并控制总使用量。',
  label_playlist_max_items_session: '每次会话最大项目数（可选）',
  help_playlist_max_items_session: '每次会话的最大唯一文件数',
  label_session_reset_interval: '会话重置间隔（可选）',
  help_playlist_session_reset: '会话多久后重置，用户可播放新项目（留为 0 表示不重置）',
  label_playlist_min_interval_between_items: '项目之间的最小间隔（可选）',
  help_playlist_min_interval_between_items: '不同文件之间的等待时间（0 表示无最小值）',
  label_playlist_max_total_items: '播放的项目总数上限（可选）',
  help_playlist_max_total_items: '唯一文件的终身上限——达到此数量后播放列表将被永久锁定',
  label_playlist_expiration: '播放列表到期日期时间（可选）',
  help_playlist_expiration: '到此日期/时间后播放列表将永久锁定（可与包不同）',
  section_media_files: '媒体文件',
  button_add_media: '添加媒体文件',
  empty_no_media: '尚未添加任何文件',
  loading_creating_bundle: '正在创建包…',
  button_create_bundle: '创建包',
  button_reset_settings: '重置设置',
  tooltip_reset_settings: '将所有设置重置为默认值',
  button_reset_form: '清除文件和名称',
  tooltip_reset_form: '仅清除所选文件和包名称',
  device_id_badge: '设备 ID',
  details_max_plays: '最大播放',
  details_reset: '重置',
  details_interval: '间隔',
  details_none: '无',
  details_max_total_prefix: '总上限：',
  details_no_lifetime_limit: '无终身上限',
  details_free_preview_prefix: '预览：',
  remove: '移除',
  err_failed_add_media_prefix: '添加文件失败：',
  err_max_items_session_min: '每次会话的项目数至少为 1',
  err_max_total_items_min: '项目总数至少为 1',
  err_invalid_playlist_expiration: '播放列表到期日期无效',
  err_please_enter_bundle_name: '请输入包名称',
  err_please_enter_device_id: '请输入至少一个设备 ID',
  err_please_add_media: '请添加至少一个媒体文件',
  err_max_plays_at_least: '最大播放次数至少为 1',
  err_reset_interval_min: '重置间隔至少为 1 分钟',
  err_expiration_future: '到期日期必须在未来',
  success_title: '成功！',
  error_title: '错误！',
  bundle_created_title: '包创建成功！',
  location: '位置：',
  bundle_id: '包 ID：',
  files_processed: '处理的文件：',
  archive: '归档：',
  transfer_line1: '您现在可以将此安全的 .smbundle 文件传输到已授权设备。',
  transfer_line2: '该包已受保护并压缩以确保安全。',
  failed_create_prefix: '创建包失败：',
  ok: '确定'
};

i18n.strings.tpi = {
  app_title: 'Scripja Media Bundler',
  app_subtitle: 'Wokim seif bunol long ol makim-ap divais',
  language_settings_title: 'Tokples',
  system_default: 'Sistem i mak',
  section_bundle_config: 'Setim bunol',
  label_bundle_name: 'Ném bilong bunol *',
  placeholder_bundle_name: 'olsem: Luke_Gospel_Trial',
  label_device_ids: 'Ol Divais ID i gat pe (wan wan lain) *',
  placeholder_device_ids: 'Raitim ol ID bilong divais, wan wan long wanpela lain',
  section_playback_limits: 'Banis bilong plebek',
  label_max_plays: 'Max ples long wanpela reset taim *',
  help_max_plays: 'Hamaspela taim inap ple bipo long wetim reset',
  label_free_preview: 'Sekon bilong fri privyiu',
  help_free_preview: 'Hamaspela sekon bipo long kaunim (0 em long stopim)',
  label_reset_interval: 'Taim namel long reset *',
  label_days: 'De',
  label_hours: 'Awa',
  label_minutes: 'Minut',
  label_min_interval_between_plays: 'Min taim namel long ol ple (Opsenal)',
  help_min_interval_between_plays: 'Taim bilong wet namel long olgeta ple (0 em no gat min)',
  label_max_plays_total: 'Max ples long olgeta laip (Opsenal)',
  placeholder_no_limit: 'Larim i stap nating sapos no gat limit',
  help_max_plays_total: 'Laip taim limit — bihain long dispela namba, media i pas oltaim',
  label_expiration: 'De/taim bilong pinis bilong bunol (Opsenal)',
  help_expiration: 'Bunol i pas oltaim bihain long dispela de/taim',
  section_playlist_limits: 'Banis bilong playlist (Opsenal)',
  paragraph_playlist_limits: 'Ol dispela banis i holim olgeta playlist na kontrolim yus.',
  label_playlist_max_items_session: 'Max samting long wanpela sesen (Opsenal)',
  help_playlist_max_items_session: 'Namba bilong difren fail long wanpela sesen',
  label_session_reset_interval: 'Taim namel long reset bilong sesen (Opsenal)',
  help_playlist_session_reset: 'Hamaspela taim bipo sesen i reset na ol inap pilai nupela item (larim 0 sapos no reset)',
  label_playlist_min_interval_between_items: 'Min taim namel long ol samting (Opsenal)',
  help_playlist_min_interval_between_items: 'Taim bilong wet namel long difren fail (0 em no gat min)',
  label_playlist_max_total_items: 'Max olgeta samting i ple pinis (Opsenal)',
  help_playlist_max_total_items: 'Laip taim limit bilong difren fail — bihain long dispela namba playlist i pas tru',
  label_playlist_expiration: 'De/taim bilong pinis bilong playlist (Opsenal)',
  help_playlist_expiration: 'Playlist i pas oltaim bihain long dispela de/taim (i ken narakain long bunol)',
  section_media_files: 'Ol media fail',
  button_add_media: 'Putim ol media fail',
  empty_no_media: 'I no gat fail yet',
  loading_creating_bundle: 'Meikim bunol...',
  button_create_bundle: 'Meikim bunol',
  button_reset_settings: 'Risitim ol seting',
  tooltip_reset_settings: 'Risitim olgeta seting i go long defol',
  button_reset_form: 'Kliaim ol fail na ném',
  tooltip_reset_form: 'Kliaim tasol ol fail yu mak na ném bilong bunol',
  device_id_badge: 'Divais ID',
  details_max_plays: 'Max ple',
  details_reset: 'Risit',
  details_interval: 'Intaval',
  details_none: 'Nogat',
  details_max_total_prefix: 'Max olgeta:',
  details_no_lifetime_limit: 'Nogat laip taim limit',
  details_free_preview_prefix: 'Privyiu:',
  remove: 'Rimuv',
  err_failed_add_media_prefix: 'No inap putim ol fail: ',
  err_max_items_session_min: 'Ol samting long sesen i mas 1 o moa',
  err_max_total_items_min: 'Olgeta samting i mas 1 o moa',
  err_invalid_playlist_expiration: 'De bilong pinis bilong playlist i no stret',
  err_please_enter_bundle_name: 'Plis raitim ném bilong bunol',
  err_please_enter_device_id: 'Plis putim wanpela Divais ID o moa',
  err_please_add_media: 'Plis putim wanpela media fail o moa',
  err_max_plays_at_least: 'Max ple i mas 1 o moa',
  err_reset_interval_min: 'Taim namel long reset i mas 1 minit o moa',
  err_expiration_future: 'De bilong pinis i mas i stap bihain',
  success_title: 'Orrait!',
  error_title: 'Problem!',
  bundle_created_title: 'Bunol i redi pinis!',
  location: 'Ples:',
  bundle_id: 'Bunol ID:',
  files_processed: 'Ol fail yu wokim:',
  archive: 'Kaikai bilong fail:',
  transfer_line1: 'Nau yu ken salim dispela seif .smbundle fail i go long ol divais i gat pe.',
  transfer_line2: 'Bunol i seif na i kisim smolpela mak bilong kisim gutpela seif.',
  failed_create_prefix: 'No inap mekim bunol: ',
  ok: 'OK'
};

function detectLocale() {
  const pref = localStorage.getItem(LOCALE_STORAGE_KEY);
  if (pref && pref !== 'system') return pref;
  const nav = (navigator.language || 'en').toLowerCase();
  const code = nav.split('-')[0];
  return SUPPORTED_LOCALES.includes(code) ? code : 'en';
}

function t(key) {
  const code = detectLocale();
  const table = i18n.strings[code] || i18n.strings.en;
  return (table && table[key]) || (i18n.strings.en[key] || key);
}

function applyI18n() {
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const k = el.getAttribute('data-i18n');
    if (k) el.innerText = t(k);
  });
  document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
    const k = el.getAttribute('data-i18n-placeholder');
    if (k) el.setAttribute('placeholder', t(k));
  });
  document.querySelectorAll('[data-i18n-title]').forEach(el => {
    const k = el.getAttribute('data-i18n-title');
    if (k) el.setAttribute('title', t(k));
  });
  const titleEl = document.querySelector('title[data-i18n]');
  if (titleEl) titleEl.innerText = t(titleEl.getAttribute('data-i18n'));
  const langSelectEl = document.getElementById('lang-select');
  if (langSelectEl) {
    const stored = localStorage.getItem(LOCALE_STORAGE_KEY) || 'system';
    langSelectEl.value = stored;
  }
  // Update modal button label if present
  const modalOk = document.getElementById('modal-ok');
  if (modalOk) modalOk.innerText = t('ok');
}

let mediaFiles = [];
const STORAGE_KEY = 'bundlerStateV1';
let lastOutputDir = null;

// DOM Elements
const bundleNameInput = document.getElementById('bundle-name');
const deviceIdsInput = document.getElementById('device-ids');
const deviceIdsDisplay = document.getElementById('device-ids-display');
const maxPlaysInput = document.getElementById('max-plays');
const freePreviewSecondsInput = document.getElementById('free-preview-seconds');
const resetDaysInput = document.getElementById('reset-days');
const resetHoursInput = document.getElementById('reset-hours');
const resetMinutesInput = document.getElementById('reset-minutes');
const intervalDaysInput = document.getElementById('interval-days');
const intervalHoursInput = document.getElementById('interval-hours');
const intervalMinutesInput = document.getElementById('interval-minutes');
const maxPlaysTotalInput = document.getElementById('max-plays-total');
const expirationDateInput = document.getElementById('expiration-date');
const addMediaButton = document.getElementById('add-media-button');
const mediaList = document.getElementById('media-list');
const createBundleButton = document.getElementById('create-bundle-button');
const resetFormButton = document.getElementById('reset-form-button');
const resetSettingsButton = document.getElementById('reset-settings-button');
// Modal elements
const modalOverlay = document.getElementById('modal-overlay');
const modalTitle = document.getElementById('modal-title');
const modalBody = document.getElementById('modal-body');
const modalOk = document.getElementById('modal-ok');

function openModal(titleText, htmlBody) {
  if (!modalOverlay || !modalTitle || !modalBody) return;
  modalTitle.innerText = titleText || '';
  modalBody.innerHTML = htmlBody || '';
  modalOverlay.style.display = 'flex';
}

function closeModal() {
  if (!modalOverlay) return;
  modalOverlay.style.display = 'none';
}
const messageContainer = document.getElementById('message-container');
const loadingDiv = document.getElementById('loading');
const langSelect = document.getElementById('lang-select');

// Playlist-level limit DOM elements
const playlistMaxItemsSessionInput = document.getElementById('playlist-max-items-session');
const sessionResetDaysInput = document.getElementById('session-reset-days');
const sessionResetHoursInput = document.getElementById('session-reset-hours');
const sessionResetMinutesInput = document.getElementById('session-reset-minutes');
const playlistIntervalDaysInput = document.getElementById('playlist-interval-days');
const playlistIntervalHoursInput = document.getElementById('playlist-interval-hours');
const playlistIntervalMinutesInput = document.getElementById('playlist-interval-minutes');
const playlistMaxTotalItemsInput = document.getElementById('playlist-max-total-items');
const playlistExpirationDateInput = document.getElementById('playlist-expiration-date');

// Event Listeners
deviceIdsInput.addEventListener('input', () => { updateDeviceIdsDisplay(); saveState(); });
addMediaButton.addEventListener('click', handleAddMedia);
createBundleButton.addEventListener('click', handleCreateBundle);
resetFormButton.addEventListener('click', handleResetForm);
resetSettingsButton.addEventListener('click', handleResetSettings);
if (langSelect) {
  langSelect.addEventListener('change', () => {
    const val = langSelect.value;
    if (val === 'system') localStorage.setItem(LOCALE_STORAGE_KEY, 'system');
    else localStorage.setItem(LOCALE_STORAGE_KEY, val);
    applyI18n();
    renderMediaList();
  });
}

// Modal events
if (modalOk) modalOk.addEventListener('click', closeModal);
if (modalOverlay) modalOverlay.addEventListener('click', (e) => {
  if (e.target === modalOverlay) closeModal();
});

// Persist on all input changes
[
  bundleNameInput,
  maxPlaysInput,
  freePreviewSecondsInput,
  resetDaysInput,
  resetHoursInput,
  resetMinutesInput,
  intervalDaysInput,
  intervalHoursInput,
  intervalMinutesInput,
  maxPlaysTotalInput,
  expirationDateInput,
  playlistMaxItemsSessionInput,
  sessionResetDaysInput,
  sessionResetHoursInput,
  sessionResetMinutesInput,
  playlistIntervalDaysInput,
  playlistIntervalHoursInput,
  playlistIntervalMinutesInput,
  playlistMaxTotalItemsInput,
  playlistExpirationDateInput,
].forEach(el => el.addEventListener('input', saveState));

// Functions
function calculatePlaybackLimit() {
  const resetDays = parseInt(resetDaysInput.value) || 0;
  const resetHours = parseInt(resetHoursInput.value) || 0;
  const resetMinutes = parseInt(resetMinutesInput.value) || 0;
  const resetIntervalMs = (resetDays * 24 * 60 * 60 * 1000) + (resetHours * 60 * 60 * 1000) + (resetMinutes * 60 * 1000);
  
  const intervalDays = parseInt(intervalDaysInput.value) || 0;
  const intervalHours = parseInt(intervalHoursInput.value) || 0;
  const intervalMinutes = parseInt(intervalMinutesInput.value) || 0;
  const minIntervalMs = (intervalDays * 24 * 60 * 60 * 1000) + (intervalHours * 60 * 60 * 1000) + (intervalMinutes * 60 * 1000);
  
  const maxPlaysTotalValue = maxPlaysTotalInput.value.trim();
  const maxPlaysTotal = maxPlaysTotalValue ? parseInt(maxPlaysTotalValue) : null;
  const freePreviewSeconds = Math.max(0, parseInt(freePreviewSecondsInput.value) || 0);
  
  return {
    maxPlays: parseInt(maxPlaysInput.value),
    resetIntervalMs: resetIntervalMs || 24 * 60 * 60 * 1000, // Default to 24 hours
    minIntervalBetweenPlaysMs: minIntervalMs || null,
    maxPlaysTotal: maxPlaysTotal,
    freePreviewSeconds
  };
}

function calculatePlaylistLimits() {
  const maxItemsSessionValue = playlistMaxItemsSessionInput.value.trim();
  const maxItemsPerSession = maxItemsSessionValue ? parseInt(maxItemsSessionValue) : null;
  
  // Validate maxItemsPerSession
  if (maxItemsPerSession !== null && (isNaN(maxItemsPerSession) || maxItemsPerSession < 1)) {
    throw new Error('Max items per session must be at least 1');
  }
  
  const sessionDays = Math.max(0, parseInt(sessionResetDaysInput.value) || 0);
  const sessionHours = Math.max(0, parseInt(sessionResetHoursInput.value) || 0);
  const sessionMinutes = Math.max(0, parseInt(sessionResetMinutesInput.value) || 0);
  const sessionResetMs = (sessionDays * 24 * 60 * 60 * 1000) + (sessionHours * 60 * 60 * 1000) + (sessionMinutes * 60 * 1000);
  
  const playlistIntervalDays = Math.max(0, parseInt(playlistIntervalDaysInput.value) || 0);
  const playlistIntervalHours = Math.max(0, parseInt(playlistIntervalHoursInput.value) || 0);
  const playlistIntervalMinutes = Math.max(0, parseInt(playlistIntervalMinutesInput.value) || 0);
  const minIntervalBetweenItemsMs = (playlistIntervalDays * 24 * 60 * 60 * 1000) + (playlistIntervalHours * 60 * 60 * 1000) + (playlistIntervalMinutes * 60 * 1000);
  
  const maxTotalItemsValue = playlistMaxTotalItemsInput.value.trim();
  const maxTotalItemsPlayed = maxTotalItemsValue ? parseInt(maxTotalItemsValue) : null;
  
  // Validate maxTotalItemsPlayed
  if (maxTotalItemsPlayed !== null && (isNaN(maxTotalItemsPlayed) || maxTotalItemsPlayed < 1)) {
    throw new Error('Max total items played must be at least 1');
  }
  
  const playlistExpirationValue = playlistExpirationDateInput.value;
  let playlistExpiration = null;
  if (playlistExpirationValue) {
    const expirationDate = new Date(playlistExpirationValue);
    if (isNaN(expirationDate.getTime())) {
      throw new Error('Invalid playlist expiration date');
    }
    playlistExpiration = expirationDate.toISOString();
  }
  
  return {
    maxItemsPerSession: maxItemsPerSession,
    sessionResetIntervalMs: sessionResetMs > 0 ? sessionResetMs : null,
    minIntervalBetweenItemsMs: minIntervalBetweenItemsMs > 0 ? minIntervalBetweenItemsMs : null,
    maxTotalItemsPlayed: maxTotalItemsPlayed,
    expirationDate: playlistExpiration
  };
}

function updateDeviceIdsDisplay() {
  const deviceIds = deviceIdsInput.value
    .split('\n')
    .map(id => id.trim())
    .filter(id => id.length > 0);

  deviceIdsDisplay.innerHTML = '';
  
  if (deviceIds.length > 0) {
    deviceIds.forEach(id => {
      const tag = document.createElement('div');
      tag.className = 'device-id-tag';
      tag.textContent = id;
      deviceIdsDisplay.appendChild(tag);
    });
  }
}

async function handleAddMedia() {
  try {
    const filePaths = await ipcRenderer.invoke('select-media-files');
    
    if (filePaths.length === 0) {
      return;
    }

    const playbackLimit = calculatePlaybackLimit();

    for (const filePath of filePaths) {
      const fileInfo = await ipcRenderer.invoke('get-file-info', filePath);
      
      if (fileInfo) {
        mediaFiles.push({
          path: filePath,
          name: fileInfo.name,
          size: fileInfo.size,
          type: fileInfo.type,
          title: fileInfo.name.replace(/\.[^/.]+$/, ''),
          playbackLimit: { ...playbackLimit }
        });
      }
    }

    renderMediaList();
    saveState();
  } catch (error) {
    showError(t('err_failed_add_media_prefix') + error.message);
  }
}

function renderMediaList() {
  if (mediaFiles.length === 0) {
    mediaList.innerHTML = `<div class="empty-state">${t('empty_no_media')}</div>`;
    return;
  }

  mediaList.innerHTML = '';

  mediaFiles.forEach((file, index) => {
    const item = document.createElement('div');
    item.className = 'media-item';

    const sizeInMB = (file.size / (1024 * 1024)).toFixed(2);
    
    // Format time intervals for display
    const resetMs = file.playbackLimit.resetIntervalMs || 0;
    const resetDays = Math.floor(resetMs / (24 * 60 * 60 * 1000));
    const resetHours = Math.floor((resetMs % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    const resetMinutes = Math.floor((resetMs % (60 * 60 * 1000)) / (60 * 1000));
    const resetStr = [
      resetDays > 0 ? `${resetDays}d` : '',
      resetHours > 0 ? `${resetHours}h` : '',
      resetMinutes > 0 ? `${resetMinutes}m` : ''
    ].filter(s => s).join(' ') || '0m';

    const minIntervalMs = file.playbackLimit.minIntervalBetweenPlaysMs || 0;
    const intervalDays = Math.floor(minIntervalMs / (24 * 60 * 60 * 1000));
    const intervalHours = Math.floor((minIntervalMs % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    const intervalMinutes = Math.floor((minIntervalMs % (60 * 60 * 1000)) / (60 * 1000));
    const intervalStr = minIntervalMs > 0 ? [
      intervalDays > 0 ? `${intervalDays}d` : '',
      intervalHours > 0 ? `${intervalHours}h` : '',
      intervalMinutes > 0 ? `${intervalMinutes}m` : ''
    ].filter(s => s).join(' ') : t('details_none');

    const maxTotalStr = file.playbackLimit.maxPlaysTotal ? `${t('details_max_total_prefix')} ${file.playbackLimit.maxPlaysTotal}` : t('details_no_lifetime_limit');
  const freePreviewStr = `${t('details_free_preview_prefix')} ${file.playbackLimit.freePreviewSeconds ?? 5}s`;

    item.innerHTML = `
      <div class="media-info">
        <div class="media-name">${file.name}</div>
        <div class="media-details">
          ${file.type.toUpperCase()} • ${sizeInMB} MB • 
          ${t('details_max_plays')}: ${file.playbackLimit.maxPlays} • 
          ${t('details_reset')}: ${resetStr} • 
          ${t('details_interval')}: ${intervalStr} • 
          ${maxTotalStr} • ${freePreviewStr}
        </div>
      </div>
      <div class="media-settings">
  <button class="remove-button" data-index="${index}">${t('remove')}</button>
      </div>
    `;

    const removeButton = item.querySelector('.remove-button');
    removeButton.addEventListener('click', () => removeMedia(index));

    mediaList.appendChild(item);
  });
}

function removeMedia(index) {
  mediaFiles.splice(index, 1);
  renderMediaList();
  saveState();
}

async function handleCreateBundle() {
  try {
    // Validate inputs
    const bundleName = bundleNameInput.value.trim();
    if (!bundleName) {
      showError(t('err_please_enter_bundle_name'));
      return;
    }

    const deviceIds = deviceIdsInput.value
      .split('\n')
      .map(id => id.trim())
      .filter(id => id.length > 0);

    if (deviceIds.length === 0) {
      showError(t('err_please_enter_device_id'));
      return;
    }

    if (mediaFiles.length === 0) {
      showError(t('err_please_add_media'));
      return;
    }

    const maxPlays = parseInt(maxPlaysInput.value);
    const playbackLimit = calculatePlaybackLimit();

    if (maxPlays < 1) {
      showError(t('err_max_plays_at_least'));
      return;
    }

    if (playbackLimit.resetIntervalMs < 60000) {
      showError(t('err_reset_interval_min'));
      return;
    }

    // Validate expiration date if set
    let expirationDate = null;
    if (expirationDateInput.value) {
      expirationDate = new Date(expirationDateInput.value).toISOString();
      if (new Date(expirationDate) <= new Date()) {
        showError(t('err_expiration_future'));
        return;
      }
    }

    // Validate and calculate playlist limits
    let playlistLimits;
    try {
      playlistLimits = calculatePlaylistLimits();
    } catch (error) {
      const msg = String(error.message || '');
      if (msg.includes('Max items per session')) {
        showError(t('err_max_items_session_min'));
      } else if (msg.includes('Max total items played')) {
        showError(t('err_max_total_items_min'));
      } else if (msg.includes('Invalid playlist expiration')) {
        showError(t('err_invalid_playlist_expiration'));
      } else {
        showError(error.message);
      }
      return;
    }

    // Select output directory
    const outputDir = await ipcRenderer.invoke('select-output-directory', { defaultPath: lastOutputDir });
    if (!outputDir) {
      return;
    }
    lastOutputDir = outputDir;

    // Show loading
    loadingDiv.classList.add('active');
    createBundleButton.disabled = true;

    // Create bundle
    const result = await ipcRenderer.invoke('create-bundle', {
      name: bundleName,
      deviceIds,
      mediaFiles,
      playbackLimits: {
        default: playbackLimit
      },
      playlistLimits: playlistLimits,
      expirationDate,
      outputDir
    });

    loadingDiv.classList.remove('active');
    createBundleButton.disabled = false;

    if (result.success) {
      showSuccess(`${t('bundle_created_title')}
        
${t('location')} ${result.bundleDir}
${t('bundle_id')} ${result.bundleId}
${t('files_processed')} ${result.filesProcessed}
${t('archive')} ${result.archiveName}

${t('transfer_line1')}
${t('transfer_line2')}`);

      // Persist last output dir and keep the current form/files for convenience
      saveState();
    } else {
      showError(t('failed_create_prefix') + result.error);
    }
  } catch (error) {
    loadingDiv.classList.remove('active');
    createBundleButton.disabled = false;
    showError(t('failed_create_prefix') + error.message);
  }
}

function showSuccess(message) {
  // Use custom non-blocking modal in front of the app
  const bodyHtml = (message || '').replace(/\n/g, '<br>');
  openModal(t('bundle_created_title'), bodyHtml);
}

function showError(message) {
  messageContainer.innerHTML = `
    <div class="error-message">
      <strong>${t('error_title')}</strong><br>
      ${message}
    </div>
  `;
  
  setTimeout(() => {
    messageContainer.innerHTML = '';
  }, 5000);
}

// Initialize
applyI18n();
updateDeviceIdsDisplay();
loadState();

function handleResetForm() {
  // Clear only bundle name and selected files; keep device IDs and settings
  bundleNameInput.value = '';
  mediaFiles = [];
  renderMediaList();
  saveState();
}

function handleResetSettings() {
  // Reset playback defaults
  maxPlaysInput.value = '3';
  freePreviewSecondsInput.value = '5';
  resetDaysInput.value = '0';
  resetHoursInput.value = '24';
  resetMinutesInput.value = '0';
  intervalDaysInput.value = '0';
  intervalHoursInput.value = '0';
  intervalMinutesInput.value = '0';
  maxPlaysTotalInput.value = '';
  expirationDateInput.value = '';

  // Reset playlist limits
  playlistMaxItemsSessionInput.value = '';
  sessionResetDaysInput.value = '0';
  sessionResetHoursInput.value = '0';
  sessionResetMinutesInput.value = '0';
  playlistIntervalDaysInput.value = '0';
  playlistIntervalHoursInput.value = '0';
  playlistIntervalMinutesInput.value = '0';
  playlistMaxTotalItemsInput.value = '';
  playlistExpirationDateInput.value = '';

  saveState();
}

function saveState() {
  try {
    const state = {
      bundleName: bundleNameInput.value,
      deviceIdsRaw: deviceIdsInput.value,
      playbackDefaults: {
        maxPlays: maxPlaysInput.value,
        freePreviewSeconds: freePreviewSecondsInput.value,
        resetDays: resetDaysInput.value,
        resetHours: resetHoursInput.value,
        resetMinutes: resetMinutesInput.value,
        intervalDays: intervalDaysInput.value,
        intervalHours: intervalHoursInput.value,
        intervalMinutes: intervalMinutesInput.value,
        maxPlaysTotal: maxPlaysTotalInput.value,
        expirationDate: expirationDateInput.value,
      },
      playlistLimits: {
        maxItemsPerSession: playlistMaxItemsSessionInput.value,
        sessionResetDays: sessionResetDaysInput.value,
        sessionResetHours: sessionResetHoursInput.value,
        sessionResetMinutes: sessionResetMinutesInput.value,
        intervalDays: playlistIntervalDaysInput.value,
        intervalHours: playlistIntervalHoursInput.value,
        intervalMinutes: playlistIntervalMinutesInput.value,
        maxTotalItemsPlayed: playlistMaxTotalItemsInput.value,
        expirationDate: playlistExpirationDateInput.value,
      },
      mediaFiles,
      lastOutputDir,
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (e) {
    // ignore persistence errors
  }
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    const state = JSON.parse(raw);
    if (!state || typeof state !== 'object') return;
    bundleNameInput.value = state.bundleName || '';
    deviceIdsInput.value = state.deviceIdsRaw || '';
    updateDeviceIdsDisplay();
    if (state.playbackDefaults) {
      maxPlaysInput.value = state.playbackDefaults.maxPlays ?? '3';
      freePreviewSecondsInput.value = state.playbackDefaults.freePreviewSeconds ?? '5';
      resetDaysInput.value = state.playbackDefaults.resetDays ?? '0';
      resetHoursInput.value = state.playbackDefaults.resetHours ?? '24';
      resetMinutesInput.value = state.playbackDefaults.resetMinutes ?? '0';
      intervalDaysInput.value = state.playbackDefaults.intervalDays ?? '0';
      intervalHoursInput.value = state.playbackDefaults.intervalHours ?? '0';
      intervalMinutesInput.value = state.playbackDefaults.intervalMinutes ?? '0';
      maxPlaysTotalInput.value = state.playbackDefaults.maxPlaysTotal ?? '';
      // datetime-local expects local formatted string; keep as previously entered string
      expirationDateInput.value = state.playbackDefaults.expirationDate || '';
    }
    if (state.playlistLimits) {
      playlistMaxItemsSessionInput.value = state.playlistLimits.maxItemsPerSession ?? '';
      sessionResetDaysInput.value = state.playlistLimits.sessionResetDays ?? '0';
      sessionResetHoursInput.value = state.playlistLimits.sessionResetHours ?? '0';
      sessionResetMinutesInput.value = state.playlistLimits.sessionResetMinutes ?? '0';
      playlistIntervalDaysInput.value = state.playlistLimits.intervalDays ?? '0';
      playlistIntervalHoursInput.value = state.playlistLimits.intervalHours ?? '0';
      playlistIntervalMinutesInput.value = state.playlistLimits.intervalMinutes ?? '0';
      playlistMaxTotalItemsInput.value = state.playlistLimits.maxTotalItemsPlayed ?? '';
      playlistExpirationDateInput.value = state.playlistLimits.expirationDate || '';
    }
    if (Array.isArray(state.mediaFiles)) {
      mediaFiles = state.mediaFiles;
      renderMediaList();
    }
    lastOutputDir = state.lastOutputDir || null;
  } catch (e) {
    // ignore load errors
  }
}
