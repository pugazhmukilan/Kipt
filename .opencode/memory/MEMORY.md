# KIPT — CODEBASE MEMORY
<!-- Machine-readable project memory for opencode agents. Parse by section tags. Format: [TAG] fact -->

## [INDEX]
- Quick nav: [PROJECT] → what the app is · [ARCH] → structure & layers · [MODEL] → data model ·
  [FEATURES] → implemented features · [CONVENTIONS] → code style · [GOTCHAS] → pitfalls · [FILES] → key file map · [TASKS] → in-progress context
- This file is the single source of truth. Update it, don't fork it.

## [PROJECT]
- [NAME] App brand: "Item Vault" (app_constants.dart), repo/marketing name: Kipt, package db: kipt.db
- [VERSION] appVersion = '2.0.4', DB version = 9 (schema_version in backup = 7)
- [NATURE] Offline-first personal item vault: record any possession/document with custom fields
  (TEXT, DATE, PASSWORD), attachments (photos + PDFs), reminders, tags, categories, favorites
- [LINEAGE] v1 was a rigid "warranty manager" (products/notes tables, README.md still reflects this — STALE).
  v2 is generic "item + field" model; products/notes now only exist as legacy migration drops.
- [POSITIONING] Competes with: shoebox of receipts, warranty cards, spreadsheet trackers. Key differentiators:
  fully offline, flexible field model, hardware-secured passwords, one-tap PDF reports, ZIP backup.

## [ARCH]
- [STACK] Flutter + Dart. State: BLoC/Cubit (flutter_bloc). DB: sqlite via database_helper (NOT Hive despite old README badge). Prefs: SharedPreferences. PDF: pdf + printing. Images: image_picker, image_gallery_saver_plus, in-app camera_screen. Biometrics: local_auth. Archive: archive (ZIP). Docs: file_picker, share_plus, path, path_provider, intl. OCR flow: custom BillParser (core/utils/bill_parser.dart) over OCR-extracted text.
- [LAYERS]
  - lib/core → constants, theme, utils (dates, image helpers, bill_parser), navigation observer, spacing
  - lib/data/database → database_helper (migrations up to v9)
  - lib/data/models → Item, ItemField, Category, Attachment, ItemWithDetails (list-unit + DashboardStats)
  - lib/data/repositories → item_repository, image_storage_service, notification_service, item_pdf_service,
    backup_service, auth_service, secure_field_service
  - lib/presentation/bloc → item, backup, notification blocs + theme cubit
  - lib/presentation/screens → splash, welcome, home, items_list, add, edit, item_detail, item_preview,
    search, notifications, camera, auth, settings, categories, about
  - lib/presentation/widgets → field_slot, field_editor_widget, field_entry_dialog, add_field_sheet,
    login_block_widget, login_detail_block_widget, tag_chip_input_widget, status_badge_widget,
    attachment_grid_widget, dashboard_stats_widget, favorite_seal_widget, item_card_widget, common_widgets
- [DI] main.dart wires blocs + services; item_repository injected into screens via BlocProvider

## [MODEL]
- [ITEM] id, title, categoryId, tags(JSON string), notes, favorite, createdAt, updatedAt. Extends Equatable.
- [ITEMFIELD] id, itemId, label, fieldType(TEXT|DATE|PASSWORD), value, loginTitle, reminderEnabled,
  reminderLeadDays, sortOrder. PASSWORD.value = secure-storage KEY REFERENCE, not plaintext (secure_field_service).
- [DATE FIELD STATUS] FieldStatus enum: active | expiringSoon | expired | noReminder.
  lead default 30d; expiringSoon = date within lead window; expired = past date.
- [LOGIN PAIRS] represented by consecutive fields sharing loginTitle; title stored on the Username row.
- [DASHBOARD STATS] computed at FIELD level per item_with_details.dart §5: active/expiringSoon/expired counts.
- [ITEM_WITH_DETAILS] = Item + fields + attachments + categoryName. Most-urgent status logic:
  expired > expiringSoon > active. firstPhoto used for list thumbnails.
- [CATEGORIES] presets in app_constants: General, Personal, Finance, Health, Documents, Vehicle, Home, Tech, Other.
- [PREFS KEYS] theme_mode, default_lead_days, notification_enabled, last_backup_date, onboarding_complete,
  biometric_enabled, grid_columns, sort_by (date_added | name | category)
- [CONSTANTS OF INTEREST] clipboardClearSeconds=45, passwordRemaskSeconds=20, fieldsCollapseThreshold=5,
  leadTimeOptions=[7,30,60,90], imageQuality=85, notificationChannelId='kipt_reminders'

## [FEATURES]
- [SECURITY] App lock (local_auth biometric/PIN); auto re-lock on resume-from-background (home_screen lifecycle
  observer) EXCEPT while a picker is active (ImagePickerHelper.isPickerActive guard) or on auth/settings screens.
  Password reveal → biometric each time; remask after 20s; clipboard clear after 45s.
