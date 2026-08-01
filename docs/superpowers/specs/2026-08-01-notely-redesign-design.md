# Notely UI Redesign — Design Spec

## Overview

Rebrand "Note Log" to **Notely** and apply the "Notely — Notes List" design language (from `docs/design/Notely Notes List.html` and its `src/*.jsx` files) across the whole Flutter app. The design file provides a hi-fi, interactive spec for the notes list (3 variants), an account sheet, a compose sheet, and system tokens. We adopt **Variant A · Editorial** as the primary list design, with the user's requested personalization: the serif display title reads **"Your notes, *{First Name}*"**.

The full app is restyled in this language — list, editor, account sheet, auth views, lock screen, study review, version history, and context switcher — so the UX feels and looks consistent everywhere, even though the design file only shows the list and sheets.

## Design Source

- `docs/design/Notely Notes List.html` — interactive canvas (3 variants, light/dark, live tweaks)
- `docs/design/src/theme.jsx` — color tokens, fonts, TagPill / Avatar / Wordmark primitives
- `docs/design/src/variant-editorial.jsx` — Variant A (hero list, swipe-to-archive, multi-select, sort, FAB)
- `docs/design/src/sheets.jsx` — account sheet, compose sheet
- `docs/design/src/data.jsx` — 8-tag taxonomy and sample notes
- `docs/design/src/icons.jsx` — stroke icon set (search, pin, archive, trash, sort, plus, mic, cloud, logout, chevron, check, more, edit, back)

