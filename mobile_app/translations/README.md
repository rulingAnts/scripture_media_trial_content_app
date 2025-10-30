# Translation templates

These templates help contributors add or refine UI translations for the mobile app.

The app supports two overlay formats when you import a JSON file via the Language settings screen:

1) Flat map (applies to the currently selected UI language)
- Shape: `{ "key": "translation" }`
- Use this when you want to provide translations for one language at a time.

2) Multi-locale map (contains multiple locales in one file)
- Shape: `{ "<localeCode>": { "key": "translation" }, ... }`
- Use this to ship translations for many locales in one JSON.

Notes:
- Placeholders must be preserved exactly. Examples: `{name}`, `{duration}`, `{date}`, `{max}`, `{message}`, `{reason}`.
- Duration units use abbreviations per locale (`abbr_day`, `abbr_hour`, `abbr_minute`, `abbr_second`). Keep them short; they are used in compact counters (e.g., `2h 5m`).
- If a key is missing in your custom file, the app falls back to the built‑in base language (English).
- JSON does not support comments; keep files pure JSON.

## Files in this folder

- `template_flat_en.json` — A ready‑to‑translate flat template containing all keys with English values. Duplicate this file and translate the values for your target language. When importing as a flat map, the strings will apply to the currently selected UI language.
- `template_by_locale_all.json` — A multi‑locale skeleton containing all keys for each supported locale with empty values. Fill in values per locale and import the single file to provide multiple languages at once.

## Supported locale codes

- en, es, fr, de, nl, af, pt, id, ru, hi, ar, zh, tpi

## Example (flat map)

```json
{
  "app_title": "Reproductor de demostración de Escrituras",
  "status_import_ready": "Paquete importado y listo.",
  "ui_resets_in": " · se restablece en {duration}"
}
```

## Example (multi‑locale)

```json
{
  "es": {
    "app_title": "Reproductor de demostración de Escrituras",
    "ui_resets_in": " · se restablece en {duration}"
  },
  "fr": {
    "app_title": "Lecteur de démo des Écritures",
    "ui_resets_in": " · se réinitialise dans {duration}"
  }
}
```

## How to use in the app

1. Open the app → Settings (gear icon) → Language.
2. Pick your target UI language.
3. Tap "Add custom JSON" and select your JSON file (flat or multi‑locale).
4. The app will overlay your translations on top of the built‑ins. You can remove the overlay anytime via "Remove custom translations".

## QA checklist for translations

- All placeholders preserved exactly and appear correctly in the UI.
- Pluralization is acceptable in the target language within the current key set.
- Shortened unit labels fit in compact spaces (e.g., `1d 2h`).
- Error and status messages are clear and consistent.