- [REMINDERS] per-DATE-field toggle + lead days; flutter_local_notifications; channel 'kipt_reminders'.
- [BILL OCR] bill_parser.dart extracts: seller, buyer, invoice no, date, currency, subtotal, tax(gst/cgst/sgst/
  igst/vat), total, payment method, GSTIN (regex), phone, email. Heuristic label matching.
- [PDF EXPORT] item_pdf_service.buildItemPdf(ItemWithDetails, {passwordValues}). Renders EVERY field
  (never drops data); PASSWORD row masked '******** (protected)' unless decrypted values passed after auth.
  Photos: 2-col grid, 6/page. Attached PDFs rasterized page-by-page → one self-contained PDF. Teal brand palette.
- [BACKUP] backup_service: ZIP = data.json (categories, items[fields,attachments]) + images/ folder.
  PASSWORD fields EXCLUDED from export (spec §6). Import restores full DB + copies attachments.
- [ATTACHMENTS] photos (in-app camera with aspect-ratio control, or gallery) + picker PDFs; quick actions:
  save-to-gallery, share. attachment_grid on detail/edit.
- [ORGANIZE] search screen, sort (name/date_added/category), grid columns pref, favorites pin, tags chips.
- [THEME] light/dark theme cubit, persisted theme_mode; AppTheme in core/theme/app_theme.dart; spacing tokens lib/core/spacing.dart

## [CONVENTIONS]
- State management strictly via Bloc events/states; repositories never called directly inside widgets except legacy spots ( Bloc item_repository in add_item_screen still direct)
- Models: Equatable, toMap/fromMap manual (no codegen), toJson/fromJson pass-through aliases
- Constants: every literal goes in AppConstants — no magic strings (DB names, pref keys, formats)
- Comments: sparse; only used for spec-section references (e.g. "spec §5", "spec §6") — keep that style when touching related logic
- Strict analysis_options.yaml: prefer consts (widget const everywhere)

## [GOTCHAS]
- [STALE-DOCS] README.md, DARK_THEME_UPDATE.md, PDF_*.md, TESTING_GUIDE.md describe the OLD v1 product-model.
  Verify against lib/ code before trusting them. PRIVACY_POLICY.md is current and matches v2 behavior.
- [VERSION-SKEW] appVersion 2.0.4 vs DB version 9 vs backup schema_version 7 are independent counters — bump DB version on table changes, schema_version separately if backup format changes.
- [SECURE-VALUE] NEVER write PASSWORD field values into the plain DB — save a key/alias and resolve via secure_field_service; backups skip password fields by design.
- [LIFECYCLE] auto-relock must keep the ImagePickerHelper.isPickerActive exception — native camera/gallery pickers trigger a paused/resumed cycle inside normal app flow; removing the guard would cause a re-auth prompt after taking a bill photo.
- [DATE-TOLERANCE] Item date parsing is lenient (falls back to epoch) — corrupt rows must not crash the list; extend this pattern for any new serialized field.
- Add-item flow still references item_repository directly via context; check whether Bloc migration intended.

## [FILES] — quick map (repo-relative)
- lib/main.dart → entry, DI wiring, blocs
- lib/core/constants/app_constants.dart → ALL literals (SEE [MODEL]/VERSION rows)
- lib/core/utils/bill_parser.dart → OCR heuristic parse (~326 lines)
- lib/data/database/database_helper.dart → schema v9, migrations, legacy products/notes drop
- lib/data/models/item_field.dart → field types, status/daysRemaining logic
- lib/data/models/item_with_details.dart → list unit + DashboardStats + urgency helpers
- lib/data/repositories/secure_field_service.dart → password storage/reveal
- lib/data/repositories/item_pdf_service.dart → branded single-item PDF (~726 lines)
- lib/data/repositories/backup_service.dart → ZIP export/import
- lib/data/repositories/auth_service.dart → app-lock enablement + biometric verify
- lib/presentation/screens/home_screen.dart → lifecycle relock + route-aware reload
- lib/presentation/widgets/field_slot.dart + login_block_widget.dart → flexible-field & credential editors
- APP_GUIDE.md → non-technical feature/usage README (audience: end users) — wrote Oct 19 2026, kept separate from technical README.md
- PRIVACY_POLICY.md → current v2 privacy doc; placeholder support email must be replaced pre-publication

## [TASKS]
- [KNOWN-DISCUSSED] Two-test-item docs pressure: technical README.md (stale warranty-era) vs APP_GUIDE.md (feature guide) — maybe consolidate later; keep APP_GUIDE.md authoritative for user-facing copy.
- [OPEN-Q] Bill OCR pipeline source:icker (mlkit?) not located yet — camera_screen likely feeds bill_parser; verify provider if OCR changes are requested.
- [DOC-DEBT] LEGACY .md files (PDF_*, DARK_THEME_UPDATE, TESTING_GUIDE) unreviewed vs v2 — audit if they surface bugs.