Chosen tweaks (from the design's defaults, confirmed with user): variant **editorial**, density **cozy**, radius **18**, tagStyle **pill**, fabStyle **pillLabel**.

## §1 Design System Foundation (`lib/core/theme/`)

All tokens below are taken verbatim from the design.

### NotelyTheme (ThemeExtension) — `notely_tokens.dart`

| Token | Light | Dark |
|---|---|---|
| bg | `#FAF8F5` | `#0E0B14` |
| surface | `#FFFFFF` | `#17131F` |
| surface2 | `#F3F0EB` | `#1E1928` |
| border | `rgba(28,20,40,0.07)` | `rgba(255,255,255,0.08)` |
| borderStrong | `rgba(28,20,40,0.12)` | `rgba(255,255,255,0.14)` |
| text | `#1B1427` | `#F5F2FB` |
| text2 | 68% ink | 72% ink |
| text3 | 44% ink | 48% ink |
| text4 | 28% ink | 28% ink |
| violet (brand) | `#A78BFA` | `#A78BFA` |
| violetDeep | `#7C5CF5` | `#7C5CF5` |
| violetInk | `#4C1D95` | `#D7C6FF` |
| violetSoft | 12% violet wash | 14% violet wash |
| violetSoft2 | 20% violet wash | 22% violet wash |
| success dot | `#10B981` | `#10B981` |

### Tag colors — `tag_colors.dart`

Eight named tags with exact light fg/bg/dot values from the design; dark variants use the design's dark maps.

| Tag | fg (light) | bg (light) | dot |
|---|---|---|---|
| School | `#0E4B8C` | `#E4EFFC` | `#3B82F6` |
| Dev | `#0E5E3E` | `#DEF2E6` | `#10B981` |
| Projects | `#5B2A8C` | `#EEE4FB` | `#8B5CF6` |
| Career | `#8A4B0E` | `#FBEBD9` | `#F59E0B` |
| Ideas | `#8B2161` | `#FBE4EF` | `#EC4899` |
| Personal | `#4A4A55` | `#ECECEF` | `#6B7280` |
| Research | `#0D5E6B` | `#DEF1F4` | `#06B6D4` |
| Travel | `#8E1E3E` | `#FBDEE4` | `#F43F5E` |

**Free-form tags**: unknown tag names resolve deterministically to one of the 8 palettes via a stable hash of the name → consistent color per tag, per device and theme. API: `TagColors.resolve(name, Brightness) → (fg, bg, dot)`.

### Typography — `notely_typography.dart`

Three families bundled as assets (offline, no runtime fetch), declared in `pubspec.yaml`:

- **Geist** 400/500/600/700 — UI body, buttons, cards
- **Instrument Serif** regular + italic — display titles (serif headlines, "Your notes, …")
- **JetBrains Mono** 400/500 — metadata, mono labels

Fonts downloaded from Google Fonts into `assets/fonts/` during implementation.

### Theme builder — `notely_theme.dart`

Material `ThemeData` (light + dark) built from the extension: scaffold bg from tokens, card radius 18, input radius 14, sheets 24-top radius, checkbox/filter-chip styling matching the design.

### Shared widgets — `lib/core/theme/widgets/`

- `TagPill` — pill / dot / outlined styles (small + regular)
- `NotelyAvatar` — purple gradient circle + initial, optional violet ring
- `NotelyWordmark` — gradient "N" tile + "Notely" text
- `NotelySheet` — modal bottom-sheet container with grabber, 24px top radius

### Theme mode — persisted light/dark/system

- `themeModeProvider` (Riverpod) — `ThemeMode.light | dark | system`, default **system**
- Persisted via `shared_preferences` (new dependency, added to pubspec)
- `app.dart` uses the provider instead of hardcoded `ThemeMode.dark`
- **Fix**: remove the no-op `AppThemeScope` / `ThemeToggleButton` (`lib/features/settings/`) and replace their usages with the new provider + account sheet row. (Confirmed with user: fix broken toggles where found.)

## §2 Data Layer

### `Note` model (`lib/features/notes/data/note.dart`)

- Add `bool isArchived` (default `false`); serialized in `toMap` / `fromFirestore`; `copyWith` support.
- Existing notes without the field deserialize as `false` → no migration.

### `NotesService` (`lib/features/notes/data/notes_service.dart`)

- `setArchived(note, bool)` — toggle a single note
- Batch ops via Firestore `WriteBatch`: `archiveMany(notes)`, `deleteMany(notes)`, `setPinnedMany(notes, bool)`
- Archived notes excluded client-side from the home list (already-decrypted in memory — consistent with today's approach; no Firestore query change needed)

### Sort

- `enum NoteSort { updated, created, titleAZ, tag }`, applied in-memory after filtering. Default `updated`.
- Comparator implementations unit-testable.

### Palette hoisting

- The 6-color note palette duplicated in `notes_home_view.dart` and `note_editor_view.dart` moves to `lib/core/theme/note_palette.dart` (single definition, both consumers). Backwards-compatible with existing `colorIndex` data.

### Search

- Stays in-memory substring match on decrypted title/content/tags (current behavior). FTS wiring remains a separate, pre-existing "Phase 2" effort — out of scope.

## §3 Notes List Screen (`lib/features/notes/presentation/`)

`notes_home_view.dart` rewritten as small widgets: `notes_home_view.dart`, `widgets/note_card.dart`, `widgets/list_header.dart`, `widgets/home_fab.dart`, `widgets/empty_state.dart`.

- **Header row**: Notely wordmark; right = select-mode toggle (✓ circle button) + gradient avatar with violet ring → opens account sheet.
- **Serif display title**: `Your notes,` (ink serif) + first name (italic violet serif) from auth profile; fallbacks: email prefix → `Your notes.` Below: green success dot + `N notes · synced to Firestore`.
- **Search bar**: surface, radius 14, placeholder `Search notes, tags, content…`, clear (✕) when non-empty. (No `⌘K` badge — desktop-web affordance, dropped on mobile.)
- **Filter chips + sort**: `All` / `Pinned` (live count) / `Recent` (updated within the last 24h, based on `updatedAt`); active chip violet-filled. Sort dropdown (`Updated` / `Created` / `Title A–Z` / `Tag`) in a floating menu with checkmark on current.
- **Sections**: `Pinned` (filled pin icon, uppercase label, count, hairline divider) then `All notes`; each a column of cards, 12px gaps (cozy density).
- **Note card**: surface + hairline border, radius 18, cozy padding (14/16). Title 15.5 / w600, 2-line clamp, pin toggle top-right (violet filled when pinned, grey outline when not). Preview 13.25 / text3, 2-line clamp — existing `[[wiki-link]]` parsing **kept**, link color changed from `#8AA7FF` to violetInk. Footer: small tonal `TagPill`s (Wrap) + relative time (existing relative-time formatter reused).
- **Status tweaks** (per "tweak as needed"): locked / self-destruct / read-once / shared become small icons before the time label (replaces old status chips; keeps info, cleaner card). Tapping a tag pill focuses that tag (existing context-switcher behavior → restyled `Focus: {tag}` bar under the header with clear ✕).
- **Swipe-to-archive**: left swipe reveals red-gradient Archive action; snaps past 72px threshold; fires archive → toast `Note archived · Undo` (240ms slide-in, auto-dismiss ~2.4s).
- **Multi-select**: header toggle enters select mode → violet-soft bar `N selected` + Pin / Archive / Delete (delete keeps confirm dialog). Cards show round checkboxes + violet outline. FAB hidden in select mode.
- **FAB**: centered bottom pill — 135° violet→violetDeep gradient, `+` in frosted inner circle, `New note`, violet glow. Opens existing full-screen editor.
- **Empty state**: stacked-cards illustration, serif headline (`A blank page awaits.` / `No notes match "…"`), `Start writing` violet button (hidden for search-empty).
- **Preserved plumbing**: merged own + shared notes stream, locked-note routing through `LockScreen`, error/loading states (restyled).

## §4 Account Sheet + Archived View (`lib/features/account/`)

- **Account sheet** (modal bottom sheet, design style):
  - Grabber; profile row (48px gradient avatar, display name, email)
  - Sync card: cloud icon in green wash, `Synced to Firestore`, `{n} notes · just now`
  - Rows: **Appearance** (detail = current Light/Dark/System, cycles) → `themeModeProvider`; **Study cards** (detail = due count) → pushes existing `ReviewView`; **Archive** (detail = archived count) → pushes Archived view; **Sign out** (red) → existing `logOut()`
  - Dropped: `Preferences`, `What's new`, `Pro` (no such features — YAGNI)
  - Moves the study + sign-out entry points out of the old app bar into the sheet
- **Archived view** (new, small): same list styling; archived notes; unarchive (with undo toast) + delete-forever. Ensures archive is not a black hole.

## §5 Editor Restyle (`note_editor_view.dart`)

Visual translation only; all functionality unchanged (OCR, mic, location, lock, self-destruct, share, version history, `[[links]]` autocomplete, color labels, audio attachments, map preview, backlinks, comments, save).

- Title field → Instrument Serif 30, `Title` placeholder (compose-sheet look); content → Geist 15 / line-height 1.5
- Containers → surface + hairline border, radius 18 on theme bg; AppBar transparent, circle icon buttons
- Tags → outlined `TagPill`s; tags dialog, self-destruct sheet, share sheet → Notely bottom sheets
- Pin/Study chips → design filter-chip style; color-label picker kept, restyled container
- Save → violet gradient pill; comments/backlinks as surface cards
- **Skipped**: B/I/U formatting strip (plain-text/markdown editor; rich text is separate large feature — YAGNI)

## §6 Secondary Screens (same language, unchanged layouts)

Mechanical restyle to tokens — no layout inventions:

- **Auth** (login / register / verify): Notely bg, wordmark + serif headline, inputs radius 14, violet gradient primary button, violetInk links
- **LockScreen**: serif heading, restyled PIN field + numpad, violet biometric button
- **Study `ReviewView`**: flashcard → surface card radius 18; SM-2 answer buttons → tonal pills; progress in violet
- **`VersionHistoryView`**: surface rows, violetInk restore actions
- **Context switcher sheet**: Notely sheet; tag rows with colored dot + count
- Delete old `TagChip` / `InfoChip` once unused; remove no-op `ThemeToggleButton` / `AppThemeScope`

## §7 Error Handling & Testing

### Error handling

- Keep existing `.when(error:)` stream handling, restyled with retry
- Archive/delete failures: revert optimistic UI + error toast
- Delete keeps restyled confirm dialog

### Testing

- **Unit**: `TagColors.resolve` deterministic hash; `Note.isArchived` round-trip + `copyWith`; sort comparators; theme-mode persistence (mocked `shared_preferences`)
- **Widget**: home list (pinned-first, chip filters, search, multi-select bar, swipe→archive→undo); account sheet rows; archived-view unarchive
- Existing suite stays green (tags, search, auth, lock, crypto, etc.)
- `flutter analyze` clean

### Manual verification

- Run on Windows + Android emulator; toggle light/dark across every screen; archive/undo flow; locked-note routing; shared notes.

## Scope Boundaries

**In**: design system, theme-mode persistence + toggle fix, notes list rebuild, account sheet, archived view, editor restyle, secondary screen restyles, data-layer archive/sort additions, tag-color system, fonts.

**Out**: rich-text editing (B/I/U), FTS search wiring, trash/soft-delete beyond archive, new note model fields beyond `isArchived`, `Pro`/billing concepts, per-screen redesigns beyond the design language (layouts are preserved).
