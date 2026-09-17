# Mavro Keyboard

A native **Apple-Silicon** Bengali (Bangla) input method for macOS — a future-proof
replacement for the unmaintained, Intel-only **iAvro**. Mavro brings Avro Phonetic
typing to macOS as a native `arm64` InputMethodKit app, so it stays first-class as
Apple winds Rosetta down.

> Status: **v0.2.0** — Avro Phonetic input with iAvro-style, Preview and Raw modes. See [Roadmap](#roadmap).

## Why

iAvro is an Intel-only build that runs on Apple Silicon only via Rosetta, which Apple
is deprecating. Mavro is built natively and reuses the proven, maintained
[`riti`](https://github.com/OpenBangla/riti) engine (MPL-2.0) that also powers
OpenBangla Keyboard (Linux) and Lekho (macOS), so the hard linguistic logic — Avro
Phonetic transliteration, the dictionary, and autocorrect — is battle-tested rather
than re-derived.

## Features

- **Avro Phonetic** typing (type Bangla in Roman letters), with three modes:
  - **iAvro style** (default) — behaves like [iAvro](https://github.com/torifat/iAvro):
    the typed English stays inline (underlined) while Bangla suggestions show in a
    plain list; ↑/↓ choose, Space/Return commit, digits are typed into the word.
    ←/→ commit and move the caret, and clicking away commits the Bangla word —
    deliberate fixes over iAvro, which swallowed ←/→ and committed the English.
  - **Preview** — the Bangla word inline, numbered suggestions (Tab / 1–9) that
    also offer the typed English.
  - **Raw** — deterministic, as-typed transliteration with no autocorrect:
    `sonar → সনার`, `sOnar → সোনার`, `mon → মন`, `moN → মণ`.
  - Cycle modes with **⌘⇧M** (or the menu-bar **ম** menu). iAvro style and
    Preview share riti's suggestion engine, whose ordering is a port of iAvro's
    (autocorrect → dictionary by edit distance → suffixes → phonetic, with
    remembered picks); they differ only in presentation and keys.
- **Output encoding** (Avro's "ASCII" output): **⌘⇧E** cycles **Unicode → ANSI
  (SutonnyMJ/classic Bijoy) → ANSI (Kalpurush)**. riti always produces Unicode;
  the committed text is converted to the chosen layout on commit.
- **⌘⇧M / ⌘⇧E work only while Mavro is the active input method** (system-level
  hotkeys), so they never disturb apps' normal ⌘-shortcuts in other input sources.
- **Return** commits the in-progress word *and* sends/newlines in one press.
- On-screen flash confirms each mode/encoding switch (works even when the menu-bar
  icon is hidden behind the notch).
- Custom candidate window (keyboard + mouse selectable).
- **Tools**
  - **Character Map** — click Bengali glyphs to insert them.
  - **Unicode ↔ ANSI (Bijoy) Converter** with a target selector:
    - **SutonnyMJ / classic Bijoy** — both directions (Unicode↔Bijoy), ported from
      the verified bijoyconverter.com mapping plus the fixes from the
      ANSI-Unicode-Doc-Converter project (ro-fola `Ö`, word-initial `†`/`ˆ`,
      legacy-glyph patches and kar/reph reordering). The port is byte-identical
      to that project's `convert.js` over ~160k words each way.
    - **Kalpurush ANSI** — Unicode→ANSI (via `poriborton`); reverse not available.
    - Output pane previews in the matching font (SutonnyMJ / Kalpurush ANSI).

## Architecture

```
Mavro.app (~/Library/Input Methods/)
  Swift InputMethodKit layer  ──C FFI──►  libmavro_engine.a  ──►  riti (Rust)
```

- `engine/` — Rust crate wrapping `riti`; builds a static lib + C header
  (`mavro_keycode_for_char` + all `riti_*` FFI). Mode toggle maps to riti's
  `phonetic_suggestion` flag.
- `Sources/` — Swift IMK layer: `MavroInputController` (key handling),
  `CandidatePanel` (custom NSPanel), `StatusMenu`, `InputMode`, and `Tools/`.
- `Resources/` — `Info.plist`, entitlements, and the `data/` dictionary files.

Builds with `swiftc` + `cargo` (no Xcode project required).

## Build & install

Requirements: macOS 13+ on Apple Silicon, Rust (`cargo`), and the Xcode Command
Line Tools.

```sh
make install        # build + ad-hoc sign + copy to ~/Library/Input Methods, then launch
```

Then add it: **System Settings → Keyboard → Input Sources → Edit… → +**, pick
**Mavro** (under Bangla), and switch with the Globe/Fn key or Ctrl-Space. On a
first-ever install you may need to log out and back in so macOS registers it.
(`Mavro.app/Contents/MacOS/Mavro --install` registers and enables the input
source without either step; the DMG installer runs it.)

Other targets: `make build`, `make build-debug`, `make uninstall`, `make clean`.

### Shareable installer

`make dmg` builds `build/Mavro-Installer-<version>.dmg` — a disk image with `Mavro.app`, a
double-click **Install Mavro.command**, a Read Me, and font licenses. The app
bundles a set of free/open Bengali fonts (Ekushey Kalpurush/Siyam Rupali +
their ANSI variants, and OFL Google fonts: Noto Sans/Serif Bengali, Anek Bangla,
Baloo Da 2, Hind Siliguri, Tiro Bangla, Atma, Mina); the installer also copies
them to `~/Library/Fonts`. **SutonnyMJ is not bundled** (proprietary Bijoy font);
the open **Kalpurush ANSI** is, for a fully-open ANSI workflow. The build is
ad-hoc signed (not notarized), and macOS 15+ no longer allows right-click → Open
for such files, so the Read Me gives two ways in: run the installer through
`bash` in Terminal (no prompt), or double-click and approve it under
**Privacy & Security → Open Anyway**. The installer strips the quarantine flag
from the app and fonts it copies, then runs `Mavro --install`.

## Verify

```sh
bash scripts/test_engine.sh   # Raw-mode conversions, SutonnyMJ output, iAvro-style inline text
```

## Roadmap

- Notarized signed distribution (DMG) once feature-complete.
- Polish: preferences, mode-toggle hotkey, menu-bar icon asset.

## License & credits

[MPL-2.0](LICENSE). Built on [`riti`](https://github.com/OpenBangla/riti) by the
OpenBangla project. The macOS InputMethodKit integration patterns (riti FFI
driving, candidate window, cursor-rect fallbacks) are adapted from
[Lekho](https://github.com/ARahim3/Lekho) (MPL-2.0).
